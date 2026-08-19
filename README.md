# VPS Hysteria2 Shadowrocket

[![Release](https://img.shields.io/github/v/release/Aaron-Lzb/vps-hysteria2-shadowrocket)](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/releases)
A private and self-managed VPN deployment solution based on AWS EC2, Hysteria2, TLS encryption, and Shadowrocket intelligent routing.

This project provides a simple, reproducible approach to build a personal VPN infrastructure with:

- AWS EC2 VPS
- Elastic IP
- Custom domain
- Let's Encrypt TLS certificate
- Hysteria2 protocol
- systemd service management
- Automatic certificate renewal
- Shadowrocket split routing


## Architecture

```text
Phone / iPad / Mac
        |
        |
   Shadowrocket
        |
        |
 Hysteria2 Protocol
   (QUIC + UDP 443)
        |
        |
  Custom Domain
        |
        |
    AWS EC2 VPS
        |
        |
     Internet
```


## Features

- Self-managed private VPN server
- High-performance Hysteria2 transport
- TLS encrypted communication
- Automatic TLS certificate renewal
- Automatic service recovery after reboot
- Mainland China traffic direct routing
- Overseas traffic through proxy
- No dependency on third-party VPN providers
- Full control of server, traffic, and routing rules


## Components

| Component          | Purpose                    |
| ------------------ | -------------------------- |
| AWS EC2            | Overseas VPS server        |
| Elastic IP         | Static public IP address   |
| Custom Domain      | Stable server endpoint     |
| AWS Security Group | Network access control     |
| Let's Encrypt      | TLS certificate provider   |
| Certbot            | Certificate automation     |
| Hysteria2          | Encrypted proxy protocol   |
| Shadowrocket       | Client and traffic routing |


## Requirements

Before deployment, prepare:

- AWS account
- Ubuntu 22.04/24.04 VPS
- Registered domain name
- Shadowrocket client
- Basic Linux command line knowledge


## Quick Start

### Server Side

1. Create an AWS EC2 instance
2. Allocate and attach Elastic IP
3. Configure domain DNS record
4. Install Hysteria2 server
5. Configure TLS certificate
6. Enable systemd service
7. Configure automatic certificate renewal


### Client Side

1. Import Shadowrocket configuration
2. Add Hysteria2 node
3. Enable configuration mode
4. Use split routing:

```
Mainland China traffic  → DIRECT

Other traffic           → PROXY
```


## Deployment Overview

The deployment process contains the following steps:

### 1. AWS EC2

Create an Ubuntu VPS instance and configure:

- Security Group
- UDP 443 access
- SSH access


### 2. Domain Configuration

Configure DNS:

```
your-domain.com
        |
        ↓
Elastic IP address
```

The domain provides a stable endpoint for the VPN service.


### 3. Hysteria2 Installation

Install and configure Hysteria2 server:

```
Hysteria2
      |
      |
QUIC + UDP 443
      |
      |
Encrypted tunnel
```


### 4. TLS Certificate

Use Let's Encrypt:

```
Certbot
    |
    ↓
Let's Encrypt
    |
    ↓
TLS Certificate
```

Certificates are automatically renewed.


### 5. Service Management

Use systemd to keep Hysteria2 running:

- Start automatically after reboot
- Restart automatically after failure
- Manage service status easily


## Configuration

Example configuration files are provided:

```
configs/

├── hysteria/
│   └── config.example.yaml

├── systemd/
│   └── hysteria-server.service

└── shadowrocket/
    └── Hysteria2-Split-Routing.conf
```


Before deployment:

Replace all placeholders:

```
YOUR_DOMAIN
YOUR_PASSWORD
YOUR_SERVER_IP
```

with your own information.


## Shadowrocket Routing Logic

The recommended routing strategy:

```
LAN traffic
      |
      ↓
   DIRECT


Mainland China domains/IP
      |
      ↓
   DIRECT


Other traffic
      |
      ↓
   Hysteria2 Proxy
      |
      ↓
 AWS VPS
```


This design helps:

- Reduce unnecessary VPS traffic usage
- Improve domestic website performance
- Keep overseas access stable


## Troubleshooting


### Hysteria2 service failed to start

Check service status:

```bash
sudo systemctl status hysteria-server
```

Check logs:

```bash
sudo journalctl -u hysteria-server -f
```


Common causes:

- Incorrect configuration format
- TLS certificate permission issue
- Wrong certificate path


### TLS certificate permission denied

Verify:

- Certificate path
- File permission
- systemd service user


Example:

```
/etc/letsencrypt/live/YOUR_DOMAIN/
```


### Shadowrocket connection timeout

Check network traffic:

```bash
sudo tcpdump -i any -n udp port 443
```

Verify:

- AWS Security Group allows UDP 443
- Domain points to correct IP
- Hysteria2 service is running
- Password matches server configuration


## Security Notice

Never upload sensitive information:

- AWS SSH private keys
- TLS private keys
- Real passwords
- Personal server IP addresses
- Personal domain information


Use the example configuration files provided in this repository.

For public repositories, always replace real credentials with placeholders.


## Maintenance

Recommended maintenance:

Monthly:

```bash
systemctl status hysteria-server
```

Check:

- Service status
- Server availability
- AWS billing


Every few months:

Verify:

- Domain expiration
- Certificate renewal status


## License

MIT License