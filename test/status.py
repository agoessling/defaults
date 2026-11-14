#!/usr/bin/env python3
"""Build and test the status worker using an isolated tmux server and PTYs."""
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

def check_output(binary):
    args = ['host', '']

    def launch(arguments):
        return subprocess.Popen([binary, *arguments], stdout=subprocess.PIPE, text=True)

    def stop(process):
        process.terminate()
        assert process.wait(timeout=2) == 0

    p = launch(args)
    try:
        first = p.stdout.readline()
        second = p.stdout.readline()
        assert '--% CPU' in first
        assert '--% CPU' not in second
        assert 'MEM' in second and 'host' in second
        assert len(first) == len(second)
        for marker in ('CPU', 'MEM', '↓', '↑', 'host'):
            assert first.index(marker) == second.index(marker)
    finally:
        stop(p)

    # tmux omits the empty optional interface argument after shell expansion.
    p = launch(args[:-1])
    try:
        assert 'MEM' in p.stdout.readline()
    finally:
        stop(p)

    # Broken output pipes must not leave an orphaned collector.
    p = launch(args)
    p.stdout.close()
    assert p.wait(timeout=3) in (0, -13)

    invalid_interface = subprocess.run([binary, '--once', *args[:-1], 'missing-interface'],
                                       capture_output=True, text=True, timeout=3, check=True)
    assert 'n/a' in invalid_interface.stdout

    bad = subprocess.run([binary, 'host', 'interface', 'extra'], capture_output=True)
    assert bad.returncode == 2

ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix='defaults-status-') as directory:
    directory = Path(directory)
    binary = directory / 'status'
    subprocess.run(['bash', str(ROOT / 'tmux/build-status.sh'), str(binary)], check=True)
    # A second build should leave the same inode: no needless replacements.
    inode = binary.stat().st_ino
    subprocess.run(['bash', str(ROOT / 'tmux/build-status.sh'), str(binary)], check=True)
    assert binary.stat().st_ino == inode
    failed = subprocess.run(['bash', str(ROOT / 'tmux/build-status.sh'), str(binary)],
                            env=dict(os.environ, CC='/bin/false'), capture_output=True)
    assert failed.returncode != 0 and binary.stat().st_ino == inode
    assert not list(directory.glob('status.*')), 'Failed build left temporary output'
    check_output(binary)
    config = directory / 'tmux.conf'
    config.write_text((ROOT / 'tmux/tmux-colorscheme.conf').read_text().replace(
        '~/.tmux/tmux-status-right', str(binary)))
    socket = str(directory / 'socket')
    clients = []

    def tmux(*args):
        return subprocess.check_output(['tmux', '-S', socket, *args], text=True)

    def collectors():
        found = set()
        for proc in Path('/proc').iterdir():
            if proc.name.isdigit():
                try:
                    if os.readlink(proc / 'exe') == str(binary):
                        found.add(int(proc.name))
                except (FileNotFoundError, PermissionError, ProcessLookupError):
                    pass
        return found

    def pump(seconds):
        output = b''
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            fds = [fd for process, fd in clients if process.poll() is None]
            ready, _, _ = select.select(fds, [], [], 0.05)
            for fd in ready:
                try:
                    output += os.read(fd, 65536)
                except OSError:
                    pass
        return output

    def expect_count(count):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            pump(0.1)
            if len(collectors()) == count:
                return
        raise AssertionError(f'Expected {count} collectors, found {collectors()}')

    def resize(client, width):
        process, fd = client
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 30, width, 0, 0))
        process.send_signal(signal.SIGWINCH)

    def attach(first=False):
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 200, 0, 0))
        command = ['tmux', '-S', socket, '-f', str(config)]
        command += ['new-session', '-s', 'probe', '/bin/sh'] if first else ['attach-session', '-t', 'probe']
        process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave,
                                   env=dict(os.environ, TERM='xterm-256color', NO_TMUX='1'))
        os.close(slave)
        client = process, master
        clients.append(client)
        return client

    try:
        first = attach(first=True)
        rendered = pump(2.5)
        assert b'CPU' in rendered and b'MEM' in rendered
        expect_count(1)
        crashed = collectors().pop()
        os.kill(crashed, signal.SIGKILL)
        pump(2)
        expect_count(1)
        assert crashed not in collectors(), 'Crashed collector was not restarted'
        original = collectors()
        for width in (140, 100, 40, 200):
            resize(first, width)
            pump(1.2)
            assert tmux('display-message', '-p', '#{client_width}').strip() == str(width)
            expect_count(1)
            assert collectors() == original, 'Resize restarted the fixed status worker'
        tmux('new-window', '-d', '-t', 'probe', '/bin/sh')
        pump(1.2)
        assert collectors() == original, 'Window list change restarted the worker'
        second = attach()
        pump(2)
        expect_count(2)
        # Detach only the second client, then reattach it.
        names = tmux('list-clients', '-F', '#{client_name}').splitlines()
        tmux('detach-client', '-t', names[-1])
        pump(1)
        expect_count(1)
        third = attach()
        pump(2)
        expect_count(2)
        for name in tmux('list-clients', '-F', '#{client_name}').splitlines():
            tmux('detach-client', '-t', name)
        pump(1)
        expect_count(0)
        attach()
        pump(2)
        expect_count(1)
        tmux('kill-server')
        expect_count(0)
        print('PASS: build safety, fixed output, worker lifetime, and crash recovery.')
    finally:
        subprocess.run(['tmux', '-S', socket, 'kill-server'], capture_output=True)
        for process, fd in clients:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=3)
            os.close(fd)
