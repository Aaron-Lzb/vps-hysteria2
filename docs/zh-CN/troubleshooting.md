# 故障排查指南

[English](../troubleshooting.md) | 简体中文

## 排查原则

遇到连接问题时，建议从底层到上层逐步确认：

```text
客户端
  |
  v
当前网络
  |
  v
云防火墙 / 主机防火墙
  |
  v
VPS 与 UDP 443
  |
  v
Hysteria2 服务
  |
  v
TLS 与认证配置
  |
  v
客户端配置或分流规则
```

不要一次修改多个参数，否则很难判断哪一项才是真正原因。先收集状态和日志，再针对证据进行修改。

## 部署检查清单

- [ ] `YOUR_DOMAIN` 能正确解析到 VPS
- [ ] 云平台防火墙允许 UDP 443
- [ ] VPS 主机防火墙允许 UDP 443
- [ ] Hysteria2 服务处于 active (running)
- [ ] 服务器正在监听 UDP 443
- [ ] TLS 证书有效并包含 `YOUR_DOMAIN`
- [ ] 客户端密码与服务器的 `YOUR_PASSWORD` 完全一致
- [ ] 客户端节点域名、端口和 TLS/SNI 正确

先运行只读状态检查：

```bash
bash scripts/check-status.sh YOUR_DOMAIN
```

它以只读方式检查 systemd 服务、本机 UDP 443 监听、配置所用 TLS 证书的剩余时间、Certbot 续期定时器、Ubuntu 安全更新、重启标记、根文件系统用量、系统版本、已安装的 Hysteria2 版本，以及可选的 DNS 解析。它不会修复、续期、更新、重启或修改服务器。无需 root 权限；如果证书或 systemd 信息不可读，可使用 `sudo` 重新运行。

`HEALTHY` 的退出状态为 0，`ATTENTION REQUIRED` 和 `CRITICAL` 的退出状态为 1。UDP 结果只检查本机套接字；还需要确认云平台与主机防火墙规则，并从客户端测试，才能证明端到端可达。

## 1. Hysteria2 服务启动失败

### 现象

```text
Active: failed
```

### 检查服务状态

```bash
sudo systemctl status hysteria-server
```

状态输出通常会显示退出码和最近几行日志。

### 查看实时日志

```bash
sudo journalctl -u hysteria-server -f
```

如果服务不断自动重启，可先用状态命令查看完整错误，不要只观察连接结果。

### 常见原因

- `/etc/hysteria/config.yaml` 的 YAML 缩进错误
- 配置项名称或格式不正确
- TLS 证书路径不存在
- Hysteria2 无法读取证书或私钥
- UDP 443 已被其他进程占用
- Hysteria2 可执行文件路径不正确

检查配置文件：

```bash
sudo nano /etc/hysteria/config.yaml
```

检查监听端口：

```bash
sudo ss -ulnp | grep 443
```

修改后重新启动并再次查看状态：

```bash
sudo systemctl restart hysteria-server
sudo systemctl status hysteria-server
```

## 2. TLS 证书权限不足

### 现象

日志出现类似内容：

```text
tls.cert:
permission denied
```

### 原因

Let's Encrypt 证书通常位于：

```text
/etc/letsencrypt/live/
```

`live` 目录中的文件通常还会链接到 Certbot 管理的其他目录。服务运行用户如果没有读取这些目录和私钥的权限，Hysteria2 就无法启动 TLS。

本项目的 systemd 示例明确使用：

```ini
[Service]
User=root
```

这是当前架构中的技术选择，用于读取 Certbot 证书并绑定服务端口。不要只修改 `User=` 而忽略证书目录权限和进程能力。

### 检查方法

查看服务文件：

```bash
sudo systemctl cat hysteria-server
```

查看 Certbot 已知证书：

```bash
sudo certbot certificates
```

如果服务文件已经按照项目示例配置，重新加载 systemd 后重启：

```bash
sudo systemctl daemon-reload
sudo systemctl restart hysteria-server
sudo systemctl status hysteria-server
```

不要为了临时解决权限问题而把 TLS 私钥设置为所有用户可读。

## 3. 客户端连接超时

连接超时可能发生在域名解析、客户端网络、云防火墙、主机防火墙、UDP 443、服务监听或 TLS 等多个位置。

### 第一步：确认域名

```bash
dig YOUR_DOMAIN
```

确认解析结果对应当前 VPS。若刚修改 DNS，等待传播后再测试。

### 第二步：确认服务与端口

```bash
sudo systemctl status hysteria-server
sudo ss -ulnp | grep 443
```

预期服务为 active (running)，并且存在 UDP 443 监听。

### 第三步：观察 UDP 数据包

在 VPS 上运行：

```bash
sudo tcpdump -i any -n udp port 443
```

然后在客户端中重新发起连接。

如果完全看不到数据包，优先检查：

- 客户端中的域名和端口
- 客户端当前 Wi-Fi 或移动网络是否允许 UDP
- 域名是否解析到正确 VPS
- AWS Security Group 或其他云防火墙是否允许 UDP 443
- VPS 内部防火墙是否允许 UDP 443

如果能看到双向数据包：

```text
Client -> Server
Server -> Client
```

这通常说明客户端与服务器之间的基本网络路径和 UDP 443 已经可以双向传输。接下来重点检查：

