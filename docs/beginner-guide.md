# Beginner guide: deploy your first Hysteria2 server

English | [简体中文](zh-CN/beginner-guide.md)

Start here even if you have never bought a VPS or domain or used Linux, DNS, or SSH. Complete each section, check the result, then continue. If a command fails, stop at that step.

> This project builds a personal encrypted proxy server, sometimes informally called a “VPN node.” It is not a traditional full-network VPN or a commercial proxy-service management system. It does not provide registration, subscriptions, plans, billing, payments, or abuse prevention. Use it within local law and provider terms.

Jump to: [VPS and firewall](#4-create-a-vps-and-configure-its-firewall) · [Domain and DNS](#5-buy-a-domain-and-configure-dns) · [SSH](#6-log-in-with-ssh-for-the-first-time) · [Installation](#7-download-the-project-and-install-hysteria2) · [Clients](#12-choose-and-configure-a-client) · [Troubleshooting](#14-common-problems).

## 1. What you will build

`Compatible Hysteria2 client → QUIC/TLS (UDP 443) → Ubuntu VPS → Internet`

The server does not depend on the client's operating system or brand. Compatible clients on iOS/iPadOS, macOS, Android, Windows, and Linux can connect in principle. The server installer in this guide still requires Ubuntu; client neutrality does not make that installer portable to every OS.

Follow this order: choose a VPS → public IP and firewall → buy a domain and configure DNS → SSH login → installation, certificate and configuration → server checks → client connection.

## 2. Before you start

Have a computer with a browser and terminal, an email address, and a payment method. The next steps explain how to obtain the VPS, domain, and SSH credentials. Install a client later; an Apple device is not required.

A VPS is a remote computer you rent that stays online. A domain is a memorable name. DNS maps that name to an IP address. SSH lets you manage the remote computer from your own terminal. VPS and domain charges are usually separate; DNS hosting depends on the chosen service.

This guide uses public IPv4 and a domain certificate. Avoid IPv6-only plans, shared NAT without a UDP 443 mapping, or plans that prohibit your intended proxy use. Before buying, check:

- Ubuntu 22.04 LTS or 24.04 LTS, administrator access, and inbound UDP support;
- a region suitable for your location and budget, test connectivity or a short-term plan; proximity alone does not guarantee a good route;
- monthly traffic, bandwidth, excess-transfer, disk, and public IPv4 charges;
- static/reserved IP options, a web recovery console, and cancellation terms.

AWS EC2 is the project's original tested reference; other Linux VPS providers meeting these requirements are suitable alternatives. Do not assume a plan is free. Start with a basic size for personal use and adjust after observing resource usage.

## 3. Record your own values

| Placeholder | Replace with |
| --- | --- |
| `YOUR_SERVER_IP` | Public IPv4 shown in the VPS console |
| `YOUR_DOMAIN` | Full domain name for the node |
| `YOUR_EMAIL` | Email used for certificate registration |
| `YOUR_PASSWORD` | Hysteria2 random password generated later |
| `YOUR_SSH_KEY.pem` | SSH private-key filename on your computer |
| `YOUR_ADMIN_IP` | Public IPv4 of your current computer's network, for the SSH firewall rule |

Keep these values in private notes. Replace placeholders before running commands; do not copy terminal prompts or code fences. SSH credentials and the Hysteria2 password serve different purposes.

“Local terminal” means your computer; “server terminal” means the window after SSH login. Press Enter after each command and wait for the prompt to return. `sudo` runs a command with administrator privileges. Password input may show no characters or asterisks.

## 4. Create a VPS and configure its firewall

### General procedure (provider console in your browser)

1. Register, verify your email and payment method, enable MFA, and set budget/traffic alerts.
2. Choose Create server/instance, region, Ubuntu 22.04/24.04 LTS, size, and disk. Confirm public IPv4 is included or can be attached.
3. Create/select an SSH key as instructed and save the private key; securely record a system password if supplied. Record the image's login username.
4. Review costs, create the server, and wait until it is running and its checks pass.
5. Copy **Public IPv4** from the instance's network/details page as `YOUR_SERVER_IP`. Do not use its private IP, instance ID, or your computer's IP.

Private addresses serve the cloud's internal network and cannot directly identify this server to external clients. A static public IP keeps DNS stable; if the address changes, update the A record and allow cached answers to expire.

### AWS EC2 example

Choose a region in the AWS console, then **EC2 → Instances → Launch instances**:

1. Enter a recognizable name and select Canonical Ubuntu 22.04/24.04 LTS, not Amazon Linux.
2. Choose a basic instance size matching the image architecture, such as `t3.micro` for x86_64 Ubuntu; review current cost and disk capacity.
3. Under **Key pair (login)**, create an RSA key in `.pem` format and save it on your computer. Do not skip this or upload the key to the repository.
4. Under **Network settings**, use a public VPC/subnet with automatic public IPv4 assignment. If no default VPC exists, first use AWS's VPC wizard to create networking with an Internet Gateway route. Do not select a private-only subnet.
5. Create and attach a security group using the table below, review, launch, and wait for checks to pass.
6. Select the instance and find **Public IPv4 address**. **Connect → SSH client** shows the key and connection command; Ubuntu normally uses username `ubuntu`.

See [AWS's launch and connection steps](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html). Console labels may change; follow the meaning of each field.

For a fixed address, use **EC2 → Elastic IPs → Allocate → Associate** in the same region and associate it with this instance. Copy the new public IPv4 for both DNS and SSH. Public IPv4 and Elastic IPs may incur charges, including while idle; see [Elastic IP documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html).

An AWS **Reboot** retains public IPv4; **Stop then Start** normally changes an automatically assigned public IPv4. An Elastic IP keeps it stable. Other providers may behave differently. See [EC2 instance lifecycle](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html).

### Allow inbound ports

Security Group is AWS's cloud firewall; other providers may call it Firewall or a security group. Attach the rules to your instance.

| Protocol | Port | Source | Purpose |
| --- | --- | --- | --- |
| TCP | 22 | `YOUR_ADMIN_IP/32`, or the console's My IP option | SSH; update this source when changing networks |
| TCP | 80 | `0.0.0.0/0` | This guide's HTTP-01 certificate issuance and automatic renewal |
| UDP | 443 | `0.0.0.0/0`, or known client networks | Hysteria2 connections |

`/32` means one IPv4 address. `0.0.0.0/0` means all IPv4 sources, not the server address to put in DNS. TCP 443 cannot replace UDP 443; no extra TCP 443 rule is needed without another HTTPS service. Retain normal outbound access for downloads, DNS, and destinations.

The server may also have a host firewall such as UFW; inspect it after SSH login in section 6. Cloud rules do not automatically open the host firewall. Do not permanently close TCP 80 after certificate issuance: that breaks this standalone renewal setup. See [Let's Encrypt HTTP-01](https://letsencrypt.org/docs/challenge-types/).

Checkpoint: the instance runs, its public IPv4 is recorded, and the three inbound rules are attached. The existing [VPS reference guide](aws-deployment.md) has more provider context.

## 5. Buy a domain and configure DNS

### Why a domain, and where to buy one

This project's default uses a domain and Certbot certificate so TLS can verify the server's identity. DNS does not forward proxy traffic. This is the guide's deployment choice, not the only certificate option Hysteria2 supports.

Register on a domain registrar's official site, search available names, compare initial and renewal prices, select a registration term, enter contact details, and pay. Verify the email, enable MFA, and set renewal reminders or auto-renewal. You do not need an extra web-hosting, paid-certificate, or email package for this tutorial. An existing domain with DNS access can supply a subdomain.

Cloudflare Registrar is one example; another registrar is fine. Domains registered with Cloudflare must use its authoritative DNS. Check registrar policy before buying if you want a separate DNS host. See [Cloudflare domain registration](https://developers.cloudflare.com/registrar/get-started/register-domain/).

### Find the DNS service that actually controls the domain

The registrar handles ownership and renewal; the DNS host handles records. They can be different companies. Using the domain's existing DNS service is simplest.

To use Cloudflare for a new domain bought elsewhere, add the domain, choose a suitable plan, review records, then enter the assigned Cloudflare nameservers in the registrar's Nameservers page. Wait for Active status. For an existing website or email domain, preserve all records and follow the official DNSSEC migration instructions; do not clear the zone. Adding an A record in Cloudflare without delegating DNS to it does not make that record effective. See [nameserver setup](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/).

### Add an A record (DNS console)

Open **DNS → Records → Add record**. Choose a dedicated hostname such as `vpn`; combined with the registered root domain, this is `YOUR_DOMAIN`. A subdomain does not need a separate purchase.

| Field | Value |
| --- | --- |
| Type | `A`, which maps to IPv4 |
| Name | Host part of `YOUR_DOMAIN`, such as `vpn`; usually `@` for the root domain |
| IPv4 address / Content | `YOUR_SERVER_IP`, without a scheme, port, or path |
| TTL | Default or Auto |
| Proxy status, if available | **DNS only**, the grey cloud in Cloudflare |

Check the complete displayed name before saving to avoid appending the domain twice. Do not enter IPv4 into URL forwarding, CNAME, or AAAA fields. Cloudflare's ordinary orange-cloud proxy cannot replace this direct Hysteria2 UDP endpoint. See [record management](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/) and [proxy status](https://developers.cloudflare.com/dns/proxy-status/).

### Check the result (local terminal)

Open PowerShell on Windows or Terminal on macOS/Linux:

```bash
nslookup -type=A YOUR_DOMAIN
```

The answer for your domain must contain `YOUR_SERVER_IP`. The initial Server/Address lines identify the DNS resolver, not the VPS. After installing this project, you can also run these on the server:

```bash
dig +short A YOUR_DOMAIN
dig +short AAAA YOUR_DOMAIN
```

The first should return the VPS public IPv4. In this IPv4-only tutorial, the second should be empty. If an AAAA record exists, check whether IPv6 really reaches the same service; correct erroneous records for this node's name before requesting a certificate.

- `NXDOMAIN`: check spelling, domain email verification, nameserver activation, and whether you edited the authoritative DNS host.
- Old address: check the fixed-IP association and conflicting A records; wait for cached answers to expire.
- Cloudflare addresses: check whether the orange-cloud proxy is still enabled.
- `SERVFAIL`: check nameservers and DNSSEC using the DNS provider's troubleshooting guide.
- Query timeout: check your local connection or try another network; timeout does not mean the record is absent.

Updates may take minutes or longer, and caches differ between networks. Confirm the A record before continuing to certificates.

## 6. Log in with SSH for the first time

### Private-key login (your own computer)

On macOS/Linux, open Terminal and enter the directory containing your downloaded key, for example:

```bash
cd ~/Downloads
chmod 400 YOUR_SSH_KEY.pem
ssh -i YOUR_SSH_KEY.pem ubuntu@YOUR_SERVER_IP
```

On Windows, open PowerShell:

```powershell
cd "$HOME\Downloads"
ssh -i .\YOUR_SSH_KEY.pem ubuntu@YOUR_SERVER_IP
```

Replace the filename and IP; quote the full path if the file is elsewhere. Other images may use `root` or another username; follow the provider's instructions. If Windows cannot find `ssh`, install OpenSSH Client through Optional features or use the provider's documented web SSH. Do not copy the macOS `chmod` command into PowerShell.

### Password login and host identity

Only if the provider supplies password login, run locally:

```bash
ssh ubuntu@YOUR_SERVER_IP
```

Enter the system password when asked; characters are hidden. EC2 key-based login normally does not use this path.

On first connection, compare the host-key fingerprint with the console system log or the provider's published SSH fingerprint, then enter `yes` if they match. Checking the IP alone is not identity verification. If a later host-key change warning appears, establish whether the VPS was rebuilt rather than blindly deleting saved fingerprints. See [AWS SSH guidance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-to-linux-instance.html).

Success shows an Ubuntu welcome message and a prompt like `ubuntu@hostname:~$`. From now on commands run in this **server terminal**, unless marked local. Run:

```bash
cat /etc/os-release
```

Expect Ubuntu 22.04 or 24.04. `exit` returns to your computer; reconnect with SSH after disconnection.

- Timeout: check public IP, your current SSH source IP, instance state, and public routing.
- `Permission denied (publickey)`: check username and the instance's matching key, not the Hysteria2 password.
- Key permissions too open: use the above `chmod` on macOS/Linux; follow official Windows instructions to restrict key-file access.
- Connection refused: inspect SSH service and firewall through the provider's web console instead of repeatedly changing DNS.

### Inspect the host firewall

On the server, run `sudo ufw status`. If inactive, leave it so. If active, keep the current SSH session open, allow your administrator address on the actual SSH port, then TCP 80 and UDP 443:

```bash
sudo ufw allow from YOUR_ADMIN_IP to any port 22 proto tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/udp
sudo ufw status
```

The rules should appear. Test a second SSH connection from a new local terminal before closing the old one. If UFW is absent, there is no need to install it for this tutorial; check whether another host firewall is used. Do not clear existing rules or blindly enable UFW.

## 7. Download the project and install Hysteria2

In the server terminal, run each command and wait for it to finish. `apt-get update` refreshes package metadata; the next command installs the tools used to download the project, edit configuration, and generate a password.

```bash
sudo apt-get update
sudo apt-get install -y git nano openssl
git clone https://github.com/Aaron-Lzb/vps-hysteria2.git
```

Expect package installation and clone completion, with a `vps-hysteria2` directory. If it already exists, establish whether it is an earlier deployment; do not overwrite it. Enter the directory and use the existing installer:

```bash
cd vps-hysteria2
sudo bash scripts/install-hysteria.sh
```

The script downloads the upstream installer, installs Hysteria2, Certbot, and standalone `hysteria-check` / `hysteria-update` commands. It does not pin Hysteria2 to a particular version. `Installation preparation completed.` means preparation succeeded; the service has not yet been started, which is normal.

If an `ERROR` appears, stop and read it rather than repeatedly reinstalling. Use section 14 for troubleshooting.

## 8. Obtain a TLS certificate

In the server terminal, confirm DNS points to the VPS, TCP 80 is allowed by both firewalls, and no other program occupies that port. Replace `YOUR_DOMAIN` and `YOUR_EMAIL` before running:

```bash
sudo certbot certonly --standalone --preferred-challenges http -d YOUR_DOMAIN -m YOUR_EMAIL --agree-tos --no-eff-email
```

Expect `Successfully received certificate`. Then check:

```bash
sudo certbot certificates
```

Expect your domain and certificate paths such as:

```text
/etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
/etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem
```

`privkey.pem` is the server private key; never publish it. Continue only after certificate issuance succeeds.

## 9. Generate a password and configure the server

In the server terminal:

```bash
openssl rand -hex 24
```

Save the 48-character result privately as `YOUR_PASSWORD`.

Work in `~/vps-hysteria2` on the server. Copying below is for first deployment only. First run `sudo test -e /etc/hysteria/config.yaml && echo 'CONFIG EXISTS'`. If it prints `CONFIG EXISTS`, this may be an upstream sample or an existing configuration: inspect and back it up, then proceed only if replacement is appropriate. Do not overwrite a working deployment.

If the existence check prints nothing and no permission error, the file is absent. If it exists, back it up with the following command before replacing it; numbered backups preserve earlier copies:

```bash
sudo cp --backup=numbered /etc/hysteria/config.yaml /etc/hysteria/config.yaml.before-beginner
```

Copy the project template and open the server copy:

```bash
sudo cp configs/hysteria/config.example.yaml /etc/hysteria/config.yaml
sudo nano /etc/hysteria/config.yaml
```

Make two substitutions:

1. Replace both `YOUR_DOMAIN` occurrences. If Certbot reported a directory with an extra suffix, use the actual certificate paths it reported.
2. Replace `YOUR_PASSWORD` with the random password.

Keep `listen: :443`, TLS, password authentication, and the existing masquerade configuration; do not add `obfs`. The masquerade website is only a web-response target, not an Apple-client requirement. Preserve YAML indentation and colons.

In nano, press **Ctrl+O**, Enter to confirm the filename, then **Ctrl+X**. Check for missed placeholders:

```bash
sudo grep -n 'YOUR_' /etc/hysteria/config.yaml
```

No output means none remain; otherwise reopen and correct the file.

## 10. Start and check the service

In the server terminal:

```bash
sudo systemctl enable --now hysteria-server
sudo systemctl status hysteria-server --no-pager
```

Expect `active (running)`. Then run:

```bash
sudo hysteria-check
```

Expected findings include an active service, local UDP 443 listener, valid TLS certificate, and active Certbot timer.

Root is optional for `hysteria-check`; sudo provides certificate visibility and the command remains read-only. `HEALTHY` exits 0; warnings/critical findings exit 1. Interpret each finding: not every warning means deployment failed. If automatic IP detection fails, use `sudo hysteria-check YOUR_SERVER_IP`.

Local checks cannot prove cloud-firewall or end-to-end client connectivity. Install the renewal hook next.

## 11. Configure automatic certificate renewal

Still in the repository directory on the server:

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
sudo certbot renew --dry-run
```

Expect a successful simulated renewal. By default dry-run does not execute deploy hooks, so it does not prove Hysteria2 restarted. Run `systemctl is-active certbot.timer` and expect `active`. If inactive, inspect `systemctl status certbot.timer --no-pager`; if present but disabled, run `sudo systemctl enable --now certbot.timer`. If absent, investigate the Certbot installation method instead of assuming scheduling works.

With a working timer, manual `renew` is normally unnecessary. Keep DNS and TCP 80 reachable. A real successful renewal triggers the deploy hook to restart Hysteria2 and load the new certificate; connections may briefly interrupt. See [Certbot renewal guidance](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates).

## 12. Choose and configure a client

Work on the device that will use the proxy. The server does not depend on its OS or brand. Any client implementing this deployment's Hysteria2, password authentication, and TLS/SNI requirements can connect in principle.

| Platform | Client examples to explore |
| --- | --- |
| iOS / iPadOS | Hiddify, Shadowrocket |
| macOS | Hiddify, FlClash |
| Android | Hiddify, FlClash |
| Windows | Hiddify, FlClash |
| Linux | Hiddify, FlClash, or the official Hysteria CLI |

Sources: [Hysteria's client directory](https://v2.hysteria.network/docs/getting-started/3rd-party-apps/), [Hiddify](https://github.com/hiddify/hiddify-app), and [FlClash](https://github.com/chen08209/FlClash). This is platform guidance, not a list of devices individually acceptance-tested by this project. Confirm current Hysteria2 support, OS requirements, and import methods before installing. Mihomo/Clash.Meta is a core used by some apps; apps expose different capabilities. Check other apps, including Surge, against their specific version's official documentation.

1. Download the matching version from the project's official release page or its linked app store.
2. Find Add node/server and select **Hysteria2**, not legacy Hysteria. If the app only imports configuration, follow its official Hysteria2 format; do not import the server YAML.
3. Enter the fields below, save, select the node, and connect. Approve VPN/network-extension permissions only after confirming the request belongs to the client you installed.

| Field | Value |
| --- | --- |
| Address / Server | `YOUR_DOMAIN`, without `https://` or a path |
| Port | `443` (UDP) |
| Password / auth | Server's `YOUR_PASSWORD` |
| SNI / Server Name | `YOUR_DOMAIN` |
| Skip certificate verification / Allow Insecure | Off |
| Extra obfuscation / Salamander | Off, matching the project defaults |

For CLI or native configurations, see the [Hysteria client tutorial](https://v2.hysteria.network/docs/getting-started/Client/) or [Mihomo Hysteria2 fields](https://wiki.metacubex.one/en/config/proxies/hysteria2/). Keep completed configurations private; do not send passwords or node links to public converter websites.

If a desktop client only opens a local proxy port, follow its instructions to enable system proxy or configure the intended application. Traffic is not automatically routed just because a client runs. Test connectivity, then open a page expected to use the proxy. A latency number or browser success does not prove routing for every app; troubleshoot using section 14.

### Shadowrocket: one maintained example

Shadowrocket is not the default or only choice. If using it, tap `+`, choose Hysteria2, fill the fields above, save, select, and connect. iOS/iPadOS requests permission to add a VPN configuration.

After the node works, follow the [Shadowrocket routing guide](clients/shadowrocket.md) to import the existing configuration and choose the `PROXY` node. Test expected DIRECT and PROXY destinations. Rules are relatively independent of compatible nodes, so switching nodes usually does not require rule changes. This configuration is not directly portable to other client brands.

## 13. Routine maintenance

After logging into the VPS by SSH:

```bash
# Read-only overall status
sudo hysteria-check

# Service state
sudo systemctl status hysteria-server --no-pager

# Restart after intentionally changing configuration
sudo systemctl restart hysteria-server

# Last 100 log lines
sudo journalctl -u hysteria-server -n 100 --no-pager

# Simulate certificate renewal
sudo certbot renew --dry-run
```

`sudo hysteria-update` updates only this project's maintenance checker, not Hysteria2 itself, Ubuntu, or configuration.

Log in at least monthly to run `sudo hysteria-check` and review traffic/billing alerts.

## 14. Common problems

### Certificate issuance fails

Check that DNS equals the VPS public IP, TCP 80 is open, DNS-only mode is selected, domain/email spelling is correct, and recent DNS changes have propagated.

### Service is not active (running)

In the server terminal:

```bash
sudo journalctl -u hysteria-server -n 100 --no-pager
```

Common causes are missed domain replacements, incorrect certificate paths, broken YAML indentation, or another program occupying UDP 443.

### Client times out

Check UDP 443 (not just TCP 443), Hysteria2 protocol selection, a domain without a scheme, port 443, and matching password/SNI. Try another Wi-Fi/mobile network to check whether the current network blocks UDP.

### Authentication fails

The client password must match `/etc/hysteria/config.yaml`. Keep both ends consistent; after changing server configuration, run:

```bash
sudo systemctl restart hysteria-server
```

### Still unresolved

Use the [troubleshooting guide](troubleshooting.md). Share only redacted errors, never passwords, SSH/TLS keys, or complete node links.

## 15. Security and usage boundaries

- This is not an anonymity guarantee. Providers can see account/traffic metadata, and destinations may see the VPS public IP.
- A shared password suits personal or a small trusted group. If exposed, replace it and restart the service.
- Do not publish nodes; abuse may exhaust traffic, create charges, or cause provider suspension.
- Enable MFA for VPS and domain accounts and set billing/traffic alerts.
- Maintain Ubuntu, Hysteria2, and clients, and check renewal.
- A commercial multi-user service needs separate user isolation, subscriptions, rate limits, accounting, payment, auditing, abuse prevention, privacy, logging, and compliance work; this project does not implement those systems.

You now have a personal Hysteria2 node for compatible clients.
