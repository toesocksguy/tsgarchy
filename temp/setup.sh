#!/bin/sh

# Arch Linux DWM Setup Script
# Run this script from TTY after fresh Arch installation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=13
CURRENT_STEP=0

# Logging functions
log() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Progress indicator function
progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    printf "${BLUE}[%d/%d]${NC} %s\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
}

# Check if running as root
check_root() {
    progress "Checking user permissions..."
    if [ "$(id -u)" -eq 0 ]; then
        error "Don't run this script as root!"
        exit 1
    fi
}

# Update system packages
update_system() {
    progress "Updating system packages..."
    sudo pacman -Syu --noconfirm
}

# Handle PulseAudio conflicts
handle_pulseaudio_conflict() {
    if pacman -Qs pulseaudio >/dev/null 2>&1; then
        warn "PulseAudio is currently installed and may conflict with PipeWire"
        printf "Do you want to remove PulseAudio? (y/N): "
        read -r response
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            log "Removing PulseAudio..."
            sudo pacman -R pulseaudio --noconfirm
        else
            warn "Keeping PulseAudio - you may experience audio conflicts"
        fi
    fi
}

# Install essential packages
install_packages() {
    progress "Installing essential packages..."
    handle_pulseaudio_conflict
    
    sudo pacman -S --noconfirm \
        base-devel \
        git \
        wget \
        curl \
        vim \
        nano \
        htop \
        firefox \
        xorg-server \
        xorg-xinit \
        xorg-xrandr \
        xorg-xsetroot \
        lightdm \
        lightdm-gtk-greeter \
        picom \
        feh \
        rofi \
        ghostty \
        dmenu \
        ttf-dejavu \
        ttf-liberation \
        noto-fonts \
        pipewire \
        pipewire-alsa \
        pipewire-pulse \
        pipewire-jack \
        wireplumber \
        pavucontrol \
        networkmanager \
        network-manager-applet \
        bluez \
        bluez-utils \
        thunar \
        gvfs \
        tumbler \
        xdg-user-dirs \
        xdg-utils \
        unzip \
        p7zip \
        fastfetch
}

# Install AUR helper (yay)
install_yay() {
    progress "Installing AUR helper (yay)..."
    if ! command -v yay >/dev/null 2>&1; then
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd "$HOME"
    else
        log "yay already installed, skipping..."
    fi
}

# Create necessary directories
create_directories() {
    progress "Creating user directories..."
    mkdir -p "$HOME/.local/src"
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.config/X11"
    mkdir -p "$HOME/.config/dwm"
    mkdir -p "$HOME/.config/rofi"
    mkdir -p "$HOME/.config/picom"
    mkdir -p "$HOME/.config/ghostty"
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/Pictures/wallpapers"
}

# Clone and build suckless software
build_suckless() {
    project="$1"
    log "Cloning and building $project..."
    
    cd "$HOME/.local/src"
    
    if [ ! -d "$project" ]; then
        git clone "https://git.suckless.org/$project"
    else
        warn "$project directory already exists, pulling latest changes..."
        cd "$project"
        git pull
        cd ..
    fi
    
    cd "$project"
    log "Building $project..."
    make clean
    sudo make clean install
    cd "$HOME/.local/src"
}

# Enable multilib repository
enable_multilib() {
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        log "Enabling multilib repository..."
        sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy --noconfirm
    else
        log "Multilib repository already enabled"
    fi
}

# Detect CPU vendor
detect_cpu_vendor() {
    if grep -q "GenuineIntel" /proc/cpuinfo; then
        echo "intel"
    elif grep -q "AuthenticAMD" /proc/cpuinfo; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Install CPU microcode
install_cpu_microcode() {
    cpu_vendor=$(detect_cpu_vendor)
    case $cpu_vendor in
        "intel")
            log "Installing Intel microcode..."
            sudo pacman -S --noconfirm intel-ucode
            ;;
        "amd")
            log "Installing AMD microcode..."
            sudo pacman -S --noconfirm amd-ucode
            ;;
        *)
            warn "Unknown CPU vendor, skipping microcode installation"
            ;;
    esac
}

