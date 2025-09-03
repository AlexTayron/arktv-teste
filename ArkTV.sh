#!/bin/bash


#-----------------------#
# ArkTV - versão M3U    #
#-----------------------#

# --- Root privilege check ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

set -euo pipefail

# --- Global Variables ---
CURR_TTY="/dev/tty1"
MPV_SOCKET="/tmp/mpvsocket"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
M3U_URL="https://raw.githubusercontent.com/AlexTayron/arktv-teste/refs/heads/main/channels/canais.m3u
M3U_FILE="/tmp/canais.m3u"

# --- Functions ---

ExitMenu() {
    rm -f "$M3U_FILE"
    printf "\033c" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY" # Show cursor again
    pkill -f "gptokeyb -1 arktv.sh" || true
    exit 0
}

check_internet() {
    if ! curl -s --connect-timeout 5 --max-time 5 "http://1.1.1.1" >/dev/null 2>&1; then
        dialog --msgbox "Sem conexão com a internet.\nVerifique sua rede e tente novamente." 6 50 > "$CURR_TTY"
        return 1
    fi
    return 0
}

check_and_install_dependencies() {
    if ! check_internet; then
        ExitMenu
    fi

    local missing=()
    for cmd in mpv dialog curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        if ! command -v apt >/dev/null; then
            dialog --msgbox "Erro: apt não encontrado. Instale manualmente: ${missing[*]}" 8 60 > "$CURR_TTY"
            ExitMenu
        fi
        dialog --infobox "Instalando dependências: ${missing[*]}..." 3 60 > "$CURR_TTY"
        apt update >/dev/null 2>&1 && apt install -y "${missing[@]}" >/dev/null 2>&1
    fi
}

fetch_m3u_file() {
    if ! curl -s -o "$M3U_FILE" "$M3U_URL"; then
        dialog --msgbox "Erro ao baixar lista M3U." 6 50 > "$CURR_TTY"
        ExitMenu
    fi
}

load_categories() {
    # Pega todos os group-title, remove duplicados e ordena
    mapfile -t CATEGORIES < <(grep -oP 'group-title="[^"]+"' "$M3U_FILE" | sed -E 's/group-title="([^"]+)"/\1/' | sort -u)
}


load_channels_list() {
    declare -gA CHANNELS
    CHANNEL_MENU_OPTIONS=()
    local index=1
    local name=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^#EXTINF ]]; then
            name=$(echo "$line" | sed -E 's/.*,(.*)/\1/')
            read -r url
            CHANNEL_MENU_OPTIONS+=("$index" "$name")
            CHANNELS["$index"]="$url"
            ((index++))
        fi
    done < "$M3U_FILE"
    CHANNEL_MENU_OPTIONS+=("0" "Sair")
}

choose_channel_list() {
    local choice
    choice=$(dialog --output-fd 1 \
        --backtitle "ArkTV" \
        --title "Canais" \
        --menu "Escolha um canal:" 20 70 15 \
        "${CHANNEL_MENU_OPTIONS[@]}" \
        2>"$CURR_TTY")

    if [[ -z "$choice" || "$choice" == "0" ]]; then
        ExitMenu
    fi

    play_channel_list "$choice"
}

play_channel_list() {
    local idx="$1"
    local url="${CHANNELS[$idx]}"
    local name="${CHANNEL_MENU_OPTIONS[$(( ($idx-1)*2 + 1 ))]}"

    dialog --infobox "Iniciando canal: $name..." 3 50 > "$CURR_TTY"
    sleep 1

    /usr/bin/mpv --fullscreen --geometry=640x480 --hwdec=auto --vo=drm --input-ipc-server="$MPV_SOCKET" "$url" >/dev/null 2>&1

    ExitMenu
}

# --- Main execution ---
trap ExitMenu EXIT SIGINT SIGTERM
printf "\033c" > "$CURR_TTY"
printf "\e[?25l" > "$CURR_TTY" # Hide cursor

check_and_install_dependencies
fetch_m3u_file
load_channels_list
choose_channel_list
            name=$(echo "$line" | sed -E 's/.*,(.*)/\1/')
            read -r url
            CHANNEL_MENU_OPTIONS+=("$index" "$name")
            CHANNELS["$index"]="$url"
            ((index++))
        fi
    done < "$M3U_FILE"

    CHANNEL_MENU_OPTIONS+=("0" "Voltar")
}

choose_channel() {
    local choice
    choice=$(dialog --output-fd 1 \
        --backtitle "ArkTV" \
        --title "Canais - $CATEGORY" \
        --menu "Escolha um canal:" 20 70 15 \
        "${CHANNEL_MENU_OPTIONS[@]}" \
        2>"$CURR_TTY")

    if [[ -z "$choice" || "$choice" == "0" ]]; then
        return 1
    fi

    play_channel "$choice"
    return 0
}

play_channel() {
    local idx="$1"
    local url="${CHANNELS[$idx]}"
    local name="${CHANNEL_MENU_OPTIONS[$(( ($idx-1)*2 + 1 ))]}"

    dialog --infobox "Iniciando canal: $name..." 3 50 > "$CURR_TTY"
    sleep 1

    /usr/bin/mpv --fullscreen --geometry=640x480 --hwdec=auto --vo=drm --input-ipc-server="$MPV_SOCKET" "$url" >/dev/null 2>&1

    ExitMenu
}

# --- Main execution ---
trap ExitMenu EXIT SIGINT SIGTERM
printf "\033c" > "$CURR_TTY"
printf "\e[?25l" > "$CURR_TTY" # Hide cursor

check_and_install_dependencies
fetch_m3u_file
load_categories

while true; do
    choose_category
    load_channels_by_category
    choose_channel || continue
done
