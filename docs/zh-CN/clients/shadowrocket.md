# Shadowrocket 客户端配置

[English](../../clients/shadowrocket.md) | 简体中文

## 文档范围

Shadowrocket 是本项目记录的一种 Hysteria2 兼容客户端。VPS 服务端部署保持客户端中立；本文只说明项目现有的 Shadowrocket 节点和分流示例。

项目维护的客户端配置文件：

```text
configs/shadowrocket/Hysteria2-Split-Routing.conf
```

不要把这个文件直接导入其他客户端。即使其他客户端支持 Hysteria2，它们的配置格式和规则引擎也可能不同。

## Hysteria2 节点字段

在 Shadowrocket 中创建 Hysteria2 节点，并让以下内容与服务器一致：

| 客户端字段 | 内容 |
| --- | --- |
| 服务器 | `YOUR_DOMAIN` |
| 端口 | `443` |
| 密码 | 服务端 `YOUR_PASSWORD` 被替换后的同一个私有值 |
| TLS/SNI 名称 | `YOUR_DOMAIN` |

不同 Shadowrocket 版本的字段名称可能略有不同。关键是选择 Hysteria2 协议，并正确填写 UDP 端口、密码和 TLS 服务器名称。

不要通过关闭证书验证来绕过域名或证书不匹配。应修正 DNS、证书和 SNI 配置。

## 分流策略

项目示例使用：

```text
局域网流量              -> DIRECT
中国大陆域名和 IP       -> DIRECT
其他流量                -> PROXY
```

### 中国大陆与局域网流量

```text
用户应用
  |
  v
Shadowrocket
  |
  v
规则匹配
  |
  v
DIRECT
  |
  v
通过本地网络访问目标
```

### 其他流量

```text
用户应用
  |
  v
Shadowrocket
  |
  v
选定的 Hysteria2 节点
  |
  v
VPS
  |
  v
Internet 目标
```

只有被选为 `PROXY` 的流量经过 VPS。实际结果取决于规则集可用性、规则顺序、DNS 解析、客户端版本和当前网络。

## DNS 设计

当前 Shadowrocket 示例优先使用国内 DoH：

```text
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
```

备用 DNS：

```text
223.5.5.5
119.29.29.29
```

DoH 会加密客户端到 DNS 服务之间的查询传输。国内解析服务用于提高中国大陆域名解析的实用稳定性，并与 DIRECT 规则配合。

这是一套实用默认值，不保证在所有运营商和网络下结果完全相同，也不代表能够普遍或完美地解决 DNS 污染问题。

## 导入与使用

1. 添加并测试 Hysteria2 节点。
2. 把 `configs/shadowrocket/Hysteria2-Split-Routing.conf` 导入 Shadowrocket。
3. 为 `PROXY` 策略选择目标 Hysteria2 节点。
4. 启用配置或规则模式。
5. 分别测试一个预期 DIRECT 和一个预期 PROXY 的目标。

配置中引用远程规则集。如果规则集无法访问或发生变化，分流结果也可能变化。

## 故障排查

### 连接超时

在 VPS 上检查服务和监听：

```bash
sudo systemctl status hysteria-server
sudo ss -ulnp | grep 443
```

重新连接客户端时抓取流量：

```bash
sudo tcpdump -i any -n udp port 443
```

如果没有数据包到达，检查域名、UDP 443 防火墙和客户端当前网络。如果能看到双向数据包，继续检查密码、TLS/SNI、证书和 Hysteria2 日志。

### 认证失败

Shadowrocket 密码必须与以下配置完全一致：

```yaml
auth:
  type: password
  password: YOUR_PASSWORD
```

检查大小写、首尾空格，以及客户端是否仍在使用旧节点。

### 分流结果异常

- 确认已经启用配置模式。
- 确认 `PROXY` 选择的是目标 Hysteria2 节点。
- 检查规则顺序，靠前的匹配优先。
- 检查远程规则集是否成功加载。
- 检查目标域名的 DNS 解析结果。

服务端、TLS、续期和网络问题见[中文故障排查指南](../troubleshooting.md)。

## 安全注意事项

- 不公开填写完成的节点链接、密码、个人域名或服务器地址。
- 保持 TLS 验证开启，并使用证书域名作为 SNI。
- 把导出的客户端配置视为敏感文件。
- 分享示例前替换为 `YOUR_DOMAIN`、`YOUR_SERVER_IP` 和 `YOUR_PASSWORD`。

## 相关文档

- [中文项目主页](../../../README_CN.md)
- [中文系统架构](../architecture.md)
- [中文故障排查](../troubleshooting.md)
- [Shadowrocket 分流示例](../../../configs/shadowrocket/Hysteria2-Split-Routing.conf)
