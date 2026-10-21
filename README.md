# nexboot (Docker image)

Docker image for [NexBoot / ndiskless](https://github.com/waterlemon0108/nexboot)（基于 Go 的轻量级无盘启动平台：iPXE、ZFS、iSCSI、Web 管理）。

自动跟随上游 release tag 构建并推送 `ghcr.io/dockers-x/nexboot:{v版本,latest}`。

## 构建方式

- 多阶段：web（vite）→ Go 静态编译（CGO=0，web/dist 通过 go:embed 打入二进制）→ Ubuntu 24.04 运行时（含 zfsutils-linux、dnsmasq、targetcli-fb、keepalived、qemu-utils）
- 入口脚本幂等生成 `/etc/ndiskless/ndiskless.env`（沿用上游 install-go.sh 的 env 契约），首次启动输出随机管理员密码

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `NDISKLESS_BOOTSTRAP_PASSWORD` | 随机 | 初始管理员密码（仅首次生成，之后保留） |
| `NDISKLESS_BOOTSTRAP_USERNAME` | `admin` | 管理员用户名 |
| `NDISKLESS_POOL` | `tank` | ZFS 池名 |
| `NDISKLESS_ADDR` | `:8080` | HTTP 监听地址 |
| `NDISKLESS_DATA_DIR` | `/var/lib/ndiskless` | 数据目录（SQLite/导入文件） |

## 运行要求（重要）

NexBoot 不是普通 Web 应用，容器内正常工作需要：

- **privileged** 容器（ZFS 内核模块、iSCSI LIO、dnsmasq 监听）
- **host network**（DHCP/PXE/iSCSI 需与客户机同二层网段）
- 宿主机有**独立数据盘**用于 ZFS 存储池（需手工 `zpool create tank ...` 或在 UI 中操作）
- 宿主机**静态 IP**，网段内无其它 DHCP 服务器

在容器/轻量环境中这些条件往往无法全部满足——请先确认你的运行时支持，再部署。

## 许可

AGPL-3.0（上游）
