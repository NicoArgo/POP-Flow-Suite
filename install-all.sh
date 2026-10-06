#!/usr/bin/env bash
# POP Flow — fetch, build & install ALL components of the suite in one go.
#
# Works from a fresh clone of this repo: each component lives in its own repo
# (see README.md), and any that isn't here yet is cloned next to this script.
# Components already present are used as they are — a working copy is never
# pulled or reset behind your back.
#
# Then runs each component's own install.sh (build release -> backup -> sudo
# install) and reloads what's running. Needs sudo: run it in a real terminal
# (the password is asked once for the whole run).
#
#   ./install-all.sh          # asks before installing on an untested COSMIC
#   POP_FLOW_YES=1 ./install-all.sh   # doesn't ask
set -euo pipefail
cd "$(dirname "$0")"

# The COSMIC release these forks are built and tested against. They replace
# system binaries, so a very different COSMIC may not like them.
TESTED_COSMIC="1.0.7"
# Oldest Rust the components build with (their `rust-version`).
MIN_RUST="1.93"

# folder | repo — in install order. The launcher's fork was renamed POP-Flow.
REPOS=(
    "cosmic-launcher|https://github.com/NicoArgo/POP-Flow.git"
    "cosmic-files|https://github.com/NicoArgo/cosmic-files.git"
    "cosmic-applets|https://github.com/NicoArgo/cosmic-applets.git"
    "cosmic-term|https://github.com/NicoArgo/cosmic-term.git"
)
# Optional system components: a refusal from their own install.sh (e.g. the
# installed COSMIC is older than the fork — the overview checks this) skips
# them with a note instead of stopping the whole run.
OPTIONAL_REPOS=(
    "cosmic-workspaces-epoch|https://github.com/NicoArgo/cosmic-workspaces-epoch.git"
    # Settings → Displays: the "show desktop" scope toggle. Its own install.sh
    # wants libpipewire-0.3-dev + libclang-dev, which are NOT in BUILD_DEPS on
    # purpose: that -dev package upgrades the running PipeWire.
    "cosmic-settings|https://github.com/NicoArgo/cosmic-settings.git"
)
# The compositor: installed last, and only after its own "type yes" prompt —
# a bad build here costs the session, not just one app. Takes effect at the
# next login; refusing it skips it without failing the rest of the install.
COMP_REPOS=(
    "cosmic-comp|https://github.com/NicoArgo/cosmic-comp.git"
)
# Installed per user (no system binary replaced, so no sudo and no APT hook).
USER_REPOS=(
    "cosmic-wallsync|https://github.com/NicoArgo/cosmic-wallsync.git"
    "cosmic-clipboard-history|https://github.com/NicoArgo/cosmic-clipboard-history.git"
)

# Build dependencies: what a machine that builds every component here has
# installed (the debian/control files list more, for applets POP Flow doesn't
# build). Checked one by one; only what's missing is installed.
BUILD_DEPS=(
    git pkgconf libxkbcommon-dev libwayland-dev libglib2.0-dev libegl-dev
    libudev-dev libinput-dev libssl-dev libfontconfig-dev libfreetype-dev
    libexpat1-dev
)

say() { printf '\n==> %s\n' "$*"; }
banner() {
    echo
    echo "=================================================================="
    echo "==> $*"
    echo "=================================================================="
}

# --- 1. Is this a COSMIC we know? -------------------------------------------
if ! command -v dpkg-query >/dev/null; then
    echo "!! POP Flow targets Pop!_OS (COSMIC on a Debian base); dpkg not found."
    exit 1
fi
cosmic_version=$(dpkg-query -W -f='${Version}' cosmic-files 2>/dev/null || true)
cosmic_version=${cosmic_version%%~*}
if [ -z "$cosmic_version" ]; then
    echo "!! COSMIC doesn't seem to be installed (no cosmic-files package)."
    exit 1
fi
if [ "$cosmic_version" != "$TESTED_COSMIC" ]; then
    echo "!! This system has COSMIC $cosmic_version; POP Flow is tested on $TESTED_COSMIC."
    echo "   The components replace system binaries and may misbehave on another"
    echo "   release. Each one can be undone with its uninstall.sh."
    if [ "${POP_FLOW_YES:-}" != 1 ]; then
        read -r -p "   Continue anyway? [y/N] " answer
        [[ "$answer" =~ ^[yYsS] ]] || exit 1
    fi
fi

# --- 2. sudo once, kept fresh for the whole (long) run -------------------------
sudo -v
while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# --- 3. Build dependencies ------------------------------------------------------
missing=()
for pkg in "${BUILD_DEPS[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$' \
        || missing+=("$pkg")
done
# Rust: Pop!_OS ships a recent enough cargo; only if there is none at all do we
# install it. An existing older toolchain (rustup or apt) is the user's to update.
if ! command -v cargo >/dev/null; then
    missing+=(cargo rustc)
