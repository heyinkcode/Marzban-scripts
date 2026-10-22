# 部署脚本功能

- [用户名迁移与已有服务器一键更新](docs/GITHUB_NAMESPACE_MIGRATION.md)

基于上游 Gozargah/Marzban-scripts，保留原历史、作者署名与许可证。安装和命令见 [README](README.md)。

- install：新服务器部署 Fork 镜像。
- adopt：已有官方安装首次切换 Fork，先备份并核对真实配置；不是通用修复命令。
- update：已有 Fork 备份、拉取镜像、启动并刷新脚本；保留用户数据、.env、证书、端口和数据卷，不通过重装或删卷升级。
- 更新来源识别：读取 Docker Compose 解析后的目标服务镜像，不依赖 yq；区分官方、其他镜像和配置读取失败，失败阶段不报成功。[原因、修复与验收](docs/UPDATE_IMAGE_RECOGNITION.md)

出口、检测、中转和使用系数由配对[主控](https://github.com/heyinkcode/Marzban/blob/master/docs/README.md)及[Node](https://github.com/heyinkcode/Marzban-node/blob/master/docs/README.md)实现，不由脚本搬运用户流量。是否需要更新某台 Node，以相应功能的能力要求为准。

[更新摘要](CHANGELOG.md) · [发布检查](RELEASE_CHECKLIST.md) · [历史证据](docs/releases/README.md)

使用与协议说明见[文档中心](docs/README.md)，旧阶段测试和发布证据见[对应历史索引](docs/releases/README.md)；文档整理不改变运行时。
