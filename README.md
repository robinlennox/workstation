
# workstation
A collection of configuration files and a setup script for a Debian/GNOME environment.

## Description
This repository contains my bootstrap script (`setup_workstation.sh`) designed to transform a fresh Debian 13 installation into a development workstation. It handles AMD/Nvidia Hybrid graphics drivers to GNOME extensions and shell customisation.

## Features
 - Automated Installation: One-script setup for essential tools.
 - Shell Setup: Pre-configured Zsh with Oh My Zsh.
 - Drivers: Automated setup for Hybrid AMD/Nvidia graphics.
 - Optimised GNOME: Custom extensions (Dash-to-Dock, Tiling Assistant) and dark mode by default.
 - Productivity: Integrated tools like Syncthing, Signal and Cloudflare WARP.

## Quick Start
**Warning**: This script is designed for my personal use. Review the contents of `setup_workstation.sh` before running it on your own hardware.
 1. Clone the repository:
```bash
git clone https://github.com/robinlennox/workstation.git
cd workstation
```
 2. Make the script executable:
```bash
chmod +x setup_workstation.sh
```
 3. Run the setup:
```bash
./setup_workstation.sh
```

## Included Tools
 - Terminal: Terminator (set as default)
 - Editor: Visual Studio Code & Vim
 - Networking: Cloudflare WARP, OpenVPN, sshuttle
 - Utilities: htop, ncdu, rsync, and p7zip

## Author
Robin Lennox – [GitHub Profile](https://github.com/robinlennox)
