# Troubleshooting Guide

English | [简体中文](zh-CN/troubleshooting.md)

This document summarizes common issues and solutions for the Hysteria2 encrypted networking deployment.

## Deployment checklist

- [ ] Domain resolves correctly
- [ ] UDP 443 is open in the VPS-provider firewall and host firewall
- [ ] Hysteria2 is running
- [ ] TLS certificate is valid
- [ ] Client password matches `YOUR_PASSWORD` on the server

Run the diagnostic-only server helper:

```bash
bash scripts/check-status.sh YOUR_DOMAIN
```

It checks the Hysteria2 service, local UDP 443 listener, configured TLS certificate lifetime, Certbot renewal timer, pending Ubuntu security updates, reboot marker, root filesystem use, OS version, installed Hysteria2 version, and optional DNS resolution. It does not repair, renew, update, restart, or otherwise change the server. Root is not required; rerun with `sudo` if certificate or systemd details are unreadable.

`HEALTHY` exits 0, while `ATTENTION REQUIRED` and `CRITICAL` exit 1. UDP 443 listening confirms only that the server appears to be listening locally. It does not prove full client-to-server connectivity. Confirm VPS-provider and host firewall rules, then test from a client to establish end-to-end reachability.

## Security checklist

- [ ] Never upload private keys
- [ ] Never upload real passwords
- [ ] Never upload certificates, provider credentials, real server IP addresses, or personal domains
- [ ] Restrict SSH access to trusted source addresses or networks
- [ ] Enable MFA on the VPS-provider account
- [ ] Keep Ubuntu, Hysteria2, and Certbot updated
- [ ] Review firewall rules and remove ports that are no longer required

The troubleshooting process follows a simple principle:

```
Client
  |
Network
  |
Server
  |
Service
  |
Configuration
```

Check each layer step by step.


# 1. Hysteria2 Service Failed to Start


## Symptom

The service status shows:

```
Active: failed
```


Check:


```bash
sudo systemctl status hysteria-server
```


View logs:


```bash
sudo journalctl -u hysteria-server -f
```



## Common Causes


### Invalid Configuration


Example:


```
failed to load server config
```


Check:


```bash
sudo nano /etc/hysteria/config.yaml
```


Verify:

- YAML indentation
- Certificate path
- Password format



---

# 2. TLS Certificate Permission Error


## Symptom


Example error:


```
tls.cert:
permission denied
```


## Cause


Let's Encrypt certificates are stored under:


```
/etc/letsencrypt/live/
```


The service user may not have permission to read certificate files.



## Solution


Ensure systemd service runs as root:


```ini
[Service]

User=root
```


Reload:


```bash
sudo systemctl daemon-reload

sudo systemctl restart hysteria-server
```



# 3. Client Connection Timeout


## Symptoms


A compatible client reports:

```
Connection timeout
```


## Step 1: Check Server Status


On server:


```bash
sudo systemctl status hysteria-server
```


Expected:


```
Active: active (running)
```



## Step 2: Check UDP Traffic


Run:


```bash
sudo tcpdump -i any -n udp port 443
```


A successful connection should show:


```
Client → Server UDP 443

Server → Client UDP 443
```



## Step 3: Check the VPS-provider firewall


Verify the equivalent provider rule (an AWS Security Group in the reference deployment):


| Protocol | Port |
| -------- | ---- |
| UDP      | 443  |
| TCP      | 443  |



# 4. Authentication Failure


## Symptom


Connection reaches server but authentication fails.



## Cause


Client password does not match server configuration.



Server:


```yaml
auth:
  type: password
  password: YOUR_PASSWORD
```


Client:

```
Client password

must be identical
```

Client field names differ. Shadowrocket users can also review the dedicated [Shadowrocket client guide](clients/shadowrocket.md).



Common mistakes:


- Extra spaces
- Different capitalization
- Old password cached in client



# 5. Certificate Renewal


## Check Certificate


```bash
sudo certbot certificates
```


Example:


```
Certificate Name:
YOUR_DOMAIN

Expiry Date:
YYYY-MM-DD
```



## Test Renewal


Run:


```bash
sudo certbot renew --dry-run
```


Expected:


```
Congratulations,
all simulated renewals succeeded
```



# 6. Check Automatic Restart After Renewal


Certbot uses a deploy hook to make Hysteria2 load the renewed certificate:


```text
Certbot renewal
       |
       v
renewal hook
       |
       v
restart Hysteria2
       |
       v
load new certificate
```


Certificate renewal hook:


```
/etc/letsencrypt/renewal-hooks/deploy/
```


Example installation path:


```
/etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
```


Content:


```bash
#!/bin/bash

systemctl restart hysteria-server
```


Install the repository script with executable permissions:


```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
```



# 7. General Diagnostic Commands


## Service Status


```bash
systemctl status hysteria-server
```


## Service Logs


```bash
journalctl -u hysteria-server -f
```


## Listening Ports


```bash
sudo ss -tulpn
```


## Network Check


```bash
curl ifconfig.me
```



# Troubleshooting Philosophy


Do not randomly change configuration parameters.

Always check in this order:


```
1. Is the server running?

2. Is the network reachable?

3. Is UDP 443 allowed?

4. Is TLS certificate valid?

5. Does client authentication match?

6. Are routing rules correct?
```



This approach minimizes unnecessary changes and helps locate the real root cause quickly.
