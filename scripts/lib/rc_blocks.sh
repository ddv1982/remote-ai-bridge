# shellcheck shell=bash
# RC file managed block and function detection helpers
rc_has_shell_function() {
  local fn_name="${1:?missing function name}"
  grep -Eq "^[[:space:]]*${fn_name}[[:space:]]*\\(\\)" "$RC_FILE" 2>/dev/null
}

tailmux_function_installed() {
  rc_has_shell_function "tailmux"
}

managed_block_content() {
  local block_begin="${1:?missing block begin marker}"
  local block_end="${2:?missing block end marker}"
  local state
  local in_block=false
  local line
  local content=""

  state="$(managed_block_state "$block_begin" "$block_end")"
  if [[ "$state" != "valid" ]]; then
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$block_begin" ]]; then
      in_block=true
      continue
    fi
    if [[ "$line" == "$block_end" && "$in_block" == true ]]; then
      break
    fi
    if [[ "$in_block" == true ]]; then
      content+="$line"$'\n'
    fi
  done < "$RC_FILE"

  printf '%s' "$content"
}

managed_block_content_matches() {
  local block_begin="${1:?missing block begin marker}"
  local block_end="${2:?missing block end marker}"
  local expected_content="${3:?missing expected content}"
  local actual_content

  actual_content="$(managed_block_content "$block_begin" "$block_end")" || return 1
  [[ "$actual_content" == "$expected_content" ]]
}

tailmux_function_up_to_date() {
  managed_block_content_matches "$TAILMUX_BLOCK_BEGIN" "$TAILMUX_BLOCK_END" "$TAILMUX_FUNC"
}

taildrive_functions_installed() {
  local os_name
  if ! rc_has_shell_function "tailshare" || ! rc_has_shell_function "tailunshare" || ! rc_has_shell_function "tailshare-ls"; then
    return 1
  fi
  os_name="$(get_os_name)"
  if [[ "$os_name" == "Darwin" || "$os_name" == "Linux" ]]; then
    if ! rc_has_shell_function "tailmount" || ! rc_has_shell_function "tailumount" || ! rc_has_shell_function "tailmount-ls"; then
      return 1
    fi
  fi
  return 0
}

taildrive_functions_up_to_date() {
  local os_name
  local taildrive_content="$TAILDRIVE_SHARE_FUNCS"

  os_name="$(get_os_name)"
  if [[ "$os_name" == "Darwin" || "$os_name" == "Linux" ]]; then
    taildrive_content+=$'\n'"$TAILDRIVE_MOUNT_FUNCS"
  fi

  managed_block_content_matches "$TAILDRIVE_BLOCK_BEGIN" "$TAILDRIVE_BLOCK_END" "$taildrive_content"
}

managed_block_state() {
  local block_begin="${1:?missing block begin marker}"
  local block_end="${2:?missing block end marker}"
  local begin_count
  local end_count
  local in_block=false
  local line

  begin_count="$(grep -Fxc "$block_begin" "$RC_FILE" 2>/dev/null || true)"
  end_count="$(grep -Fxc "$block_end" "$RC_FILE" 2>/dev/null || true)"
  begin_count="${begin_count:-0}"
  end_count="${end_count:-0}"

  if [[ "$begin_count" == "0" && "$end_count" == "0" ]]; then
    echo "none"
    return 0
  fi
  if [[ "$begin_count" != "1" || "$end_count" != "1" ]]; then
    echo "malformed"
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$block_begin" ]]; then
      if [[ "$in_block" == true ]]; then
        echo "malformed"
        return 0
      fi
      in_block=true
      continue
    fi
    if [[ "$line" == "$block_end" ]]; then
      if [[ "$in_block" == false ]]; then
        echo "malformed"
        return 0
      fi
      in_block=false
      continue
    fi
  done < "$RC_FILE"

  if [[ "$in_block" == true ]]; then
    echo "malformed"
  else
    echo "valid"
  fi
}

append_managed_block() {
  local block_begin="${1:?missing block begin marker}"
  local block_end="${2:?missing block end marker}"
  local block_content="${3:?missing block content}"
  {
    echo ""
    echo "$block_begin"
    printf '%s\n' "$block_content"
    echo "$block_end"
  } >> "$RC_FILE"
}

remove_managed_block() {
  local block_begin="${1:?missing block begin marker}"
  local block_end="${2:?missing block end marker}"
  local state
  local tmp_file
  local in_block=false
  local line
  state="$(managed_block_state "$block_begin" "$block_end")"
  if [[ "$state" != "valid" ]]; then
    return 1
  fi
  tmp_file="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$block_begin" ]]; then
      in_block=true
      continue
    fi
    if [[ "$line" == "$block_end" && "$in_block" == true ]]; then
      in_block=false
      continue
    fi
    if [[ "$in_block" == false ]]; then
      printf '%s\n' "$line" >> "$tmp_file"
    fi
  done < "$RC_FILE"
  if [[ "$in_block" == true ]]; then
    rm -f "$tmp_file"
    return 1
  fi
  mv "$tmp_file" "$RC_FILE"
}