# Detect GPU vendor
detect_gpu_vendor() {
    # Check for QEMU/KVM virtual graphics first
    if lspci | grep -i "1234:1111\|qemu\|virtio.*vga" >/dev/null 2>&1; then
        echo "virtual"
    elif lspci | grep -i "nvidia" >/dev/null 2>&1; then
        echo "nvidia"
    elif lspci | grep -i "amd\|radeon" >/dev/null 2>&1; then
        echo "amd"
    elif lspci | grep -i "intel.*graphics\|intel.*display" >/dev/null 2>&1; then
        echo "intel"
    else
        # Fallback: check VGA controllers more broadly
        if lspci | grep -i "vga.*intel" >/dev/null 2>&1; then
            echo "intel"
        elif lspci | grep -i "vga.*nvidia" >/dev/null 2>&1; then
            echo "nvidia"
        elif lspci | grep -i "vga.*amd\|vga.*radeon" >/dev/null 2>&1; then
            echo "amd"
        else
            echo "unknown"
        fi
    fi
}

# Install GPU drivers
install_gpu_drivers() {
    enable_multilib
    
    gpu_vendor=$(detect_gpu_vendor)
    case $gpu_vendor in
        "nvidia")
            log "Installing NVIDIA proprietary drivers..."
            sudo pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils
            ;;
        "amd")
            log "Installing AMD open-source drivers..."
            sudo pacman -S --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu
            ;;
        "intel")
            log "Installing Intel graphics drivers..."
            sudo pacman -S --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver libva-intel-driver
            ;;
        "virtual")
            log "Virtual GPU detected (QEMU/KVM), installing basic drivers..."
            sudo pacman -S --noconfirm mesa lib32-mesa xf86-video-qxl
            ;;
        *)
            warn "Unknown GPU vendor, installing generic mesa drivers..."
            sudo pacman -S --noconfirm mesa lib32-mesa
            ;;
    esac
}

# Detect virtualization environment
detect_virtualization() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt_type=$(systemd-detect-virt)
        if [ "$virt_type" != "none" ]; then
            echo "$virt_type"
        else
            echo "none"
        fi
    elif [ -f /sys/class/dmi/id/product_name ]; then
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case $product_name in
            *"QEMU"*|*"KVM"*)
                echo "kvm"
                ;;
            *"VirtualBox"*)
                echo "virtualbox"
                ;;
            *"VMware"*)
                echo "vmware"
                ;;
            *)
                echo "none"
                ;;
        esac
    else
        echo "none"
    fi
}

# Install VM guest tools
install_vm_tools() {
    virt_env=$(detect_virtualization)
    case $virt_env in
        "kvm"|"qemu")
            log "Installing QEMU guest tools..."
            sudo pacman -S --noconfirm qemu-guest-agent spice-vdagent
            sudo systemctl enable qemu-guest-agent
            ;;
        "virtualbox")
            log "Installing VirtualBox guest tools..."
            sudo pacman -S --noconfirm virtualbox-guest-utils
            sudo systemctl enable vboxservice
            ;;
        "vmware")
            log "Installing VMware guest tools..."
            sudo pacman -S --noconfirm open-vm-tools
            sudo systemctl enable vmtoolsd
            ;;
        "none")
            log "No virtualization detected, skipping guest tools..."
            ;;
        *)
            warn "Unknown virtualization environment: $virt_env, skipping guest tools..."
            ;;
    esac
}

# Setup hardware support
setup_hardware_support() {
    progress "Detecting and configuring hardware support..."
    install_cpu_microcode
    install_gpu_drivers
    install_vm_tools
}
build_all_suckless() {
    progress "Building suckless software (DWM, ST, dmenu)..."
    build_suckless "dwm"
    build_suckless "st" 
    build_suckless "dmenu"
}

