# 系统架构

[English](../architecture.md) | 简体中文

## 概览

本项目在 Linux VPS 上部署 Hysteria2 代理服务，并使用 TLS、Certbot 和 systemd 管理服务端。客户端属于独立层：只要当前版本实现了本项目所需的 Hysteria2 连接字段，就可以使用同一台服务器。

AWS EC2 是最初的 VPS 测试参考，不是必需基础设施。Shadowrocket 是项目维护的客户端示例，不是服务端依赖。

系统包含：

- 支持 Hysteria2 的客户端
- 通过 QUIC 和 UDP 443 建立的 Hysteria2 加密代理连接
- 指向服务器的 `YOUR_DOMAIN`
- 具有公网地址的 Ubuntu VPS
- 由 Certbot 管理的 Let's Encrypt TLS 证书
- 运行 Hysteria2 的 systemd 服务

## 总体架构

```text
+--------------------------+
| 兼容 Hysteria2 的客户端  |
| - 建立连接               |
| - 可选分流与 DNS         |
+--------------------------+
             |
             v
+--------------------------+
| Hysteria2                |
| QUIC + UDP 443           |
| TLS + 密码认证           |
+--------------------------+
             |
             v
+--------------------------+
| YOUR_DOMAIN              |
| DNS -> 公网地址          |
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

域名负责把稳定名称解析为公网地址，本身不转发代理流量。真正的加密连接由 Hysteria2 客户端与 VPS 上的 Hysteria2 服务端建立。

## 三层职责

| 层级 | 负责内容 | 示例 |
| --- | --- | --- |
| VPS 提供商 | 计算资源、公网地址、云防火墙 | AWS EC2 参考或其他 Linux VPS |
| 服务端应用 | 认证、加密代理、TLS、服务生命周期 | Hysteria2、Certbot、systemd |
| 客户端 | 连接字段及可选分流和 DNS | Shadowrocket 或其他 Hysteria2 客户端 |

把三层分开后，更换客户端不会要求重新设计服务端；更换 VPS 提供商也不应改变客户端协议字段。

## VPS 提供商层

合适的 VPS 环境应支持：

- Ubuntu 22.04 或 24.04
- 可供 DNS 使用的公网 IPv4 或 IPv6 地址
- 入站 UDP 443
- SSH 管理
- Certbot 验证方式需要时可用的 TCP 80

AWS EC2、Oracle Cloud、Google Cloud、Azure、DigitalOcean、Vultr 和其他 Linux VPS 都可能适用。

AWS 使用 Security Group 和 Elastic IP，其他平台可能称为云防火墙、保留 IP 或静态 IP。名称不同，但架构职责相同。

原始测试环境见[中文 VPS 部署指南](vps-deployment.md)。

## 服务端组件

### Linux VPS

VPS 负责：

- 运行 Hysteria2 服务端
- 接收 UDP 443 上的 Hysteria2 流量
- 读取 TLS 证书文件
- 转发通过认证的代理流量
- 作为被代理流量的 Internet 出口

### 静态公网 IP 与域名

静态或保留公网地址可以避免常规服务器生命周期操作意外改变 DNS 映射。

```text
YOUR_DOMAIN
     |
     v
稳定公网地址
     |
     v
Linux VPS
```

客户端连接和 TLS 证书都使用该域名。以后迁移服务器时，通常可以通过更新 DNS 完成切换。

### Let's Encrypt 与 Certbot

TLS 用于服务器身份认证和加密通信。Certbot 负责申请和续期证书。

```text
Certbot 完成续期
       |
       v
执行 deploy hook
       |
       v
重启 Hysteria2
       |
       v
加载新证书
```

deploy hook 位于 `/etc/letsencrypt/renewal-hooks/deploy/`。

### Hysteria2

Hysteria2 负责：

- 验证客户端密码
- 使用 TLS 加密连接
- 通过 QUIC 和 UDP 传输代理流量
- 在配置端口监听

服务端路径保持：

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

### systemd

systemd 负责开机启动和进程异常后的重新启动：

```bash
sudo systemctl status hysteria-server
```

它不能自动修复 YAML、证书路径或认证配置错误。

## 客户端层

兼容客户端需要支持 Hysteria2 和以下字段：

- 服务器：`YOUR_DOMAIN`
- UDP 端口：`443`
- 密码认证
- TLS/SNI：`YOUR_DOMAIN`

分流、DNS、订阅格式和导入语法属于客户端层，不同产品和版本可能有明显差异。

### 项目维护的 Shadowrocket 示例

Shadowrocket 继续作为项目记录的客户端示例，提供客户端 DNS 和以下分流策略：

```text
局域网与中国大陆流量 -> DIRECT
其他流量             -> PROXY
```

这些规则不是 Hysteria2 服务端功能，也不能默认直接移植到其他客户端。详见 [Shadowrocket 客户端配置](clients/shadowrocket.md)。

### 其他客户端

Mihomo 提供原生 Hysteria2 代理类型；使用兼容 Mihomo/Clash.Meta 内核的客户端时，需要确认当前内核版本是否暴露该功能。Surge 等其他产品应以当前官方文档为准，不能因为产品名称出现在列表中就默认兼容。

本项目不提供未经验证的客户端配置语法。

## 流量流程

### 客户端支持规则时的直连流量

```text
应用
  |
  v
客户端规则判断
  |
  v
DIRECT
  |
  v
目标
```

直连是客户端决策，不经过 VPS。

### 代理流量

```text
应用
  |
  v
Hysteria2 兼容客户端
  |
  v
Hysteria2 加密连接
  |
  v
Linux VPS
  |
  v
目标
```

不提供分流规则的客户端仍可连接服务器，但如何选择流量由该客户端决定。

## 设计原则

### 简单

使用少量标准组件和明确配置路径。

### 客户端中立

Hysteria2 服务端不绑定客户端品牌；客户端专用示例存放在明确命名的目录中。

### 可复现

公开示例不包含个人域名、服务器地址、真实密码、证书或云平台凭据。

### 安全

使用 TLS，限制 SSH 和防火墙，为云平台账户启用 MFA，并把私有材料留在仓库外。

### 可靠

使用 systemd 管理服务，使用 Certbot deploy hook 加载续期证书。

### 可维护

分离 VPS 指南、服务端配置、客户端示例、脚本和故障排查文档。

## 相关文档

- [中文项目主页](../../README_CN.md)
- [中文 VPS 部署](vps-deployment.md)
- [中文故障排查](troubleshooting.md)
- [Shadowrocket 客户端配置](clients/shadowrocket.md)
