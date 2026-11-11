#!/usr/bin/env python3
"""Apply or check the recorded Cinnamon settings.

  settings.py apply   load dconf.ini and merge applets.json into the applets'
                      settings files
  settings.py check   report recorded values that differ; exit 1 if any do
  settings.py scale --scale 100   change only linked text/panel/cursor size
  settings.py get-scale           print the saved percentage (default 100)

dconf.ini holds dconf keys (panels and their applets). applets.json maps
"<applet uuid>/<instance id>" to the settings recorded for that applet
instance; other settings in the instance's file are left alone.
"""
import argparse
import ast
import configparser
import hashlib
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
SPICES_DIR = os.path.join(CONFIG_DIR, "cinnamon", "spices")
APPLET_DIRS = [
    os.path.expanduser("~/.local/share/cinnamon/applets"),
    "/usr/share/cinnamon/applets",
]


SCALE_FILE = os.path.join(CONFIG_DIR, "defaults", "cinnamon-scale")


def scale_percent(value):
    try:
        percent = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError("scale must be a whole percentage (50–200)")
    if not 50 <= percent <= 200:
        raise argparse.ArgumentTypeError("scale must be between 50 and 200")
    return percent


def saved_scale():
    if os.path.exists(SCALE_FILE):
        with open(SCALE_FILE) as f:
            return scale_percent(f.read().strip())
    return 100


def scaling_values(percent):
    """Scale the recorded 125% layout, preserving automatic sizes (zero)."""
    factor = percent / 125
    for path, value in recorded_dconf():
        key = path.rsplit("/", 1)[1]
        if key == "text-scaling-factor":
            yield path, str(percent / 100)
        elif key == "cursor-size":
            yield path, str(round(int(value) * factor))
        elif key == "panels-height":
            heights = ast.literal_eval(value)
            yield path, repr([f"{panel}:{round(int(height) * factor)}"
                              for panel, height in (entry.split(":") for entry in heights)])
        elif key in ("panel-zone-icon-sizes", "panel-zone-symbolic-icon-sizes",
                     "panel-zone-text-sizes"):
            zones = json.loads(ast.literal_eval(value))
            for zone in zones:
                for name in ("left", "center", "right"):
                    zone[name] = round(zone[name] * factor)
            yield path, repr(json.dumps(zones, separators=(",", ":")))


def effective_dconf(percent):
    overrides = dict(scaling_values(percent))
    for path, value in recorded_dconf():
        yield path, overrides.get(path, value)


def apply_scale(percent):
    for path, value in scaling_values(percent):
        subprocess.run(["dconf", "write", path, value], check=True)
    os.makedirs(os.path.dirname(SCALE_FILE), exist_ok=True)
    with open(SCALE_FILE, "w") as f:
        f.write(f"{percent}\n")


def recorded_dconf():
    """Yield (path, value) for each key in dconf.ini, values as GVariant text."""
    parser = configparser.RawConfigParser(delimiters=("=",))
    parser.optionxform = str
    parser.read(os.path.join(HERE, "dconf.ini"))
    for section in parser.sections():
        for key, value in parser.items(section):
            yield f"/{section}/{key}", value


def recorded_applets():
    with open(os.path.join(HERE, "applets.json")) as f:
        return json.load(f)


def read_json(path):
    # Cinnamon occasionally leaves trailing bytes after the object.
    with open(path) as f:
        return json.JSONDecoder().raw_decode(f.read())[0]


def new_instance(uuid):
    """Build an instance file the way Cinnamon installs one from its schema."""
    for applet_dir in APPLET_DIRS:
        schema_path = os.path.join(applet_dir, uuid, "settings-schema.json")
        if os.path.exists(schema_path):
            break
    else:
        raise SystemExit(f"Applet not installed: {uuid}")
    with open(schema_path, "rb") as f:
        schema_text = f.read()
    data = json.loads(schema_text)
    for props in data.values():
        if isinstance(props, dict) and "type" in props and "default" in props:
            props["value"] = props["default"]
    # A matching checksum tells Cinnamon the file is current for this schema.
    data["__md5__"] = hashlib.md5(schema_text).hexdigest()
    return data


def apply_applets():
    for instance, settings in recorded_applets().items():
        uuid, instance_id = instance.split("/")
        path = os.path.join(SPICES_DIR, uuid, f"{instance_id}.json")
        data = read_json(path) if os.path.exists(path) else new_instance(uuid)
        changed = not os.path.exists(path)
        for key, value in settings.items():
            if key not in data:
                raise SystemExit(f"{instance} has no setting {key}")
            if data[key].get("value") != value:
                data[key]["value"] = value
                changed = True
        if changed:
            # Cinnamon watches this file and reloads the applet on change.
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                json.dump(data, f, indent=4)
            print(f"Updated: {path}")


def check(percent):
    differences = []
    for path, value in effective_dconf(percent):
        current = subprocess.run(["dconf", "read", path], capture_output=True,
                                 text=True, check=True).stdout.strip()
        # Compare structured variants independently of JSON whitespace.
        if "panel-zone-" in path and current:
            matches = json.loads(ast.literal_eval(current)) == json.loads(ast.literal_eval(value))
        else:
            matches = current == value
        if not matches:
            differences.append(f"{path}: expected {value}, got {current or 'unset'}")
    for instance, settings in recorded_applets().items():
        uuid, instance_id = instance.split("/")
        path = os.path.join(SPICES_DIR, uuid, f"{instance_id}.json")
        data = read_json(path) if os.path.exists(path) else {}
        for key, value in settings.items():
            current = data.get(key, {}).get("value")
            if current != value:
                differences.append(f"{instance} {key}: expected {value}, got {current}")
    for difference in differences:
        print(difference)
    return 1 if differences else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("apply", "check", "scale", "get-scale"))
    parser.add_argument("--scale", type=scale_percent, help="linked size percentage (50–200)")
    args = parser.parse_args()
    percent = args.scale if args.scale is not None else saved_scale()
    if args.command == "get-scale":
        print(percent)
    elif args.command == "scale":
        apply_scale(percent)
    elif args.command == "apply":
        # Applet files first so panels load with their recorded settings.
        apply_applets()
        sections = configparser.RawConfigParser(delimiters=("=",))
        sections.optionxform = str
        for path, value in effective_dconf(percent):
            section, key = path.lstrip("/").rsplit("/", 1)
            if not sections.has_section(section):
                sections.add_section(section)
            sections.set(section, key, value)
        import io
        output = io.StringIO()
        sections.write(output)
        subprocess.run(["dconf", "load", "/"], input=output.getvalue(), text=True, check=True)
        apply_scale(percent)
    else:
        return check(percent)
    return 0


if __name__ == "__main__":
    sys.exit(main())