# Enable system services
enable_services() {
    progress "Enabling system services..."
    sudo systemctl enable lightdm
    sudo systemctl enable NetworkManager
    sudo systemctl enable bluetooth
    
    # Enable pipewire services for current user
    systemctl --user enable pipewire.service
    systemctl --user enable pipewire-pulse.service
    systemctl --user enable wireplumber.service
}

# Create xinitrc configuration
create_xinitrc() {
    progress "Creating X11 session configuration..."
    cat > "$HOME/.config/X11/xinitrc" << 'EOF'
#!/bin/sh

userresources=$HOME/.config/X11/Xresources
usermodmap=$HOME/.config/X11/Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps
if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# start some nice programs
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# Set wallpaper (if available)
if [ -f ~/Pictures/wallpapers/wallpaper.jpg ]; then
    feh --bg-scale ~/Pictures/wallpapers/wallpaper.jpg &
fi

# Start pipewire
pipewire &
pipewire-pulse &
wireplumber &

# Start compositor
picom --config ~/.config/picom/picom.conf &

# Start network manager applet
nm-applet &

# Set status bar info
while true; do
    xsetroot -name "$(date '+%Y-%m-%d %H:%M:%S') | $(cat /proc/loadavg | cut -d' ' -f1-3)"
    sleep 60
done &

# Execute DWM
exec dwm
EOF
    chmod +x "$HOME/.config/X11/xinitrc"
    
    # Create a symlink for compatibility
    ln -sf "$HOME/.config/X11/xinitrc" "$HOME/.xinitrc"
}

# Create DWM desktop entry for LightDM
create_desktop_entry() {
    progress "Creating desktop session entry..."
    sudo mkdir -p /usr/share/xsessions
    sudo tee /usr/share/xsessions/dwm.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager
Exec=/usr/local/bin/dwm
Type=XSession
EOF
}

# Create Xresources configuration
create_xresources() {
    progress "Creating X resources configuration..."
    cat > "$HOME/.config/X11/Xresources" << 'EOF'
! Terminal colors
*foreground: #d0d0d0
*background: #151515
*color0: #151515
*color1: #ac4142
*color2: #7e8d50
*color3: #e5b567
*color4: #6c99bb
*color5: #9f4e85
*color6: #7dd6cf
*color7: #d0d0d0
*color8: #505050
*color9: #ac4142
*color10: #7e8d50
*color11: #e5b567
*color12: #6c99bb
*color13: #9f4e85
*color14: #7dd6cf
*color15: #f5f5f5

! Font settings
*font: DejaVu Sans Mono:size=11
EOF
    
    # Create a symlink for compatibility
    ln -sf "$HOME/.config/X11/Xresources" "$HOME/.Xresources"
}

# Generate XDG user directories
setup_user_dirs() {
    progress "Setting up user directories..."
    xdg-user-dirs-update
}

# Create additional config files
create_additional_configs() {
    progress "Creating additional configuration files..."
    
    # Create basic picom config
    cat > "$HOME/.config/picom/picom.conf" << 'EOF'
# Basic picom configuration for DWM
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;

# Fading
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 10;

# Transparency/Opacity
inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 0.9;

# Window type settings
wintypes:
{
  tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; };
  dock = { shadow = false; };
  dnd = { shadow = false; };
  popup_menu = { opacity = 0.95; };
  dropdown_menu = { opacity = 0.95; };
};
EOF

    # Create basic rofi config
    mkdir -p "$HOME/.config/rofi"
    cat > "$HOME/.config/rofi/config.rasi" << 'EOF'
