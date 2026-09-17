#!/usr/bin/env python3
"""Install the KDE extension and replace Solaar's Haptic → Alt+Tab rule."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import yaml  # Already installed with Solaar.


def install():
    source = Path(__file__).resolve().parent
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    rules_path = config / "solaar/rules.yaml"
    original = rules_path.read_text() if rules_path.exists() else ""
    documents = list(yaml.safe_load_all(original)) if original else []
    command = ["/usr/bin/qdbus6", "org.kde.kglobalaccel", "/component/kwin", "invokeShortcut", "MXRingToggle"]
    rule = [{"Key": ["Haptic", "pressed"]}, {"Execute": command}]
    old_rule = [{"Key": ["Haptic", "pressed"]}, {"KeyPress": [["Alt_L", "Tab"], "click"]}]
    if old_rule in documents:
        documents[documents.index(old_rule)] = rule
    elif rule not in documents:
        if "Haptic" in original:
            raise SystemExit("Another Haptic rule exists. Review it before replacing it with the rule in README.md.")
        documents.insert(0, rule)

    # Install only the extension, not the installer and development checks.
    with tempfile.TemporaryDirectory(prefix="mx-ring-") as staging:
        package = Path(staging)
        shutil.copy2(source / "metadata.json", package)
        shutil.copytree(source / "contents", package / "contents")
        operation = "--upgrade" if (data / "kwin/scripts/mx-ring").exists() else "--install"
        subprocess.run(["kpackagetool6", "--type", "KWin/Script", operation, str(package)], check=True)
    subprocess.run(["kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key", "mx-ringEnabled", "true"], check=True)

    rules_path.parent.mkdir(parents=True, exist_ok=True)
    backup = rules_path.with_name("rules.yaml.before-mx-ring")
    if rules_path.exists() and not backup.exists():
        shutil.copy2(rules_path, backup)
    updated = "%YAML 1.3\n" + yaml.safe_dump_all(documents, explicit_start=True, explicit_end=True, sort_keys=False)
    with tempfile.NamedTemporaryFile("w", dir=rules_path.parent, delete=False) as temporary:
        temporary.write(updated)
    os.replace(temporary.name, rules_path)

    active = subprocess.run(["qdbus6", "org.kde.KWin", "/KWin"], capture_output=True).returncode == 0
    if active:
        subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "unloadScript", "mx-ring"], capture_output=True)
        subprocess.run(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], check=True)
        print("Installed. Restart Solaar to load the new mouse rule. Press Meta+Alt+Space to try the wheel.")
    else:
        print("Installed and enabled for your next KDE login. Solaar will load the new rule when it starts.")
    print(f"Original Solaar rules: {backup}")


if __name__ == "__main__":
    install()
