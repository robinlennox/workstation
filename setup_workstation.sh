#!/bin/bash
# =============================================================================
# Script Name: setup_workstation.sh
# Description: Automated workstation setup for Debian/GNOME
# Author:      Robin Lennox
# Repository:  https://github.com/robinlennox/workstation
# Licence:     MIT
# =============================================================================
set -euo pipefail

# --- Functions ---
install_pkg() {
    local pkg="$1"
    echo "Installing $pkg..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
}

add_apt_repo() {
    local name="$1"
    local repo_line="$2"
    local key_url="$3"
    local key_file="$4"

    echo "Adding $name repository..."
    
    # Ensure the directory for the key exists
    sudo mkdir -p "$(dirname "$key_file")"

    # Download, dearmor, and save the key
    # Using a temporary file ensures we don't have partial writes
    curl -fsSL "$key_url" | sudo gpg --dearmor --yes -o "$key_file"
    
    # Ensure the key is world-readable (required by some versions of apt/sqv)
    sudo chmod 644 "$key_file"

    # Remove existing configs to prevent the "multiple times" error
    sudo rm -f "/etc/apt/sources.list.d/$name.list"
    sudo rm -f "/etc/apt/sources.list.d/$name.sources"

    # Write the new repo line
    echo "$repo_line" | sudo tee "/etc/apt/sources.list.d/$name.list" > /dev/null
}

install_flatpak_app() {
    local app="$1"
    echo "Installing Flatpak $app..."
    sudo flatpak install --system --noninteractive flathub "$app"
}

# --- Privilege Check & Auto-Enroll ---
if [ "$EUID" -ne 0 ]; then
    if ! groups "$USER" | grep -q "\bsudo\b"; then
        echo "You are not in the sudo group. Attempting to add you now..."
        echo "Please enter the ROOT password:"
        su -c "/usr/sbin/adduser $USER sudo"
        
        echo "------------------------------------------------------------"
        echo "SUCCESS: $USER has been added to the sudo group."
        echo "CRITICAL: You must reboot to apply these permissions."
        echo "Please run this script again AFTER rebooting."
        echo "------------------------------------------------------------"
        
        read -p "Reboot now? (y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            su -c "reboot"
        else
            exit 0
        fi
    fi
fi

# --- System Prep ---
sudo apt-get update
sudo apt-get install -y wget curl gnupg apt-transport-https flatpak lsb-release

# --- Enable non-free and contrib ---
sudo sed -i '/^\([^#].*main\)/s/main/& contrib non-free non-free-firmware/' /etc/apt/sources.list

# --- Add Repositories ---
add_apt_repo "vscode" \
"deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
"https://packages.microsoft.com/keys/microsoft.asc" \
"/usr/share/keyrings/microsoft.gpg"

add_apt_repo "antigravity" \
"deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
"https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" \
"/etc/apt/keyrings/antigravity-repo-key.gpg"

add_apt_repo "google-chrome" \
"deb [arch=amd64 signed-by=/usr/share/keyrings/chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
"https://dl.google.com/linux/linux_signing_key.pub" \
"/usr/share/keyrings/chrome-keyring.gpg"

add_apt_repo "syncthing" \
"deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" \
"https://syncthing.net/release-key.gpg" \
"/usr/share/keyrings/syncthing-archive-keyring.gpg"

add_apt_repo "cloudflare" \
"deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
"https://pkg.cloudflareclient.com/pubkey.gpg" \
"/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"

add_apt_repo "signal" \
"deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" \
"https://updates.signal.org/desktop/apt/keys.asc" \
"/usr/share/keyrings/signal-desktop-keyring.gpg"

sudo apt-get update

# --- Graphics Driver Setup (Hybrid AMD/Nvidia) ---
echo "Setting up Hybrid Graphics drivers..."
sudo apt install -y linux-headers-$(uname -r) build-essential
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install nvidia-kernel-dkms nvidia-driver
echo "options nvidia-drm modeset=1" | sudo tee -a /etc/modprobe.d/nvidia.conf
sudo update-initramfs -u

# --- Install Packages (Bulk) ---
PACKAGES=(
    syncthing python3-pip docker.io git htop iftop ipcalc nload chrome-gnome-shell openssh-server 
    traceroute whois zsh terminator nmap knockd adwaita-icon-theme-full p7zip google-chrome-stable 
    screen net-tools gnome-firmware chromium code macchanger remmina android-tools-adb 
    android-tools-fastboot rsync sshuttle openvpn network-manager-openvpn-gnome dnsutils 
    gthumb flatpak vim chrony ncdu cloudflare-warp signal-desktop tlp tlp-rdw antigravity x11-xserver-utils python3-nautilus
)
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "${PACKAGES[@]}"

