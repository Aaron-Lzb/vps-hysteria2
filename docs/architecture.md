# System Architecture

English | [简体中文](zh-CN/architecture.md)

## Overview

This project builds self-hosted encrypted networking infrastructure from a Linux VPS, Hysteria2, TLS, and Shadowrocket split routing.

The application architecture is provider-neutral. AWS EC2 is the original tested environment and serves as a reference VPS deployment example, not required infrastructure.

The system consists of:

- A client device running Shadowrocket
- A Hysteria2 encrypted tunnel over QUIC and UDP 443
- A custom domain that resolves to the server
- An Ubuntu VPS with a public IP address
- A Let's Encrypt TLS certificate managed by Certbot
- A systemd service that runs Hysteria2

## High-level architecture

```text
+----------------------+
| iPhone / iPad / Mac  |
+----------------------+
            |
            v
+----------------------+
| Shadowrocket         |
| - Client connection  |
| - Traffic routing    |
| - DNS control        |
+----------------------+
            |
            v
+----------------------+
| Hysteria2            |
| QUIC + UDP 443       |
| TLS encryption       |
+----------------------+
            |
            v
+----------------------+
| YOUR_DOMAIN          |
| DNS -> public IP     |
+----------------------+
            |
            v
+----------------------+
| Ubuntu Linux VPS     |
| Hysteria2 + systemd  |
+----------------------+
            |
            v
+----------------------+
| Internet             |
+----------------------+
```

## VPS provider layer

The VPS provider supplies compute, a public network interface, and network firewall controls. A suitable provider must allow:

- Ubuntu 22.04 or 24.04
- A public IPv4 or IPv6 address supported by the chosen DNS record
- Inbound UDP 443
- SSH administration
- TCP 80 when the selected Certbot validation method requires it

Supported VPS providers may include:

- AWS EC2
- Oracle Cloud
- Google Cloud
- Azure
- DigitalOcean
- Vultr
- Other Linux VPS providers

Provider-specific terms differ. For example, AWS uses Security Groups and Elastic IPs, while another provider may call them cloud firewalls and reserved IPs. These products serve the same architectural roles.

The [AWS deployment guide](aws-deployment.md) documents the original tested environment as a reference example.

## Component responsibilities

### Linux VPS

The VPS is responsible for:

- Running the Hysteria2 server
- Accepting Hysteria2 traffic on UDP 443
- Reading TLS certificate files
- Forwarding authenticated client traffic
- Acting as the selected Internet exit point

The project keeps provider infrastructure separate from Hysteria2 configuration so users can migrate providers without redesigning the application layer.

### Stable public IP and domain

A stable public IP is recommended because it prevents DNS mapping from changing after server lifecycle events. It may be called an Elastic IP, reserved IP, static IP, or another provider-specific name.

```text
YOUR_DOMAIN
     |
     v
Stable public IP
     |
     v
Linux VPS
```

The domain supplies a stable server name for client configuration and TLS issuance. It also makes a future server migration easier because the DNS record can be changed without editing the public examples in this repository.

### Let's Encrypt and Certbot

TLS provides server authentication and encrypted communication. Certbot obtains and renews the certificate used by Hysteria2.

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

The deploy hook belongs under `/etc/letsencrypt/renewal-hooks/deploy/`. It runs after a successful renewal so the service begins using the new certificate.

### Hysteria2

Hysteria2 is responsible for:

- Authenticating the configured client password
- Encrypting traffic with TLS
- Transporting traffic with QUIC over UDP
- Listening on the configured server port

The v1.0.0-compatible server paths remain:

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

### systemd

systemd starts Hysteria2 after boot and restarts it after a failure. Administrators use the same service name for every supported VPS provider:

```bash
sudo systemctl status hysteria-server
```

### Shadowrocket

Shadowrocket is responsible for:

- Establishing the Hysteria2 client connection
- Applying direct and proxy routing rules
- Controlling client DNS behavior

The example routing policy sends LAN and mainland China traffic directly and sends remaining traffic through the selected Hysteria2 node.

## Traffic flow

### Direct traffic

```text
Client
  |
  v
Shadowrocket routing rule
  |
  v
DIRECT
  |
  v
Destination
```

Direct routing avoids unnecessary VPS traffic and can reduce latency for local services.

### Proxied traffic

```text
Client
  |
  v
Shadowrocket
  |
  v
Hysteria2 encrypted tunnel
  |
  v
Linux VPS
  |
  v
Destination
```

Only traffic selected by the client rules passes through the VPS.

## Deployment boundaries

The project separates three layers:

| Layer | Responsibility | Example |
| --- | --- | --- |
| VPS provider | Compute, public IP, and firewall | AWS EC2 reference deployment |
| Server application | Encrypted transport, TLS, and service lifecycle | Hysteria2, Certbot, systemd |
| Client | Connection details, DNS, and routing policy | Shadowrocket |

This separation is the basis for provider portability and keeps the existing deployment model simple.

## Design principles

### Simplicity

Use a small number of standard components and explicit configuration files.

### Reproducibility

Keep public examples free of personal domains, server addresses, passwords, certificates, and provider credentials. Replace placeholders only in private deployment copies.

### Security

Use TLS, restrict provider firewall and SSH rules, protect provider accounts with MFA, and keep private material outside the repository.

### Reliability

Use systemd for startup and recovery and a Certbot deploy hook for certificate reloads.

### Maintainability

Keep infrastructure guidance, application configuration, client routing, scripts, and troubleshooting documentation separated so each can evolve without unnecessary redesign.
