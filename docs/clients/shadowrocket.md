# Shadowrocket Client Configuration

English | [简体中文](../zh-CN/clients/shadowrocket.md)

## Scope

Shadowrocket is one compatible Hysteria2 client documented by this project. The VPS deployment itself is client-neutral; this guide covers only the included Shadowrocket node and split-routing example.

The maintained configuration file is:

```text
configs/shadowrocket/Hysteria2-Split-Routing.conf
```

Do not import this file into unrelated clients. Their configuration formats and rule engines may differ even when they support Hysteria2.

## Hysteria2 node fields

Create a Hysteria2 node in Shadowrocket and match these values to the server:

| Client field | Value |
| --- | --- |
| Server | `YOUR_DOMAIN` |
| Port | `443` |
| Password | The exact private value replacing server-side `YOUR_PASSWORD` |
| TLS/SNI name | `YOUR_DOMAIN` |

Field labels may differ between Shadowrocket versions. The important requirements are the Hysteria2 protocol, UDP port, password, and TLS server name.

Do not disable certificate verification to work around a domain or certificate mismatch. Correct the DNS, certificate, and SNI values instead.

## Split-routing policy

The included example applies this policy:

```text
LAN traffic                    -> DIRECT
Mainland China domains and IPs -> DIRECT
All remaining traffic          -> PROXY
```

The existing routing rules are largely independent of the specific proxy node, so switching to another compatible node usually does not require changing them.

### Mainland China and LAN traffic

```text
User application
      |
      v
Shadowrocket
      |
      v
Routing rule match
      |
      v
DIRECT
      |
      v
Destination through local network
```

### Remaining traffic

```text
User application
      |
      v
Shadowrocket
      |
      v
Selected Hysteria2 node
      |
      v
VPS
      |
      v
Internet destination
```

Only traffic selected as `PROXY` passes through the VPS. Results depend on rule-set availability, rule ordering, DNS results, the client version, and the current network.

## DNS design

The current Shadowrocket example uses encrypted domestic DNS first:

```text
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
```

Fallback DNS:

```text
223.5.5.5
119.29.29.29
```

DNS over HTTPS encrypts DNS transport between the client and resolver. Domestic resolvers are used to support reliable mainland China resolution and align with direct-routing rules.

This is a practical default, not a claim of perfect results on every carrier or network, and not a guarantee of universal DNS anti-pollution protection.

## Import and use

1. Add and test the Hysteria2 node.
2. Import `configs/shadowrocket/Hysteria2-Split-Routing.conf` into Shadowrocket.
3. Select the intended Hysteria2 node for the `PROXY` policy.
4. Enable configuration/rule mode.
5. Test one expected DIRECT destination and one expected PROXY destination.

The configuration references remote rule sets. If those rule sets are unavailable or change, routing results may differ.

## Troubleshooting

### Connection timeout

On the VPS, verify the service and listener:

```bash
sudo systemctl status hysteria-server
sudo ss -ulnp | grep 443
```

Observe client traffic while reconnecting:

```bash
sudo tcpdump -i any -n udp port 443
```

If no packets arrive, check the domain, UDP 443 firewall rules, and the client's current network. If packets flow in both directions, check the password, TLS/SNI name, certificate, and Hysteria2 logs.

### Authentication failure

The Shadowrocket password must exactly match:

```yaml
auth:
  type: password
  password: YOUR_PASSWORD
```

Check capitalization, whitespace, and whether the client is still using an older saved node.

### Unexpected routing

- Confirm configuration mode is enabled.
- Confirm the intended Hysteria2 node is selected for `PROXY`.
- Check rule order; earlier matches take precedence.
- Check whether remote rule sets loaded successfully.
- Review DNS results for the affected domain.

See the general [troubleshooting guide](../troubleshooting.md) for server, TLS, renewal, and network diagnostics.

## Security

- Never publish the completed node URL, password, personal domain, or server IP.
- Keep TLS verification enabled and use the certificate's domain as SNI.
- Treat exported client configurations as sensitive.
- Replace deployment details with `YOUR_DOMAIN`, `YOUR_SERVER_IP`, and `YOUR_PASSWORD` before sharing examples.

## Related documentation

- [Project README](../../README.md)
- [System architecture](../architecture.md)
- [Troubleshooting guide](../troubleshooting.md)
- [Shadowrocket split-routing example](../../configs/shadowrocket/Hysteria2-Split-Routing.conf)
