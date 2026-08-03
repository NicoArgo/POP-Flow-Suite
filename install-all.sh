#!/usr/bin/env bash
# POP Flow — build & install ALL components of the suite in one go.
#
# Runs each component's own install.sh (build release -> backup -> sudo install),
# then reloads the running components so every feature is active. Needs sudo:
# run this in a real terminal (the credentials are cached once for the whole run).
set -euo pipefail
cd "$(dirname "$0")"

# Components that ship an install.sh (modifiable forks), in install order.
COMPONENTS=(cosmic-launcher cosmic-files cosmic-applets cosmic-term)

echo "==> POP Flow — installing: ${COMPONENTS[*]}"
echo "    Each component also gets an APT post-invoke hook so a package update"
echo "    can't silently revert it. Undo per component with remove-auto-reapply.sh"

# Prompt for sudo once up front and keep the timestamp fresh for the whole run
# (so long builds don't cause a second password prompt mid-way).
sudo -v
while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

for comp in "${COMPONENTS[@]}"; do
    if [ -x "$comp/install.sh" ]; then
        echo
        echo "=================================================================="
        echo "==> $comp"
        echo "=================================================================="
        ( cd "$comp" && ./install.sh )
        # Make it stick: without this, the next package update of the component
        # restores the stock binary and the feature disappears with no warning.
        if [ -x "$comp/setup-auto-reapply.sh" ]; then
            ( cd "$comp" && ./setup-auto-reapply.sh )
        else
            echo "!! $comp has no setup-auto-reapply.sh — a package update will revert it"
        fi
    else
        echo "!! skipping $comp (no executable install.sh)"
    fi
done

# Reload the running components so the new binaries take effect:
#  - cosmic-launcher was already restarted by its own installer (COSMIC respawns
#    it; this does NOT close your app windows).
#  - cosmic-files is NOT session-managed, so we stop it here to drop the old
#    binary. THIS CLOSES ANY OPEN FILE-MANAGER WINDOWS — reopen it afterwards.
#  - cosmic-term is deliberately NOT killed: this script is running inside one,
#    and killing it would close the user's shells mid-install.
echo
echo "==> Reloading cosmic-files (this closes its open windows)..."
pkill -x cosmic-files 2>/dev/null || true

echo
echo "==> POP Flow installed."
echo "    Alt+Tab is live now. Reopen the file manager to use its new features."
echo "    Open a NEW terminal window for the per-directory appearance — this one"
echo "    is still running the old binary, and was left alone on purpose."
