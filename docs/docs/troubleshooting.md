# Troubleshooting Guide

This document summarizes common issues and solutions during deployment and operation of the Hysteria2 VPN system.

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



# 3. Shadowrocket Connection Timeout


## Symptoms


Shadowrocket shows:

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



## Step 3: Check AWS Security Group


Verify:


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
Shadowrocket Password

must be identical
```



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


Certificate renewal hook:


```
/etc/letsencrypt/renewal-hooks/deploy/
```


Example:


```
restart-hysteria.sh
```


Content:


```bash
#!/bin/bash

systemctl restart hysteria-server
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