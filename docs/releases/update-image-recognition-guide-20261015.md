# 更新时误报官方镜像 历史说明快照

原文截至 2026-10-15，整理于 2026-10-16。下方保留开发阶段、测试及发布证据，不是当前使用指引；其中 latest、未发布、预期 revision 等仅指当时状态。

[当前说明](../UPDATE_IMAGE_RECOGNITION.md) · [历史索引](README.md) · [不可变原文](https://github.com/kissow/Marzban-scripts/blob/c864c5090b9f5582bd208efb2b356d83cf2ba458/docs/UPDATE_IMAGE_RECOGNITION.md)

---

# 更新时误报官方镜像

变更MR-20261015-UPDATE-RECOGNITION；脚本已合并发布，正式Linux回归及线上脚本字节核对通过，用户已反馈故障 Node 更新流程测试 OK；该反馈不等于全部业务或客户端验收。脚本运行时代码变化；Marzban与Node镜像、HTTP API、REST/RPyC、设备策略、数据库、证书、端口、.env、数据卷及固定Xray v26.3.27均无变化，不需要重新构建业务镜像。

## 原因

旧marzban-node update与marzban update把「yq不存在」和「Compose镜像不是Fork」合并成同一个分支。因此已经使用ghcr.io/kissow镜像，但未安装yq或装了不兼容yq的主机，会被错误要求adopt；成功更新的主机可能恰好具备兼容yq。截图符合这个确定存在的代码缺陷；用户随后刷新脚本并完成更新，反馈测试 OK，但没有独立读取故障机原 yq 环境。

这不是Node掉线或容器启动失败。status的running仅证明某个容器正在运行，不能证明本次更新成功或镜像revision正确。旧update在guard之前退出，也就不能执行末尾自更新，需要先刷新脚本一次。

## 命令合同

- update的命令名、参数和成功路径保留；先检查原目标服务的Compose实际模型，再执行原备份、拉取、启动和脚本刷新。
- 只读Docker Compose config的规范输出；它已处理环境变量、.env和YAML合并。只取目标服务的image，不搜索整个文件，不以另一个服务的Fork镜像或当前运行容器兜底。参考[Docker Compose官方合同](https://docs.docker.com/reference/cli/docker/compose/config/)。
- update不再要求yq。真正修改官方Compose镜像的adopt仍保留原yq要求；没有自动迁移、重装或修改镜像配置。
- 接受精确Fork仓库的隐式latest、标签、sha256摘要及标签加摘要；不能用相似前缀冒充。保留原标签/摘要，固定摘要不会自动追踪latest。
- Compose读取失败、目标服务/唯一image缺失、其他自定义镜像分别停止；不会一概称为官方镜像。只有精确识别官方仓库才提示查阅迁移指南。
- 备份、拉取、刷新脚本任一步失败，返回非零且不报更新成功；即使Bash调用处处于条件表达式，也不能依靠set -e掩盖错误。备份预检/建目录/临时文件/停服/归档/校验/恢复启动失败均中止，已停止服务在归档失败时尝试原配置启动。
- 控制/API端口、REST证书及数据保持不变，无新监听或依赖；不打印完整解析配置或代理凭据。

## 已切换Fork的服务器

以下是默认命令名。先刷新脚本，不重装Node，不执行adopt：

```sh
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/kissow/Marzban-scripts/master/marzban-node.sh)" @ install-script
sudo marzban-node update
sudo marzban-node status
docker inspect marzban-node --format '{{.Config.Image}} | {{index .Config.Labels "org.opencontainers.image.revision"}}'
```

自定义命令名例如marzban-node2，刷新时增加--name marzban-node2，随后继续使用该命令；不要换成默认命令而指向另一个安装目录。主控如需刷新，只将脚本URL与命令换成marzban.sh/marzban。正常已更新的容器不必为此次脚本修复再拉镜像；刷新命令可单独执行。

新安装直接使用仓库install，部署同一版识别逻辑。真正官方或自定义镜像不能仅因看见报错就盲目adopt，应先核对配置及备份。

## 检测和验收

Windows固定PowerShell7/项目Python执行静态合同检查，不切换到Bash作为本地命令环境。真实Bash和Docker Compose回归在Ubuntu22.04、24.04各三轮运行；覆盖无yq/不兼容yq、自定义命令名、标签/摘要/引号、官方与其他镜像、相似前缀、缺失/重复字段、多个服务、敏感配置不泄露、失败中止和实际tar归档。实际Compose测试解析.env变量、YAML锚点和数据库依赖，但不启动/拉取业务容器。

这些是隔离回归。2026-10-15 用户提供故障 Node 刷新旧脚本、备份、拉取 Fork 镜像和启动成功的截图，并反馈“测试 OK”；据此确认用户已验收该更新流程。未由本次工作独立 SSH 核对实际 revision、证书端口及全部业务链路，不把 status Up 或这次反馈扩大为所有客户端、供应商和出口的验收。

## 发布证据

2026-10-15：源提交e881580ea3da2e74542eddb7f6cffe46ff72eff5，经[PR #3](https://github.com/kissow/Marzban-scripts/pull/3)合入a26b6af35785c47cefc7deca78627d8e8262d075。

分支[38692092775](https://github.com/kissow/Marzban-scripts/actions/runs/38692092775)、PR[38692104130](https://github.com/kissow/Marzban-scripts/actions/runs/38692104130)、正式[38692284027](https://github.com/kissow/Marzban-scripts/actions/runs/38692284027)均成功。每次包含Ubuntu22.04/24.04各三轮31/31，无Linux跳过；包含真实Compose展开与tar归档。Windows本地4项静态通过、27项Linux相关明确跳过，不把跳过当本地真实执行。

原始master下载字节与GitHub API对应Git blob及本地源对象核对一致：

| 文件 | Git blob | SHA256 |
| --- | --- | --- |
| marzban-node.sh | 1db88a93e65bed3013196c897b73f07c9c1dfec0 | f7cc3c8df0d2ecfb2e9fffe0af7ab180943aeccbb877a8b4029a11349725e07f |
| marzban.sh | d56f71005962b95c45a713ba33adddf853d9d59f | 7c729715227f62cf01775aaf837d6c932b7b461ec92487de8b3366a57b3884eb |

此次脚本修复不发布 Docker 镜像。脚本修复发布时的主控镜像为258218c07c9f2e265e790764bd727e528dcb761d、Node 为 168a9e63d7c5219dffafd5839876db30b57e3cd5；这是当时版本快照，不代表之后的 latest。用户截图证明主控和一台Node执行更新成功，另一台被旧guard拒绝；没有把这些截图认定为全部业务/客户端验收。故障机随后刷新本地旧命令并成功 update，用户已确认该更新流程测试 OK；业务出口与新功能需分别验收。

发布前Git fetch出现连接重置，未改变全局TLS/证书；只读API与原始下载校验成功。文档证据仅Markdown [skip ci]回写，不再改动已测试脚本和镜像。完整回归已成为工作流固定门槛，以免缺少yq误判再次出现。