fi
if [ ${#missing[@]} -gt 0 ]; then
    say "Installing build dependencies: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
fi
rust_version=$(rustc --version | awk '{print $2}')
if [ "$(printf '%s\n%s\n' "$MIN_RUST" "$rust_version" | sort -V | head -1)" != "$MIN_RUST" ]; then
    echo "!! Rust $rust_version is too old; the components need $MIN_RUST or newer."
    echo "   With rustup: rustup update stable"
    echo "   With apt:    sudo apt install --only-upgrade cargo rustc"
    exit 1
fi

# --- 4. Fetch what's missing ----------------------------------------------------
fetch() {
    local dir=$1 url=$2
    if [ -d "$dir/.git" ]; then
        echo "    $dir: already here, used as is"
        return 0
    fi
    echo "    $dir: cloning $url"
    # No password prompt: a repo we can't read (private) is skipped, not fatal.
    if ! GIT_TERMINAL_PROMPT=0 git clone --quiet "$url" "$dir"; then
        echo "    !! could not clone $dir (private, or offline?) — skipped"
        rm -rf "$dir"
        return 1
    fi
}
say "Components"
for entry in "${REPOS[@]}" "${OPTIONAL_REPOS[@]}" "${COMP_REPOS[@]}" "${USER_REPOS[@]}"; do
    fetch "${entry%%|*}" "${entry#*|}" || true
done

# --- 5. System components -------------------------------------------------------
for entry in "${REPOS[@]}"; do
    comp=${entry%%|*}
    if [ ! -x "$comp/install.sh" ]; then
        echo "!! skipping $comp (not here, or no install.sh)"
        continue
    fi
    banner "$comp"
    ( cd "$comp" && ./install.sh )
    # Make it stick: without this, the next package update of the component
    # restores the stock binary and the feature disappears with no warning.
    if [ -x "$comp/setup-auto-reapply.sh" ]; then
        ( cd "$comp" && ./setup-auto-reapply.sh )
    else
        echo "!! $comp has no setup-auto-reapply.sh — a package update will revert it"
    fi
done

# --- 5b. Optional system components -------------------------------------------
for entry in "${OPTIONAL_REPOS[@]}"; do
    comp=${entry%%|*}
    [ -x "$comp/install.sh" ] || { echo "!! skipping $comp (not here, or no install.sh)"; continue; }
    banner "$comp (optional)"
    if ! ( cd "$comp" && ./install.sh ); then
        echo "!! $comp not installed (see above; often: sudo apt full-upgrade first)"
        continue
    fi
    if [ -x "$comp/setup-auto-reapply.sh" ]; then
        ( cd "$comp" && ./setup-auto-reapply.sh )
    fi
done

# --- 6. Compositor --------------------------------------------------------------
comp_installed=0
for entry in "${COMP_REPOS[@]}"; do
    comp=${entry%%|*}
    if [ ! -x "$comp/install.sh" ]; then
        echo "!! skipping $comp (not here, or no install.sh)"
        continue
    fi
    banner "$comp (compositor — read the prompt)"
    if ! ( cd "$comp" && ./install.sh ); then
        echo "!! $comp not installed — the rest of POP Flow is unaffected"
        continue
    fi
    comp_installed=1
    if [ -x "$comp/setup-auto-reapply.sh" ]; then
        ( cd "$comp" && ./setup-auto-reapply.sh )
    else
        echo "!! $comp has no setup-auto-reapply.sh — a package update will revert it"
    fi
done

# --- 7. User components ---------------------------------------------------------
for entry in "${USER_REPOS[@]}"; do
    comp=${entry%%|*}
    [ -x "$comp/install.sh" ] || continue
    banner "$comp (user)"
    ( cd "$comp" && ./install.sh )
done

# --- 7b. Panel buttons and shortcuts -------------------------------------------
# The only step that edits your desktop configuration, so it asks (default yes).
banner "Panel buttons and shortcuts"
answer=y
if [ "${POP_FLOW_YES:-}" != 1 ]; then
    read -r -p "   Add the POP Flow buttons to the panel and bind Super+D / Super+V? [Y/n] " answer
fi
if [[ ! "$answer" =~ ^[nN] ]]; then
    ./setup-desktop.sh || echo "!! setup-desktop.sh failed — the components are installed anyway"
else
    echo "    skipped; run ./setup-desktop.sh any time"
fi

# --- 8. Reload ----------------------------------------------------------------
# - cosmic-launcher and the desktop icons were restarted by their installers
#   (COSMIC respawns them; no app window is closed).
# - cosmic-files windows are NOT session-managed, so we stop them here to drop
#   the old binary. THIS CLOSES ANY OPEN FILE-MANAGER WINDOWS.
# - cosmic-term is deliberately NOT killed: this script is running inside one.
say "Reloading cosmic-files (this closes its open windows)..."
pkill -x cosmic-files 2>/dev/null || true

say "POP Flow installed."
cat <<'EOF'
    Alt+Tab is live now; so is the show-desktop triangle in the bottom-right
    corner of every screen (click it, or rest the pointer on it).

    Vampire mode (bat/moon in the panel) starts OFF; click it to choose.

    One thing you do yourself:
    - Per-folder look in the terminal: open a NEW terminal window (this one
      still runs the old binary) and create a rule for a folder; the file
      manager then shows that folder in the rule's color.
EOF
if [ "$comp_installed" = 1 ]; then
    cat <<EOF

    Three-finger touchpad gestures come with the new compositor, which starts
    at your NEXT LOGIN: log out and back in. If the session doesn't come back:
      Ctrl+Alt+F3 -> log in -> cd $(pwd)/cosmic-comp -> ./uninstall.sh -> reboot
EOF
fi
