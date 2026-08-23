# 零基础使用说明：搭建个人 Hysteria2 节点

这份说明面向没有编程经验、第一次接触 VPS 的用户。只要能够购买云服务器和域名，并能复制、粘贴命令，就可以按顺序完成部署。

> **先说明用途：**本项目搭建的是一台自用 Hysteria2 加密代理服务器，日常口语中有人把它叫作“VPN 节点”或“机场节点”，但它不是传统的全网 VPN，也不是商业机场管理系统。项目不包含用户注册、多人账号、订阅链接、套餐、流量统计、支付、客服或防滥用功能。请只在当地法律法规和服务商条款允许的范围内使用。

## 一、你最终会得到什么

完成后，网络路径大致如下：

```text
iPhone / iPad 上的 Shadowrocket
              |
              | Hysteria2 加密连接（UDP 443）
              v
        你的 Ubuntu VPS
              |
              v
           互联网
```

你需要自己保管四项信息：

| 信息 | 示例 | 用途 |
| --- | --- | --- |
| VPS 公网 IP | `203.0.113.10` | 域名指向服务器 |
| 域名 | `vpn.example.com` | TLS 证书和客户端服务器地址 |
| Hysteria2 密码 | 一串随机字符 | 客户端身份验证 |
| SSH 私钥或登录密码 | 由 VPS 商家提供 | 管理服务器 |

示例中的地址和域名不能直接使用，必须换成你自己的。

## 二、开始前准备

请准备：

- 一台安装 **Ubuntu 22.04 LTS 或 Ubuntu 24.04 LTS** 的 VPS；
- 一个自己可以修改 DNS 记录的域名；
- 一台可以通过 SSH 登录 VPS 的电脑；
- iPhone 或 iPad 上已安装、且当前版本支持 Hysteria2 的 Shadowrocket；
- 大约 30～60 分钟操作时间。

购买 VPS 时不必追求高配置。个人轻量使用通常更看重线路、流量额度和 UDP 支持。购买前务必确认服务商允许入站 UDP 流量，并查看带宽、流量和公网 IP 的费用。

## 三、约定自己的信息

下面所有命令都使用这些占位符：

| 占位符 | 你要替换成 |
| --- | --- |
| `YOUR_SERVER_IP` | VPS 的公网 IPv4 地址 |
| `YOUR_DOMAIN` | 你准备使用的完整域名，例如 `vpn.example.com` |
| `YOUR_EMAIL` | 接收证书通知的邮箱 |
| `YOUR_PASSWORD` | 你生成的 Hysteria2 随机密码 |

建议先把自己的四项内容写在私人备忘录里。不要把真实密码、SSH 私钥或完整客户端配置发到公开论坛。

## 四、创建 VPS 并设置防火墙

在 VPS 商家的控制台创建服务器：

1. 系统选择 Ubuntu 22.04 LTS 或 24.04 LTS。
2. 保存系统显示的公网 IP。
3. 保存 SSH 登录用户名和私钥。Ubuntu 镜像的用户名常见为 `ubuntu` 或 `root`，以商家说明为准。
4. 在商家的“防火墙”“安全组”或“入站规则”中添加下表规则。

| 协议 | 端口 | 来源 | 说明 |
| --- | --- | --- | --- |
| TCP | 22 | 最好只允许你当前的公网 IP | SSH 登录服务器 |
| TCP | 80 | `0.0.0.0/0` | 申请和续期 TLS 证书 |
| UDP | 443 | `0.0.0.0/0` | Hysteria2 的核心通信端口 |

注意：Hysteria2 使用的是 **UDP 443**。只开放 TCP 443 没有作用。TCP 22 不建议长期向全世界开放。

## 五、让域名指向 VPS

进入域名商的 DNS 管理页面，新建一条 A 记录。

例如，你拥有 `example.com`，希望使用 `vpn.example.com`：

| DNS 字段 | 填写内容 |
| --- | --- |
| 类型 | `A` |
| 主机记录 / 名称 | `vpn` |
| 记录值 / 内容 | 你的 `YOUR_SERVER_IP` |
| TTL | 默认值 |

保存后等待 DNS 生效，通常需要几分钟，也可能更久。在电脑终端中检查：

```bash
nslookup YOUR_DOMAIN
```

