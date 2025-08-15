#!/bin/sh
set -e  # Exit on any error

# Colors for output (disabled if terminal lacks color support)
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'  # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Debug log file
DEBUG_LOG="$HOME/.logs/arch-setup-`date +%F-%H%M%S`.log"
mkdir -p "$HOME/.logs"
exec 3>&1 1>>"$DEBUG_LOG" 2>&1

# Logging functions
log() {
    printf '%s [%s] %s%s\n' "$GREEN" "`date +'%Y-%m-%d %H:%M:%S'`" "$1" "$NC" | tee -a /dev/fd/3
}

warn() {
    printf '%s [WARNING] %s%s\n' "$YELLOW" "$1" "$NC" | tee -a /dev/fd/3
}

error() {
    printf '%s [ERROR] %s%s\n' "$RED" "$1" "$NC" | tee -a /dev/fd/3
    exit 1
}

info() {
    printf '%s [INFO] %s%s\n' "$BLUE" "$1" "$NC" | tee -a /dev/fd/3
}

# Configuration variables
USER_NAME=`whoami`
AUR_HELPER=yay
DESKTOP_ENVIRONMENT=dwm
ENABLE_MULTILIB=true
ENABLE_AUR=true
DRY_RUN=false

# Directory configuration
DWM_DIR="$HOME/.local/src/dwm"
DWMBLOCKS_DIR="$HOME/.local/src/dwmblocks"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CONFIG_DIR="$HOME/.local/src/arch-setup/configs"

# Main execution
main() {
    log "Arch Linux Post-Install Setup Script"
    log "Debug output is being saved to $DEBUG_LOG"
    info "Starting setup process..."
    warn "This is a test warning"
    log "Setup completed successfully!"
}

main "$@"
