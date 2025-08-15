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
    # System utilities
    "base-devel"
    "git"
    "curl"
    "wget"
    "vim"
    "nano"
    "htop"
    "neofetch"
    "tree"
    "unzip"
    "zip"
    
    # DWM and X11 essentials
    "xorg-server"
    "xorg-xinit"
    "xorg-xsetroot"
    "xorg-xrandr"
    "ghostty"
    "rofi"
    "feh"
    "picom"
    "dunst"
    "xsel"
    "xclip"
    "maim"
    "thunar"
    "thunar-archive-plugin"
    "thunar-media-tags-plugin"
    
    # Development tools
    "python"
    "python-pip"
    "ruby"
    "emacs"
    "docker"
    "docker-compose"
    "openssh"
    
    # System utilities
    "flatpak"
    "btop"
    "yt-dlp"
    "bluez"
    "bluez-utils"
    "blueman"
    "ufw"
    
    # Media and codecs
    "mpv"
    "celluloid"
    "ffmpeg"
    "obs-studio"
    "gst-plugins-good"
    "gst-plugins-bad"
    "gst-plugins-ugly"
    "gst-libav"
    
    # Archive support
    "p7zip"
    "unrar"
    "tar"
    "gzip"
    "bzip2"
    "xz"
    
    # Document viewers
    "okular"
    "zathura"
    "zathura-pdf-mupdf"
    
    # Backup solution
    "rsync"
    "timeshift"
    
    # Font rendering
    "fontconfig"
    "freetype2"
    "cairo"
    
    # Ruby development (Odin Project requirements)
    "nodejs"
    "npm"
    "postgresql"
    
    # AMD-specific
    "amd-ucode"
    "mesa"
    "vulkan-radeon"
    "libva-mesa-driver"
    "mesa-vdpau"
    
    # Audio
    "pipewire"
    "pipewire-alsa"
    "pipewire-pulse"
    "pipewire-jack"
    "wireplumber"
    
    # Networking
    "networkmanager"
    "network-manager-applet"
    
    # Fonts
    "ttf-dejavu"
    "ttf-liberation"
    "noto-fonts"
    "noto-fonts-emoji"
    
    # File system support
    "ntfs-3g"
    "exfat-utils"
)

ADDITIONAL_PACKAGES=(
    "firefox"
    "vlc"
    "gimp"
    "discord"
    "steam"
    "thunderbird"
    "lm_sensors"
    "ttf-jetbrains-mono"
    "nitrogen"
)

