# 零基础使用说明：搭建个人 Hysteria2 节点

[English](../beginner-guide.md) | 简体中文

本指南从购买 VPS 和域名开始，不要求你已经会 Linux、DNS 或 SSH。按顺序完成一节、确认结果，再进入下一节；遇到错误先停在当前步骤。

> 本项目搭建的是自用 Hysteria2 加密代理服务器，日常也有人称它为“VPN 节点”，但它不是传统的全网 VPN 或商业“机场”管理系统。项目不包含用户注册、订阅、套餐、计费、支付或防滥用系统。请在当地法律和服务商条款允许的范围内使用。

快速定位：[VPS 与防火墙](#四创建-vps-并设置防火墙) · [域名与 DNS](#五购买域名并设置-dns) · [SSH](#六第一次通过-ssh-登录) · [安装](#七下载项目并安装-hysteria2) · [客户端](#十二选择并配置客户端) · [排错](#十四常见问题)。

## 一、你最终会得到什么

`兼容 Hysteria2 的客户端 → QUIC/TLS（UDP 443）→ Ubuntu VPS → 互联网`

服务器不依赖客户端的操作系统或品牌；iOS/iPadOS、macOS、Android、Windows 和 Linux 上的兼容客户端原则上都可以连接。本文服务端安装脚本仍要求 Ubuntu；“客户端中立”不表示安装脚本可以在任意系统上运行。

按顺序完成：选购 VPS → 公网 IP 和防火墙 → 购买域名及设置 DNS → SSH 登录 → 安装、证书和配置 → 服务检查 → 客户端连接。

## 二、开始前准备

准备一台能打开浏览器和终端的电脑、可用邮箱和支付方式。后面的步骤会带你获得 Ubuntu VPS、域名及 SSH 登录信息。客户端可以稍后安装，不要求有 Apple 设备。

VPS 是你租用的一台一直联网的远程电脑；域名是便于记忆的名称；DNS 把名称映射到服务器 IP；SSH 是从本机终端管理远程电脑的连接方式。VPS、域名通常分别收费，DNS 托管则取决于所选服务。

本教程采用公网 IPv4 和域名证书。不要购买只有 IPv6、共享 NAT 且没有 UDP 443 映射、或禁止所需代理用途的套餐。购买前检查：

- 是否提供 Ubuntu 22.04 LTS 或 24.04 LTS、管理员权限和入站 UDP；
- 地区是否适合你的使用位置与预算，是否提供测试地址或短期套餐；地理距离近不保证线路质量；
- 月流量、带宽、超额流量、磁盘和公网 IPv4 如何收费；
- 是否提供固定或保留 IP、网页救援控制台及清晰的取消规则。

AWS EC2 是项目原始测试参考，也可以选其他满足条件的 Linux VPS 服务商。不要默认任何套餐免费。个人首次部署可从基础规格开始，观察实际资源使用后再调整。

## 三、约定自己的信息

| 占位符 | 你要替换成 |
| --- | --- |
| `YOUR_SERVER_IP` | VPS 控制台显示的公网 IPv4 |
| `YOUR_DOMAIN` | 准备用于节点的完整域名 |
| `YOUR_EMAIL` | 证书注册时使用的邮箱 |
| `YOUR_PASSWORD` | 后面生成的 Hysteria2 随机密码 |
| `YOUR_SSH_KEY.pem` | 下载到自己电脑的 SSH 私钥文件名 |
| `YOUR_ADMIN_IP` | 你当前电脑所在网络的公网 IPv4，用于 SSH 防火墙来源 |

把这些值保存在私人备忘录。命令中的占位符不能原样执行；不要连同终端提示符或代码块标记一起复制。SSH 私钥或系统登录密码与 Hysteria2 密码是不同的凭据。

“本机终端”指你的电脑；“服务器终端”指 SSH 登录后的窗口。每条命令按回车执行，等提示符重新出现再继续。后面用到的 `sudo` 表示以管理员权限执行；输入密码时没有星号或文字回显是正常的。

## 四、创建 VPS 并设置防火墙

### 通用创建流程（在浏览器中的 VPS 控制台操作）

1. 注册账号，完成邮箱及支付验证，启用 MFA，设置预算和流量提醒。
2. 点击创建服务器或实例，选择地区、Ubuntu 22.04/24.04 LTS、规格和磁盘；确认公网 IPv4 已包含或可以绑定。
3. 按页面要求创建/选择 SSH 密钥并保存私钥；若提供系统密码则妥善保存。记录登录用户名，以镜像说明为准。
4. 核对预计费用后创建，等待状态为运行中且检查通过。
5. 在实例详情的网络或地址栏复制“公网 IPv4”，记为 `YOUR_SERVER_IP`。不要用私有 IP、实例 ID 或自己的电脑 IP。

私网地址用于云内部通信，不能直接让外部客户端找到服务器。固定公网 IP 能保持 DNS 指向稳定；如果地址改变，必须更新 A 记录并等待缓存过期。

### AWS EC2 详细示例

在 AWS 控制台选择地区，进入 **EC2 → Instances → Launch instances**：

1. 输入便于识别的名称；在镜像中选择 Canonical 的 Ubuntu 22.04/24.04 LTS，不要误选 Amazon Linux。
2. 选择与镜像架构匹配的基础实例规格，例如 x86_64 Ubuntu 对应的 `t3.micro`；核对当前费用与磁盘容量。
3. 在 **Key pair (login)** 创建密钥，选择 RSA、`.pem`，下载并保存到自己电脑。不要跳过密钥，也不要上传到仓库。
4. 在 **Network settings** 选可访问公网的 VPC/子网并启用自动分配公网 IPv4；默认 VPC 不存在时，先按 AWS 的 VPC 创建向导建立带 Internet Gateway 公网路由的网络。不要把实例放到只有私网连接的子网。
5. 创建安全组，按下表配置；核对配置后启动，等待状态和检查通过。
6. 选中实例，在详情中找到 **Public IPv4 address**；**Connect → SSH client** 会显示对应私钥文件和连接命令，Ubuntu 用户名通常为 `ubuntu`。

官方步骤见 [EC2 创建与连接](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html)。控制台标签可能变化，以字段含义为准。

需要固定地址时，在同一地区进入 **EC2 → Elastic IPs → Allocate → Associate**，把地址关联到刚创建的实例；再次复制新的公网 IPv4，后续 DNS 和 SSH 都用它。Elastic IP 和公网 IPv4 可能收费，闲置也应检查账单。见 [Elastic IP 官方说明](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)。

AWS 的普通 **Reboot** 会保留公网 IPv4；**Stop 后 Start** 的自动公网 IPv4 通常会改变，Elastic IP 可保持地址稳定。其他服务商规则可能不同。见 [EC2 生命周期](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html)。

### 配置入站端口

Security Group 是 AWS 的云防火墙；其他平台可能叫 Firewall 或安全组。规则必须关联到你的实例。

| 协议 | 端口 | 来源 | 用途 |
| --- | --- | --- | --- |
| TCP | 22 | `YOUR_ADMIN_IP/32`，或控制台的 My IP | SSH；换网络后更新来源 |
| TCP | 80 | `0.0.0.0/0` | 本教程的 HTTP-01 证书申请和自动续期 |
| UDP | 443 | `0.0.0.0/0`，或已知客户端网段 | Hysteria2 连接 |

`/32` 表示单个 IPv4；`0.0.0.0/0` 表示所有 IPv4 来源，不是要填入 DNS 的服务器地址。TCP 443 不能替代 UDP 443；本教程没有其他 HTTPS 服务时不需要额外开放 TCP 443。保留正常出站网络访问，以便下载安装包、DNS 查询和访问目标。

服务器内部可能还有 UFW 等防火墙，SSH 登录后再按第六节检查。开放云端规则不等于内部防火墙自动开放。TCP 80 不能在证书申请后永久关闭，否则这个 standalone 续期方案会失败。见 [Let's Encrypt HTTP-01](https://letsencrypt.org/docs/challenge-types/)。

完成标志：实例运行正常，公网 IPv4 已记录，三条入站规则已关联到实例。更详细的已有参考见 [VPS 部署指南](vps-deployment.md)。

## 五、购买域名并设置 DNS

### 为什么使用域名、在哪里买

本项目默认使用域名和 Certbot 证书，让客户端通过 TLS 验证连接的是你的服务器；域名本身不会转发代理流量。这是本教程的部署方式，不代表 Hysteria2 只有这一种证书方案。

在域名注册商官网注册账号，搜索可购买的名称，比较首年和续费价格，选择注册年限、填写联系信息并付款。完成邮箱验证，设置续费提醒或自动续费，并启用 MFA。无需额外购买网页空间、商业证书或邮箱套餐来完成本教程；如果已有可管理 DNS 的域名，可以直接使用其子域名。

Cloudflare Registrar 是一个例子，也可用其他注册商。Cloudflare 注册的域名要求使用它的权威 DNS；如果希望自由选择 DNS 托管商，在购买前确认注册商政策。见 [Cloudflare 域名注册](https://developers.cloudflare.com/registrar/get-started/register-domain/)。

### 找到真正生效的 DNS 管理处

域名注册商负责所有权和续费；DNS 托管商负责解析记录，可以是不同公司。最简单的是使用域名现有的 DNS 服务。

如果使用 Cloudflare 管理在别处购买的新域名：添加域名、选择合适计划、检查记录，然后在注册商的 Nameservers 页面填入 Cloudflare 分配的名称服务器，等待 Cloudflare 显示 Active。已有网站或邮箱的域名需要先保留全部现有记录，按官方迁移步骤处理 DNSSEC；不要直接清空记录。仅在 Cloudflare 添加 A 记录、却没有切换到它的名称服务器，不会使该记录生效。见 [名称服务器设置](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/)。

### 添加 A 记录（在 DNS 控制台操作）

进入域名的 **DNS → Records → Add record**。可以选一个专用子域名，如主机名 `vpn`；它与购买的根域名组合后的完整名称就是 `YOUR_DOMAIN`，无需单独购买子域名。

| 字段 | 填写内容 |
| --- | --- |
| Type / 类型 | `A`，表示映射到 IPv4 |
| Name / 名称 | `YOUR_DOMAIN` 的主机部分，例如 `vpn`；根域名通常填 `@` |
| IPv4 address / 内容 | `YOUR_SERVER_IP`，不加协议、端口或路径 |
| TTL | 默认或 Auto |
| Proxy status（若有） | **DNS only / 仅 DNS**，Cloudflare 中为灰色云朵 |

保存前核对页面展示的完整域名，避免名称被重复追加；不要选 URL 转发、CNAME 或 AAAA 来填写 IPv4。Cloudflare 普通橙色云朵代理不能替代本教程的直连 Hysteria2 UDP 入口。见 [DNS 记录管理](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/)与[代理状态](https://developers.cloudflare.com/dns/proxy-status/)。

### 检查是否生效（在本机终端操作）

Windows 打开 PowerShell；macOS/Linux 打开终端：

```bash
nslookup -type=A YOUR_DOMAIN
```

查看应答中的域名和 Address，必须是 `YOUR_SERVER_IP`；开头的 Server/Address 是 DNS 查询服务器，不是 VPS。安装本项目后也可在服务器运行：

```bash
dig +short A YOUR_DOMAIN
dig +short AAAA YOUR_DOMAIN
```

第一条应返回 VPS 公网 IPv4。本教程仅配置 IPv4，第二条应无结果；如果有 AAAA，先确认 IPv6 是否确实通向同一服务，修正这个节点域名的错误记录后再申请证书。

- `NXDOMAIN`：检查拼写、域名邮箱验证、名称服务器是否生效，以及是否在正确 DNS 服务商添加记录。
- 旧地址：检查固定 IP 是否已关联、是否有多条冲突的 A 记录；等待 TTL 缓存过期再查询。
- Cloudflare 地址：检查是否仍开启橙色云朵代理。
- `SERVFAIL`：检查名称服务器和 DNSSEC 配置，参照 DNS 服务商排错说明。
- 查询超时：检查本机网络或换一个网络查询；不要把超时当成记录不存在。

DNS 更新可能几分钟生效，也可能更久；不同网络的缓存可能不同。确认 A 记录正确后再进入证书步骤。

## 六、第一次通过 SSH 登录

### 私钥登录（在本机电脑操作）

macOS/Linux 打开终端，先进入保存私钥的目录，例如下载目录，再运行：

```bash
cd ~/Downloads
chmod 400 YOUR_SSH_KEY.pem
ssh -i YOUR_SSH_KEY.pem ubuntu@YOUR_SERVER_IP
```

Windows 打开 PowerShell；进入 Downloads 后运行：

```powershell
cd "$HOME\Downloads"
ssh -i .\YOUR_SSH_KEY.pem ubuntu@YOUR_SERVER_IP
```

把文件名、IP 替换成自己的；文件在别处就使用完整路径并加引号。其他镜像可能使用 `root` 等用户名，以商家说明为准。Windows 若没有 `ssh`，通过系统“可选功能”安装 OpenSSH Client，或按商家文档使用网页 SSH；不要把 macOS 的 `chmod` 命令照搬到 PowerShell。

### 密码登录与首次主机确认

只有服务商明确提供密码登录时，才在本机运行：

```bash
ssh ubuntu@YOUR_SERVER_IP
```

按提示输入系统密码，输入时不显示字符。EC2 的密钥登录通常不使用这一路径。

第一次连接提示主机指纹时，与控制台系统日志或服务商提供的 SSH 指纹核对，相符后输入 `yes`。仅核对 IP 不足以验证主机身份。以后出现主机密钥变化警告时，先确认是否重建过 VPS，不要盲目删除已保存指纹。见 [AWS SSH 指南](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-to-linux-instance.html)。

成功后会看到 Ubuntu 欢迎信息和类似 `ubuntu@主机名:~$` 的提示符。此后命令都在这个**服务器终端**执行，除非明确写“本机”。运行：

```bash
cat /etc/os-release
```

应显示 Ubuntu 22.04 或 24.04。输入 `exit` 会返回本机；断线后重新执行 SSH 命令即可。

- 连接超时：核对公网 IP、TCP 22 来源是否仍为当前本机 IP、实例状态和公网路由。
- `Permission denied (publickey)`：检查用户名和与实例匹配的私钥；不要使用 Hysteria2 密码。
- 私钥权限过宽：macOS/Linux 用上述 `chmod`；Windows 按官方指南限制私钥文件的访问权限。
- SSH 端口被拒绝：通过服务商网页控制台检查 SSH 服务与防火墙，不要反复改 DNS。

### 检查服务器内部防火墙

在服务器运行 `sudo ufw status`。若显示 inactive，保持现状即可；若显示 active，先保留当前 SSH 窗口，按实际 SSH 端口允许管理来源，再放行 TCP 80 和 UDP 443：

```bash
sudo ufw allow from YOUR_ADMIN_IP to any port 22 proto tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/udp
sudo ufw status
```

规则应出现在列表中；另开一个本机终端验证 SSH 仍可连接后再关闭旧窗口。若 UFW 不存在，不必为教程额外安装；检查服务商是否使用其他主机防火墙。不要清空既有规则或盲目启用 UFW。

## 七、下载项目并安装 Hysteria2

在服务器终端执行。`apt-get update` 更新软件包目录；下一条安装下载项目、编辑配置和生成密码所需工具。依次复制并执行下面三条命令。每输入一条就按一次回车，并等待它执行完成。

```bash
sudo apt-get update
sudo apt-get install -y git nano openssl
git clone https://github.com/Aaron-Lzb/vps-hysteria2.git
```

应看到软件包安装完成和项目下载完成，当前目录中出现 `vps-hysteria2`。若目录已存在，先确认是否为此前部署，勿重复覆盖。进入项目目录并运行现有安装脚本：

```bash
cd vps-hysteria2
sudo bash scripts/install-hysteria.sh
```

脚本会从上游下载安装程序，安装 Hysteria2、Certbot 和独立的 `hysteria-check` / `hysteria-update`；它没有把 Hysteria2 固定为某个版本。安装结束出现 `Installation preparation completed.` 表示安装准备完成；服务此时还没有正式启动，这是正常的。

如果出现红色 `ERROR`，不要反复重装。先复制错误文字，对照本文“常见问题”检查。

## 八、申请 TLS 证书

在服务器终端，确认域名已正确指向 VPS、云端和主机防火墙已开放 TCP 80，且没有其他程序占用该端口，然后运行：

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

在服务器的 `~/vps-hysteria2` 目录操作。以下复制只用于首次部署：先运行 `sudo test -e /etc/hysteria/config.yaml && echo 'CONFIG EXISTS'`。若显示 `CONFIG EXISTS`，可能是上游示例，也可能是已有配置；先检查并备份，确认可替换后再继续。不要覆盖已有有效部署。

若存在性检查无输出且没有权限错误，表示文件不存在。若文件存在，替换前先用以下命令备份；编号备份会保留此前的副本：

```bash
sudo cp --backup=numbered /etc/hysteria/config.yaml /etc/hysteria/config.yaml.before-beginner
```

复制项目的配置模板：

```bash
sudo cp configs/hysteria/config.example.yaml /etc/hysteria/config.yaml
```

打开配置文件：

```bash
sudo nano /etc/hysteria/config.yaml
```

在编辑器里只做两种替换：

1. 把文件中两处 `YOUR_DOMAIN` 都换成你的真实域名；若 Certbot 显示的证书目录有额外后缀，则使用它实际给出的证书路径；
2. 把一处 `YOUR_PASSWORD` 换成刚生成的随机密码。

保留 `listen: :443`、TLS、密码认证和原有 masquerade 设置，不添加 `obfs`；masquerade 中的网站只是 Web 响应目标，不表示需要 Apple 客户端。不要修改缩进，也不要删除冒号。完成后：

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

`hysteria-check` 不强制 root，`sudo` 有助于读取证书，仍是只读检查。`HEALTHY` 返回 0；warning/critical 返回 1，需要按提示判断原因，并非所有 warning 都代表部署失败。自动 IP 检测失败时可用 `sudo hysteria-check YOUR_SERVER_IP`。

状态检查只能证明服务器本机大致正常，云防火墙和客户端到服务器的完整连接仍需要实际测试。下一步安装续期钩子。

## 十一、设置证书自动续期

仍在项目目录内执行：

```bash
sudo install -m 0755 scripts/restart-hysteria-after-renew.sh /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
sudo certbot renew --dry-run
```

应看到模拟续期成功；默认 dry-run 不执行 deploy hook，所以它不证明 Hysteria2 已被重启。再运行 `systemctl is-active certbot.timer`，应返回 `active`；若为 inactive，先用 `systemctl status certbot.timer --no-pager` 检查，存在但未启用时可执行 `sudo systemctl enable --now certbot.timer`。若单元不存在，按 Certbot 安装方式排查，不要假定自动续期已开启。

定时器运行正常时通常无需手动 `renew`。保留 DNS 和 TCP 80 可达；实际续期成功后 deploy hook 会重启 Hysteria2 加载新证书，连接可能短暂中断。见 [Certbot 续期说明](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates)。

## 十二、选择并配置客户端

在要使用代理的设备上操作。服务端与客户端操作系统、品牌无关；原则上任何实现本部署所需 Hysteria2、密码认证和 TLS/SNI 的客户端都能连接。

| 平台 | 可查看的客户端示例 |
| --- | --- |
| iOS / iPadOS | Hiddify、Shadowrocket |
| macOS | Hiddify、FlClash |
| Android | Hiddify、FlClash |
| Windows | Hiddify、FlClash |
| Linux | Hiddify、FlClash，或官方 Hysteria 命令行客户端 |

来源：[Hysteria 官方第三方客户端目录](https://v2.hysteria.network/docs/getting-started/3rd-party-apps/)、[Hiddify](https://github.com/hiddify/hiddify-app)、[FlClash](https://github.com/chen08209/FlClash)。这些是平台入口，不是本项目已逐一完成设备验收的名单；安装前确认当前版本支持 Hysteria2、设备系统版本及所需导入方式。Mihomo/Clash.Meta 是部分应用使用的核心，不是所有应用都暴露相同功能。其他应用（包括 Surge）也应按具体版本官方说明确认。

1. 从项目官方发布页或其指向的应用商店安装匹配设备的版本。
2. 找到添加节点/服务器，选择 **Hysteria2**，不是旧版 Hysteria；若应用只接受配置导入，使用其官方 Hysteria2 配置说明，不要导入服务器 YAML。
3. 按下表填写、保存、选中节点，再启用连接。系统要求 VPN 或网络扩展权限时，确认是刚安装的客户端后允许。

| 字段 | 填写内容 |
| --- | --- |
| 地址 / 服务器 | `YOUR_DOMAIN`，不加 `https://` 或路径 |
| 端口 | `443`（UDP） |
| 密码 / auth | 与服务端一致的 `YOUR_PASSWORD` |
| SNI / Server Name | `YOUR_DOMAIN` |
| 跳过证书验证 / Allow Insecure | 关闭 |
| 额外混淆 / Salamander | 关闭，与本项目默认配置一致 |

需要命令行或原生配置的用户可参考 [Hysteria 客户端教程](https://v2.hysteria.network/docs/getting-started/Client/) 或 [Mihomo Hysteria2 字段](https://wiki.metacubex.one/en/config/proxies/hysteria2/)。只填写本机私有配置，不把密码或完整节点链接贴到公开转换网站。

桌面客户端若只是启动了本地代理端口，还需按其说明启用系统代理或为目标应用指定代理；并非所有流量都会自动经过节点。先使用连通性测试，再打开一个预期经代理访问的网页。延迟数字或浏览器成功都不能单独证明所有应用的路由正确；失败时按第十四节检查。

### Shadowrocket：项目维护的一个示例

Shadowrocket 不是默认或唯一选择。若使用它，在主界面点击 `+`，选择 Hysteria2，填写上述字段，保存、选中并打开连接开关；iOS/iPadOS 会请求添加 VPN 配置。

节点测试通过后，再按 [Shadowrocket 分流指南](clients/shadowrocket.md)导入现有配置并选择 `PROXY` 节点。分别测试预期 DIRECT 和 PROXY 的目标；规则与兼容节点相对独立，切换节点通常不必改规则。此配置不能直接用于其他品牌客户端。

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

### 3. 客户端一直超时

依次确认：

- 云防火墙开放的是 **UDP 443**，不是只有 TCP 443；
- 客户端节点类型确实是 Hysteria2；
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

完成以上步骤后，你已经拥有一个可由兼容客户端连接的个人 Hysteria2 节点。