返回的地址必须与 `YOUR_SERVER_IP` 相同。不同就先等待或修正 DNS，不要继续申请证书。

如果 DNS 服务商提供“代理”“CDN”或“小云朵”开关，请先设为 **仅 DNS / DNS only**，不要让普通 HTTP CDN 代理这个记录。

## 六、登录服务器

### macOS 或 Linux

打开“终端”。如果商家给的是密码，通常可以输入：

```bash
ssh ubuntu@YOUR_SERVER_IP
```

如果用户名是 `root`，把 `ubuntu` 改成 `root`。

如果商家给的是私钥文件，按照商家提供的 SSH 教程连接。第一次连接出现是否信任主机的提示时，核对 IP 后输入 `yes`。

### Windows

打开 Windows Terminal 或 PowerShell，使用同样的 `ssh` 命令。也可以直接使用 VPS 商家网页里的“远程连接”或“Web SSH”。

登录成功后，你会看到类似 `ubuntu@服务器名:~$` 的提示符。后续命令都在这个服务器窗口内执行。

## 七、下载项目并安装 Hysteria2

依次复制并执行下面三条命令。每输入一条就按一次回车，并等待它执行完成。

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/Aaron-Lzb/vps-hysteria2.git
```

进入项目目录并运行安装脚本：

```bash
cd vps-hysteria2
sudo bash scripts/install-hysteria.sh
```

脚本会安装 Hysteria2、Certbot 和状态检查工具。安装结束出现 `Installation preparation completed.` 表示安装准备完成；服务此时还没有正式启动，这是正常的。

如果出现红色 `ERROR`，不要反复重装。先复制错误文字，对照本文“常见问题”检查。

## 八、申请 TLS 证书

确认域名已经正确指向 VPS，并且云防火墙已开放 TCP 80，然后运行：

```bash
sudo certbot certonly --standalone --preferred-challenges http -d YOUR_DOMAIN -m YOUR_EMAIL --agree-tos --no-eff-email
```

一定要先把命令中的 `YOUR_DOMAIN` 和 `YOUR_EMAIL` 换成真实内容。

看到 `Successfully received certificate` 表示成功。再运行：

```bash
sudo certbot certificates
```

输出中应显示你的域名，以及类似下面的证书路径：

```text
/etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
/etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem
```

`privkey.pem` 是服务器私钥，绝不能下载后公开分享。

## 九、生成密码并填写服务端配置

生成一个只用于此节点的随机密码：

```bash
openssl rand -hex 24
```

终端会显示一串 48 位字符。把它复制到私人备忘录，这就是后面所说的 `YOUR_PASSWORD`。

复制项目的配置模板：

```bash
sudo cp configs/hysteria/config.example.yaml /etc/hysteria/config.yaml
```

打开配置文件：

```bash
sudo nano /etc/hysteria/config.yaml
```

在编辑器里只做两种替换：

1. 把文件中两处 `YOUR_DOMAIN` 都换成你的真实域名；
2. 把一处 `YOUR_PASSWORD` 换成刚生成的随机密码。

不要修改缩进，也不要删除冒号。完成后：

1. 按 `Ctrl + O` 保存；
2. 按回车确认文件名；
3. 按 `Ctrl + X` 退出。

检查是否还有忘记替换的占位符：

```bash
sudo grep -n 'YOUR_' /etc/hysteria/config.yaml
```

如果这条命令没有任何输出，说明占位符已经全部替换。如果还有输出，重新打开文件修改。

## 十、启动服务并检查

运行：

```bash
sudo systemctl enable --now hysteria-server
sudo systemctl status hysteria-server --no-pager
```

看到绿色或文字形式的 `active (running)` 就表示服务已启动。按以下命令运行项目自带的完整检查：

```bash
sudo hysteria-check
```

理想结果包含：

- 服务为 active；
- 本机正在监听 UDP 443；
- TLS 证书有效；
- Certbot 自动续期定时器正常。

状态检查只能证明服务器本机大致正常，云防火墙和手机到服务器的完整连接仍需要实际测试。

## 十一、设置证书自动续期

仍在项目目录内执行：

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
sudo certbot renew --dry-run
```

第二条命令成功表示自动续期流程可以工作。以后证书续期成功时，Hysteria2 会自动重启并读取新证书。

