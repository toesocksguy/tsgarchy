#!/bin/bash

# Arch Linux Post-Install Setup Script for Beelink SER5 (AMD Ryzen)
# Modular version with function-based architecture
# Run this script after a fresh Arch installation with DWM and Ghostty

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Debug log file
DEBUG_LOG="/tmp/arch-setup-$(date +%F-%H%M%S).log"
exec 3>&1 1>>"$DEBUG_LOG" 2>&1

# Configuration variables
USER_NAME=$(whoami)
AUR_HELPER="yay"
DESKTOP_ENVIRONMENT="dwm"
ENABLE_MULTILIB=true
ENABLE_AUR=true
DRY_RUN=false

# Directory configuration
DWM_DIR="$HOME/.local/src/dwm"
DWMBLOCKS_DIR="$HOME/.local/src/dwmblocks"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CONFIG_DIR="$HOME/.local/src/arch-setup/configs"

# Package arrays
ESSENTIAL_PACKAGES=(
    "base-devel" "git" "curl" "wget" "vim" "nano" "htop" "neofetch" "tree" "unzip" "zip"
    "xorg-server" "xorg-xinit" "xorg-xsetroot" "xorg-xrandr" "ghostty" "rofi" "feh" "picom"
    "dunst" "xsel" "xclip" "maim" "thunar" "thunar-archive-plugin" "thunar-media-tags-plugin"
    "python" "python-pip" "ruby" "emacs" "docker" "docker-compose" "openssh" "flatpak" "btop"
    "yt-dlp" "bluez" "bluez-utils" "blueman" "ufw" "mpv" "celluloid" "ffmpeg" "obs-studio"
    "gst-plugins-good" "gst-plugins-bad" "gst-plugins-ugly" "gst-libav" "p7zip" "unrar"
    "tar" "gzip" "bzip2" "xz" "okular" "zathura" "zathura-pdf-mupdf" "rsync" "timeshift"
    "fontconfig" "freetype2" "cairo" "nodejs" "npm" "postgresql" "amd-ucode" "mesa"
    "vulkan-radeon" "libva-mesa-driver" "mesa-vdpau" "pipewire" "pipewire-alsa"
    "pipewire-pulse" "pipewire-jack" "wireplumber" "networkmanager" "network-manager-applet"
    "ttf-dejavu" "ttf-liberation" "noto-fonts" "noto-fonts-emoji" "ntfs-3g" "exfat-utils"
)

ADDITIONAL_PACKAGES=(
    "firefox" "vlc" "gimp" "discord" "steam" "thunderbird" "lm_sensors" "ttf-jetbrains-mono" "nitrogen"
)

AUR_PACKAGES=(
    "google-chrome" "protonvpn" "onlyoffice-bin" "mise-bin" "lazygit" "lazydocker"
    "yazi" "jrnl" "catppuccin-gtk-theme-mocha" "papirus-icon-theme"
)

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a /dev/fd/3
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a /dev/fd/3
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a /dev/fd/3
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a /dev/fd/3
}

# Utility functions
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak-$(date +%F-%H%M%S)"
        log "Backed up $file"
    fi
}

is_installed() {
    pacman -Q "$1" &>/dev/null
}

package_exists() {
    pacman -Si "$1" &>/dev/null
}

clone_or_update_repo() {
    local repo_url=$1
    local dest=$2
    if [ -d "$dest" ]; then
        log "Updating existing $dest..."
        cd "$dest" && git pull
    else
        log "Cloning $repo_url to $dest..."
        git clone "$repo_url" "$dest"
    fi
}

# Validation functions
validate_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Run as your regular user."
    fi
}