- 客户端与服务端的认证密码
- TLS 证书是否有效、域名是否匹配
- Hysteria2 服务日志中的握手或认证错误

双向数据包只是网络路径正常的重要证据，不代表认证、TLS 或完整代理访问一定成功。

### 第四步：查看 Hysteria2 日志

```bash
sudo journalctl -u hysteria-server -f
```

在日志窗口保持打开的同时重试客户端连接，观察是否出现 TLS、认证或配置错误。

## 4. 密码不匹配

### 现象

UDP 数据包能够到达服务器，但服务端拒绝认证或客户端仍无法建立连接。

### 服务端配置

```yaml
auth:
  type: password
  password: YOUR_PASSWORD
```

客户端中的密码必须与 `YOUR_PASSWORD` 替换后的真实值完全一致。

检查以下细节：

- 大小写必须一致
- 开头和结尾不能多空格
- 修改服务器密码后，客户端也要同步更新
- 客户端不应继续使用旧节点或缓存的旧密码
- 不要把真实密码粘贴到公开问题、日志或仓库

修改服务端配置后重启服务：

```bash
sudo systemctl restart hysteria-server
sudo systemctl status hysteria-server
```

## 5. TLS 证书问题

### 查看证书

```bash
sudo certbot certificates
```

确认：

- 证书状态有效
- 域名列表包含 `YOUR_DOMAIN`
- 配置中的证书和私钥路径与 Certbot 输出对应
- 证书没有过期

配置路径示例：

```yaml
tls:
  cert: /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem
```

客户端连接的服务器名称和 TLS/SNI 名称应与证书域名一致。

## 6. 证书续期

测试 Certbot 续期：

```bash
sudo certbot renew --dry-run
```

如果 dry run 失败，优先检查：

- 域名是否仍指向当前 VPS
- 当前验证方式要求的端口是否可达
- 是否有其他服务占用验证端口
- Certbot 输出的具体错误

项目 deploy hook 的安装路径示例：

```text
/etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
```

安装命令：

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh \
  /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
```

正式续期成功后的流程：

```text
Certbot 续期成功
       |
       v
执行 deploy hook
       |
       v
重启 hysteria-server
       |
       v
Hysteria2 读取新证书
```

如果续期成功但服务重启失败，检查：

```bash
sudo systemctl status hysteria-server
sudo journalctl -u hysteria-server -f
```

## 7. 云防火墙与主机防火墙

AWS 参考环境中的关键规则是 UDP 443。其他平台也必须创建等价规则。

| 协议 | 端口 | 作用 |
| --- | --- | --- |
| TCP | 22 | SSH 管理 |
| TCP | 80 | Certbot HTTP-01 验证，按需 |
| TCP | 443 | HTTPS 兼容或其他服务，按需 |
| UDP | 443 | Hysteria2，关键 |

云防火墙允许流量并不代表 VPS 内部防火墙一定允许。排查时要分别检查两层。

不要因为连接超时就把所有管理端口永久开放给整个 Internet。SSH 应尽量限制为可信来源。

## 8. 客户端分流异常

如果客户端支持规则分流，并且节点能够连接，但某些网站没有按照预期走 DIRECT 或 PROXY：

- 确认已经启用正确的配置模式
- 确认当前选中的代理节点是目标 Hysteria2 节点
- 检查规则顺序，靠前的匹配会先执行
- 检查远程规则集是否可以访问和更新
- 检查域名解析结果是否影响 GEOIP 或规则判断
- 临时记录具体目标域名，判断它命中了哪一条规则

Shadowrocket 示例保持：

```text
局域网和中国大陆流量 -> DIRECT
其他流量             -> PROXY
```

这套分流是 Shadowrocket 客户端专用示例，不是 Hysteria2 服务端行为，也不能默认直接用于其他客户端。详见 [Shadowrocket 客户端配置](clients/shadowrocket.md)。

## 9. 常用诊断命令

```bash
# 服务状态
sudo systemctl status hysteria-server

# 实时日志
sudo journalctl -u hysteria-server -f

# UDP 443 监听
sudo ss -ulnp | grep 443

# UDP 443 抓包
sudo tcpdump -i any -n udp port 443

# 证书信息
sudo certbot certificates

# 续期测试
sudo certbot renew --dry-run

# 域名解析
dig YOUR_DOMAIN

# 项目综合检查
bash scripts/check-status.sh YOUR_DOMAIN
```

## 10. 安全检查清单

- [ ] 没有把 SSH 私钥或 TLS 私钥上传到仓库
- [ ] 没有提交真实密码、证书、云平台凭据、个人域名或服务器公网地址
- [ ] 公开示例只使用 `YOUR_DOMAIN`、`YOUR_SERVER_IP`、`YOUR_PASSWORD` 和 `YOUR_EMAIL`
- [ ] SSH 只允许可信来源
- [ ] VPS 提供商账户已启用 MFA
- [ ] 不再需要的端口已经从防火墙规则中移除
- [ ] Ubuntu、Hysteria2 和 Certbot 有正常维护计划

## 相关文档

- [中文项目主页](../../README_CN.md)
- [中文系统架构](architecture.md)
- [中文 VPS 部署指南](vps-deployment.md)
- [English troubleshooting guide](../troubleshooting.md)
