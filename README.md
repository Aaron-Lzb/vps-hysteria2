# VPS Hysteria2 Shadowrocket

English | [简体中文](README_CN.md)

[![Release](https://img.shields.io/github/v/release/Aaron-Lzb/vps-hysteria2-shadowrocket)](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/releases)
[![License](https://img.shields.io/github/license/Aaron-Lzb/vps-hysteria2-shadowrocket)](LICENSE)
[![Validation](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/actions/workflows/validate.yml/badge.svg)](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/actions/workflows/validate.yml)

A simple, reproducible framework for self-hosted encrypted networking infrastructure using Hysteria2, TLS, systemd, and Shadowrocket split routing.

AWS EC2 is the original tested environment and is retained as a reference VPS deployment example. It is not required infrastructure; the same architecture can be used with other Linux VPS providers that support Ubuntu and inbound UDP traffic.

## Contents

- [Status](#status)
- [Features](#features)
- [Architecture](#architecture)
- [Supported VPS providers](#supported-vps-providers)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Certificate renewal](#certificate-renewal)
- [Health checks](#health-checks)
- [Documentation](#documentation)
- [Security](#security)

## Status

Current version: **v1.2.0**

**v1.2.0 - Bilingual Documentation Release** adds a complete Simplified Chinese README, architecture guide, VPS deployment guide, troubleshooting guide, and bilingual navigation. This release does not change networking, installation, service, routing, workflow, or configuration behavior.

## Features

- Self-hosted Hysteria2 server on an Ubuntu VPS
- QUIC transport over UDP 443 with TLS encryption
- systemd startup and failure recovery
- Certbot certificate renewal with a deploy hook
- Shadowrocket split routing for direct and proxied traffic
- Provider-neutral application configuration
- Example files that use placeholders instead of secrets

## Architecture

```text
Phone / iPad / Mac
        |
   Shadowrocket
        |
 Hysteria2 (QUIC + UDP 443)
        |
   Custom domain
        |
    Linux VPS
        |
     Internet
```

The VPS supplies Ubuntu, a public IP address, firewall controls, and UDP 443 connectivity. Hysteria2 supplies the encrypted transport, while Shadowrocket controls client routing. See the [architecture guide](docs/architecture.md) for details.

## Supported VPS providers

The framework may be deployed on:

- AWS EC2
- Oracle Cloud
- Google Cloud
- Azure
- DigitalOcean
- Vultr
- Other Linux VPS providers

Provider product names, firewall interfaces, and static-IP features differ. The [AWS deployment guide](docs/aws-deployment.md) remains the original tested reference example; translate its network requirements to your chosen provider.

## Requirements

Before deployment, prepare:

- An Ubuntu 22.04 or 24.04 VPS with a public IP address
- Permission to allow inbound UDP 443 in the provider firewall
- A registered domain with an A or AAAA record pointing to the VPS
- A TLS certificate issued through Certbot
- Shadowrocket on the client device
- Basic Linux command-line knowledge

TCP 80 may also be needed temporarily for the HTTP-01 certificate challenge. Restrict SSH access to trusted source addresses whenever possible.

## Quick start

### 1. Prepare the VPS

Create an Ubuntu VPS, assign a stable public IP if the provider offers one, allow inbound UDP 443, and point `YOUR_DOMAIN` to the server. AWS users can follow the [reference AWS deployment guide](docs/aws-deployment.md).

### 2. Install Hysteria2

Run the installer as root from a trusted checkout:

```bash
sudo bash scripts/install-hysteria.sh
```

The installer preserves existing Hysteria2 configuration and systemd unit files. Review its printed next steps before starting the service.

### 3. Configure the server

Copy and edit the examples:

```text
configs/
├── hysteria/config.example.yaml
├── shadowrocket/Hysteria2-Split-Routing.conf
└── systemd/hysteria-server.service
```

Replace every applicable placeholder:

```text
YOUR_DOMAIN
YOUR_PASSWORD
YOUR_EMAIL
YOUR_SERVER_IP
```

Never commit the completed configuration.

### 4. Enable the service

After installing the certificate and reviewing `/etc/hysteria/config.yaml`:

```bash
sudo systemctl enable --now hysteria-server
sudo systemctl status hysteria-server
```

### 5. Configure Shadowrocket

Add a Hysteria2 node whose domain, port, and password match the server. Import the example split-routing configuration so local and mainland China traffic is direct and remaining traffic uses the selected proxy.

## Configuration

The server example listens on UDP 443, reads Let's Encrypt certificates from `/etc/letsencrypt/live/YOUR_DOMAIN/`, and authenticates with `YOUR_PASSWORD`. The provided systemd unit continues to use the v1.0.0 paths:

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

Keeping these paths unchanged preserves compatibility with existing deployments.

## Certificate renewal

Install the renewal hook so Hysteria2 loads a newly renewed certificate:

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
sudo certbot renew --dry-run
```

The deploy hook runs only after a successful renewal:

```text
Certbot renewal
       |
       v
renewal deploy hook
       |
       v
restart Hysteria2
       |
       v
load new certificate
```

## Health checks

Run the status helper on the server after replacing or passing the domain placeholder:

```bash
sudo bash scripts/check-status.sh YOUR_DOMAIN
```

It reports PASS or FAIL for the systemd service, UDP 443 listener, Certbot certificate information, and DNS resolution. Missing diagnostic commands are reported clearly instead of causing an abrupt exit.

## Documentation

English documentation:

- [System architecture](docs/architecture.md)
- [AWS reference VPS deployment](docs/aws-deployment.md)
- [Troubleshooting, deployment, and security checklists](docs/troubleshooting.md)

Simplified Chinese documentation:

- [中文项目主页](README_CN.md)
- [系统架构](docs/zh-CN/architecture.md)
- [VPS 部署指南](docs/zh-CN/vps-deployment.md)
- [故障排查指南](docs/zh-CN/troubleshooting.md)

Configuration references:

- [Hysteria2 server example](configs/hysteria/config.example.yaml)
- [systemd service example](configs/systemd/hysteria-server.service)
- [Shadowrocket split-routing example](configs/shadowrocket/Hysteria2-Split-Routing.conf)

## Security

- Never upload private keys, certificates, real passwords, provider credentials, personal domains, or server IP addresses.
- Keep `YOUR_DOMAIN`, `YOUR_PASSWORD`, `YOUR_EMAIL`, and `YOUR_SERVER_IP` in public examples.
- Restrict SSH access and enable MFA on the VPS-provider account.
- Review provider firewall rules and installed scripts before use.
- Keep Ubuntu, Hysteria2, and Certbot updated through normal maintenance.

For diagnosis, use [the troubleshooting guide](docs/troubleshooting.md) and check the service, network, UDP firewall, TLS certificate, authentication, and routing layers in order.

## License

See [LICENSE](LICENSE).
