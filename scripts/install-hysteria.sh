#!/bin/bash

#
# Hysteria2 Installation Script
#
# Tested on Ubuntu 22.04 / 24.04
#
# This script:
# - Installs Hysteria2
# - Creates configuration directory
# - Creates systemd service
#


set -e


echo "================================="
echo "Installing Hysteria2"
echo "================================="


# Update packages

echo "[1/5] Updating system packages..."

apt update
apt upgrade -y



# Install required packages

echo "[2/5] Installing dependencies..."

apt install -y curl wget certbot



# Install Hysteria2

echo "[3/5] Installing Hysteria2..."

bash <(curl -fsSL https://get.hy2.sh/)



# Create configuration directory

echo "[4/5] Creating directories..."

mkdir -p /etc/hysteria



# Create systemd service

echo "[5/5] Creating systemd service..."


cat > /etc/systemd/system/hysteria-server.service <<EOF

[Unit]
Description=Hysteria2 Server Service
After=network.target


[Service]
Type=simple

User=root

ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml

Restart=always
RestartSec=3


[Install]
WantedBy=multi-user.target

EOF



systemctl daemon-reload

systemctl enable hysteria-server



echo "================================="
echo "Installation completed"
echo "================================="


echo ""
echo "Next steps:"
echo "1. Upload config.yaml to /etc/hysteria/"
echo "2. Configure TLS certificate"
echo "3. Start service:"
echo ""
echo "sudo systemctl start hysteria-server"
echo ""