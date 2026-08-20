# AWS Reference VPS Deployment

English | [简体中文](zh-CN/vps-deployment.md)

This guide describes the original tested environment for the project. AWS EC2 is a **reference VPS deployment example**, not required infrastructure.

The same Hysteria2 application architecture can run on any suitable Ubuntu VPS. Alternative providers may include:

- AWS EC2
- Oracle Cloud
- Google Cloud
- Azure
- DigitalOcean
- Vultr
- Other Linux VPS providers

When using another provider, translate AWS terms such as *Security Group* and *Elastic IP* to that provider's firewall and static-IP products. The core requirements remain a public IP address, domain endpoint, inbound UDP 443, SSH access, and a supported Ubuntu release.

## 1. Prepare the AWS account

Create or use an existing AWS account.

Recommended safeguards:

- Enable MFA
- Enable billing alerts
- Monitor usage and unexpected resources
- Avoid using the root account for routine administration

## 2. Create an EC2 instance

### Reference configuration

| Setting | Reference value |
| --- | --- |
| Operating system | Ubuntu 22.04 LTS or Ubuntu 24.04 LTS |
| Instance type | `t3.micro` or another size appropriate for expected traffic |
| Storage | Default EBS storage is sufficient for a basic deployment |

Choose a region appropriate for the intended clients, applicable regulations, and cost. The Hysteria2 service has modest disk requirements, but bandwidth and data-transfer pricing vary.

## 3. Configure the Security Group

The EC2 Security Group provides instance-level network filtering.

| Protocol | Port | Purpose |
| --- | --- | --- |
| TCP | 22 | SSH management |
| UDP | 443 | Hysteria2 traffic |
| TCP | 80 | HTTP-01 certificate validation, when used |

TCP 443 is not required by Hysteria2's UDP listener. Add it only if another HTTPS service or chosen deployment method needs it.

For SSH, set the source to a trusted administrator IP address or controlled network whenever possible. Avoid exposing SSH to the entire Internet.

For Hysteria2, allow inbound UDP 443 from the client networks that need access. If broad client mobility requires a wider source range, keep authentication strong and monitor the service.

## 4. Allocate an Elastic IP

An EC2 automatic public IP may change after an instance is stopped and started. An Elastic IP provides stable DNS mapping.

```text
AWS Console
    |
    v
EC2 -> Elastic IPs
    |
    v
Allocate Elastic IP
    |
    v
Associate with instance
```

AWS may charge for public IPv4 addresses. Review current AWS pricing before allocating resources.

On other providers, use the equivalent reserved or static IP feature when available.

## 5. Configure domain DNS

Create an A record at the domain's DNS provider:

```text
Type:  A
Name:  the host portion of YOUR_DOMAIN
Value: YOUR_SERVER_IP
```

The result should be:

```text
YOUR_DOMAIN
     |
     v
YOUR_SERVER_IP
     |
     v
EC2 instance
```

Verify resolution from a terminal:

```bash
dig YOUR_DOMAIN
```

Wait for DNS propagation before requesting the certificate.

## 6. Connect to Ubuntu

Use the private key created or selected when launching the instance:

```bash
ssh ubuntu@YOUR_SERVER_IP
```

Never commit that private key or copy it into the repository.

Update package metadata and apply normal operating-system updates according to your maintenance policy:

```bash
sudo apt-get update
sudo apt-get upgrade
```

Review proposed package changes before confirming an upgrade on an existing server.

## 7. Verify the network

Confirm the server's public address through the provider console. After Hysteria2 is configured and running, verify the UDP listener:

```bash
sudo ss -ulnp | grep 443
```

You can also use the project health check:

```bash
sudo bash scripts/check-status.sh YOUR_DOMAIN
```

If the service listens locally but clients time out, recheck the Security Group, any subnet network ACL, the instance firewall, and the client's current network.

## 8. Continue with application deployment

After the AWS resources are ready:

1. Install Hysteria2 with `scripts/install-hysteria.sh`.
2. Obtain a certificate for `YOUR_DOMAIN` with Certbot.
3. Create `/etc/hysteria/config.yaml` from the example.
4. Replace `YOUR_DOMAIN` and `YOUR_PASSWORD` only in the private server copy.
5. Review and start `hysteria-server.service`.
6. Install the certificate-renewal deploy hook.
7. Configure the matching Shadowrocket node and routing rules.

See the repository [README](../README.md), [architecture guide](architecture.md), and [troubleshooting guide](troubleshooting.md) for the remaining steps.

## AWS-to-generic terminology

| AWS reference term | Generic role |
| --- | --- |
| EC2 instance | Linux VPS |
| Elastic IP | Stable or reserved public IP |
| Security Group | Provider network firewall |
| EBS volume | VPS disk storage |

Only the provider layer changes. The Hysteria2 configuration, systemd unit, Certbot hook, and Shadowrocket routing model remain the same.
