#!/bin/bash

#
# Restart Hysteria2 after Let's Encrypt certificate renewal
#
# This script is executed by Certbot renewal hooks.
# It reloads the new TLS certificate after renewal.
#

systemctl restart hysteria-server