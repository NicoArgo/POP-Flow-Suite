#!/usr/bin/env bash
# POP Flow — put the suite on the desktop: panel buttons and keyboard shortcuts.
#
# The component installers only install; they never rewrite your panel or your
# shortcuts. This does, once, so a fresh install looks like the author's:
#
#   panel, left:   show desktop, Pictures, Downloads   (after what's there)
#   panel, right:  vampire mode                         (first in the group)
#   Super+D        show desktop (this screen, or all — the corner's setting)
#   Super+V        clipboard history (only if cosmic-clipboard-history is in)
#
# Safe to run again: anything already present is left alone, and a shortcut
# key that is already bound to something else is skipped, not taken over.
# Every file it changes is backed up first under ~/.local/state/pop-flow/.
# Undo: copy the backup back over the file (paths are printed).
set -euo pipefail

COSMIC="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/pop-flow/desktop-backup-$(date +%Y%m%d-%H%M%S)"

have_clipboard=0
if command -v cosmic-clipboard-history >/dev/null || [ -x "$HOME/.local/bin/cosmic-clipboard-history" ]; then
    have_clipboard=1
fi

COSMIC="$COSMIC" BACKUP="$BACKUP" HAVE_CLIPBOARD="$have_clipboard" python3 - <<'PYEOF'
import os, re, shutil

cosmic = os.environ["COSMIC"]
backup = os.environ["BACKUP"]
have_clipboard = os.environ["HAVE_CLIPBOARD"] == "1"

def save_backup(path):
    if os.path.exists(path):
        os.makedirs(backup, exist_ok=True)
        dest = os.path.join(backup, os.path.relpath(path, cosmic).replace("/", "__"))
        shutil.copy2(path, dest)
        print(f"    backup: {dest}")

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".pop-flow-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)

# --- panel ---------------------------------------------------------------------
wings = os.path.join(cosmic, "com.system76.CosmicPanel.Panel/v1/plugins_wings")
source = wings if os.path.exists(wings) else \
    "/usr/share/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"
try:
    text = open(source, encoding="utf-8").read()
    lists = re.findall(r"\[(.*?)\]", text, re.S)
    if text.strip().startswith("None") or len(lists) < 2:
        raise ValueError("no panel wings configured")
    left, right = ([re.findall(r'"([^"]+)"', l) for l in lists[:2]])
    added = []
    for applet in ["com.popflow.CosmicAppletShowDesktop",
                   "com.popflow.CosmicAppletPicturesFolder",
                   "com.popflow.CosmicAppletDownloadsFolder"]:
        if applet not in left and applet not in right:
            left.append(applet); added.append(applet)
    if "com.popflow.CosmicAppletVampire" not in left + right:
        right.insert(0, "com.popflow.CosmicAppletVampire")
        added.append("com.popflow.CosmicAppletVampire")
    if added:
        save_backup(wings)
        fmt = lambda xs: "".join(f'    "{x}",\n' for x in xs)
        write(wings, f"Some(([\n{fmt(left)}], [\n{fmt(right)}]))\n")
        print("    panel: added " + ", ".join(a.split(".")[-1] for a in added))
    else:
        print("    panel: POP Flow buttons already there")
except Exception as err:
    print(f"    !! panel left alone ({err}); add the buttons in Settings -> Desktop -> Panel")

# --- shortcuts -----------------------------------------------------------------
custom = os.path.join(cosmic, "com.system76.CosmicSettings.Shortcuts/v1/custom")
defaults = "/usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/defaults"
text = open(custom, encoding="utf-8").read() if os.path.exists(custom) else "{\n}"
stock = open(defaults, encoding="utf-8").read() if os.path.exists(defaults) else ""

def bound(ron, key):
    # Super alone on this key, in COSMIC's RON layout.
    return re.search(r'modifiers:\s*\[\s*Super\s*,?\s*\]\s*,\s*key:\s*"%s"' % key, ron) is not None

wanted = [("d", "cosmic-applet-show-desktop --toggle", "show desktop")]
if have_clipboard:
    wanted.append(("v", "cosmic-launcher input 'cb '", "clipboard history"))

entries = ""
for key, command, what in wanted:
    if command in text:
        print(f"    Super+{key.upper()}: already {what}")
    elif bound(text, key) or bound(stock, key):
        print(f"    !! Super+{key.upper()} is already taken; {what} not bound (command: {command})")
    else:
        entries += (f'    (\n        modifiers: [\n            Super,\n        ],\n'
                    f'        key: "{key}",\n    ): Spawn("{command}"),\n')
        print(f"    Super+{key.upper()}: {what}")
if entries:
    body = text.rstrip()
    if not body.endswith("}"):
        raise SystemExit(f"!! {custom} is not a map; shortcuts left alone")
    body = body[:-1].rstrip()
    if body != "{" and not body.endswith(","):
        body += ","
    save_backup(custom)
    write(custom, body + "\n" + entries + "}\n")
PYEOF