AUR_PACKAGES=(
    "google-chrome"
    "protonvpn"
    "onlyoffice-bin"
    "mise-bin"
    "lazygit"
    "lazydocker"
    "yazi"
    "jrnl"
    "catppuccin-gtk-theme-mocha"
    "papirus-icon-theme"
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

# DWM configuration functions
create_dwm_config() {
    log "Creating custom DWM configuration..."
    backup_file "$DWM_DIR/config.h"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create DWM config.h"
        return
    fi
    
    cat > "$DWM_DIR/config.h" << 'EOF'
/* See LICENSE file for copyright and license details. */

/* Catppuccin Mocha Colors */
static const char col_base[]        = "#1e1e2e";  /* Background */
static const char col_mantle[]      = "#181825";  /* Darker background */
static const char col_surface0[]    = "#313244";  /* Surface */
static const char col_surface1[]    = "#45475a";  /* Surface variant */
static const char col_surface2[]    = "#585b70";  /* Surface variant 2 */
static const char col_text[]        = "#cdd6f4";  /* Foreground text */
static const char col_subtext1[]    = "#bac2de";  /* Subtext */
static const char col_subtext0[]    = "#a6adc8";  /* Subtext variant */
static const char col_blue[]        = "#89b4fa";  /* Blue accent */
static const char col_lavender[]    = "#b4befe";  /* Lavender accent */
static const char col_mauve[]       = "#cba6f7";  /* Mauve accent */

/* appearance */
static const unsigned int borderpx  = 2;        /* border pixel of windows */
static const unsigned int snap      = 32;       /* snap pixel */
static const int swallowfloating    = 0;        /* 1 means swallow floating windows by default */
static const unsigned int gappih    = 10;       /* horiz inner gap between windows */
static const unsigned int gappiv    = 10;       /* vert inner gap between windows */
static const unsigned int gappoh    = 10;       /* horiz outer gap between windows and screen edge */
static const unsigned int gappov    = 10;       /* vert outer gap between windows and screen edge */
static       int smartgaps          = 0;        /* 1 means no outer gap when there is only one window */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const char *fonts[]          = { "JetBrains Mono:size=10" };
static const char dmenufont[]       = "JetBrains Mono:size=10";

static const char *colors[][3]      = {
	/*               fg           bg           border   */
	[SchemeNorm] = { col_text,     col_base,    col_surface1 },
	[SchemeSel]  = { col_base,     col_mauve,   col_mauve    },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	/* class           instance  title           tags mask  isfloating  isterminal  noswallow  monitor */
	{ "Gimp",          NULL,     NULL,           0,         1,          0,           0,        -1 },
	{ "Firefox",       NULL,     NULL,           1 << 8,    0,          0,          -1,        -1 },
	{ "ghostty",       NULL,     NULL,           0,         0,          1,           0,        -1 },
	{ "ProtonVPN",     NULL,     NULL,           0,         1,          0,           0,        -1 },
	{ "Blueman-manager", NULL,   NULL,           0,         1,          0,           0,        -1 },
	{ "Thunar",        NULL,     NULL,           0,         0,          0,           0,        -1 },
	{ "mpv",           NULL,     NULL,           0,         0,          0,           0,        -1 },
	{ "Celluloid",     NULL,     NULL,           0,         0,          0,           0,        -1 },
	{ "obs",           NULL,     NULL,           0,         0,          0,           0,        -1 },
	{ "Okular",        NULL,     NULL,           0,         0,          0,           0,        -1 },
	{ NULL,            NULL,     "Event Tester", 0,         0,          0,           1,        -1 }, /* xev */
};

/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* key definitions */
#define MODKEY Mod4Mask  /* Windows/Super key */
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = { "rofi", "-show", "drun", NULL };
static const char *termcmd[]  = { "ghostty", NULL };
static const char *randomwallcmd[] = { "sh", "-c", "feh --bg-fill --randomize ~/Pictures/Wallpapers/*", NULL };
static const char *screenshotcmd[] = { "maim", "-s", "-u", "/tmp/screenshot.png", NULL };
static const char *filemanagercmd[] = { "thunar", NULL };
static const char *yazifilemanagercmd[] = { "ghostty", "-e", "yazi", NULL };

static Key keys[] = {
	/* modifier                     key        function        argument */
	{ MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
	{ MODKEY|ShiftMask,             XK_Return, spawn,          {.v = termcmd } },
	{ MODKEY|ShiftMask,             XK_w,      spawn,          {.v = randomwallcmd } },
	{ MODKEY,                       XK_Print,  spawn,          {.v = screenshotcmd } },
	{ MODKEY,                       XK_e,      spawn,          {.v = filemanagercmd } },
	{ MODKEY|ShiftMask,             XK_e,      spawn,          {.v = yazifilemanagercmd } },
	{ MODKEY,                       XK_b,      togglebar,      {0} },
	{ MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
	{ MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
	{ MODKEY,                       XK_h,      setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,      setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Return, zoom,           {0} },
	{ MODKEY,                       XK_Tab,    view,           {0} },
	{ MODKEY|ShiftMask,             XK_c,      killclient,     {0} },
	{ MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_f,      setlayout,      {.v = &layouts[1]} },
	{ MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                       XK_space,  setlayout,      {0} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
	{ MODKEY,                       XK_0,      view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period, focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
	TAGKEYS(                        XK_1,                      0)
	TAGKEYS(                        XK_2,                      1)
	TAGKEYS(                        XK_3,                      2)
	TAGKEYS(                        XK_4,                      3)
	TAGKEYS(                        XK_5,                      4)
	TAGKEYS(                        XK_6,                      5)
	TAGKEYS(                        XK_7,                      6)
	TAGKEYS(                        XK_8,                      7)
	TAGKEYS(                        XK_9,                      8)
	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} },
};

/* button definitions */
static Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};
EOF
}

apply_dwm_patches() {
    log "Downloading and applying DWM patches..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would apply DWM patches"
        return
    fi
    
    cd "$DWM_DIR"
    
    local patches=(
        "https://dwm.suckless.org/patches/autostart/dwm-autostart-20210120-cb3f58a.diff"
        "https://dwm.suckless.org/patches/center/dwm-center-6.2.diff"
        "https://dwm.suckless.org/patches/swallow/dwm-swallow-20201211-61bb8b2.diff"
        "https://dwm.suckless.org/patches/cursorwarp/dwm-cursorwarp-20210222-61bb8b2.diff"
    )
    
    local patch_names=(
        "autostart.patch"
        "center.patch"
        "swallow.patch"
        "cursorwarp.patch"
    )
    
    for i in "${!patches[@]}"; do
        local url="${patches[$i]}"
        local filename="${patch_names[$i]}"
        
        if curl -o "$filename" "$url"; then
            if patch -p1 < "$filename"; then
                log "Applied $filename successfully"
            else
                warn "Failed to apply $filename. Continuing with default configuration."
            fi
        else
            warn "Failed to download $filename"
        fi
    done
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
    
    cat > "$DWMBLOCKS_DIR/blocks.h" << 'EOF'
static const Block blocks[] = {
	/*Icon*/	/*Command*/		/*Update Interval*/	/*Update Signal*/
	{"🔊 ", "amixer get Master | grep -o '[0-9]*%' | head -1", 5, 0},
	{"💾 ", "free -h | awk '/^Mem/ { print $3\"/\"$2 }' | sed s/i//g", 30, 0},
	{"💻 ", "btop -p 0 | grep -o '[0-9]*\\.[0-9]*%' | head -1 || echo '0%'", 10, 0},
	{"🌡️ ", "sensors | grep 'Tctl' | awk '{print $2}' | sed 's/+//' || echo 'N/A'", 10, 0},
	{"📅 ", "date '+%b %d (%a) %I:%M%p'", 60, 0},
};

//sets delimiter between status commands
static char delim[] = " | ";
static unsigned int delimLen = 5;
EOF
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

create_xinitrc() {
    log "Creating .xinitrc..."
    backup_file ~/.xinitrc
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create .xinitrc"
        return
    fi
    
    cat > ~/.xinitrc << 'EOF'
#!/bin/sh

# Start compositor
picom -b &

# Start notification daemon
dunst &

# Set wallpaper (random from wallpapers directory)
if [ -d "$HOME/Pictures/Wallpapers" ] && [ "$(ls -A $HOME/Pictures/Wallpapers)" ]; then
    feh --bg-fill --randomize ~/Pictures/Wallpapers/* &
else
    # Fallback solid color
    xsetroot -solid '#1e1e1e' &
fi

# Start dwmblocks
dwmblocks &

# Start DWM
exec dwm
EOF
    
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
    
    cat > ~/.dwm/autostart.sh << 'EOF'
#!/bin/bash

# Network Manager applet
nm-applet &

# Set keyboard repeat rate
xset r rate 300 50 &

# Disable bell
xset b off &

# Start compositor if not already running
if ! pgrep -x "picom" > /dev/null; then
    picom -b &
fi
EOF
    
    chmod +x ~/.dwm/autostart.sh
}

# AMD-specific functions
setup_amd_optimizations() {
    if ! lspci | grep -i "VGA.*AMD" &>/dev/null; then
        warn "No AMD GPU detected, skipping GPU-specific configurations"
        return
    fi
    
    log "
