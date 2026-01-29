#!/usr/bin/env bash
set -euo pipefail

# ai-home: Client Setup (macOS/Linux/WSL)

SSH_CONFIG="$HOME/.ssh/config"

print_step() { echo -e "\n→ $1"; }
print_success() { echo "✓ $1"; }
print_warning() { echo "⚠ $1"; }
print_error() { echo "✗ $1" >&2; }

cleanup() {
    jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT INT TERM

detect_os() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
        msys*|cygwin*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Timeout wrapper (macOS doesn't have timeout by default)
run_with_timeout() {
    local secs=$1
    shift
    ( "$@" ) & local pid=$!
    ( sleep "$secs" && kill -9 $pid 2>/dev/null ) & local killer=$!
    wait $pid 2>/dev/null
    local ret=$?
    kill $killer 2>/dev/null
    wait $killer 2>/dev/null
    return $ret
}

get_tailscale_state() {
    run_with_timeout 3 tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo ""
}

detect_shell_rc() {
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        echo "$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
    else
        echo "$HOME/.profile"
    fi
}

install_tailscale() {
    if command -v tailscale &>/dev/null; then
        print_success "Tailscale installed"
        return 0
    fi
    
    print_step "Installing Tailscale"
    local os
    os=$(detect_os)
    
    case "$os" in
        macos)
            if command -v brew &>/dev/null; then
                brew install --cask tailscale
            else
                print_warning "Install Tailscale from: https://tailscale.com/download/mac"
            fi
            ;;
        *)
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
    esac
    print_success "Tailscale installed"
}

start_tailscale() {
    print_step "Checking Tailscale"
    local os state
    os=$(detect_os)
    
    state=$(get_tailscale_state)
    
    if [[ "$state" == "Running" ]]; then
        print_success "Tailscale connected"
        return 0
    fi
    
    # Open app on macOS
    if [[ "$os" == "macos" ]] && [[ -d "/Applications/Tailscale.app" ]]; then
        open -a Tailscale
        sleep 2
    elif [[ "$os" != "macos" ]]; then
        echo "If prompted, open the URL in your browser to authenticate."
        sudo tailscale up --timeout=10s 2>&1 || true
    fi
    
    state=$(get_tailscale_state)
    
    if [[ "$state" == "Running" ]]; then
        print_success "Tailscale connected"
    elif [[ "$state" == "NeedsLogin" ]]; then
        print_warning "Tailscale needs login - complete via menu bar after setup"
    else
        print_warning "Tailscale not ready - open app and log in after setup"
    fi
}

setup_ssh_key() {
    print_step "Setting up SSH key"
    local key="$HOME/.ssh/id_ed25519"
    
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    if [[ -f "$key" ]]; then
        print_success "SSH key exists: $key"
    else
        ssh-keygen -t ed25519 -f "$key" -N "" -C "$USER@client"
        print_success "SSH key generated"
    fi
}

get_home_info() {
    print_step "Home Machine Info"
    echo ""
    read -rp "Tailscale hostname or IP of home machine: " HOME_HOST
    [[ -z "$HOME_HOST" ]] && { print_error "Required"; exit 1; }
    
    read -rp "Username on home machine [$USER]: " HOME_USER
    HOME_USER="${HOME_USER:-$USER}"
}

copy_ssh_key() {
    print_step "SSH Key"
    print_success "Key ready: ~/.ssh/id_ed25519.pub"
}

setup_ssh_config() {
    print_step "Configuring SSH"
    
    if grep -q "^Host home$" "$SSH_CONFIG" 2>/dev/null; then
        echo ""
        echo "Existing 'Host home' config:"
        echo "  hostname: $(ssh -G home 2>/dev/null | grep '^hostname ' | cut -d' ' -f2)"
        echo "  user: $(ssh -G home 2>/dev/null | grep '^user ' | cut -d' ' -f2)"
        echo ""
        read -rp "Update with new values? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            print_warning "Keeping existing SSH config"
            return 0
        fi
        # Remove old Host home block before adding new one
        local backup
        backup="$SSH_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
        cp "$SSH_CONFIG" "$backup"
        awk '
            /^# (ai-home|SSH-LLM|Remote AI Bridge)$/ { skip=1; next }
            /^Host home$/ { skip=1; next }
            skip && /^Host / { skip=0 }
            skip && /^[^ \t]/ && !/^$/ { skip=0 }
            !skip { print }
        ' "$backup" > "$SSH_CONFIG"
    fi
    
    cat >> "$SSH_CONFIG" << EOF

# ai-home
Host home
    HostName $HOME_HOST
    User $HOME_USER
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chmod 600 "$SSH_CONFIG"
    print_success "SSH config added"
}

setup_shell_functions() {
    print_step "Adding shell commands"
    local rc
    rc=$(detect_shell_rc)
    
    if grep -qE "# (ai-home|SSH-LLM)" "$rc" 2>/dev/null; then
        print_warning "Commands exist in $rc, skipping"
        return 0
    fi
    
    cat >> "$rc" << 'EOF'

# ai-home
ai() { ssh -t home "tmux new-session -A -s ${1:-ai}"; }
ai-run() { [[ $# -eq 0 ]] && { echo "Usage: ai-run <cmd>"; return 1; }; ssh -t home "$*"; }
EOF
    print_success "Commands added to $rc"
}

test_connection() {
    print_step "Testing connection"
    
    if ssh -o BatchMode=yes -o ConnectTimeout=5 home "echo ok" &>/dev/null; then
        print_success "SSH connection works"
        if ssh home "command -v tmux" &>/dev/null; then
            print_success "tmux available"
        else
            print_warning "tmux missing on home"
        fi
        if ssh home "command -v claude" &>/dev/null; then
            print_success "claude available"
        else
            print_warning "claude missing on home"
        fi
    else
        print_warning "SSH key not yet copied to home machine"
    fi
}

show_completion() {
    local rc
    rc=$(detect_shell_rc)
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  SETUP COMPLETE"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    # Check if SSH key needs to be copied
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 home "echo ok" &>/dev/null; then
        echo "  Step 1: Copy your SSH key to home machine:"
        echo "    ssh-copy-id $HOME_USER@$HOME_HOST"
        echo ""
        echo "  Step 2: Connect:"
        echo "    source $rc && ai"
    else
        echo "  source $rc && ai"
    fi
    echo ""
    echo "  Commands: ai, ai-run"
    echo ""
}

main() {
    echo ""
    echo "ai-home: Client Setup"
    echo "═════════════════════"
    echo ""
    echo "This will: Install Tailscale, configure SSH, add commands"
    echo ""
    
    local confirm
    read -rp "Continue? [Y/n]: " confirm
    [[ "$confirm" =~ ^[Nn] ]] && exit 0
    
    install_tailscale
    start_tailscale
    setup_ssh_key
    get_home_info
    copy_ssh_key
    setup_ssh_config
    setup_shell_functions
    test_connection
    show_completion
}

main "$@"
