#!/usr/bin/env python3
"""Apply or check the recorded Cinnamon settings.

  settings.py apply   load dconf.ini and merge applets.json into the applets'
                      settings files
  settings.py check   report recorded values that differ; exit 1 if any do

dconf.ini holds dconf keys (panels and their applets). applets.json maps
"<applet uuid>/<instance id>" to the settings recorded for that applet
instance; other settings in the instance's file are left alone.
"""
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


def check():
    differences = []
    for path, value in recorded_dconf():
        current = subprocess.run(["dconf", "read", path], capture_output=True,
                                 text=True, check=True).stdout.strip()
        if current != value:
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
    if sys.argv[1:] == ["apply"]:
        # Applet files first so panels load with their recorded settings.
        apply_applets()
        with open(os.path.join(HERE, "dconf.ini")) as f:
            subprocess.run(["dconf", "load", "/"], stdin=f, check=True)
        return 0
    if sys.argv[1:] == ["check"]:
        return check()
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
