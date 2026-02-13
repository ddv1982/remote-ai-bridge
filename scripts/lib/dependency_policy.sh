# shellcheck shell=bash
# Central dependency policy.
#
# Edit this file to control dependency upgrade behavior from one place.
# This first phase centralizes Tailscale policy. Other dependencies can be
# added here later (for example tmux or davfs2).
#
# Tailscale:
# - TRACK accepts "stable" (default) or "unstable".
# - VERSION pins Linux installs to an exact version when non-empty.
# - VERSION empty means "latest available in the selected track".
# - macOS currently stays on Homebrew formula latest; exact version pinning is
#   Linux-only in this implementation.

: "${TAILMUX_TAILSCALE_TRACK:=stable}"
: "${TAILMUX_TAILSCALE_VERSION:=}"
