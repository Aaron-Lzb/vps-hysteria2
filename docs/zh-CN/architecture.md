# 系统架构

[English](../architecture.md) | 简体中文

## 概览

本项目把 Linux VPS、Hysteria2、TLS、systemd 和 Shadowrocket 组合成一套自托管加密网络基础设施。

应用层设计不绑定某一家云平台。AWS EC2 是本项目主要测试和参考的 VPS 环境，但不是唯一选择。其他提供商只要能提供受支持的 Ubuntu、公网地址、SSH 管理和 UDP 443 入站访问，就可以沿用相同架构。

系统由以下部分组成：

- 运行 Shadowrocket 的 iPhone、iPad 或 Mac
- 通过 QUIC 和 UDP 443 建立的 Hysteria2 加密传输
- 指向服务器公网地址的 `YOUR_DOMAIN`
- 运行 Hysteria2 的 Ubuntu VPS
- 由 Certbot 管理的 Let's Encrypt TLS 证书
- 管理 Hysteria2 进程的 systemd 服务

## 总体架构

```text
+----------------------+
| iPhone / iPad / Mac  |
+----------------------+
            |
            v
+----------------------+
| Shadowrocket         |
| - 建立客户端连接     |
| - 执行分流规则       |
| - 控制 DNS           |
+----------------------+
            |
            v
+----------------------+
| Hysteria2            |
| QUIC + UDP 443       |
| TLS 加密             |
+----------------------+
            |
            v
+----------------------+
| YOUR_DOMAIN          |
| DNS -> 公网地址      |
+----------------------+
            |
            v
+----------------------+
| Ubuntu Linux VPS     |
| Hysteria2 + systemd  |
+----------------------+
            |
            v
+----------------------+
| Internet             |
+----------------------+
```

域名并不转发流量，它负责把稳定的服务器名称解析为公网地址。真正的数据传输发生在 Shadowrocket 与 VPS 上的 Hysteria2 服务之间。

## 三层职责

| 层级 | 负责内容 | 本项目中的例子 |
| --- | --- | --- |
| VPS 提供商 | 计算资源、公网地址、云防火墙 | AWS EC2 参考环境 |
| 服务器应用 | 加密传输、TLS、认证、服务生命周期 | Hysteria2、Certbot、systemd |
| 客户端 | 节点连接、DNS 和流量分流 | Shadowrocket |

把这三层分开有两个好处：更换 VPS 提供商时不必重新设计 Hysteria2 配置；调整客户端分流时也不需要改变服务器基础设施。

## VPS 提供商层

合适的 VPS 环境应具备：

- Ubuntu 22.04 或 Ubuntu 24.04
- 可供域名解析使用的公网 IPv4 或 IPv6 地址
- 入站 UDP 443
- SSH 管理能力
- 使用 Certbot HTTP-01 验证时可用的 TCP 80

可能适用的提供商包括 AWS EC2、Oracle Cloud、Google Cloud、Azure、DigitalOcean、Vultr 和其他 Linux VPS 提供商。

不同平台的名称并不相同：AWS 使用 Security Group 和 Elastic IP，其他平台可能称为云防火墙、保留 IP 或静态 IP。名称不同，但在本架构中承担的职责相同。

AWS EC2 的实际准备流程见[中文 VPS 部署指南](vps-deployment.md)。

## 各组件作用

### Linux VPS

VPS 可以理解为一台放在数据中心、通过网络远程管理的 Linux 服务器。它负责：

- 运行 Hysteria2 服务端
- 接收 UDP 443 上的 Hysteria2 流量
- 读取 TLS 证书文件
- 转发已经通过认证的客户端流量
- 作为被代理流量的 Internet 出口

### 静态公网 IP 与域名

普通公网地址可能在服务器停止和重新启动后发生变化。静态或保留公网地址可以减少这种变化，使 DNS 映射更稳定。

```text
YOUR_DOMAIN
     |
     v
稳定公网地址
     |
     v
Linux VPS
```