## 十二、在 Shadowrocket 中添加节点

打开 Shadowrocket，点击右上角 `+` 新增节点。不同版本的界面名称可能略有差别，但必须填写以下内容：

| Shadowrocket 字段 | 填写内容 |
| --- | --- |
| 类型 | `Hysteria2` |
| 地址 / 服务器 | 你的 `YOUR_DOMAIN`，不要填 `https://` |
| 端口 | `443` |
| 密码 | 与服务器完全相同的 `YOUR_PASSWORD` |
| SNI / Server Name / TLS 域名 | 你的 `YOUR_DOMAIN` |
| 跳过证书验证 / Allow Insecure | 关闭 |

保存节点，选中它，然后打开 Shadowrocket 的连接开关。iOS 第一次会请求添加 VPN 配置，按系统提示允许。

先使用 Shadowrocket 自带的连通性测试。确认节点可用后，再按[Shadowrocket 分流说明](clients/shadowrocket.md)导入项目的分流配置。建议先测试节点，再配置分流，这样出现问题时更容易判断原因。

## 十三、最常用的维护命令

以后通过 SSH 登录 VPS 后，可以使用：

```bash
# 查看整体健康状态，不会修改服务器
sudo hysteria-check

# 查看服务是否运行
sudo systemctl status hysteria-server --no-pager

# 修改配置后重启服务
sudo systemctl restart hysteria-server

# 查看最近 100 行日志
sudo journalctl -u hysteria-server -n 100 --no-pager

# 测试证书续期
sudo certbot renew --dry-run
```

`sudo hysteria-update` 只更新本项目的状态检查工具，不会更新 Hysteria2 本体、Ubuntu 或配置文件。

建议至少每月登录一次，运行 `sudo hysteria-check`，并查看 VPS 商家的流量和账单告警。

## 十四、常见问题

### 1. Certbot 申请证书失败

依次确认：

- 域名解析结果是否等于 VPS 公网 IP；
- 云防火墙是否开放 **TCP 80**；
- DNS 记录是否处于“仅 DNS”模式；
- 是否输错域名或邮箱；
- 是否刚修改 DNS，仍需等待生效。

### 2. 服务不是 active (running)

查看错误日志：

```bash
sudo journalctl -u hysteria-server -n 100 --no-pager
```

最常见原因是域名没有替换完整、证书路径错误、密码所在行的格式被改坏，或 UDP 443 被其他程序占用。

### 3. Shadowrocket 一直超时

依次确认：

- 云防火墙开放的是 **UDP 443**，不是只有 TCP 443；
- Shadowrocket 节点类型确实是 Hysteria2；
- 地址只填域名，没有加 `http://` 或 `https://`；
- 端口是 `443`；
- 密码和 SNI 与服务器完全一致；
- 换一个 Wi-Fi 或移动网络测试，排除当前网络阻止 UDP。

### 4. 提示认证失败

客户端密码与 `/etc/hysteria/config.yaml` 中的密码不一致。修改任意一端后，都要保持另一端一致；修改服务器配置后还要执行：

```bash
sudo systemctl restart hysteria-server
```

### 5. 还没有解决

按[详细故障排查指南](troubleshooting.md)逐项检查。求助时可以提供去除域名、IP 和密码后的错误日志，但不要公开服务器密码、SSH 私钥、TLS 私钥或完整节点链接。

## 十五、安全和使用边界

- 这不是匿名保证。VPS 商家仍可看到服务器账号和流量元数据，访问目标也可能看到 VPS 的公网 IP。
- 一台服务器共用一个密码只适合自己或可信的小范围使用。密码泄露后应立即更换，并重启服务。
- 不要把节点公开分享。公开节点容易被滥用、耗尽流量、产生额外费用或导致 VPS 被封禁。
- 为 VPS 和域名账户启用双重验证，设置账单和流量告警。
- 定期更新 Ubuntu、Hysteria2 和客户端，并检查证书续期。
- 如果目标是经营多人商业“机场”，还需要单独设计用户隔离、订阅、限速、流量计费、支付、审计、防滥用、隐私政策、日志策略和合规流程；本项目没有实现这些能力。

完成以上步骤后，你已经拥有一个可由 Shadowrocket 连接的个人 Hysteria2 节点。