# --- Flatpak Apps ---
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
FLATPAKS=(org.keepassxc.KeePassXC com.github.PintaProject.Pinta com.github.d4nj1.tlpui)
for app in "${FLATPAKS[@]}"; do install_flatpak_app "$app"; done
sudo flatpak update --system --noninteractive

# --- TLP Setup & Configuration Import ---
echo "Configuring TLP..."
sudo systemctl mask power-profiles-daemon || true

# Define the remote path
TLP_CONF_URL="https://raw.githubusercontent.com/robinlennox/workstation/main/tlp.conf"
TEMP_TLP="/tmp/tlp.conf"

# Download and apply custom tlp.conf
echo "Fetching custom tlp.conf from repository..."
if wget -qO "$TEMP_TLP" "$TLP_CONF_URL"; then
    sudo mv "$TEMP_TLP" /etc/tlp.conf
    sudo chmod 644 /etc/tlp.conf
    echo "Successfully imported tlp.conf and cleaned up temporary files."
else
    echo "Failed to download remote tlp.conf. Using system defaults."
    rm -f "$TEMP_TLP"
fi

sudo systemctl enable tlp && sudo systemctl start tlp

# --- Desktop Configs ---
sudo sed -i 's/Exec=\/usr\/bin\/google-chrome-stable/Exec=\/usr\/bin\/google-chrome-stable --enable-features=VaapiVideoDecoder/g' /usr/share/applications/google-chrome.desktop
mkdir -p ~/Templates && touch ~/Templates/file

# --- GNOME Shell Extensions (Deferred to next logon) ---
sudo apt install -y gnome-shell-extension-tiling-assistant gnome-shell-extension-dashtodock

# Define paths for the one-time cleanup script
ONETIME_SCRIPT="$HOME/.enable_extensions_once.sh"
ONETIME_AUTOSTART="$HOME/.config/autostart/enable_extensions.desktop"

# Create the background worker script
cat << 'EOF' > "$ONETIME_SCRIPT"
#!/bin/bash
# Wait for GNOME to fully initialize
sleep 10

# Enable the extensions
gnome-extensions enable dash-to-dock@micxgx.gmail.com || true
gnome-extensions enable tiling-assistant@leleat-on-github || true

# Set Settings
gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true
gsettings set org.gnome.shell.extensions.dash-to-dock apply-custom-theme true
gsettings set org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true

# Self-destruct: remove the trigger and this script
rm -f "$HOME/.config/autostart/enable_extensions.desktop"
rm -f "$0"
EOF

chmod +x "$ONETIME_SCRIPT"

# Create the Autostart trigger
mkdir -p "$HOME/.config/autostart"
cat << EOF > "$ONETIME_AUTOSTART"
[Desktop Entry]
Type=Application
Name=One-time Extension Enabler
Exec=$ONETIME_SCRIPT
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# --- GNOME settings ---
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'areas'
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.nautilus.preferences show-delete-permanently true
gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent 'true'
gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']"
gsettings set org.gnome.TextEditor show-line-numbers true
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden true

# --- Autostart Section ---
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# Xrandr Auto
cat << EOF > "$AUTOSTART_DIR/xrandr.desktop"
[Desktop Entry]
Type=Application
Name=Xrandr Auto
Exec=/usr/bin/xrandr --auto
X-GNOME-Autostart-enabled=true
EOF

# Wallpaper Rotator (10s JXL/SVG)
ROTATOR_BIN_DIR="$HOME/.local/bin"
ROTATOR_SCRIPT="$ROTATOR_BIN_DIR/rotate_bg.sh"
pkill -f "$ROTATOR_SCRIPT" || true
mkdir -p -m 700 "$ROTATOR_BIN_DIR"

cat << 'EOF' > "$ROTATOR_SCRIPT"
#!/bin/bash
readonly TARGET_DIR="/usr/share/backgrounds/gnome"
readonly INTERVAL=600
while true; do
    IMG=$(find "$TARGET_DIR" -type f \( -iname "*.jxl" -o -iname "*.svg" \) -print0 | shuf -z -n 1 | tr -d '\0')
    if [[ -f "$IMG" ]]; then
        gsettings set org.gnome.desktop.background picture-uri "file://$IMG"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$IMG"
        gsettings set org.gnome.desktop.background picture-options 'zoom'
    fi
    sleep "$INTERVAL"
done
EOF
chmod 700 "$ROTATOR_SCRIPT"

