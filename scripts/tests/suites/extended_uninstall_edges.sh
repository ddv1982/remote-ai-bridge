#!/usr/bin/env bash

test_uninstall_malformed_tailmux_block_warns_and_preserves_file() {
  local tmp
  local fake_bin
  local out

  IFS=$'\t' read -r tmp fake_bin < <(create_fake_env)

  cat > "$tmp/home/.profile" <<'RC'
# >>> tailmux managed block (tailmux) >>>
# malformed block without end marker
RC

  out="$(run_setup_with_input uninstall $'y\nn\nn\n' "$tmp/home" "$fake_bin" Linux 2>&1)"

  [[ "$out" == *"Tailmux managed block markers are malformed"* ]] || fail "expected malformed marker warning during uninstall"
  assert_count "$tmp/home/.profile" '^# >>> tailmux managed block \(tailmux\) >>>$' 1
  assert_count "$tmp/home/.profile" '^# <<< tailmux managed block \(tailmux\) <<<$' 0
  pass "uninstall malformed tailmux block warning"
}

test_uninstall_taildrive_prompts_davfs2_removal_on_linux() {
  local tmp
  local fake_bin
  local apt_calls

  IFS=$'\t' read -r tmp fake_bin < <(create_fake_env)
  apt_calls="$tmp/home/apt.calls"

  cat > "$fake_bin/mount.davfs" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
  cat > "$fake_bin/apt-get" <<'BIN'
#!/usr/bin/env bash
if [[ -n "${APT_CALLS_FILE:-}" ]]; then
  printf '%s\n' "$*" >> "$APT_CALLS_FILE"
fi
exit 0
BIN
  chmod +x "$fake_bin/mount.davfs" "$fake_bin/apt-get"

  run_setup_with_input install $'y\ny\nn\n' "$tmp/home" "$fake_bin" Linux >/dev/null

  run_setup_with_input uninstall $'n\ny\ny\nn\nn\n' "$tmp/home" "$fake_bin" Linux APT_CALLS_FILE="$apt_calls" >/dev/null

  assert_contains "$apt_calls" '^remove -y davfs2$'
  pass "uninstall taildrive prompts davfs2 removal"
}

run_extended_uninstall_edges_suite() {
  test_uninstall_removes_blocks
  test_uninstall_tailscale_state_requires_typed_confirmation
  test_uninstall_tailscale_state_deletes_with_typed_confirmation
  test_malformed_tailmux_block_not_modified
  test_uninstall_malformed_tailmux_block_warns_and_preserves_file
  test_uninstall_taildrive_prompts_davfs2_removal_on_linux
}