域名既是 Shadowrocket 中的服务器名称，也是 TLS 证书验证的名称。以后迁移 VPS 时，通常只需要更新 DNS 指向，而不必改变公开模板。

### TLS、Let's Encrypt 与 Certbot

TLS 用于服务器身份认证和加密通信。Let's Encrypt 签发证书，Certbot 负责申请、查看和续期证书。

续期后的加载流程：

```text
Certbot 完成续期
       |
       v
执行 renewal deploy hook
       |
       v
重启 Hysteria2
       |
       v
进程读取新证书
```

部署钩子的安装目录是：

```text
/etc/letsencrypt/renewal-hooks/deploy/
```

### Hysteria2

Hysteria2 是 Shadowrocket 与 VPS 之间的加密传输通道，负责：

- 验证客户端密码
- 使用 TLS 加密连接
- 使用 QUIC 和 UDP 传输流量
- 在服务器配置的端口上监听

本项目继续使用兼容旧版本部署的路径：

```text
/usr/local/bin/hysteria
/etc/hysteria/config.yaml
/etc/systemd/system/hysteria-server.service
```

### systemd

systemd 是 Ubuntu 的服务管理器。它负责在系统启动后运行 Hysteria2，并在进程异常退出后按照服务文件中的策略重新启动。

```bash
sudo systemctl status hysteria-server
```

systemd 只能管理进程，不能自动修复证书路径错误、YAML 格式错误或密码不匹配。

### Shadowrocket

Shadowrocket 在客户端负责：

- 建立 Hysteria2 连接
- 根据域名和 IP 规则决定 DIRECT 或 PROXY
- 按示例配置处理客户端 DNS

当前示例把局域网和中国大陆流量设为 DIRECT，把剩余流量交给选定的 Hysteria2 代理节点。

## 完整流量流程

### 中国大陆与局域网流量

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
本地网络直接访问目标
```

直连流量不经过 VPS，可避免不必要的服务器带宽消耗，并通常更适合本地服务。

### 其他流量

```text
用户
  |
  v
Shadowrocket
  |
  v
Hysteria2 加密通道
  |
  v
Linux VPS
  |
  v
目标网站或服务
```

只有被规则选择为 PROXY 的流量经过 VPS。实际结果仍取决于 Shadowrocket 规则数据、节点状态和当前网络环境。

## DNS 与分流的关系

Shadowrocket 示例优先使用国内 DoH，并设置国内公共 DNS 作为备用。DNS 负责把域名转换为地址，分流规则再根据域名、规则集或 IP 判断连接方向。

```text
域名请求
   |
   v
DNS 解析
   |
   v
Shadowrocket 规则判断
   |                |
   v                v
DIRECT             PROXY
```

DNS 方案以实用和稳定为目标，并不保证在所有网络中得到完全相同的结果，也不构成对普遍防污染能力的承诺。

## 设计原则

### 简单

只使用少量职责清楚的组件：VPS、Hysteria2、TLS、Certbot、systemd 和 Shadowrocket。配置路径和管理命令保持明确。

### 可靠

使用 systemd 管理启动和异常恢复，使用 Certbot deploy hook 在证书更新后加载新证书，并提供状态检查脚本辅助验证。

### 可维护

把云平台准备、服务器配置、客户端规则、脚本和排错文档分开保存。修改某一层时尽量不影响其他层。

### 可复现

公开模板只保留 `YOUR_DOMAIN`、`YOUR_SERVER_IP`、`YOUR_PASSWORD` 和 `YOUR_EMAIL` 等占位符。真实部署信息只存在于用户自己的私有环境中。

### 安全

使用 TLS，限制 SSH 和防火墙访问，为云平台账户启用 MFA，并且不把私钥、证书、密码或云平台凭据提交到仓库。

## 相关文档

- [中文项目主页](../../README_CN.md)
- [中文 VPS 部署指南](vps-deployment.md)
- [中文故障排查指南](troubleshooting.md)
- [English architecture guide](../architecture.md)
