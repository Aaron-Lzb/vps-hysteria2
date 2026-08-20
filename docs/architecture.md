# System Architecture

English | [简体中文](zh-CN/architecture.md)

## Overview

This project deploys a Hysteria2 proxy server on a Linux VPS with TLS, Certbot, and systemd. Client software is a separate layer: any current client that implements the required Hysteria2 connection fields can use the server.

AWS EC2 is the original tested VPS reference, not required infrastructure. Shadowrocket is the maintained client example, not a server dependency.

The system consists of:

- A compatible Hysteria2 client
- A Hysteria2 encrypted proxy connection over QUIC and UDP 443
- A custom domain that resolves to the server
- An Ubuntu VPS with a public IP address
- A Let's Encrypt TLS certificate managed by Certbot
- A systemd service that runs Hysteria2

## High-level architecture

```text
+--------------------------+
| Compatible client        |
| - Hysteria2 connection   |
| - Optional routing/DNS   |
+--------------------------+
             |
             v
+--------------------------+
| Hysteria2                |
| QUIC + UDP 443           |
| TLS + password auth      |
+--------------------------+
             |
             v
+--------------------------+
| YOUR_DOMAIN              |
| DNS -> public IP         |
+--------------------------+
             |
             v
+--------------------------+
| Ubuntu Linux VPS         |
| Hysteria2 + systemd      |
+--------------------------+
             |
             v
+--------------------------+
| Internet                 |
+--------------------------+
```

The domain resolves a stable server name to its public address. It does not proxy traffic by itself. The Hysteria2 client and server establish the actual encrypted connection.

## Deployment layers

| Layer | Responsibility | Examples |
| --- | --- | --- |
| VPS provider | Compute, public IP, provider firewall | AWS EC2 reference deployment or another Linux VPS |
| Server application | Authentication, encrypted proxy transport, TLS, service lifecycle | Hysteria2, Certbot, systemd |
| Client | Connection fields and optional routing/DNS policy | Shadowrocket or another compatible Hysteria2 client |

This separation keeps server deployment independent from a particular client interface or configuration format.

## VPS provider layer

A suitable provider must allow:

- Ubuntu 22.04 or 24.04
- A public IPv4 or IPv6 address supported by the chosen DNS record
- Inbound UDP 443
- SSH administration
- TCP 80 when the selected Certbot validation method requires it

Possible providers include AWS EC2, Oracle Cloud, Google Cloud, Azure, DigitalOcean, Vultr, and other Linux VPS providers.

Provider-specific terms differ. AWS uses Security Groups and Elastic IPs, while another provider may use cloud firewalls and reserved IPs. These products serve the same architectural roles.

See the [AWS deployment guide](aws-deployment.md) for the original tested reference.

## Server component responsibilities

### Linux VPS

The VPS is responsible for:

- Running the Hysteria2 server
- Accepting Hysteria2 traffic on UDP 443
- Reading TLS certificate files
- Forwarding authenticated proxy traffic
- Acting as the selected Internet exit point

### Stable public IP and domain

A stable public IP prevents routine server lifecycle events from unexpectedly changing DNS mapping. It may be called an Elastic IP, reserved IP, or static IP.

```text
YOUR_DOMAIN
     |
     v
Stable public IP
     |
     v
Linux VPS
```

The domain is used in the client connection and TLS certificate. A future server migration can normally be handled by updating DNS rather than changing the public templates.

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

The deploy hook belongs under `/etc/letsencrypt/renewal-hooks/deploy/`.

### Hysteria2

Hysteria2 is responsible for:

- Authenticating the client password
- Encrypting the connection with TLS
- Transporting proxy traffic with QUIC over UDP
- Listening on the configured server port

The server paths remain:

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

### systemd

systemd starts Hysteria2 after boot and restarts it after a process failure:

```bash
sudo systemctl status hysteria-server
```

It manages the process but cannot correct invalid YAML, certificate paths, or authentication values.

## Client layer

A compatible client must support Hysteria2 and the connection fields used by this deployment:

- Server: `YOUR_DOMAIN`
- UDP port: `443`
- Password authentication
- TLS/SNI name: `YOUR_DOMAIN`

Routing, DNS, subscription formats, and import syntax belong to the client layer and may differ substantially between products and versions.

### Maintained Shadowrocket example

Shadowrocket remains the project's documented client example. Its configuration supplies client-side DNS and this split-routing policy:

```text
LAN and mainland China traffic -> DIRECT
Remaining traffic              -> PROXY
```

These rules are not part of the Hysteria2 server and are not automatically portable to another client. See [Shadowrocket client configuration](clients/shadowrocket.md).

### Other clients

Mihomo provides a native Hysteria2 proxy type, and clients built around compatible Mihomo/Clash.Meta cores may be usable when their installed version exposes that support. Other products, including Surge, must be checked against their current official documentation before compatibility is assumed.

This project does not provide unverified client configuration syntax.

## Traffic flow

### Direct traffic, when the client supports routing rules

```text
Application
    |
    v
Client routing rule
    |
    v
DIRECT
    |
    v
Destination
```

Direct routing is a client decision and does not involve the VPS.

### Proxied traffic

```text
Application
    |
    v
Compatible Hysteria2 client
    |
    v
Hysteria2 encrypted connection
    |
    v
Linux VPS
    |
    v
Destination
```

Clients without routing rules can still use the server, but their traffic-selection behavior depends on that client.

## Design principles

### Simplicity

Use a small number of standard components and explicit configuration paths.

### Client neutrality

Keep the Hysteria2 server independent from client brands. Store client-specific examples under clearly named paths.

### Reproducibility

Keep public examples free of personal domains, server addresses, passwords, certificates, and provider credentials.

### Security

Use TLS, restrict provider firewall and SSH rules, protect provider accounts with MFA, and keep private material outside the repository.

### Reliability

Use systemd for startup and recovery and a Certbot deploy hook for certificate reloads.

### Maintainability

Keep infrastructure guidance, server configuration, client examples, scripts, and troubleshooting documentation separated.

## Related documentation

- [Project README](../README.md)
- [AWS reference deployment](aws-deployment.md)
- [Troubleshooting guide](troubleshooting.md)
- [Shadowrocket client configuration](clients/shadowrocket.md)