check_disk_space() {
    local required_space=5000  # 5GB in MB
    local available_space=$(df -m / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        error "Insufficient disk space: ${available_space}MB available, ${required_space}MB required"
    fi
    log "Disk space check passed: ${available_space}MB available"
}

check_internet() {
    if ! ping -c 1 archlinux.org &>/dev/null; then
        error "No internet connection detected. Please connect to the internet and try again."
    fi
    log "Internet connectivity verified"
}

# System update and configuration functions
update_system() {
    log "Updating system packages..."
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would update system packages"
        return
    fi
    sudo pacman -Syu --noconfirm || error "Failed to update system packages"
}

enable_multilib() {
    if [[ "$ENABLE_MULTILIB" != true ]]; then
        return
    fi
    
    log "Enabling multilib repository..."
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would enable multilib repository"
        return
    fi
    
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
        sudo pacman -Sy --noconfirm || warn "Failed to sync multilib repository"
    fi
}

# Package installation functions
install_essential_packages() {
    log "Installing essential packages..."
    local to_install=()
    
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        if ! is_installed "$package"; then
            if package_exists "$package"; then
                to_install+=("$package")
            else
                warn "Package $package not found in repositories"
            fi
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "DRY RUN: Would install packages: ${to_install[*]}"
            return
        fi
        
        log "Installing packages: ${to_install[*]}"
        if ! sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
            warn "Some packages failed to install. Check $DEBUG_LOG for details"
        fi
    else
        log "All essential packages are already installed"
    fi
}

install_additional_packages() {
    log "Installing additional packages..."
    local to_install=()
    
    for package in "${ADDITIONAL_PACKAGES[@]}"; do
        if ! is_installed "$package"; then
            if package_exists "$package"; then
                to_install+=("$package")
            else
                warn "Package $package not found in repositories"
            fi
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "DRY RUN: Would install additional packages: ${to_install[*]}"
            return
        fi
        
        log "Installing additional packages: ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}" || warn "Some additional packages failed to install"
    else
        log "All additional packages are already installed"
    fi
}

install_aur_helper() {
    if [[ "$ENABLE_AUR" != true ]]; then
        log "Skipping AUR helper installation"
        return
    fi

    log "Installing AUR helper: $AUR_HELPER"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would install AUR helper: $AUR_HELPER"
        return
    fi
    
    if command -v "$AUR_HELPER" &>/dev/null; then
        log "$AUR_HELPER is already installed"
        return
    fi

    local temp_dir="/tmp/$AUR_HELPER"
    rm -rf "$temp_dir"
    
    cd /tmp
    git clone "https://aur.archlinux.org/$AUR_HELPER.git"
    cd "$AUR_HELPER"
    makepkg -si --noconfirm || error "Failed to install $AUR_HELPER"
    cd ~
    rm -rf "$temp_dir"
}

install_aur_packages() {
    if [[ "$ENABLE_AUR" != true ]]; then
        log "Skipping AUR packages installation"
        return
    fi
    
    log "Installing AUR packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would install AUR packages: ${AUR_PACKAGES[*]}"
        return
    fi
    
    $AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES[@]}" || warn "Some AUR packages failed to install"
}

# Service configuration functions
enable_essential_services() {
    log "Enabling essential services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would enable NetworkManager and fstrim.timer"
        return
    fi
    
    sudo systemctl enable NetworkManager || warn "Failed to enable NetworkManager"
    sudo systemctl enable fstrim.timer || warn "Failed to enable fstrim.timer"
}

setup_ufw_firewall() {
    log "Setting up UFW firewall..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure UFW firewall"
        return
    fi
    
    sudo systemctl enable ufw
    sudo ufw --force enable
    sudo ufw allow ssh
    
    echo -e "${YELLOW}Enable BitTorrent and Jellyfin firewall rules? (y/N)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ufw allow 6881:6889/tcp
        sudo ufw allow 6881:6889/udp
        sudo ufw allow 51413/tcp
        sudo ufw allow 51413/udp
        sudo ufw allow 8096/tcp
        sudo ufw allow 8920/tcp
        sudo ufw allow 1900/udp
        sudo ufw allow 7359/udp
    fi
    
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    log "UFW firewall configured and enabled"
}

