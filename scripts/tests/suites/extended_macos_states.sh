#!/usr/bin/env bash

test_macos_standalone_detection_fails_with_guidance() {
  local tmp
  local fake_bin
  local out
  local status

  IFS=$'\t' read -r tmp fake_bin < <(create_fake_env)

  cat > "$fake_bin/brew" <<'BIN'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
case "$cmd" in
  --prefix)
    printf '%s\n' "${BREW_PREFIX:?missing BREW_PREFIX}"
    ;;
  list)
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
BIN
  chmod +x "$fake_bin/brew"
  mkdir -p "$tmp/homebrew/bin"

  set +e
  out="$(run_setup_with_input install $'y\nn\n' "$tmp/home" "$fake_bin" Darwin BREW_PREFIX="$tmp/homebrew" 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected standalone detection to fail"
  [[ "$out" == *"Detected standalone/App Store Tailscale install on macOS."* ]] || fail "expected standalone detection message"
  [[ "$out" == *"remove the standalone/App Store app first"* ]] || fail "expected migration guidance"
  pass "macOS standalone detection fails with guidance"
}

test_macos_cask_decline_migration_fails_cleanly() {
  local tmp
  local fake_bin
  local out
  local status

  IFS=$'\t' read -r tmp fake_bin < <(create_fake_env)

  cat > "$fake_bin/brew" <<'BIN'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
case "$cmd" in
  --prefix)
    printf '%s\n' "${BREW_PREFIX:?missing BREW_PREFIX}"
    ;;
  list)
    if [[ "${1:-}" == "--formula" && "${2:-}" == "tailscale" ]]; then
      exit 1
    fi
    if [[ "${1:-}" == "--cask" && ( "${2:-}" == "tailscale-app" || "${2:-}" == "tailscale" ) ]]; then
      exit 0
    fi
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
BIN
  chmod +x "$fake_bin/brew"
  mkdir -p "$tmp/homebrew/bin"

  set +e
  out="$(run_setup_with_input install $'y\nn\n' "$tmp/home" "$fake_bin" Darwin BREW_PREFIX="$tmp/homebrew" 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected cask migration decline to fail"
  [[ "$out" == *"Detected macOS Tailscale install without 'tailscale drive' CLI support."* ]] || fail "expected cask detection warning"
  [[ "$out" == *"Cannot continue setup without migrating to the Homebrew CLI formula."* ]] || fail "expected explicit migration failure message"
  pass "macOS cask migration decline fails cleanly"
}

test_macos_formula_unlinked_triggers_link() {
  local tmp
  local fake_bin
  local brew_prefix
  local brew_calls
  local out

  IFS=$'\t' read -r tmp fake_bin < <(create_fake_env)
  brew_prefix="$tmp/homebrew"
  brew_calls="$tmp/home/brew.calls"
  mkdir -p "$brew_prefix/Cellar"

  cat > "$fake_bin/brew" <<'BIN'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
if [[ -n "${BREW_CALLS_FILE:-}" ]]; then
  printf '%s %s\n' "$cmd" "$*" >> "$BREW_CALLS_FILE"
fi
case "$cmd" in
  --prefix)
    printf '%s\n' "${BREW_PREFIX:?missing BREW_PREFIX}"
    ;;
  --cellar)
    printf '%s\n' "${BREW_PREFIX:?missing BREW_PREFIX}/Cellar"
    ;;
  list)
    if [[ "${1:-}" == "--formula" && "${2:-}" == "tailscale" ]]; then
      exit 0
    fi
    if [[ "${1:-}" == "--cask" ]]; then
      exit 1
    fi
    exit 1
    ;;
  outdated)
    exit 0
    ;;
  link|upgrade|services|install|uninstall|unlink|update)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
BIN
  chmod +x "$fake_bin/brew"

  out="$(run_setup_with_input install $'y\nn\n' "$tmp/home" "$fake_bin" Darwin BREW_PREFIX="$brew_prefix" BREW_CALLS_FILE="$brew_calls")"

  [[ "$out" == *"Linking Homebrew Tailscale formula"* ]] || fail "expected link step for formula_unlinked"
  assert_contains "$brew_calls" '^link tailscale$'
  pass "macOS formula_unlinked triggers brew link"
}

test_macos_daemon_timeout_shows_restart_guidance() {
  local tmp
  local fake_bin
  local brew_prefix
  local out
  local status

  IFS=$'\t' read -r tmp fake_bin < <(create_fake_env)
  brew_prefix="$tmp/homebrew"
  make_fake_macos_bin "$fake_bin" "$brew_prefix"

  cat > "$fake_bin/tailscale" <<'BIN'
#!/usr/bin/env bash
if [[ "${1:-}" == "status" ]]; then
  echo "failed to connect to local Tailscale service" >&2
  exit 1
fi
if [[ "${1:-}" == "set" || "${1:-}" == "up" || "${1:-}" == "drive" ]]; then
  exit 0
fi
exit 0
BIN
  cat > "$fake_bin/sleep" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
  chmod +x "$fake_bin/tailscale" "$fake_bin/sleep"

  set +e
  out="$(run_setup_with_input install $'y\nn\n' "$tmp/home" "$fake_bin" Darwin BREW_PREFIX="$brew_prefix" 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected failure when daemon stays unreachable"
  [[ "$out" == *"Tailscale daemon is not reachable after waiting."* ]] || fail "expected daemon timeout message"
  [[ "$out" == *"sudo brew services restart tailscale"* ]] || fail "expected restart guidance"
  pass "macOS daemon timeout shows restart guidance"
}

run_extended_macos_states_suite() {
  test_macos_path_selection_mocked
  test_macos_formula_upgrade_attempted
  test_macos_formula_up_to_date_skips_upgrade
  test_macos_standalone_detection_fails_with_guidance
  test_macos_cask_decline_migration_fails_cleanly
  test_macos_formula_unlinked_triggers_link
  test_macos_daemon_timeout_shows_restart_guidance
}
