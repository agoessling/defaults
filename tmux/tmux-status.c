#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <limits.h>
#include <errno.h>

/* One long-running tmux #() job. No subprocesses or writable state files. */
typedef unsigned long long U64;
struct sample { U64 total, idle, rx, tx; double when; char iface[64]; int cpu_ok, net_ok; };
static volatile sig_atomic_t stopped;
static void stop(int sig) { (void)sig; stopped = 1; }
static double monotime(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static int counter(const char *iface, const char *name, U64 *value) {
    char path[256];
    snprintf(path, sizeof path, "/sys/class/net/%s/statistics/%s", iface, name);
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    int ok = fscanf(f, "%llu", value) == 1;
    fclose(f);
    return ok;
}
static void interface(char *out, const char *requested) {
    out[0] = 0;
    if (*requested) { snprintf(out, 64, "%s", requested); return; }
    FILE *f = fopen("/proc/net/route", "r");
    if (!f) return;
    char line[512], name[64]; unsigned long dest, metric, best = ULONG_MAX;
    while (fgets(line, sizeof line, f)) {
        if (sscanf(line, "%63s %lx %*s %*s %*s %*s %lu", name, &dest, &metric) == 3 &&
            dest == 0 && metric < best) {
            best = metric; snprintf(out, 64, "%s", name);
        }
    }
    fclose(f);
    /* Same fallback as the shell collector when no IPv4 default exists. */
    if (!*out) {
        f = fopen("/proc/net/dev", "r");
        if (!f) return;
        while (fgets(line, sizeof line, f)) {
            char *colon = strchr(line, ':');
            if (!colon) continue;
            *colon = 0;
            if (sscanf(line, "%63s", name) != 1 || !strcmp(name, "lo")) continue;
            char path[256], state[32];
            snprintf(path, sizeof path, "/sys/class/net/%s/operstate", name);
            FILE *s = fopen(path, "r");
            if (!s) continue;
            int ok = fscanf(s, "%31s", state) == 1;
            fclose(s);
            if (ok && (!strcmp(state, "up") || !strcmp(state, "unknown"))) {
                snprintf(out, 64, "%s", name); break;
            }
        }
        fclose(f);
    }
}
static struct sample sample(const char *requested, char *memory) {
    struct sample s = {0};
    U64 v[8] = {0};
    FILE *f = fopen("/proc/stat", "r");
    if (f) {
        s.cpu_ok = fscanf(f, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
            &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6], &v[7]) == 8;
        fclose(f);
        for (int i = 0; i < 8; i++) s.total += v[i];
        s.idle = v[3] + v[4];
    }
    strcpy(memory, "--%");
    f = fopen("/proc/meminfo", "r");
    if (f) {
        char line[256]; U64 total = 0, available = 0; int have = 0;
        while (fgets(line, sizeof line, f)) {
            if (sscanf(line, "MemTotal: %llu", &total) == 1) have |= 1;
            if (sscanf(line, "MemAvailable: %llu", &available) == 1) have |= 2;
        }
        fclose(f);
        if (have == 3 && total && available <= total)
            snprintf(memory, 16, "%.0f%%", 100.0 * (total - available) / total);
    }
    interface(s.iface, requested);
    s.net_ok = *s.iface && counter(s.iface, "rx_bytes", &s.rx) && counter(s.iface, "tx_bytes", &s.tx);
    s.when = monotime();
    return s;
}
static void rate(char *out, double value) {
    const char *units = "BKMGTP";
    int u = 0;
    while (value >= 1024 && u < 5) { value /= 1024; u++; }
    snprintf(out, 32, (!u || value >= 100) ? "%4.0f%c" : "%4.1f%c", value, units[u]);
}
int main(int argc, char **argv) {
    const char *program = argv[0];
    int once = argc > 1 && !strcmp(argv[1], "--once");
    if (once) { argc--; argv++; }
    if (argc != 2 && argc != 3) {
        fprintf(stderr, "Usage: %s [--once] host [interface]\n", program);
        return 2;
    }
    signal(SIGTERM, stop); signal(SIGINT, stop);
    setvbuf(stdout, NULL, _IOLBF, 0);
    struct sample previous = {0};
    while (!stopped) {
        char memory[16], cpu[16] = "--%", rx[32] = "--", tx[32] = "--";
        struct sample now = sample(argc == 3 ? argv[2] : "", memory);
        if (now.cpu_ok && previous.cpu_ok && now.total > previous.total && now.idle >= previous.idle) {
            U64 total = now.total - previous.total, idle = now.idle - previous.idle;
            if (idle <= total) snprintf(cpu, sizeof cpu, "%.0f%%", 100.0 * (total - idle) / total);
        }
        if (!now.net_ok) { strcpy(rx, "n/a"); strcpy(tx, "n/a"); }
        else if (previous.net_ok && !strcmp(now.iface, previous.iface) && now.rx >= previous.rx && now.tx >= previous.tx && now.when > previous.when) {
            rate(rx, (now.rx - previous.rx) / (now.when - previous.when));
            rate(tx, (now.tx - previous.tx) / (now.when - previous.when));
        }
        time_t epoch = time(NULL); struct tm local; char date[64];
        localtime_r(&epoch, &local); strftime(date, sizeof date, "%Y-%m-%d %H:%M:%S", &local);
        printf(" %4s CPU │ %4s MEM │ %5s↓ %5s↑ │ %s %s \n",
               cpu, memory, rx, tx, date, argv[1]);
        if (ferror(stdout) || once) break;
        previous = now;
        struct timespec deadline;
        clock_gettime(CLOCK_MONOTONIC, &deadline); deadline.tv_sec++;
        /* Interruptible absolute sleep avoids a busy loop after signals. */
        while (!stopped && clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &deadline, NULL) == EINTR) {}
    }
    return 0;
}