# DWM setup functions
setup_dwm_environment() {
    log "Setting up DWM environment..."
    
    # Create directories
    mkdir -p ~/.local/src "$CONFIG_DIR" "$WALLPAPER_DIR"
    
    # Clone repositories
    clone_or_update_repo "https://git.suckless.org/dwm" "$DWM_DIR"
    clone_or_update_repo "https://github.com/torrinfail/dwmblocks.git" "$DWMBLOCKS_DIR"
    
    # Configure and build DWM
    create_dwm_config
    apply_dwm_patches
    build_dwm
    
    # Configure and build dwmblocks
    create_dwmblocks_config
    build_dwmblocks
    
    # Create configuration files
    create_xinitrc
    create_dwm_autostart
}

create_dwm_config() {
    log "Creating custom DWM configuration..."
    backup_file "$DWM_DIR/config.h"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create DWM config.h"
        return
    fi
    
    cat > "$DWM_DIR/config.h" << 'DWMEOF'
/* DWM Config with Catppuccin Mocha Colors */
static const char col_base[] = "#1e1e2e";
static const char col_text[] = "#cdd6f4";
static const char col_mauve[] = "#cba6f7";
static const char col_surface1[] = "#45475a";

static const unsigned int borderpx = 2;
static const unsigned int snap = 32;
static const int showbar = 1;
static const int topbar = 1;
static const char *fonts[] = { "JetBrains Mono:size=10" };

static const char *colors[][3] = {
    [SchemeNorm] = { col_text, col_base, col_surface1 },
    [SchemeSel]  = { col_base, col_mauve, col_mauve },
};

static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
    { "Firefox", NULL, NULL, 1 << 8, 0, 0, -1, -1 },
    { "ghostty", NULL, NULL, 0, 0, 1, 0, -1 },
};

static const float mfact = 0.55;
static const int nmaster = 1;
static const int resizehints = 1;

static const Layout layouts[] = {
    { "[]=", tile },
    { "><>", NULL },
    { "[M]", monocle },
};

