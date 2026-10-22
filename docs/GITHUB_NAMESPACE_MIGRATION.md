# GitHub 用户名迁移与已有服务器更新

仓库所有者改为 `heyinkcode`。主控、Node 和脚本仓库的安装、自更新、源码地址及新镜像统一使用新用户名。旧名称只作为已有 Fork 的兼容识别或历史发布证据；不修改 Gozargah/XTLS 上游来源。

## 已有默认实例：一键刷新命令并更新

在相应服务器运行下面对应的一条命令。先完整下载新脚本，下载失败不会继续执行旧 CLI；只刷新 CLI 后执行保留数据更新，不运行 install/adopt，不删除卷。

主控服务器：

```sh
sudo bash -c 'set -e; f=$(mktemp); trap '\''rm -f "$f"'\'' EXIT; curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban.sh -o "$f"; bash "$f" install-script; marzban update'
```

Node 服务器：

```sh
sudo bash -c 'set -e; f=$(mktemp); trap '\''rm -f "$f"'\'' EXIT; curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban-node.sh -o "$f"; bash "$f" install-script; marzban-node update'
```

自定义 Node 实例必须使用原命令名，例如将上述末尾改成 `bash "$f" install-script --name marzban-node2; marzban-node2 update`，不要用默认命令操作另一安装。自定义主控安装也须保留原 APP_NAME、目录和既有管理方式，不能套用默认实例命令。

完成这次 CLI 刷新和迁移后，常规更新继续使用 `sudo marzban update` 或 `sudo marzban-node update`。旧服务器上的脚本不会因 GitHub 改名被自动替换，所以第一次必须从新地址刷新命令。

## 镜像迁移合同

- 新安装、adopt 及构建目标为 `ghcr.io/heyinkcode/marzban:latest` 与 `ghcr.io/heyinkcode/marzban-node:latest`；Xray 仍固定 v26.3.27。
- update 从 Compose 解析后的目标服务读取镜像。精确的新 Fork 标签/摘要保持不变；旧 `ghcr.io/kissow/<service>` 的隐式 latest 或 `:latest` 进入同一项目的命名空间迁移，不误报为官方镜像。
- 旧固定标签、摘要或 tag+digest 不擅自追踪 latest：停止并提示先验证对应的新制品和明确修改镜像。官方 Gozargah 或其他自定义镜像不能被自动迁入。
- 先执行原一致性备份，然后生成同目录临时 Compose，只改目标服务 image。用真实 Compose 解析前后模型，确认其他配置完全相同，才允许应用；环境变量和继承锚点均按解析结果核对。流式/其他无法证明安全的 YAML 布局以及符号链接停止，原文件不改。
- 先拉取新镜像，再以原权限替换 Compose；拉取/启动失败返回非零。应用失败恢复原 Compose 并尝试启动原服务，恢复失败明确报告，绝不虚报更新成功。原 Compose 单独保存在安装目录 backup/namespace-compose-*.yml。
- 不改用户、数据库、证书、端口、.env 或数据卷；不打印完整 Compose/环境变量。更新本来会因一致性备份和容器切换有短暂停顿，不承诺零中断。
- update 不新增 yq 依赖；从真正官方安装迁入 Fork 的 adopt 仍是另一项显式操作，保留其原依赖和备份要求。

## 验收和回退

先检查命令退出码、升级备份和容器状态，再核对实际镜像、revision、原用户/订阅/Node 控制与业务出口。

```sh
marzban status
docker inspect marzban-marzban-1 --format '{{.Config.Image}} | {{index .Config.Labels "org.opencontainers.image.revision"}}'
marzban-node status
docker inspect marzban-node --format '{{.Config.Image}} | {{index .Config.Labels "org.opencontainers.image.revision"}}'
```

只在各自服务器运行对应命令；自定义容器名使用原名称。失败时保留备份，不重装、不删卷；回退时依据此次记录的原镜像和 Compose，避免无关数据库降级。历史旧 GHCR 名称/摘要是当时发布证据，不应伪改成新制品。

本地三个项目的 origin 改为 `https://github.com/heyinkcode/<repo>.git`，上游仍是 Gozargah。GitHub CLI 通过已登录身份和新仓库写权限验证；独立 GUI/OAuth 的重新授权不能靠改 URL 替代。

[本轮发布记录](releases/github-namespace-20261023.md) · [更新识别](UPDATE_IMAGE_RECOGNITION.md)
