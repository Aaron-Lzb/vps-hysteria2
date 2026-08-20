# VPS 部署指南

[English AWS reference](../aws-deployment.md) | 简体中文

## 说明

本文以 AWS EC2 作为已经测试的参考环境，面向第一次部署 VPS 服务的用户。AWS 不是必需条件；使用其他 Linux VPS 时，可以把 Security Group、Elastic IP 等名称替换为该平台对应的云防火墙和静态公网 IP 产品。

部署的核心条件始终是：

- Ubuntu 22.04 或 24.04
- 可通过 SSH 管理服务器
- 域名指向服务器公网地址
- 云防火墙允许 UDP 443
- Hysteria2 能读取有效 TLS 证书
- 客户端中的域名、端口、密码和 TLS/SNI 与服务端一致

## 1. 创建 VPS

在 AWS 控制台进入 EC2，创建一个新实例。选择离主要使用地点、预算和合规要求都合适的区域。

参考选择：

| 项目 | 建议 |
| --- | --- |
| 操作系统 | Ubuntu 22.04 LTS 或 Ubuntu 24.04 LTS |
| 实例类型 | `t3.micro` 或根据实际流量选择其他规格 |
| 磁盘 | 基础部署使用默认 EBS 容量即可 |
| 登录方式 | 创建或选择 SSH 密钥，并安全保存私钥 |

Hysteria2 对磁盘需求通常不高，但云平台的公网 IPv4、带宽和流量费用会因区域及套餐不同而变化。创建资源前应查看当前定价并设置账单提醒。

## 2. 确认 Ubuntu

本项目安装脚本会检测 Ubuntu，并对 Ubuntu 22.04 与 24.04 提供明确的已测试提示。登录服务器后可以查看：

```bash
cat /etc/os-release
```

不要把针对其他 Linux 发行版的命令直接套用到本项目安装脚本。

## 3. 配置 Security Group / 云防火墙

Security Group 是 AWS 在实例网络入口处提供的防火墙。其他云平台可能称为 Cloud Firewall、Firewall Rules 或安全组。

参考端口表：

| 协议 | 端口 | 用途 | 建议 |
| --- | --- | --- | --- |
| TCP | 22 | SSH 管理 | 只允许可信管理员地址或网络 |
| TCP | 80 | Certbot HTTP-01 验证 | 申请或续期方式需要时开放 |
| TCP | 443 | HTTPS 兼容或其他服务 | Hysteria2 的 UDP 监听本身不依赖此端口，按实际需要开放 |
| UDP | 443 | Hysteria2 客户端流量 | **核心端口，必须正确配置** |

Hysteria2 在本项目中使用的是 **UDP 443**，不是 TCP 443。只开放 TCP 443 而遗漏 UDP 443，会导致兼容客户端无法建立 Hysteria2 连接。

如果客户端经常在移动网络和不同 Wi-Fi 之间切换，UDP 443 的来源范围可能需要覆盖这些网络。此时应确保密码足够强，并持续维护服务器。SSH 的 TCP 22 不应因此对所有来源开放。

还要检查 VPS 内部是否启用了 UFW 或其他主机防火墙。云防火墙和主机防火墙中的任意一层阻止 UDP 443，客户端都会超时。

## 4. 配置静态公网 IP / Elastic IP

EC2 自动分配的公网地址可能在实例停止并重新启动后变化。Elastic IP 是 AWS 的稳定公网地址产品。

参考流程：

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

其他 VPS 提供商可能称为 Reserved IP 或 Static IP。无论名称是什么，目的都是让 `YOUR_DOMAIN` 不会因为服务器生命周期操作而频繁修改。

公网 IPv4 可能产生费用，应查看提供商当前的计费说明。不再使用时及时释放资源。

## 5. 配置域名 A 记录

在域名的 DNS 管理页面添加 A 记录：

```text
类型：A
名称：YOUR_DOMAIN 对应的主机部分
值：  YOUR_SERVER_IP
```

结果应当是：

```text
YOUR_DOMAIN
     |
     v
YOUR_SERVER_IP
     |
     v
VPS
```

检查解析：

```bash
dig YOUR_DOMAIN
```

确认返回的地址与 VPS 控制台显示的一致。DNS 传播可能需要时间，在解析正确前不要急于申请证书。

## 6. 通过 SSH 连接

AWS Ubuntu 镜像常用用户名是 `ubuntu`：

```bash
ssh ubuntu@YOUR_SERVER_IP
```

如果需要指定本地私钥文件，可使用 SSH 的 `-i` 参数。私钥只应保存在可信设备中，绝不能复制到公开仓库。

登录后更新软件包元数据：

```bash
sudo apt-get update
```

对已有服务器执行系统升级前，应先查看待更新软件包并安排维护时间：

```bash
sudo apt-get upgrade
```

## 7. 获取项目并安装 Hysteria2

在服务器上获取可信的项目副本并进入仓库目录，然后执行：

```bash
sudo bash scripts/install-hysteria.sh
```

安装脚本会：

- 检查是否具有 root 权限
- 检测 Ubuntu 系统和已测试版本
- 安装 Certbot、DNS 和端口检查所需工具
- 从 Hysteria2 上游下载安装程序
- 准备 `/etc/hysteria/`
- 仅在 systemd 服务文件不存在时创建服务文件
- 保留已有 `/etc/hysteria/config.yaml` 和 systemd 服务文件

脚本不会自动替换 `YOUR_DOMAIN` 或 `YOUR_PASSWORD`，也不会替你启动尚未检查的配置。

