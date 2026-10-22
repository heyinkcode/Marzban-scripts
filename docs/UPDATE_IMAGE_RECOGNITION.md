# 更新时误报官方镜像的处理

现行仓库所有者是 heyinkcode。已有 kissow Fork 的 latest 镜像由新版 update 安全迁移；先刷新 CLI 的一键命令、固定版本边界及失败恢复见[用户名迁移指南](GITHUB_NAMESPACE_MIGRATION.md)。历史测试数字仅代表原版本，不代替本次迁移验收。

已使用 ghcr.io/kissow 镜像，却被旧 update 命令要求 adopt 时，先核对目标服务的 Compose 镜像。旧脚本曾将缺少/不兼容 yq 与非 Fork 镜像混为一类；刷新本机命令可取得修复，不要对已切换 Fork 的安装重复迁移。

容器 running 只证明容器在运行，不能证明本次更新已执行或镜像版本正确。旧命令在更新前退出，无法完成末尾的脚本自更新，因此需要先单独刷新脚本。

## 命令合同

- update的命令名、参数和成功路径保留；先检查原目标服务的Compose实际模型，再执行原备份、拉取、启动和脚本刷新。
- 只读Docker Compose config的规范输出；它已处理环境变量、.env和YAML合并。只取目标服务的image，不搜索整个文件，不以另一个服务的Fork镜像或当前运行容器兜底。参考[Docker Compose官方合同](https://docs.docker.com/reference/cli/docker/compose/config/)。
- update不要求yq。官方镜像的adopt仍保留原yq要求；新版仅自动迁移精确识别的旧 Fork latest，其他情况不擅自修改镜像。迁移有前后 Compose 模型等价检查，不重装或删卷。
- 接受精确Fork仓库的隐式latest、标签、sha256摘要及标签加摘要；不能用相似前缀冒充。保留原标签/摘要，固定摘要不会自动追踪latest。
- Compose读取失败、目标服务/唯一image缺失、其他自定义镜像分别停止；不会一概称为官方镜像。只有精确识别官方仓库才提示查阅迁移指南。
- 备份、拉取、刷新脚本任一步失败，返回非零且不报更新成功；即使Bash调用处处于条件表达式，也不能依靠set -e掩盖错误。备份预检/建目录/临时文件/停服/归档/校验/恢复启动失败均中止，已停止服务在归档失败时尝试原配置启动。
- 控制/API端口、REST证书及数据保持不变，无新监听或依赖；不打印完整解析配置或代理凭据。

## 已切换Fork的服务器

以下是默认命令名。先刷新脚本，不重装Node，不执行adopt：

```sh
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/heyinkcode/Marzban-scripts/master/marzban-node.sh)" @ install-script
sudo marzban-node update
sudo marzban-node status
docker inspect marzban-node --format '{{.Config.Image}} | {{index .Config.Labels "org.opencontainers.image.revision"}}'
```

自定义命令名例如marzban-node2，刷新时增加--name marzban-node2，随后继续使用该命令；不要换成默认命令而指向另一个安装目录。主控如需刷新，只将脚本URL与命令换成marzban.sh/marzban。正常已更新的容器不必为此次脚本修复再拉镜像；刷新命令可单独执行。

新安装直接使用仓库install，部署同一版识别逻辑。真正官方或自定义镜像不能仅因看见报错就盲目adopt，应先核对配置及备份。

## 更新结果检查

确认升级前备份路径和命令返回码，再核对目标容器的实际镜像及 OCI revision、证书/端口保留和面板连接。固定标签或摘要不会自动跟随 latest；自定义实例须继续使用原命令名和目录。

用户已反馈故障 Node 刷新脚本和更新流程测试 OK；该结果仅确认此次更新流程，不代替出口、订阅和客户端验收。新功能仍按对应文档检查实际链路。

[历史回归、发布与用户反馈](releases/update-image-recognition-guide-20261015.md) · [安装与保留数据更新](../README.md)
