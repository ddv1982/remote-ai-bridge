# shellcheck shell=bash
show_menu() {
  while true; do
    echo ""
    echo "tailmux"
    echo "======="
    echo ""
    echo "1) Install"
    echo "2) Uninstall"
    echo "3) Update"
    echo "4) Exit"
    echo ""
    read -r -p "Choose [1-4]: " choice
    case "$choice" in
      1) do_install; break ;;
      2) do_uninstall; break ;;
      3) do_update; break ;;
      4) exit 0 ;;
      *) print_error "Invalid choice" ;;
    esac
  done
}

main() {
  case "${1:-}" in
    install) do_install ;;
    uninstall) do_uninstall ;;
    update) do_update ;;
    menu) show_menu ;;
    "") show_menu ;;
    *) show_menu ;;
  esac
}
