#!/usr/bin/env bash
set -e

# Remote AI Bridge - Home Machine Setup (macOS/Linux)

print_step() { echo -e "\n→ $1"; }
print_success() { echo "✓ $1"; }
print_warning() { echo "⚠ $1"; }
print_error() { echo "✗ $1" >&2; }

detect_os() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
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

install_homebrew() {
    if command -v brew &>/dev/null; then
        print_success "Homebrew installed"
        return 0
    fi
    
    print_step "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add to PATH
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    print_success "Homebrew installed"
}

install_tailscale() {
    if command -v tailscale &>/dev/null; then
        print_success "Tailscale installed"
        return 0
    fi
    
    print_step "Installing Tailscale"
    local os
    os=$(detect_os)
    
    if [[ "$os" == "macos" ]]; then
        brew install --cask tailscale
    else
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    print_success "Tailscale installed"
}

get_tailscale_state() {
    # Get state with 3s timeout to avoid hanging
    run_with_timeout 3 tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo ""
}

start_tailscale() {
    print_step "Checking Tailscale"
    local os state
    os=$(detect_os)
    
    # Check current state via BackendState
    state=$(get_tailscale_state)
    
    if [[ "$state" == "Running" ]]; then
        print_success "Tailscale connected"
        return 0
    fi
    
    # Open app on macOS if not running
    if [[ "$os" == "macos" ]] && [[ -d "/Applications/Tailscale.app" ]]; then
        open -a Tailscale
        sleep 2
    elif [[ "$os" == "linux" ]]; then
        sudo tailscale up 2>/dev/null || true
    fi
    
    # Re-check state
    state=$(get_tailscale_state)
    
    if [[ "$state" == "Running" ]]; then
        print_success "Tailscale connected"
    elif [[ "$state" == "NeedsLogin" ]]; then
        print_warning "Tailscale needs login - complete via menu bar after setup"
    else
        print_warning "Tailscale not ready - open app and log in after setup"
    fi
}

install_tmux() {
    if command -v tmux &>/dev/null; then
        print_success "tmux installed"
        return 0
    fi
    
    print_step "Installing tmux"
    local os
    os=$(detect_os)
    
    if [[ "$os" == "macos" ]] || command -v brew &>/dev/null; then
        brew install tmux
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update && sudo apt-get install -y tmux
    elif [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y tmux || sudo yum install -y tmux
    else
        print_error "Install tmux manually"
        return 1
    fi
    print_success "tmux installed"
}

install_claude() {
    if command -v claude &>/dev/null; then
        print_success "Claude Code installed"
        return 0
    fi
    
    print_step "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
    print_success "Claude Code installed (run 'claude' to authenticate)"
}

enable_ssh() {
    print_step "Enabling SSH"
    local os
    os=$(detect_os)
    
    if [[ "$os" == "macos" ]]; then
        if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
            print_success "SSH enabled"
        else
            sudo systemsetup -setremotelogin on
            print_success "SSH enabled"
        fi
    else
        if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
            print_success "SSH enabled"
        else
            sudo systemctl enable --now sshd 2>/dev/null || sudo systemctl enable --now ssh 2>/dev/null || print_warning "Enable SSH manually"
        fi
    fi
}

show_completion() {
    local hostname ip state
    state=$(get_tailscale_state)
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  HOME MACHINE READY"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ "$state" == "Running" ]]; then
        hostname=$(run_with_timeout 3 tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\.$//')
        ip=$(run_with_timeout 3 tailscale ip -4 2>/dev/null || echo "")
        [[ -n "$hostname" ]] && echo "  Tailscale hostname: $hostname"
        [[ -n "$ip" ]] && echo "  Tailscale IP: $ip"
    else
        echo "  Tailscale: Log in via menu bar, then run: tailscale ip"
    fi
    
    echo "  Username: $USER"
    echo ""
    echo "  Next: Run setup-work.sh on your work laptop"
    echo ""
}

main() {
    echo ""
    echo "Remote AI Bridge: Home Setup"
    echo "════════════════════════════"
    echo ""
    echo "This will install: Tailscale, tmux, Claude Code, SSH"
    echo ""
    
    local confirm os
    if [[ -t 0 ]]; then
        read -rp "Continue? [Y/n]: " confirm
        [[ "$confirm" =~ ^[Nn] ]] && exit 0
    fi
    
    os=$(detect_os)
    [[ "$os" == "unknown" ]] && { print_error "Unsupported OS"; exit 1; }
    
    install_homebrew
    install_tailscale
    start_tailscale
    install_tmux
    install_claude
    enable_ssh
    show_completion
}

main "$@"
