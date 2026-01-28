#!/usr/bin/env bash
set -euo pipefail

# Remote AI Bridge - Work Laptop Setup (macOS/Linux/WSL)

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
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
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
        sudo tailscale up 2>/dev/null || true
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
        ssh-keygen -t ed25519 -f "$key" -N "" -C "$USER@work"
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
    print_step "Copying SSH key to home machine"
    echo "Enter your home machine password when prompted."
    
    if ssh-copy-id -o StrictHostKeyChecking=accept-new "$HOME_USER@$HOME_HOST" 2>/dev/null; then
        print_success "SSH key copied"
    else
        print_warning "Auto-copy failed. Manually add this to ~/.ssh/authorized_keys on home:"
        echo ""
        cat "$HOME/.ssh/id_ed25519.pub"
        echo ""
        read -rp "Press Enter when done..."
    fi
}

setup_ssh_config() {
    print_step "Configuring SSH"
    
    if grep -q "^Host home$" "$SSH_CONFIG" 2>/dev/null; then
        print_warning "SSH config 'home' exists, skipping"
        return 0
    fi
    
    cat >> "$SSH_CONFIG" << EOF

# SSH-LLM
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
    
    if grep -q "# SSH-LLM" "$rc" 2>/dev/null; then
        print_warning "Commands exist in $rc, skipping"
        return 0
    fi
    
    cat >> "$rc" << 'EOF'

# SSH-LLM
ai() { ssh -t home "tmux new-session -A -s ${1:-ai}"; }
ai-run() { [[ $# -eq 0 ]] && { echo "Usage: ai-run <cmd>"; return 1; }; ssh -t home "$*"; }
ai-pipe() { [[ $# -eq 0 ]] && { echo "Usage: ai-pipe <cmd>"; return 1; }; ssh home "cat | $*"; }
ai-review() { ssh home "cat | claude -p 'Review this code:'"; }
ai-explain() { ssh home "cat | claude -p 'Explain this code:'"; }
EOF
    print_success "Commands added to $rc"
}

test_connection() {
    print_step "Testing connection"
    
    if ssh -o BatchMode=yes -o ConnectTimeout=10 home "echo ok" &>/dev/null; then
        print_success "SSH works"
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
        print_error "SSH failed - check Tailscale and try: ssh -v $HOME_USER@$HOME_HOST"
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
    echo "  source $rc && ai"
    echo ""
    echo "  Commands: ai, ai-run, ai-pipe, ai-review, ai-explain"
    echo ""
}

main() {
    echo ""
    echo "Remote AI Bridge: Work Setup"
    echo "════════════════════════════"
    echo ""
    echo "This will: Install Tailscale, configure SSH, add commands"
    echo ""
    
    local confirm
    if [[ -t 0 ]]; then
        read -rp "Continue? [Y/n]: " confirm
        [[ "$confirm" =~ ^[Nn] ]] && exit 0
    fi
    
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
