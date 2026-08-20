# VPS Hysteria2 Shadowrocket

[English](README.md) | 简体中文

[![Release](https://img.shields.io/github/v/release/Aaron-Lzb/vps-hysteria2-shadowrocket)](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/releases)
[![License](https://img.shields.io/github/license/Aaron-Lzb/vps-hysteria2-shadowrocket)](LICENSE)
[![Validation](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/actions/workflows/validate.yml/badge.svg)](https://github.com/Aaron-Lzb/vps-hysteria2-shadowrocket/actions/workflows/validate.yml)

一个使用 Hysteria2、TLS、systemd 和 Shadowrocket 分流规则搭建自托管加密网络基础设施的项目模板。

## 导航

- [项目简介](#1-项目简介)
- [项目特点](#2-项目特点)
- [系统架构](#3-系统架构)
- [各模块作用](#4-各模块作用)
- [部署前准备](#5-部署前准备)
- [快速开始](#6-快速开始)
- [部署流程概览](#7-部署流程概览)
- [Hysteria2 配置说明](#8-hysteria2-配置说明)
- [Shadowrocket 分流逻辑](#9-shadowrocket-分流逻辑)
- [DNS 设计说明](#10-dns-设计说明)
- [自动证书续期](#11-自动证书续期)
- [服务自动启动与恢复](#12-服务自动启动与恢复)
- [常见问题排查](#13-常见问题排查)
- [安全注意事项](#14-安全注意事项)
- [项目目录结构](#15-项目目录结构)
- [文档导航](#16-文档导航)
- [当前版本](#17-当前版本)
- [License](#18-license)

## 1. 项目简介

本项目提供一套尽量简单、可复现的个人 Hysteria2 部署框架。服务器运行在用户自己管理的 Linux VPS 上，客户端使用 Shadowrocket 建立连接并决定哪些流量直接访问、哪些流量经过 VPS。

AWS EC2 是本项目最初并持续参考的测试环境，但不是必需基础设施。只要 Linux VPS 支持 Ubuntu、拥有公网地址，并允许入站 UDP 443，就可以按照相同思路部署。Oracle Cloud、Google Cloud、Azure、DigitalOcean、Vultr 以及其他 Linux VPS 提供商都可能适用，但控制台名称、静态 IP 产品和防火墙配置方式会有所不同。

本项目不是托管服务，也不会替你保管域名、密码或证书。部署者需要自行管理服务器、云平台账户、网络规则和客户端配置。

## 2. 项目特点

- 使用自己的 Ubuntu VPS 运行 Hysteria2
- Hysteria2 通过 QUIC 和 UDP 443 传输，并使用 TLS
- 使用 systemd 管理开机启动和异常恢复
- 使用 Certbot 管理 Let's Encrypt 证书及续期
- 提供 Shadowrocket 分流示例：局域网和中国大陆流量直连，其余流量走代理
- 提供不会包含个人域名、服务器地址和真实密码的公开模板
- 保留 AWS EC2 实测参考，同时将应用配置与云平台解耦
- 提供服务、端口、证书和 DNS 状态检查脚本

## 3. 系统架构

```text
iPhone / iPad / Mac
         |
         v
    Shadowrocket
    连接与规则判断
         |
         v
 Hysteria2 加密传输
   QUIC + UDP 443
         |
         v
     YOUR_DOMAIN
         |
         v
    Ubuntu Linux VPS
         |
         v
       Internet
```

可以把整个系统理解成三层：VPS 提供服务器和公网出口；Hysteria2 负责客户端与服务器之间的加密传输；Shadowrocket 负责发起连接并执行分流规则。

完整设计见[中文系统架构文档](docs/zh-CN/architecture.md)。

## 4. 各模块作用

| 模块 | 通俗说明 | 主要作用 |
| --- | --- | --- |
| VPS | 一台放在数据中心、可远程管理的 Linux 服务器 | 运行 Hysteria2，并作为被代理流量的网络出口 |
| Elastic IP / 静态公网 IP | 不容易随服务器重启而变化的公网地址 | 让域名持续指向同一台服务器；不同云平台名称可能不同 |
| 自定义域名 | 稳定且易记的服务器入口 | 供 Shadowrocket 连接，也是申请 TLS 证书时使用的名称 |
| TLS 证书 | 用于确认服务器身份的数字证书 | 为 Hysteria2 连接提供服务器认证和加密基础 |
| Certbot | Let's Encrypt 证书管理工具 | 申请、查看、测试续期和自动更新证书 |
| Hysteria2 | 客户端与 VPS 之间的加密传输通道 | 认证客户端，并通过 QUIC/UDP 传输被代理流量 |
| Shadowrocket | 客户端连接工具和流量分流控制中心 | 保存节点信息、控制 DNS，并根据规则选择 DIRECT 或 PROXY |
| systemd | Ubuntu 的系统服务管理器 | 开机启动 Hysteria2，并在进程异常退出后自动重启 |

## 5. 部署前准备

开始前需要准备：

- 一台 Ubuntu 22.04 或 24.04 VPS
- VPS 公网地址；推荐使用提供商的静态或保留地址功能
- 一个自己管理的域名，并可修改 DNS 记录
- 云平台防火墙中开放 UDP 443 的权限
- 通过 SSH 管理服务器的方式
- 客户端已安装 Shadowrocket
- 能够执行复制、编辑文件和运行命令等基本操作

还应提前确认：

- `YOUR_DOMAIN` 已通过 A 记录指向 `YOUR_SERVER_IP`
- SSH 来源范围尽量限制为可信地址
- 使用 HTTP-01 申请证书时可以临时使用 TCP 80
- 云平台账户已经启用 MFA

## 6. 快速开始

### 1. 准备 VPS 和网络

创建 Ubuntu VPS，配置稳定公网 IP，并在云平台防火墙中允许 UDP 443。AWS 用户可以参考[中文 VPS 部署指南](docs/zh-CN/vps-deployment.md)。

### 2. 配置域名

在 DNS 服务商处添加记录：

```text
类型：A
主机：YOUR_DOMAIN 对应的主机部分
值：  YOUR_SERVER_IP
```

检查解析：

```bash
dig YOUR_DOMAIN
```

### 3. 安装 Hysteria2

在可信的仓库副本中执行：

```bash
sudo bash scripts/install-hysteria.sh
```

脚本会检查 root 权限和 Ubuntu 环境，并保留已有的 Hysteria2 配置及 systemd 服务文件。它不会自动替你填写域名和密码。

### 4. 准备服务器配置

参考：

```text
configs/hysteria/config.example.yaml
```

仅在服务器的私有配置副本中替换：

```text
YOUR_DOMAIN
YOUR_PASSWORD
```

配置文件路径保持为：

```text
/etc/hysteria/config.yaml
```

### 5. 启动服务

确认证书路径、密码和 YAML 格式无误后执行：

```bash
sudo systemctl enable --now hysteria-server
sudo systemctl status hysteria-server
```

### 6. 配置 Shadowrocket

添加 Hysteria2 节点，填写与服务器一致的域名、端口和密码，然后导入或参考：

```text
configs/shadowrocket/Hysteria2-Split-Routing.conf
```

### 7. 检查部署状态

```bash
sudo bash scripts/check-status.sh YOUR_DOMAIN
```

脚本会检查 Hysteria2 服务、UDP 443 监听、Certbot 证书信息和域名解析，并用 PASS/FAIL 显示结果。

## 7. 部署流程概览

```text
创建 Ubuntu VPS
       |
       v
配置云防火墙与静态公网 IP
       |
       v
让 YOUR_DOMAIN 指向 YOUR_SERVER_IP
       |
       v
安装 Hysteria2 和 Certbot
       |
       v
申请 TLS 证书
       |
       v
配置 /etc/hysteria/config.yaml
       |
       v
启动 hysteria-server.service
       |
       v
安装 Certbot 续期钩子
       |
       v
配置 Shadowrocket 节点和分流规则
       |
       v
运行状态检查并测试连接
```

遇到问题时，不要一次修改很多参数。建议按照“域名解析 → 云防火墙 → UDP 443 → systemd 服务 → TLS → 密码 → 客户端规则”的顺序逐层确认。

## 8. Hysteria2 配置说明

服务器示例配置的核心内容是：

```yaml
listen: :443

tls:
  cert: /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem

auth:
  type: password
  password: YOUR_PASSWORD
```

- `listen: :443`：Hysteria2 在 UDP 443 上监听。
- `tls.cert`：完整证书链文件路径。
- `tls.key`：TLS 私钥文件路径。该文件绝不能上传到仓库。
- `auth.type: password`：使用密码认证。
- `YOUR_PASSWORD`：必须与 Shadowrocket 节点中填写的密码完全一致。

示例还保留现有的 masquerade 配置。v1.2.0 只增加文档，不改变服务器模板内容或行为。

## 9. Shadowrocket 分流逻辑

当前规则的基本原则：

```text
局域网流量              -> DIRECT
中国大陆域名和 IP       -> DIRECT
其他流量                -> PROXY
```

访问中国大陆网站时：

```text
用户
  |
  v
Shadowrocket
  |
  v
规则判断
  |
  v
DIRECT
  |
  v
本地网络直接访问
```

访问其他网站时：

```text
用户
  |
  v
Shadowrocket
  |
  v
Hysteria2
  |
  v
VPS
  |
  v
Internet
```

也就是说，命中中国大陆和局域网规则的流量不会经过 VPS；其余流量交给 Shadowrocket 中选定的 Hysteria2 节点。规则效果仍取决于规则数据、客户端版本和实际网络环境。

## 10. DNS 设计说明

Shadowrocket 示例配置保持以下 DNS 设置：

主要 DNS（DoH）：

```text
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
```

备用 DNS：

```text
223.5.5.5
119.29.29.29
```

DoH 会加密客户端到 DNS 服务之间的查询传输，减少明文 DNS 在传输路径上直接暴露的情况。示例优先使用国内 DoH，并使用国内公共 DNS 作为备用，目的是让中国大陆域名解析更稳定、与直连分流更匹配。

这个设计是一个偏实用的默认方案，不代表在所有运营商、地区和网络环境下都能提供完全一致的结果，也不宣称能够完美或普遍地解决 DNS 污染问题。遇到解析异常时，应结合 Shadowrocket 日志、当前网络和域名实际解析结果排查。

## 11. 自动证书续期

Let's Encrypt 证书需要定期续期。Certbot 完成续期后，部署钩子重启 Hysteria2，使进程重新读取证书文件：

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

安装钩子：

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
```

测试续期流程：

```bash
sudo certbot renew --dry-run
```

续期钩子会短暂重启服务，已有连接可能在重启时中断。

## 12. 服务自动启动与恢复

systemd 服务文件位于：

```text
/etc/systemd/system/hysteria-server.service
```

项目示例使用：

```ini
Restart=always
RestartSec=3
```

这表示进程退出后，systemd 会等待 3 秒再尝试启动。执行 `enable` 后，服务也会随系统启动：

```bash
sudo systemctl enable hysteria-server
```

常用命令：

```bash
sudo systemctl start hysteria-server
sudo systemctl restart hysteria-server
sudo systemctl status hysteria-server
sudo journalctl -u hysteria-server -f
```

自动重启不能修复错误配置。如果证书路径、YAML 或密码配置有问题，应先查看日志并修正根因。

## 13. 常见问题排查

### 服务无法启动

```bash
sudo systemctl status hysteria-server
sudo journalctl -u hysteria-server -f
```

重点检查 YAML 缩进、证书路径、文件权限和错误日志。

### Shadowrocket 连接超时

```bash
sudo tcpdump -i any -n udp port 443
```

如果完全看不到客户端数据包，优先检查云平台防火墙、服务器防火墙、UDP 443 和客户端当前网络。如果能看到双向数据包，再检查认证密码、TLS 和 Hysteria2 日志。

### 密码认证失败

Shadowrocket 密码必须与服务器中的 `YOUR_PASSWORD` 完全一致，包括大小写，不能多空格。

### 证书问题

```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

更完整的检查步骤见[中文故障排查指南](docs/zh-CN/troubleshooting.md)。

## 14. 安全注意事项

- 不要上传 TLS 私钥、SSH 私钥或任何其他私钥。
- 不要提交真实密码、个人域名、服务器公网地址、证书或云平台凭据。
- 公开示例中只使用 `YOUR_DOMAIN`、`YOUR_SERVER_IP`、`YOUR_PASSWORD` 和 `YOUR_EMAIL`。
- 尽量把 SSH 入站来源限制为可信地址或网络。
- 为 VPS 提供商账户启用 MFA，并设置账单或用量提醒。
- 启动服务前检查脚本、配置和防火墙规则。
- 定期维护 Ubuntu、Hysteria2 和 Certbot。
- 私有部署配置与公开仓库分开保存。

## 15. 项目目录结构

```text
vps-hysteria2-shadowrocket/
├── .github/workflows/validate.yml
├── configs/
│   ├── hysteria/config.example.yaml
│   ├── shadowrocket/Hysteria2-Split-Routing.conf
│   └── systemd/hysteria-server.service
├── docs/
│   ├── architecture.md
│   ├── aws-deployment.md
│   ├── troubleshooting.md
│   └── zh-CN/
│       ├── architecture.md
│       ├── vps-deployment.md
│       └── troubleshooting.md
├── scripts/
│   ├── check-status.sh
│   ├── install-hysteria.sh
│   └── restart-hysteria-after-renew.sh
├── .gitignore
├── .yamllint.yml
├── LICENSE
├── README.md
├── README_CN.md
└── VERSION
```

## 16. 文档导航

中文文档：

- [中文项目主页](README_CN.md)
- [系统架构](docs/zh-CN/architecture.md)
- [VPS 部署指南](docs/zh-CN/vps-deployment.md)
- [故障排查指南](docs/zh-CN/troubleshooting.md)

英文文档：

- [English README](README.md)
- [System architecture](docs/architecture.md)
- [AWS reference VPS deployment](docs/aws-deployment.md)
- [Troubleshooting guide](docs/troubleshooting.md)

配置参考：

- [Hysteria2 服务器配置示例](configs/hysteria/config.example.yaml)
- [systemd 服务示例](configs/systemd/hysteria-server.service)
- [Shadowrocket 分流示例](configs/shadowrocket/Hysteria2-Split-Routing.conf)

## 17. 当前版本

当前版本：**v1.2.0**

版本定位：**v1.2.0 - Bilingual Documentation Release**

本次版本增加完整简体中文项目主页、系统架构、VPS 部署和故障排查文档，并改进中英文导航。它不增加新的网络功能，也不改变脚本、配置模板、systemd、Shadowrocket 分流或 GitHub Actions 的行为。

## 18. License

本项目使用 MIT License，详见 [LICENSE](LICENSE)。

Copyright (c) 2026 Aaron-Lzb