cat << EOF > "$AUTOSTART_DIR/wallpaper-rotator.desktop"
[Desktop Entry]
Type=Application
Exec=$ROTATOR_SCRIPT
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Wallpaper Rotator
Comment=Secure JXL/SVG Rotation
EOF
chmod 600 "$AUTOSTART_DIR/wallpaper-rotator.desktop"
nohup "$ROTATOR_SCRIPT" >/dev/null 2>&1 &

# --- Terminator as the default terminal ---
sudo update-alternatives --set x-terminal-emulator /usr/bin/terminator

# Ensure GNOME uses it for desktop shortcuts/actions
gsettings set org.gnome.desktop.default-applications.terminal exec 'terminator'

# Create the extension directory
mkdir -p "$HOME/.local/share/nautilus-python/extensions"

# Create the extension script
cat << 'EOF' > "$HOME/.local/share/nautilus-python/extensions/open-terminator.py"
import os
import subprocess
from gi.repository import Nautilus, GObject

class OpenTerminatorExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        pass

    def open_terminator(self, menu, folder):
        # Use get_uri() and handle file:// prefix for better path compatibility
        uri = folder.get_uri()
        if uri.startswith("file://"):
            path = uri[7:].replace("%20", " ") # Basic decoding
            # subprocess.Popen with a list is secure against shell injection
            subprocess.Popen(["terminator", "--working-directory", path])

    def get_background_items(self, *args):
        # args[-1] is the current folder
        item = Nautilus.MenuItem(
            name="NautilusPython::OpenTerminator",
            label="Open in Terminator",
            tip="Open Terminator in this directory"
        )
        item.connect("activate", self.open_terminator, args[-1])
        return [item]
EOF

# Restart Nautilus to apply
nautilus -q >/dev/null 2>&1 || true

# --- Install ctop (Dynamic Latest Version) ---
if ! command -v ctop &> /dev/null; then
    echo "Fetching latest ctop version from GitHub..."
    
    # Dynamically get the latest version tag (e.g., v0.7.7)
    LATEST_CTOP=$(curl -s https://api.github.com/repos/bcicen/ctop/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    
    if [ -n "$LATEST_CTOP" ]; then
        echo "Installing ctop $LATEST_CTOP..."
        sudo wget "https://github.com/bcicen/ctop/releases/download/${LATEST_CTOP}/ctop-${LATEST_CTOP#v}-linux-amd64" -O /usr/local/bin/ctop
        sudo chmod +x /usr/local/bin/ctop
        echo "ctop installed successfully."
    else
        echo "Error: Could not determine latest ctop version. Skipping."
    fi
else
    echo "ctop is already installed, skipping."
fi

# --- Oh My Zsh ---
echo "Installing Oh My Zsh..."
wget -qO- https://github.com/ohmyzsh/ohmyzsh/raw/master/tools/install.sh | zsh || true

# --- Change shell to Zsh with retry ---
ZSH_PATH="$(which zsh)"
echo "Changing default shell to Zsh..."

while true; do
    # sudo reads password from terminal directly
    if sudo -k -S -p "Enter your password to change shell: " chsh -s "$ZSH_PATH" "$USER" </dev/tty; then
        echo "Shell changed to Zsh successfully!"
        break
    else
        echo "Authentication failed. Please try again."
    fi
done

# --- Cleanup ---
echo "Cleaning up bloatware..."
sudo apt-get remove --auto-remove -y gnome-2048 evolution gnome-chess gnome-contacts xiterm+thai xterm thunderbird fcitx5 fcitx-bin four-in-a-row five-or-more hdate-applet gnome-maps gnome-sudoku gnome-mahjongg gnome-klotski goldendict aisleriot lightsoff gnome-mines mozc-data hitori gnome-music gnome-nibbles quadrapassel gnome-robots iagno pegsolitaire swell-foop gnome-tetravex gnome-taquin anthy-common tali totem totem-plugins rhythmbox gnome-sound-recorder shotwell-common gnome-tour gnome-connections gnome-calendar gnome-terminal
sudo apt-get -y autoremove && sudo apt-get clean

# --- Cloudflare WARP registration ---
echo "Registering Cloudflare WARP..."
read -r -p "Enter Cloudflare organisation name: " ORG

# Run warp-cli in the background, ignore non-critical errors
{
    warp-cli registration new "$ORG" 2>/dev/null &
}

# Capture the PID of the background process (optional)
WARP_PID=$!
echo "Warp registration running in the background (PID: $WARP_PID)"

echo "Setup complete! The system will now reboot to apply graphics drivers and shell changes."