注意：Hysteria2 上游安装程序仍在运行时通过网络下载。应从可信仓库和网络环境执行脚本，并在生产环境中考虑自己的版本固定与供应链审查策略。

## 8. 使用 Certbot 申请 TLS 证书

申请证书前确认：

- `YOUR_DOMAIN` 已解析到当前 VPS
- TCP 80 可到达 VPS（使用 HTTP-01 standalone 方法时）
- 没有其他服务占用所需验证端口
- 已准备接收续期通知的 `YOUR_EMAIL`

一种常见的 standalone 示例是：

```bash
sudo certbot certonly --standalone \
  --preferred-challenges http \
  -d YOUR_DOMAIN \
  -m YOUR_EMAIL \
  --agree-tos \
  --no-eff-email
```

签发成功后检查：

```bash
sudo certbot certificates
```

项目配置使用以下文件：

```text
/etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
/etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem
```

`privkey.pem` 是 TLS 私钥，不能上传、分享或提交到仓库。

## 9. 配置 Hysteria2

服务器示例位于：

```text
configs/hysteria/config.example.yaml
```

如果服务器已经存在 `/etc/hysteria/config.yaml`，先检查并备份自己的配置，不要无提示覆盖。首次部署时，把示例复制到目标位置，然后只在服务器私有副本中替换占位符：

```text
YOUR_DOMAIN
YOUR_PASSWORD
```

核心配置应保持与项目示例一致：

```yaml
listen: :443

tls:
  cert: /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem

auth:
  type: password
  password: YOUR_PASSWORD
```

选择一个足够强且只用于此部署的密码。不要把填写真实信息后的配置提交到 Git。

## 10. 使用 systemd 管理服务

项目服务名为：

```text
hysteria-server
```

检查服务文件和配置后，重新加载并启动：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hysteria-server
sudo systemctl status hysteria-server
```

查看实时日志：

```bash
sudo journalctl -u hysteria-server -f
```

示例服务以 root 用户运行，以便读取 Certbot 管理的证书文件并绑定所需端口。不要随意改变服务用户；如果需要降权运行，必须重新设计证书权限和进程能力，并自行验证安全边界。

确认 UDP 443 正在监听：

```bash
sudo ss -ulnp | grep 443
```

## 11. 安装证书续期钩子

把仓库脚本安装到 Certbot deploy hook 目录：

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
```

测试证书续期：

```bash
sudo certbot renew --dry-run
```

正式续期成功后，deploy hook 会重启 Hysteria2，让进程读取新证书。重启期间连接可能短暂中断。

## 12. 配置客户端

在明确支持 Hysteria2 的客户端中新增节点，至少确认：

| 客户端字段 | 应填写的内容 |
| --- | --- |
| 服务器 | `YOUR_DOMAIN` |
| 端口 | `443` |
| 密码 | 与服务器 `YOUR_PASSWORD` 完全一致 |
| TLS/SNI 名称 | `YOUR_DOMAIN`，具体界面名称随客户端和版本变化 |

客户端界面和配置语法不同，应使用当前版本的官方文档。不要把一种客户端的配置直接导入另一种客户端。

### Shadowrocket 示例

Shadowrocket 用户可以参考项目维护的客户端指南和配置：

```text
configs/shadowrocket/Hysteria2-Split-Routing.conf
```

当前分流逻辑：

```text
局域网和中国大陆流量 -> DIRECT
其他流量             -> PROXY
```

详见 [Shadowrocket 客户端配置](clients/shadowrocket.md)。如果字段名称与文档不同，应以当前客户端界面和 Hysteria2 节点类型为准，但服务器域名、UDP 443、TLS 名称和密码必须互相匹配。

### 其他客户端

Mihomo/Clash.Meta 兼容客户端可以在当前内核明确支持 Hysteria2 时使用对应的 `hysteria2` 代理类型。FlClash、Surge 或其他产品的能力取决于具体版本；本项目不提供未经验证的导入配置。

## 13. 完成部署检查

运行项目状态脚本：

```bash
hysteria-check
```

安装脚本会全局安装该命令，并通常自动检测公网 IPv4。自动检测失败时运行 `hysteria-check <PUBLIC_IP>`；证书权限导致 TLS 信息不可读时，可运行 `sudo hysteria-check`。

手工检查清单：

- [ ] `YOUR_DOMAIN` 解析到当前 VPS
- [ ] 云防火墙和主机防火墙允许 UDP 443
- [ ] `hysteria-server` 为 active (running)
- [ ] `ss` 显示 UDP 443 正在监听
- [ ] Certbot 显示证书有效且包含 `YOUR_DOMAIN`
- [ ] 客户端密码与服务器完全一致
- [ ] 客户端节点使用正确域名、端口和 TLS/SNI
- [ ] DIRECT 与 PROXY 流量分别符合预期

如果某一项失败，请按[中文故障排查指南](troubleshooting.md)逐层检查，不要同时修改多个无关参数。

## 安全检查

- 为 AWS 或其他 VPS 提供商账户启用 MFA。
- 把 SSH 来源限制为可信地址或网络。
- 不上传 SSH 私钥、TLS 私钥、证书、真实密码、云平台凭据、个人域名和服务器公网地址。
- 公共示例中只使用 `YOUR_DOMAIN`、`YOUR_SERVER_IP`、`YOUR_PASSWORD` 和 `YOUR_EMAIL`。
- 定期检查账单、资源使用、系统更新和证书状态。

## 相关文档

- [中文项目主页](../../README_CN.md)
- [中文系统架构](architecture.md)
- [中文故障排查](troubleshooting.md)
- [English AWS reference deployment](../aws-deployment.md)
