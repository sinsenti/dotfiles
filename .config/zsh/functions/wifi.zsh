# Remove conflicting alias if present
unalias wifi 2>/dev/null
unalias edit_wifi 2>/dev/null

edit_wifi() {
    local FILE="/etc/NetworkManager/dispatcher.d/10-warsaw-wifi.sh"
    sudo chattr -i "$FILE"
    sudo -E nvim "$FILE"
    sudo chattr +i "$FILE"
}

wifi() {
    local FILE="/etc/NetworkManager/dispatcher.d/10-warsaw-wifi.sh"
    local choice SSID PASS confirm

    echo "Select Wi-Fi Profile:"
    echo "1) InnoWarsaw"
    echo "2) this"
    echo "3) TP-Link_B3B9"
    echo "4) Manual Edit (Neovim)"
    printf "Choice [1-4]: "
    read -r choice

    case "$choice" in
        1)
            SSID="InnoWarsaw"
            PASS="Wise299!"
            ;;
        2)
            SSID="this"
            PASS="pozor123"
            ;;
        3)
            SSID="TP-Link_B3B9"
            PASS="97840480"
            ;;
        4)
            edit_wifi
            return 0
            ;;
        *)
            echo "Invalid selection."
            return 1
            ;;
    esac

    # Confirmation prompt
    printf "Are you sure you want to connect to %s? [y/N]: " "$SSID"
    read -r confirm

    case "$confirm" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo "Cancelled."
            return 0
            ;;
    esac

    sudo chattr -i "$FILE"
    sudo sed -i -E "s/^DESIRED_SSID=.*/DESIRED_SSID=\"$SSID\"/" "$FILE"
    sudo sed -i -E "s/^PASSWORD=.*/PASSWORD=\"$PASS\"/" "$FILE"
    sudo chattr +i "$FILE"

    echo "Successfully updated Wi-Fi profile to: $SSID"
    echo "'curl ipinfo.io'\n"
    curl ipinfo.io
}
