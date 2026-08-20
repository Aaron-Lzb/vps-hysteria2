# VPS Hysteria2

[English](README.md) | 简体中文

[![Release](https://img.shields.io/github/v/release/Aaron-Lzb/vps-hysteria2)](https://github.com/Aaron-Lzb/vps-hysteria2/releases)
[![License](https://img.shields.io/github/license/Aaron-Lzb/vps-hysteria2)](LICENSE)
[![Validation](https://github.com/Aaron-Lzb/vps-hysteria2/actions/workflows/validate.yml/badge.svg)](https://github.com/Aaron-Lzb/vps-hysteria2/actions/workflows/validate.yml)

一套简单、实用的 VPS Hysteria2 部署方案，包含 TLS、systemd、证书自动续期、状态检查，并可配合多种支持 Hysteria2 的客户端使用。

在 VPS 上部署 Hysteria2 服务端，并通过任意支持 Hysteria2 的客户端连接使用。Shadowrocket 继续作为本项目维护的客户端示例，但不再代表整个项目的身份。

AWS EC2 是最初并持续保留的 VPS 测试参考，不是必需基础设施。其他允许 Ubuntu 和入站 UDP 流量的 VPS 也可沿用相同服务端架构。

## 导航

- [项目状态](#项目状态)
- [项目特点](#项目特点)
- [系统架构](#系统架构)
- [部署前准备](#部署前准备)
- [快速开始](#快速开始)
- [客户端配置](#客户端配置)
- [服务端配置](#服务端配置)
- [证书自动续期](#证书自动续期)
- [状态检查](#状态检查)
- [项目结构](#项目结构)
- [文档导航](#文档导航)
- [安全注意事项](#安全注意事项)

## 项目状态

当前版本：**v1.4.0**

**v1.4.0 - 全局维护命令** 会把只读状态检查安装为 `hysteria-check`，日常维护无需先进入项目目录。命令通常会自动检测 VPS 公网 IPv4，也保留手工传入地址的方式。

v1.3.0 的客户端中立化定位及此前发布历史保持不变。

## 项目特点

- 在自己的 Ubuntu VPS 上运行 Hysteria2 代理服务
- 使用 QUIC、UDP 443 和 TLS
- 使用 systemd 管理开机启动和异常恢复
- 使用 Certbot 管理证书及续期钩子
- 提供全局 `hysteria-check` 只读维护检查
- 服务端配置不绑定 VPS 提供商或客户端品牌
- 保留经过项目维护的 Shadowrocket 分流示例
- 提供中英文部署和排错文档
- 公开模板只使用占位符，不包含部署者的敏感信息

## 系统架构

```text
支持 Hysteria2 的客户端
          |
          v
 Hysteria2 加密代理连接
    QUIC + UDP 443
          |
          v
      YOUR_DOMAIN
          |
          v
     Ubuntu VPS
          |
          v
       Internet
```

VPS 提供 Ubuntu、公网地址和防火墙；Hysteria2 负责认证及加密代理传输；客户端负责填写连接参数，并在支持时管理 DNS 和分流规则。

客户端可以更换，但服务端的域名、UDP 端口、密码和 TLS 证书必须与客户端配置匹配。详见[中文系统架构](docs/zh-CN/architecture.md)。

## 部署前准备

需要准备：

- Ubuntu 22.04 或 24.04 VPS
- 可用于域名解析的公网地址
- 可以修改 DNS 记录的域名
- 云平台防火墙允许 UDP 443
- 使用 HTTP-01 申请证书时可用的 TCP 80
- 一个明确支持 Hysteria2 的客户端版本
- 基本 Linux 命令行操作能力

AWS、Oracle Cloud、Google Cloud、Azure、DigitalOcean、Vultr 和其他 Linux VPS 都可能适用。各平台的防火墙和静态公网 IP 产品名称不同。

## 快速开始

### 1. 准备 VPS 和域名

创建 Ubuntu VPS，配置稳定公网地址，在云防火墙中允许 UDP 443，并让 `YOUR_DOMAIN` 指向 `YOUR_SERVER_IP`。

```bash
dig YOUR_DOMAIN
```

AWS 用户可参考[中文 VPS 部署指南](docs/zh-CN/vps-deployment.md)。

### 2. 安装 Hysteria2

在可信的仓库副本中执行：

```bash
sudo bash scripts/install-hysteria.sh
```

安装脚本会检查 root 权限和 Ubuntu 环境，保留已有配置及 systemd 服务文件，并安装独立的 `/usr/local/bin/hysteria-check` 副本；之后移动或删除仓库副本不会破坏该命令。

### 3. 准备服务端配置

参考：

```text
configs/hysteria/config.example.yaml
```

只在服务器的私有副本中替换：

```text
YOUR_DOMAIN
YOUR_PASSWORD
```

目标配置路径保持为：

```text
/etc/hysteria/config.yaml
```

### 4. 启动服务

```bash
sudo systemctl enable --now hysteria-server
sudo systemctl status hysteria-server
```

### 5. 配置客户端

在支持 Hysteria2 的客户端中填写：

| 字段 | 内容 |
| --- | --- |
| 服务器 | `YOUR_DOMAIN` |
| 端口 | `443` |
| 密码 | 与服务端 `YOUR_PASSWORD` 完全一致 |
| TLS/SNI 名称 | `YOUR_DOMAIN` |

不同客户端界面和语法不同，应以当前安装版本的官方文档为准。

### 6. 检查状态

```bash
hysteria-check
```

命令通常会通过简短的只读 HTTPS 请求自动检测公网 IPv4。检测失败时可手工提供：

```bash
hysteria-check <PUBLIC_IP>
```

脚本会拒绝私网和特殊用途 IPv4，并以只读方式检查 Hysteria2 服务、本机 UDP 443 监听、TLS 证书剩余时间、Certbot 续期定时器、安全更新、重启状态、根文件系统用量、系统和 Hysteria2 版本，以及公网 IP 或可选 DNS 信息。它不会续期证书、安装更新、重启服务或修改配置。无需 root 权限，但 `sudo hysteria-check` 可能读取到普通用户无权查看的证书或服务信息。

## 客户端配置

本项目的 Hysteria2 服务端与客户端品牌解耦。只要客户端当前版本实现了 Hysteria2，并能配置域名、UDP 端口、密码认证和 TLS/SNI，就可以按照对应客户端文档尝试连接。

| 客户端或客户端系列 | 本项目说明 |
| --- | --- |
| Shadowrocket | 提供详细客户端文档和现有分流配置 |
| Mihomo / Clash.Meta 兼容客户端 | Mihomo 提供 Hysteria2 代理类型；按客户端及内核版本文档配置 |
| FlClash | 基于 ClashMeta；需要确认所带内核版本并使用兼容的 Mihomo 配置 |
| Surge | 本项目暂不提供配置，也不默认承诺兼容；请先确认当前版本的 Hysteria2 支持情况 |
| 其他 Hysteria2 客户端 | 按客户端官方文档填写与服务端一致的连接参数 |

这里列出产品名称不代表所有历史版本都支持 Hysteria2。除 Shadowrocket 外，本项目暂不维护可直接导入的客户端配置；详细指南会在配置得到验证后再添加。

### Shadowrocket

现有 Shadowrocket 配置是有意保留的客户端专用示例：

```text
configs/shadowrocket/Hysteria2-Split-Routing.conf
```

它把局域网和中国大陆流量设为 DIRECT，把其他流量交给选定的 Hysteria2 代理节点。节点字段、完整流量图、DNS 设计和排错方法见 [Shadowrocket 客户端配置](docs/zh-CN/clients/shadowrocket.md)。

### Mihomo / Clash.Meta 兼容客户端

Mihomo 官方文档提供原生 `hysteria2` 代理类型。配置字段可能随内核和客户端版本变化，因此本项目链接[官方 Mihomo Hysteria2 配置参考](https://wiki.metacubex.one/en/config/proxies/hysteria2/)，不复制未经本项目验证的配置。

### 其他客户端

使用 FlClash、Surge 或其他客户端时，应先确认当前版本明确支持 Hysteria2。不要把其他协议的配置格式直接套用到 Hysteria2，也不要假设不同客户端可以导入 Shadowrocket 配置文件。

## 服务端配置

服务器示例核心内容：

```yaml
listen: :443

tls:
  cert: /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem

auth:
  type: password
  password: YOUR_PASSWORD
```

- `listen: :443`：Hysteria2 监听 UDP 443。
- `tls.cert`：完整证书链。
- `tls.key`：TLS 私钥，绝不能上传。
- `YOUR_PASSWORD`：必须与客户端密码完全一致。

固定服务端路径：

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

更换客户端不需要改变这些路径。

## 证书自动续期

安装 Certbot deploy hook：

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
sudo certbot renew --dry-run
```

```text
Certbot 续期成功
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

服务重启时，已有连接可能短暂中断。

## 状态检查

```bash
hysteria-check
```

自动检测不可用时：

```bash
hysteria-check <PUBLIC_IP>
```

仓库开发和尚未重新运行安装脚本的已有部署仍可使用：

```bash
bash scripts/check-status.sh <PUBLIC_IP>
```

已有仓库副本也可以只安装或更新全局命令，无需重新运行完整的 Hysteria2 安装流程：

```bash
sudo install -m 0755 scripts/check-status.sh /usr/local/bin/hysteria-check
```

`HEALTHY` 的退出状态为 0；`ATTENTION REQUIRED` 和 `CRITICAL` 的退出状态为 1。本机存在 UDP 443 监听只说明服务器套接字正常，不能证明云防火墙已放行或客户端能够端到端连接。

遇到问题时按以下顺序检查：

```text
DNS 解析
  -> 云防火墙和主机防火墙
  -> UDP 443
  -> systemd 服务
  -> TLS 证书
  -> 密码认证
  -> 客户端配置
```

详细命令见[中文故障排查指南](docs/zh-CN/troubleshooting.md)。

## 项目结构

```text
vps-hysteria2/
├── .github/workflows/validate.yml
├── configs/
│   ├── hysteria/config.example.yaml
│   ├── shadowrocket/Hysteria2-Split-Routing.conf
│   └── systemd/hysteria-server.service
├── docs/
│   ├── architecture.md
│   ├── aws-deployment.md
│   ├── troubleshooting.md
│   ├── clients/shadowrocket.md
│   └── zh-CN/
│       ├── architecture.md
│       ├── vps-deployment.md
│       ├── troubleshooting.md
│       └── clients/shadowrocket.md
├── scripts/
│   ├── check-status.sh
│   ├── install-hysteria.sh
│   └── restart-hysteria-after-renew.sh
├── LICENSE
├── README.md
├── README_CN.md
└── VERSION
```

## 文档导航

中文：

- [中文项目主页](README_CN.md)
- [系统架构](docs/zh-CN/architecture.md)
- [VPS 部署指南](docs/zh-CN/vps-deployment.md)
- [故障排查指南](docs/zh-CN/troubleshooting.md)
- [Shadowrocket 客户端配置](docs/zh-CN/clients/shadowrocket.md)

English:

- [English README](README.md)
- [System architecture](docs/architecture.md)
- [AWS reference VPS deployment](docs/aws-deployment.md)
- [Troubleshooting guide](docs/troubleshooting.md)
- [Shadowrocket client configuration](docs/clients/shadowrocket.md)

配置参考：

- [Hysteria2 服务端配置](configs/hysteria/config.example.yaml)
- [systemd 服务](configs/systemd/hysteria-server.service)
- [Shadowrocket 分流示例](configs/shadowrocket/Hysteria2-Split-Routing.conf)

## 安全注意事项

- 不上传 TLS 私钥、SSH 私钥、证书、真实密码、云平台凭据、个人域名或服务器公网地址。
- 公开示例只使用 `YOUR_DOMAIN`、`YOUR_SERVER_IP`、`YOUR_PASSWORD` 和 `YOUR_EMAIL`。
- 限制 SSH 来源，并为 VPS 提供商账户启用 MFA。
- 定期维护 Ubuntu、Hysteria2、Certbot 和所选客户端。
- 私有部署配置与公开仓库分开保存。

## License

本项目使用 MIT License，详见 [LICENSE](LICENSE)。

Copyright (c) 2026 Aaron-Lzb
