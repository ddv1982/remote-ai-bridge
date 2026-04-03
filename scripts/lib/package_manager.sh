# shellcheck shell=bash
# Shared package manager primitives

_detect_package_manager() {
  local include_brew="${1:-false}"
  local pm

  if [[ "$include_brew" == "true" ]] && command_exists brew; then
    echo "brew"
    return 0
  fi

  for pm in apt-get dnf yum pacman; do
    if command_exists "$pm"; then
      echo "$pm"
      return 0
    fi
  done

  echo "none"
}

detect_package_manager() {
  _detect_package_manager true
}

detect_linux_package_manager() {
  _detect_package_manager false
}

_package_manager_install() {
  local pm="${1:?missing package manager}"
  local package="${2:?missing package name}"

  case "$pm" in
    brew)
      brew install "$package"
      ;;
    apt-get)
      sudo apt-get update -y && sudo apt-get install -y "$package"
      ;;
    dnf)
      sudo dnf install -y "$package"
      ;;
    yum)
      sudo yum install -y "$package"
      ;;
    pacman)
      sudo pacman -S --noconfirm "$package"
      ;;
    *)
      return 1
      ;;
  esac
}

package_manager_install() {
  local package="${1:?missing package name}"
  _package_manager_install "$(detect_package_manager)" "$package"
}

linux_package_manager_install() {
  local package="${1:?missing package name}"
  _package_manager_install "$(detect_linux_package_manager)" "$package"
}

_package_manager_uninstall() {
  local pm="${1:?missing package manager}"
  local package="${2:?missing package name}"
  local purge="${3:-false}"

  case "$pm" in
    brew)
      HOMEBREW_NO_AUTOREMOVE=1 brew uninstall "$package"
      ;;
    apt-get)
      sudo apt-get remove -y "$package"
      if [[ "$purge" == "true" ]]; then
        sudo apt-get purge -y "$package" 2>/dev/null || true
      fi
      ;;
    dnf)
      sudo dnf remove -y "$package"
      ;;
    yum)
      sudo yum remove -y "$package"
      ;;
    pacman)
      sudo pacman -R --noconfirm "$package"
      ;;
    *)
      return 1
      ;;
  esac
}

package_manager_uninstall() {
  local package="${1:?missing package name}"
  local purge="${2:-false}"
  _package_manager_uninstall "$(detect_package_manager)" "$package" "$purge"
}

linux_package_manager_uninstall() {
  local package="${1:?missing package name}"
  local purge="${2:-false}"
  _package_manager_uninstall "$(detect_linux_package_manager)" "$package" "$purge"
}

_package_manager_install_hint() {
  local pm="${1:?missing package manager}"
  local package="${2:?missing package name}"

  case "$pm" in
    brew)
      echo "Install manually with: brew install $package"
      ;;
    apt-get)
      echo "Install manually with: sudo apt-get update -y && sudo apt-get install -y $package"
      ;;
    dnf)
      echo "Install manually with: sudo dnf install -y $package"
      ;;
    yum)
      echo "Install manually with: sudo yum install -y $package"
      ;;
    pacman)
      echo "Install manually with: sudo pacman -S --noconfirm $package"
      ;;
    *)
      echo "Install $package manually using your distribution's package manager."
      ;;
  esac
}

package_manager_install_hint() {
  local package="${1:?missing package name}"
  _package_manager_install_hint "$(detect_package_manager)" "$package"
}

linux_package_manager_install_hint() {
  local package="${1:?missing package name}"
  _package_manager_install_hint "$(detect_linux_package_manager)" "$package"
}
