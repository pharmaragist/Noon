import json
import os
import sys

CONF_PATH = os.path.expanduser("~/.noon/user/beats.json")


def load_conf() -> dict:
    try:
        with open(CONF_PATH) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError, IOError):
        return {}


def _write(data: dict):
    os.makedirs(os.path.dirname(CONF_PATH), exist_ok=True)
    with open(CONF_PATH, "w") as f:
        json.dump(data, f, indent=4)


def conf_require(*keys: str) -> dict:
    conf = load_conf()
    missing = [k for k in keys if not conf.get(k)]
    if missing:
        print(f"beats.json missing: {', '.join(missing)} — run 'beats init' or set via shell", file=sys.stderr)
        sys.exit(1)
    return conf