#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
    { MODKEY, KEY, view, {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask, KEY, toggleview, {.ui = 1 << TAG} }, \
    { MODKEY|ShiftMask, KEY, tag, {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask|ShiftMask, KEY, toggletag, {.ui = 1 << TAG} },

static const char *dmenucmd[] = { "rofi", "-show", "drun", NULL };
static const char *termcmd[] = { "ghostty", NULL };

static Key keys[] = {
    { MODKEY, XK_p, spawn, {.v = dmenucmd } },
    { MODKEY|ShiftMask, XK_Return, spawn, {.v = termcmd } },
    { MODKEY, XK_b, togglebar, {0} },
    { MODKEY, XK_j, focusstack, {.i = +1 } },
    { MODKEY, XK_k, focusstack, {.i = -1 } },
    { MODKEY, XK_Return, zoom, {0} },
    { MODKEY|ShiftMask, XK_c, killclient, {0} },
    { MODKEY, XK_t, setlayout, {.v = &layouts[0]} },
    { MODKEY, XK_f, setlayout, {.v = &layouts[1]} },
    { MODKEY, XK_m, setlayout, {.v = &layouts[2]} },
    TAGKEYS(XK_1, 0)
    TAGKEYS(XK_2, 1)
    TAGKEYS(XK_3, 2)
    TAGKEYS(XK_4, 3)
    TAGKEYS(XK_5, 4)
    TAGKEYS(XK_6, 5)
    TAGKEYS(XK_7, 6)
    TAGKEYS(XK_8, 7)
    TAGKEYS(XK_9, 8)
    { MODKEY|ShiftMask, XK_q, quit, {0} },
};
DWMEOF
}

apply_dwm_patches() {
    log "Applying DWM patches..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would apply DWM patches"
        return
    fi
    
    cd "$DWM_DIR"
    # Skip patches for now to avoid complexity
    log "Skipping patches for simplified setup"
}

build_dwm() {
    log "Building DWM..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would build and install DWM"
        return
    fi
    
    cd "$DWM_DIR"
    make clean install || error "Failed to build DWM"
}

create_dwmblocks_config() {
    log "Creating dwmblocks configuration..."
    backup_file "$DWMBLOCKS_DIR/blocks.h"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create dwmblocks config"
        return
    fi
    
    cat > "$DWMBLOCKS_DIR/blocks.h" << 'BLOCKSEOF'
static const Block blocks[] = {
    {"🔊 ", "amixer get Master | grep -o '[0-9]*%' | head -1", 5, 0},
    {"💾 ", "free -h | awk '/^Mem/ { print $3\"/\"$2 }' | sed s/i//g", 30, 0},
    {"📅 ", "date '+%b %d (%a) %I:%M%p'", 60, 0},
};

static char delim[] = " | ";
static unsigned int delimLen = 5;
BLOCKSEOF
}

build_dwmblocks() {
    log "Building dwmblocks..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would build and install dwmblocks"
        return
    fi
    
    cd "$DWMBLOCKS_DIR"
    make && sudo make install || error "Failed to build dwmblocks"
}

create_xinitrc() {
    log "Creating .xinitrc..."
    backup_file ~/.xinitrc
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create .xinitrc"
        return
    fi
    
    cat > ~/.xinitrc << 'XINITEOF'
#!/bin/sh
picom -b &
dunst &
if [ -d "$HOME/Pictures/Wallpapers" ] && [ "$(ls -A $HOME/Pictures/Wallpapers)" ]; then
    feh --bg-fill --randomize ~/Pictures/Wallpapers/* &
else
    xsetroot -solid '#1e1e1e' &
fi
dwmblocks &
exec dwm
XINITEOF
    
    chmod +x ~/.xinitrc
}

create_dwm_autostart() {
    log "Creating DWM autostart script..."
    mkdir -p ~/.dwm
    backup_file ~/.dwm/autostart.sh
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create DWM autostart script"
        return
    fi
    
    cat > ~/.dwm/autostart.sh << 'AUTOSTARTEOF'
#!/bin/bash
nm-applet &
xset r rate 300 50 &
xset b off &
if ! pgrep -x "picom" > /dev/null; then
    picom -b &
fi
AUTOSTARTEOF
    
    chmod +x ~/.dwm/autostart.sh
}

# AMD-specific functions
setup_amd_optimizations() {
    if ! lspci | grep -i "VGA.*AMD" &>/dev/null; then
        warn "No AMD GPU detected, skipping GPU-specific configurations"
        return
    fi
    
    log "AMD GPU detected, applying optimizations..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create AMD GPU configuration"
        return
    fi
    
    sudo tee /etc/X11/xorg.conf.d/20-amd.conf > /dev/null << 'AMDEOF'
Section "Device"
    Identifier "AMD Graphics"
    Driver "amdgpu"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
    Option "TearFree" "true"
EndSection
AMDEOF

    configure_amd_kernel_parameters
}

configure_amd_kernel_parameters() {
    log "Configuring kernel parameters..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure AMD kernel parameters"
        return
    fi
    
    echo "Choose AMD P-state mode (active/guided/passive/none): "
    read PSTATE_MODE
    if [[ -n "$PSTATE_MODE" && "$PSTATE_MODE" != "none" ]]; then
        if ! grep -q "amd_pstate=$PSTATE_MODE" /etc/default/grub; then
            sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/&amd_pstate=$PSTATE_MODE /" /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg || warn "Failed to update GRUB configuration"
        fi
    fi
}

# Additional configuration functions
setup_font_rendering() {
    log "Configuring font rendering..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure font rendering"
        return
    fi
    
    sudo mkdir -p /etc/fonts/conf.d
    backup_file /etc/fonts/local.conf
    sudo tee /etc/fonts/local.conf > /dev/null << 'FONTEOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
  </match>
  <match target="font">
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
  </match>
</fontconfig>
FONTEOF

    sudo fc-cache -fv || warn "Failed to update font cache"
}

setup_shell_aliases() {
    log "Configuring shell aliases..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure shell aliases"
        return
    fi
    
    local shell_config=~/.bashrc
    [[ -n "$ZSH_VERSION" ]] && shell_config=~/.zshrc
    
    backup_file "$shell_config"
    cat >> "$shell_config" << 'ALIASEOF'

# Custom aliases
alias la='ls -la --color=always'
alias fm='yazi'
alias backup='sudo timeshift --create --comments "Manual backup $(date)"'
ALIASEOF
}

create_user_directories() {
    log "Creating user directories..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create user directories"
        return
    fi
    
    mkdir -p ~/Documents/Scripts ~/Downloads/Software ~/.local/bin
    mkdir -p ~/Pictures/Screenshots
}

cleanup_system() {
    log "Cleaning up system..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would clean up system"
        return
    fi
    
    sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null || true
}

# Menu and execution functions
show_menu() {
    echo -e "${BLUE}=== Arch Linux Post-Install Setup ===${NC}"
    echo "Available modules:"
    echo "1.  System Update"
    echo "2.  Enable Multilib"  
    echo "3.  Install Essential Packages"
    echo "4.  Install Additional Packages"
    echo "5.  Install AUR Helper"
    echo "6.  Install AUR Packages" 
    echo "7.  Setup DWM Environment"
    echo "8.  AMD Optimizations"
    echo "9.  Enable Services"
    echo "10. Setup Firewall"
    echo "11. Font Rendering"
    echo "12. Shell Aliases"
    echo "13. User Directories"
    echo "14. Cleanup System"
    echo "15. Run All (Full Setup)"
    echo "16. Toggle Dry Run (currently: $DRY_RUN)"
    echo "0.  Exit"
    echo
}

run_selected_modules() {
    local modules=("$@")
    
    for module in "${modules[@]}"; do
        case $module in
            1) update_system ;;
            2) enable_multilib ;;
            3) install_essential_packages ;;
            4) install_additional_packages ;;
            5) install_aur_helper ;;
            6) install_aur_packages ;;
            7) setup_dwm_environment ;;
            8) setup_amd_optimizations ;;
            9) enable_essential_services ;;
            10) setup_ufw_firewall ;;
            11) setup_font_rendering ;;
            12) setup_shell_aliases ;;
            13) create_user_directories ;;
            14) cleanup_system ;;
            *) warn "Unknown module: $module" ;;
        esac
    done
}

run_full_setup() {
    log "Starting full setup..."
    local all_modules=(1 2 3 4 5 6 7 8 9 10 11 12 13 14)
    run_selected_modules "${all_modules[@]}"
    log "Full setup completed!"
}

interactive_menu() {
    while true; do
        show_menu
        echo -n "Select option(s) (space-separated, e.g., '1 3 5' or 'q' to quit): "
        read -r input
        
        case $input in
            q|Q|0) 
                log "Exiting..."
                exit 0
                ;;
            15)
                run_full_setup
                break
                ;;
            16)
                DRY_RUN=$( [ "$DRY_RUN" = true ] && echo false || echo true )
                log "Dry run mode set to: $DRY_RUN"
                continue
                ;;
            *)
                local selected_modules
                read -ra selected_modules <<< "$input"
                run_selected_modules "${selected_modules[@]}"
                echo -e "${GREEN}Selected modules completed!${NC}"
                echo -n "Press Enter to continue..."
                read
                ;;
        esac
    done
}

# Main execution
main() {
    validate_root
    check_disk_space  
    check_internet
    
    log "Arch Linux Post-Install Setup Script"
    log "Debug output is being saved to $DEBUG_LOG"
    
    if [ $# -eq 0 ]; then
        echo -e "${YELLOW}Continue with interactive mode? (y/N)${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Script execution cancelled by user"
        fi
        interactive_menu
    else
        case $1 in
            --full|--all)
                run_full_setup
                ;;
            --dry-run)
                DRY_RUN=true
                if [ $# -gt 1 ]; then
                    shift
                    run_selected_modules "$@"
                else
                    run_full_setup
                fi
                ;;
            --help|-h)
                echo "Usage: $0 [options] [module_numbers...]"
                echo "Options:"
                echo "  --full, --all     Run all modules"
                echo "  --dry-run         Enable dry run mode"
                echo "  --help, -h        Show this help"
                exit 0
                ;;
            *)
                run_selected_modules "$@"
                ;;
        esac
    fi
    
    echo -e "\n${GREEN}Setup completed! Reboot recommended.${NC}"
}

main "$@"
