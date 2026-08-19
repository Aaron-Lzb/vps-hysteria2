# System Architecture

## Overview

This project builds a personal VPN infrastructure based on AWS EC2, Hysteria2, TLS encryption, and Shadowrocket intelligent routing.

The system consists of:

- Client device
- Shadowrocket application
- Hysteria2 encrypted tunnel
- Custom domain
- AWS EC2 VPS
- Let's Encrypt TLS certificate


## High-Level Architecture


```text
+----------------------+
| iPhone / iPad / Mac  |
+----------------------+
            |
            |
            v
+----------------------+
|    Shadowrocket      |
|                      |
| - VPN client         |
| - Traffic routing    |
| - DNS control        |
+----------------------+
            |
            |
            v
+----------------------+
|    Hysteria2         |
|                      |
| QUIC + UDP 443       |
| TLS encrypted tunnel |
+----------------------+
            |
            |
            v
+----------------------+
| Custom Domain        |
|                      |
| DNS -> Elastic IP    |
+----------------------+
            |
            |
            v
+----------------------+
| AWS EC2 VPS          |
|                      |
| Ubuntu               |
| Hysteria2 Server     |
+----------------------+
            |
            |
            v
+----------------------+
| Internet             |
+----------------------+
```


## Component Description


## AWS EC2 VPS

AWS EC2 provides the overseas server environment.

Responsibilities:

- Running Hysteria2 server
- Providing public network access
- Forwarding encrypted traffic
- Acting as the Internet exit point


## Elastic IP

Elastic IP provides a static public IP address.

Benefits:

- Stable endpoint
- IP does not change after reboot
- Allows domain mapping


## Custom Domain

The domain provides a stable and readable endpoint.

Example:

```
vpn.example.com
        |
        v
Elastic IP
        |
        v
AWS EC2
```


Advantages:

- Easier client configuration
- Supports TLS certificates
- Allows future server migration


## Let's Encrypt TLS

TLS provides:

- Server authentication
- Encrypted communication
- Protection against man-in-the-middle attacks


Certificate management:

```
Certbot
    |
    v
Let's Encrypt
    |
    v
TLS Certificate
```


Certificates are automatically renewed.


## Hysteria2

Hysteria2 provides the encrypted communication tunnel.

Main technologies:

- QUIC protocol
- UDP transport
- TLS encryption


Responsibilities:

- Encrypt client traffic
- Transport data between client and server
- Provide high-performance proxy connection


## Shadowrocket

Shadowrocket runs on client devices.

Responsibilities:

- Establish Hysteria2 connection
- Apply routing rules
- Control DNS behavior


Traffic decision example:

```
Mainland China websites

        |
        v

DIRECT


Overseas websites

        |
        v

Hysteria2 Proxy

        |
        v

AWS EC2
```


## Traffic Flow


### Mainland China Traffic

Example:

```
User
 |
 v
Shadowrocket
 |
 v
Routing Rule
 |
 v
DIRECT
 |
 v
China Internet
```


Benefits:

- Lower latency
- No AWS traffic consumption
- Better experience for local services


### Overseas Traffic

Example:

```
User
 |
 v
Shadowrocket
 |
 v
Hysteria2 Tunnel
 |
 v
AWS EC2
 |
 v
Internet
```


Benefits:

- Private overseas exit
- Encrypted communication
- Self-managed infrastructure


## Design Principles

This project follows several principles:

### 1. Simplicity

Avoid unnecessary components.

Only use:

- AWS
- Hysteria2
- TLS
- Shadowrocket


### 2. Reliability

Use:

- systemd service management
- Automatic restart
- Automatic certificate renewal


### 3. Maintainability

Keep:

- Configuration templates
- Deployment scripts
- Troubleshooting documents

separated and easy to update.