# Mr.shaw Marzban 更新脚本

这是基于 [Gozargah/Marzban-scripts](https://github.com/Gozargah/Marzban-scripts) 的开源 Fork。感谢原作者和贡献者，保留原仓库历史与许可证。本 Fork 的功能说明见 [更新记录](CHANGELOG.md)，主面板和 Node 的具体功能分别见 [Marzban](https://github.com/heyinkcode/Marzban/blob/master/FORK_FEATURES.md) 与 [Marzban-Node](https://github.com/heyinkcode/Marzban-node/blob/master/FORK_FEATURES.md)。

## 已经安装官方版的服务器

已经切换为Fork、但旧脚本误报官方镜像的安装，不要重复adopt；请先按[更新脚本修复指南](docs/UPDATE_IMAGE_RECOGNITION.md)刷新命令，再执行update。

先确认 `ghcr.io/heyinkcode/marzban:latest` 和 `ghcr.io/heyinkcode/marzban-node:latest` 已发布、服务器能拉取。下面的 `adopt` 只替换对应 Compose 服务的镜像字段；原有 `.env`、数据库、Xray 配置、证书、端口及数据卷不重建。脚本会在 `/opt/marzban/backup/` 或 `/opt/marzban-node/backup/` 保存带时间戳的数据归档，并校验归档后才切换镜像。

主面板：

```bash
curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban.sh -o /tmp/marzban-mrshaw.sh
sudo install -m 755 /tmp/marzban-mrshaw.sh /usr/local/bin/marzban
sudo marzban adopt
sudo marzban status
```

已有 Node（在每台 Node 服务器分别执行）：

```bash
curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban-node.sh -o /tmp/marzban-node-mrshaw.sh
sudo install -m 755 /tmp/marzban-node-mrshaw.sh /usr/local/bin/marzban-node
sudo marzban-node adopt
sudo marzban-node status
```

若 Node 原本使用自定义命令名（例如 `marzban-node2`），把上述安装目标与命令改为原命令名。`adopt` 会备份对应的原数据目录并保持证书与端口。

后续更新直接运行：

```bash
sudo marzban update
sudo marzban-node update
```

两个命令只拉取 `ghcr.io/heyinkcode/` 下的 Fork 镜像，并在更新前再次创建归档。它们不会执行原版 `install`，也不会重置已有用户。外部 MySQL/PostgreSQL 不在本机数据目录内；脚本检测到这种数据库时会先停止并要求单独备份。

## 新服务器

主面板安装命令会从 `heyinkcode/Marzban` 获取 Compose、环境示例和 Xray 示例文件，再启动 Fork 镜像：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban.sh)" @ install
```

新 Node 的安装流程继续生成官方方式的连接证书与端口配置，但镜像来自 `heyinkcode/Marzban-node`：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban-node.sh)" @ install
```

新服务器必须先在主面板创建 Node，再把主面板提供的证书按安装提示放到 Node 服务器。主面板与 Node 都升级到配对版本后，才使用住宅 IP 出口。

## Xray 核心版本策略

正式安装和更新统一使用仓库构建时的 `XRAY_CORE_VERSION=v26.3.27`。主面板与 Node 镜像必须使用同一个值；脚本默认值也固定为该稳定版本，并在下载解压后核对实际 `xray -version`，避免服务器在不同时间安装出不同核心。`v25.3.6`、`1.8.24` 仅是历史预览文字，不参与安装。

`v26.9.9` 目前属于预发布版本，不进入正式 `latest`。如果要测试，只能通过单独的测试构建参数和镜像标签验证，测试通过后再变更正式基线。不要在生产服务器直接运行 `core-update` 期待它同步仓库；该命令可能修改容器外的 Xray 二进制，从而造成主面板、Node 和外部核心版本不一致。

核心升级也不等于面板功能自动增加。新协议/传输层必须同时完成主面板模型、Xray 配置生成、Node 下发预检、订阅转换、前端设置和客户端联调，才可以写入正式功能清单。
## 数据和版本边界

- `install` 遇到现有安装目录会退出；已有服务器使用 `adopt`，以后使用 `update`。
- 不运行 `uninstall`、`docker compose down -v` 或手动删除 `/var/lib/marzban`、`/var/lib/marzban-node`。
- 发布镜像前，应完成主面板、Node 和真实 Xray 的配对验证。镜像是否公开可拉取也应在服务器上确认。
- 一次性切换前检查归档与可用磁盘空间，并保留原 Compose 文件供回退排查；数据库发生迁移后不能仅靠旧镜像回退，应使用对应备份恢复。

## 文档

- [使用与维护文档](docs/README.md)
- [功能说明](FORK_FEATURES.md)
- [更新记录](CHANGELOG.md)
