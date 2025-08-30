#!/usr/bin/env bash
# File: /Users/office-ls/Documents/dev/geisterbio/ubuntu-CAD-server-setup/scripts/ubuntu24lts/setup.sh
# Purpose: Install a lightweight desktop, enable remote desktop (xrdp) and install Blender on Ubuntu 24.04 LTS.
# Usage: sudo ./setup.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo $0" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
apt update -y

echo "Upgrading packages (non-interactive)..."
apt upgrade -y

echo "Installing desktop environment (Xfce), XRDP and supporting packages..."
apt install -y --no-install-recommends \
    xfce4 xfce4-goodies xorg dbus-x11 dbus-user-session \
    xrdp policykit-1 pulseaudio alsa-utils

echo "Adding xrdp user to ssl-cert group (needed for certificate access)..."
if getent group ssl-cert >/dev/null; then
    adduser xrdp ssl-cert >/dev/null || true
fi

XRDP_STARTWM="/etc/xrdp/startwm.sh"
if [ -f "$XRDP_STARTWM" ]; then
    echo "Backing up existing $XRDP_STARTWM to ${XRDP_STARTWM}.bak"
    cp -a "$XRDP_STARTWM" "${XRDP_STARTWM}.bak"
fi

echo "Writing Xfce startup wrapper to $XRDP_STARTWM"
cat > "$XRDP_STARTWM" <<'EOF'
#!/bin/sh
# startwm.sh for xrdp - start Xfce session
if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG
fi
# ensure dbus session available
if command -v dbus-launch >/dev/null 2>&1; then
    exec dbus-launch --exit-with-session startxfce4
else
    exec startxfce4
fi
EOF
chmod 755 "$XRDP_STARTWM"

echo "Enabling and starting xrdp service..."
systemctl enable --now xrdp

# If system uses firewalld or ufw, try to open RDP port 3389
if command -v ufw >/dev/null 2>&1; then
    echo "Configuring UFW to allow RDP (3389/tcp)..."
    ufw allow 3389/tcp || true
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo "Configuring firewalld to allow RDP (3389/tcp)..."
    firewall-cmd --permanent --add-port=3389/tcp || true
    firewall-cmd --reload || true
fi

echo "Installing Blender..."
# Use apt-provided Blender (fast, offline-friendly). If you prefer snap replace with: snap install blender --classic
apt install -y blender

echo ""
echo "Setup complete."
echo " - XRDP is running and should present an Xfce session on connection (port 3389)."
echo " - Connect with an RDP client (Windows Remote Desktop, Remmina, etc.) to: <server-ip>:3389"
echo " - Use your regular username/password to log in. If you have multiple sessions, choose Xorg/Xvnc as needed."
echo ""
echo "Notes:"
echo " - If you prefer GNOME or the full Ubuntu desktop experience, install 'ubuntu-desktop' instead of xfce packages."
echo " - To install Blender via snap for newer versions: snap install blender --classic"