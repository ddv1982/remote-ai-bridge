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

start_tailscale() {
    print_step "Starting Tailscale"
    local os
    os=$(detect_os)
    
    if [[ "$os" == "macos" ]]; then
        [[ -d "/Applications/Tailscale.app" ]] && open -a Tailscale
        echo "Open Tailscale from menu bar and log in."
    else
        sudo tailscale up 2>/dev/null || echo "Run: sudo tailscale up"
    fi
    
    if [[ -t 0 ]]; then
        read -rp "Press Enter when Tailscale is connected..."
    else
        echo "Waiting 5s for Tailscale..."
        sleep 5
    fi
    
    if tailscale status &>/dev/null; then
        print_success "Tailscale connected"
    else
        print_warning "Tailscale may not be connected"
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
    local hostname ip
    hostname=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\.$//')
    ip=$(tailscale ip -4 2>/dev/null)
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  HOME MACHINE READY"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    [[ -n "$hostname" ]] && echo "  Tailscale hostname: $hostname"
    [[ -n "$ip" ]] && echo "  Tailscale IP: $ip"
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