configuration {
    modi: "run,drun,window";
    width: 50;
    lines: 15;
    columns: 1;
    font: "DejaVu Sans Mono 12";
    show-icons: true;
    terminal: "ghostty";
    ssh-client: "ssh";
    ssh-command: "{terminal} -e {ssh-client} {host} [-p {port}]";
    run-command: "{cmd}";
    drun-match-fields: "name,generic,exec,categories";
    disable-history: false;
    ignored-prefixes: "";
    sort: false;
    case-sensitive: false;
    cycle: true;
    sidebar-mode: false;
    eh: 1;
    auto-select: false;
    parse-hosts: false;
    parse-known-hosts: true;
    combi-modi: "window,run";
    matching: "fuzzy";
    tokenize: true;
    m: "-5";
    filter: "";
    dpi: -1;
    threads: 0;
    scroll-method: 0;
    scrollbar-width: 8;
    click-to-exit: true;
    show-match: true;
    theme: "Arc-Dark";
    color-normal: "#2e3440, #d8dee9, #3b4252, #bf616a, #eceff4";
    color-urgent: "#2e3440, #ebcb8b, #3b4252, #bf616a, #eceff4";
    color-active: "#2e3440, #b48ead, #3b4252, #bf616a, #eceff4";
    color-window: "#2e3440, #a3be8c, #4c566a";
    max-history-size: 25;
    combi-hide-mode-prefix: false;
    matching-negate-char: '-';
}
EOF

    # Create basic ghostty config
    cat > "$HOME/.config/ghostty/config" << 'EOF'
# Ghostty Terminal Configuration
font-family = "DejaVu Sans Mono"
font-size = 11

# Colors (matching Xresources theme)
background = 151515
foreground = d0d0d0

palette = 0=#151515
palette = 1=#ac4142
palette = 2=#7e8d50
palette = 3=#e5b567
palette = 4=#6c99bb
palette = 5=#9f4e85
palette = 6=#7dd6cf
palette = 7=#d0d0d0
palette = 8=#505050
palette = 9=#ac4142
palette = 10=#7e8d50
palette = 11=#e5b567
palette = 12=#6c99bb
palette = 13=#9f4e85
palette = 14=#7dd6cf
palette = 15=#f5f5f5

# Window settings
window-padding-x = 8
window-padding-y = 8
window-decoration = false

# Other settings
scrollback-limit = 10000
confirm-close-surface = false
EOF
}

# Display completion message
show_completion() {
    progress "Setup complete! Displaying final information..."
    log "Basic setup complete!"
    printf "\n"
    printf "${BLUE}=====================================${NC}\n"
    printf "${BLUE}  Arch Linux DWM Setup Complete!${NC}\n"
    printf "${BLUE}=====================================${NC}\n"
    printf "\n"
    printf "${GREEN}Next steps:${NC}\n"
    printf "1. Reboot your system: sudo reboot\n"
    printf "2. Login through LightDM\n"
    printf "3. DWM should start automatically\n"
    printf "\n"
    printf "${YELLOW}Key bindings (DWM defaults):${NC}\n"
    printf "• Super+Return: Open terminal\n"
    printf "• Super+p: Open dmenu\n"
    printf "• Super+j/k: Navigate windows\n"
    printf "• Super+Shift+c: Close window\n"
    printf "• Super+Shift+q: Quit DWM\n"
    printf "\n"
    printf "${YELLOW}Installed terminals:${NC}\n"
    printf "• ghostty (modern)\n"
    printf "• st (suckless)\n"
    printf "\n"
    printf "${YELLOW}Configuration files location:${NC}\n"
    printf "• All configs are in ~/.config/\n"
    printf "• X11: ~/.config/X11/ (xinitrc, Xresources)\n"
    printf "• Picom: ~/.config/picom/picom.conf\n"
    printf "• Rofi: ~/.config/rofi/config.rasi\n"
    printf "• Ghostty: ~/.config/ghostty/config\n"
    printf "• DWM source: ~/.local/src/dwm/\n"
    printf "• ST source: ~/.local/src/st/\n"
    printf "• dmenu source: ~/.local/src/dmenu/\n"
    printf "\n"
    warn "Remember to customize DWM config in ~/.local/src/dwm/config.h"
    warn "After changes, run 'sudo make clean install' in the dwm directory"
}

# Main execution function
main() {
    log "Starting Arch Linux DWM setup..."
    
    check_root
    update_system
    install_packages
    install_yay
    create_directories
    setup_hardware_support
    build_all_suckless
    enable_services
    create_xinitrc
    create_desktop_entry
    create_xresources
    create_additional_configs
    setup_user_dirs
    show_completion
}

# Execute main function
main "$@"
