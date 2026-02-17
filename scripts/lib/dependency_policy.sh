# shellcheck shell=bash
# shellcheck disable=SC2034
# Central dependency policy.
#
# Edit this file to control dependency upgrade behavior from one place.
#
# Tailscale:
# - TRACK accepts "stable" (default) or "unstable".
# - Always installs/upgrades to the latest available version in the selected track.

: "${TAILMUX_TAILSCALE_TRACK:=stable}"
TAILMUX_MANAGED_PACKAGES=(tailscale tmux davfs2)
