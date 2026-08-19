# AWS Deployment Guide

This document explains how to prepare the AWS infrastructure required for the Hysteria2 VPN server.

The goal is to create a stable overseas VPS environment with:

- Public IP address
- Stable domain endpoint
- UDP 443 access
- Ubuntu server


# 1. AWS Account

Create or use an existing AWS account.

Recommended:

- Enable MFA authentication
- Enable billing alerts
- Monitor monthly usage


# 2. Create EC2 Instance


## Recommended Configuration


Operating System:

```
Ubuntu 22.04 LTS / Ubuntu 24.04 LTS
```


Instance type:

```
t3.micro
```

(or other instance types according to requirements)


Storage:

```
Default EBS storage
```

The VPN service has low disk requirements.


# 3. Configure Security Group


The EC2 Security Group controls network access.


Required inbound rules:


| Protocol | Port | Purpose                   |
| -------- | ---- | ------------------------- |
| TCP      | 22   | SSH management            |
| UDP      | 443  | Hysteria2 traffic         |
| TCP      | 443  | TLS / HTTPS compatibility |
| TCP      | 80   | Certificate validation    |


Example:


```
Inbound Rules

SSH
TCP
22

Hysteria2
UDP
443

HTTPS
TCP
443

HTTP
TCP
80
```


Security recommendation:

For SSH:

```
Source:
Your IP address only
```

Avoid exposing SSH to the entire internet when possible.



# 4. Allocate Elastic IP


AWS EC2 default public IP may change after instance stop/start.


Elastic IP provides:

- Permanent public IP
- Stable DNS mapping
- Easier server management


Process:


```
AWS Console

EC2
 |
Elastic IPs
 |
Allocate Elastic IP
 |
Associate with Instance
```


After association:


```
Domain
   |
   v
Elastic IP
   |
   v
EC2 Instance
```



# 5. Configure Domain DNS


Create an A record at your domain provider.


Example:


```
Type:
A


Name:
vpn


Value:
YOUR_ELASTIC_IP
```


Result:


```
vpn.example.com

        |

        v

YOUR_ELASTIC_IP

        |

        v

AWS EC2
```



Verify:


```bash
ping vpn.example.com
```


Expected result:


```
PING vpn.example.com

YOUR_ELASTIC_IP
```



# 6. Connect to Ubuntu Server


SSH example:


```bash
ssh ubuntu@YOUR_SERVER_IP
```


Update system:


```bash
sudo apt update

sudo apt upgrade -y
```



# 7. Verify Network


Check IP:


```bash
curl ifconfig.me
```


Check listening ports:


```bash
sudo ss -tulpn
```


After Hysteria2 installation:

Expected:


```
udp :443
```



# 8. Next Steps


After AWS preparation:

Continue with:


1. Install Hysteria2

2. Install Certbot

3. Generate TLS certificate

4. Configure Hysteria2 server

5. Enable systemd service

6. Import Shadowrocket configuration



# Notes


This project separates infrastructure and application layers:


AWS:

```
Provides server and network
```


Hysteria2:

```
Provides encrypted transport
```


Shadowrocket:

```
Provides client routing
```