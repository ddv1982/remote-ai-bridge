#!/usr/bin/env bash
set -euo pipefail

# ai-home: Uninstall Script

print_step() { echo -e "\n→ $1"; }
print_success() { echo "✓ $1"; }
print_warning() { echo "⚠ $1"; }
print_error() { echo "✗ $1" >&2; }

SSH_CONFIG="$HOME/.ssh/config"

detect_shell_rc() {
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        echo "$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
    else
        echo "$HOME/.profile"
    fi
}

has_ssh_config() {
    grep -q "^Host home$" "$SSH_CONFIG" 2>/dev/null
}

has_shell_functions() {
    local rc
    rc=$(detect_shell_rc)
    grep -qE "# (ai-home|SSH-LLM)" "$rc" 2>/dev/null
}

remove_ssh_config() {
    print_step "Removing SSH config for 'home'"
    
    if ! has_ssh_config; then
        print_warning "No SSH config for 'home' found"
        return 0
    fi
    
    # Create timestamped backup
    local backup
    backup="$SSH_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SSH_CONFIG" "$backup"
    
    # Remove the Host home block (from "# ai-home", "# SSH-LLM" or "# Remote AI Bridge" comment through the Host block)
    awk '
        /^# (ai-home|SSH-LLM|Remote AI Bridge)$/ { skip=1; next }
        /^Host home$/ { skip=1; next }
        skip && /^Host / { skip=0 }
        skip && /^[^ \t]/ && !/^$/ { skip=0 }
        !skip { print }
    ' "$backup" > "$SSH_CONFIG"
    
    print_success "SSH config removed (backup: $backup)"
}

remove_shell_functions() {
    print_step "Removing shell functions"
    local rc
    rc=$(detect_shell_rc)
    
    if ! has_shell_functions; then
        print_warning "No shell functions found in $rc"
        return 0
    fi
    
    # Create timestamped backup
    local backup
    backup="$rc.bak.$(date +%Y%m%d%H%M%S)"
    cp "$rc" "$backup"
    
    # Remove the ai-home block (comment + all ai* function lines until next non-ai line or blank)
    awk '
        /^# (ai-home|SSH-LLM)$/ { skip=1; next }
        skip && /^ai[-a-z]*\(?\)? *\{/ { next }
        skip && /^$/ { skip=0; next }
        skip && !/^ai/ { skip=0 }
        !skip { print }
    ' "$backup" > "$rc"
    
    print_success "Shell functions removed (backup: $backup)"
}

remove_ssh_key() {
    print_step "SSH key removal"
    local key="$HOME/.ssh/id_ed25519"
    
    if [[ ! -f "$key" ]]; then
        print_warning "No SSH key found at $key"
        return 0
    fi
    
    echo "SSH key exists at: $key"
    echo "This key may be used for other purposes."
    
    read -rp "Delete SSH key? [y/N]: " confirm < /dev/tty
    if [[ "$confirm" =~ ^[Yy] ]]; then
        rm -f "$key" "$key.pub"
        print_success "SSH key deleted"
    else
        print_warning "SSH key kept"
    fi
}

main() {
    echo ""
    echo "ai-home: Uninstall"
    echo "══════════════════"
    echo ""
    
    local found_something=false
    
    # Check what's installed
    if has_ssh_config; then
        echo "  • SSH config for 'home' found"
        found_something=true
    fi
    
    if has_shell_functions; then
        local rc
        rc=$(detect_shell_rc)
        echo "  • Shell functions found in $rc"
        found_something=true
    fi
    
    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        echo "  • SSH key exists (optional removal)"
    fi
    
    if [[ "$found_something" == false ]]; then
        echo "Nothing to uninstall. ai-home config not found."
        exit 0
    fi
    
    echo ""
    echo "This will NOT uninstall Tailscale (if installed)"
    echo ""
    
    read -rp "Continue with uninstall? [y/N]: " confirm < /dev/tty
    [[ ! "$confirm" =~ ^[Yy] ]] && { echo "Cancelled."; exit 0; }
    
    remove_ssh_config
    remove_shell_functions
    remove_ssh_key
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  UNINSTALL COMPLETE"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  Restart your shell or run: source $(detect_shell_rc)"
    echo ""
    echo "  To reinstall: curl -fsSL https://raw.githubusercontent.com/ddv1982/ai-home/main/setup-client.sh | bash"
    echo ""
}

main "$@"
