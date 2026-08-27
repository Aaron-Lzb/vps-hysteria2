# VPS Hysteria2

English | [简体中文](README_CN.md)

[![Release](https://img.shields.io/github/v/release/Aaron-Lzb/vps-hysteria2)](https://github.com/Aaron-Lzb/vps-hysteria2/releases)
[![License](https://img.shields.io/github/license/Aaron-Lzb/vps-hysteria2)](LICENSE)
[![Validation](https://github.com/Aaron-Lzb/vps-hysteria2/actions/workflows/validate.yml/badge.svg)](https://github.com/Aaron-Lzb/vps-hysteria2/actions/workflows/validate.yml)

A simple and practical Hysteria2 deployment solution for VPS servers, with TLS, systemd, automatic certificate renewal, status checking, and support for multiple Hysteria2 clients.

Deploy Hysteria2 on a VPS and connect using any compatible Hysteria2 client. Shadowrocket remains a documented client example, but the server deployment is not tied to one client application.

AWS EC2 is the original tested VPS reference. It is not required infrastructure; the same server architecture can be used with other Ubuntu VPS providers that allow inbound UDP traffic.

## Contents

- [Status](#status)
- [Features](#features)
- [Architecture](#architecture)
- [Supported VPS providers](#supported-vps-providers)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Client configuration](#client-configuration)
- [Server configuration](#server-configuration)
- [Certificate renewal](#certificate-renewal)
- [Health checks](#health-checks)
- [Maintenance tool updates](#maintenance-tool-updates)
- [Documentation](#documentation)
- [Security](#security)

## Status

Current version: **v1.4.0**

**v1.4.0 - Global Maintenance Command** installs the read-only status helper as `hysteria-check`, so routine checks work from any directory. The command normally detects the VPS public IPv4 automatically and retains an optional manual form.

The `main` branch also contains unreleased maintenance UX work, including color-coded status output and `hysteria-update`. `VERSION` remains `1.4.0` until that work completes release acceptance.

The v1.3.0 client-neutral positioning and all earlier release history remain unchanged.

## Features

- Self-hosted Hysteria2 proxy server on an Ubuntu VPS
- QUIC transport over UDP 443 with TLS
- systemd startup and failure recovery
- Certbot certificate renewal with a deploy hook
- Global `hysteria-check` command for read-only maintenance diagnostics
- Global `hysteria-update` command for safely updating project maintenance tools
- Provider-neutral server configuration
- Client-neutral connection model
- Maintained Shadowrocket split-routing example
- English and Simplified Chinese documentation
- Public examples that use placeholders instead of secrets

## Architecture

```text
Compatible Hysteria2 client
          |
          v
 Hysteria2 encrypted proxy
    QUIC + UDP 443
          |
          v
      YOUR_DOMAIN
          |
          v
     Ubuntu VPS
          |
          v
       Internet
```

The VPS supplies Ubuntu, a public IP address, firewall controls, and UDP 443 connectivity. Hysteria2 provides authentication and encrypted proxy transport. The client supplies connection details and, where supported, routing and DNS policy.

See the [architecture guide](docs/architecture.md) for component boundaries and traffic flow.

## Supported VPS providers

The server framework may be deployed on:

- AWS EC2
- Oracle Cloud
- Google Cloud
- Azure
- DigitalOcean
- Vultr
- Other Linux VPS providers

Provider product names, firewall interfaces, and static-IP features differ. The [AWS deployment guide](docs/aws-deployment.md) remains the original tested reference; translate its network requirements to the selected provider.

## Requirements

Before deployment, prepare:

- An Ubuntu 22.04 or 24.04 VPS with a public IP address
- Permission to allow inbound UDP 443 in the provider firewall
- A registered domain with an A or AAAA record pointing to the VPS
- A TLS certificate issued through Certbot
- A client version that explicitly supports Hysteria2
- Basic Linux command-line knowledge

TCP 80 may be needed temporarily for the HTTP-01 certificate challenge. Restrict SSH access to trusted source addresses whenever possible.

## Quick start

### 1. Prepare the VPS

Create an Ubuntu VPS, assign a stable public IP when available, allow inbound UDP 443, and point `YOUR_DOMAIN` to the server. AWS users can follow the [reference AWS deployment guide](docs/aws-deployment.md).

### 2. Install Hysteria2

Run the installer as root from a trusted checkout:

```bash
sudo bash scripts/install-hysteria.sh
```

The installer preserves existing Hysteria2 configuration and systemd unit files. It also installs standalone `/usr/local/bin/hysteria-check` and `/usr/local/bin/hysteria-update` commands that do not depend on keeping the repository checkout. Review the printed next steps before starting the service.

### 3. Configure the server

Copy and edit the server example:

```text
configs/hysteria/config.example.yaml
```

Replace the applicable placeholders only in the private deployment copy:

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

### 5. Configure a client

In a compatible Hysteria2 client, configure the server domain, UDP port `443`, password, and TLS/SNI name. The password and domain must match the server.

Client interfaces and configuration syntax vary. Follow the documentation for the installed client version. This repository currently includes a detailed [Shadowrocket guide](docs/clients/shadowrocket.md) and split-routing example.

## Client configuration

The Hysteria2 server is client-neutral. A client is suitable when its current version implements Hysteria2 and supports the connection fields used by this deployment: server domain, UDP port, password authentication, and TLS/SNI verification.

| Client or client family | Project guidance |
| --- | --- |
| Shadowrocket | Documented client example with an included split-routing configuration |
| Mihomo / Clash.Meta-compatible clients | Mihomo provides a Hysteria2 proxy type; use the documentation for the client and bundled core version |
| FlClash | ClashMeta-based client; verify the bundled core/version and use compatible Mihomo configuration guidance |
| Surge | No configuration is supplied here; verify Hysteria2 support in the installed version before use |
| Other Hysteria2 clients | Use the client vendor's current documentation and match the server connection fields |

The repository does not claim that every version of every named client supports Hysteria2. Detailed guides for clients other than Shadowrocket may be added after their configuration is verified.

### Shadowrocket

The existing Shadowrocket example remains supported and intentionally client-specific:

```text
configs/shadowrocket/Hysteria2-Split-Routing.conf
```

It sends LAN and mainland China traffic directly and sends remaining traffic through the selected Hysteria2 proxy. See [Shadowrocket client configuration](docs/clients/shadowrocket.md) for node fields, routing flow, DNS design, and troubleshooting.

### Mihomo / Clash.Meta-compatible clients

Mihomo documents a native `hysteria2` proxy type. Configuration details can change with the core and client version, so this project links to the [official Mihomo Hysteria2 reference](https://wiki.metacubex.one/en/config/proxies/hysteria2/) instead of maintaining an unverified copy.

## Server configuration

The server example listens on UDP 443, reads Let's Encrypt certificates from `/etc/letsencrypt/live/YOUR_DOMAIN/`, and authenticates with `YOUR_PASSWORD`.

The default deployment uses Hysteria2 over standard QUIC/TLS on UDP 443 and configures HTTP masquerading to provide a normal web response for non-Hysteria2 HTTP requests. Additional protocol obfuscation such as Salamander is not enabled by default and should be considered only when required by the network environment.

The established server paths remain unchanged:

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

Changing client software does not require changing these server paths.

## Certificate renewal

Install the renewal hook so Hysteria2 loads a newly renewed certificate:

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
sudo certbot renew --dry-run
```

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

Run the status helper on the server:

```bash
hysteria-check
```

The public IPv4 is normally detected automatically through short, read-only HTTPS requests. If detection is unavailable, provide the address explicitly:

```bash
hysteria-check <PUBLIC_IP>
```

The helper rejects private and special-use IPv4 ranges. It reports service and local UDP 443 state, TLS certificate lifetime, Certbot renewal timer state, pending Ubuntu security updates, reboot status, root filesystem use, OS and installed Hysteria2 versions, and public-IP or optional DNS information. It does not require root privileges and remains read-only: it never renews certificates, installs updates, restarts services, or changes configuration. For the most complete server-side diagnostics, `sudo hysteria-check` is recommended because elevated read access may reveal certificate or service details unavailable to an unprivileged user.

For repository development or an existing deployment that has not rerun the installer, the original entry point remains supported:

```bash
bash scripts/check-status.sh <PUBLIC_IP>
```

An existing checkout can install or refresh only the global command without rerunning the full Hysteria2 installer:

```bash
sudo install -m 0755 scripts/check-status.sh /usr/local/bin/hysteria-check
```

When run in an interactive terminal, status labels are color-coded for quicker scanning: `PASS` is green, `INFO` is cyan, `WARN` is yellow, and `CRITICAL` is red. Colors are automatically disabled for non-TTY output, `TERM=dumb`, or when `NO_COLOR` is set, so pipes, redirects, CI logs, and automation continue to receive plain text.

`HEALTHY` exits with status 0; `ATTENTION REQUIRED` and `CRITICAL` exit with status 1. UDP 443 listening confirms only that the server appears to be listening locally. It does not prove full client-to-server connectivity or validate cloud-firewall rules.

## Maintenance tool updates

Update the project-provided maintenance tools from any directory:

```bash
sudo hysteria-update
```

The updater currently manages only `/usr/local/bin/hysteria-check`. It downloads `scripts/check-status.sh` from the official `Aaron-Lzb/vps-hysteria2` repository into a temporary file, validates the Bash shebang and syntax, and replaces the installed command only after validation succeeds. The repository checkout does not need to remain on the VPS.

The updater follows the repository `main` branch rather than the latest tagged Release, so it may install validated maintenance-tool changes newer than the current stable release. This does not update the installed Hysteria2 server binary or change the project `VERSION`.

`hysteria-update` is **not a Hysteria2 server updater**. It does not update the Hysteria2 binary, modify `/etc/hysteria/config.yaml`, restart services, change firewall rules or certificates, renew certificates, or run `apt update` or `apt upgrade`. If download or validation fails, the existing `hysteria-check` installation remains unchanged.

## Documentation

English documentation:

- [System architecture](docs/architecture.md)
- [AWS reference VPS deployment](docs/aws-deployment.md)
- [Troubleshooting, deployment, and security checklists](docs/troubleshooting.md)
- [Shadowrocket client configuration](docs/clients/shadowrocket.md)

Simplified Chinese documentation:

- [中文项目主页](README_CN.md)
- [系统架构](docs/zh-CN/architecture.md)
- [VPS 部署指南](docs/zh-CN/vps-deployment.md)
- [故障排查指南](docs/zh-CN/troubleshooting.md)
- [Shadowrocket 客户端配置](docs/zh-CN/clients/shadowrocket.md)

Configuration references:

- [Hysteria2 server example](configs/hysteria/config.example.yaml)
- [systemd service example](configs/systemd/hysteria-server.service)
- [Shadowrocket split-routing example](configs/shadowrocket/Hysteria2-Split-Routing.conf)

## Security

- Never upload private keys, certificates, real passwords, provider credentials, personal domains, or server IP addresses.
- Keep `YOUR_DOMAIN`, `YOUR_PASSWORD`, `YOUR_EMAIL`, and `YOUR_SERVER_IP` in public examples.
- Restrict SSH access and enable MFA on the VPS-provider account.
- Review provider firewall rules and installed scripts before use.
- Keep Ubuntu, Hysteria2, Certbot, and the selected client updated.

For diagnosis, use the [troubleshooting guide](docs/troubleshooting.md) and check DNS, network firewalls, UDP 443, the service, TLS, authentication, and client configuration in order.

## License

See [LICENSE](LICENSE).
