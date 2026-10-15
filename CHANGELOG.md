# Mr.shaw Marzban-scripts Fork 更新记录

## MR-20261015-UPDATE-RECOGNITION（开发中）

修复update因缺少/不兼容yq误报官方镜像；主控和Node使用相同的目标Compose服务只读识别，保留标签、摘要、备份和原安装。识别失败与官方/自定义镜像分开报错，阶段失败明确中止。仅脚本，无业务镜像/API/证书/端口变化；测试与发布见[专页](docs/UPDATE_IMAGE_RECOGNITION.md)。首页只留产品与文档导航，历史维护记录迁入docs。

## MR-20261008-NODE-RELAY-SOURCES（镜像已发布，服务器/视觉验收待完成）

连接方式采用原React/Chakra独立管理弹窗和原信息图标。可选择Marzban主服务器或另一台源Node中转到目标Node；保留原订阅别名、顺序、数量，只替换精确匹配的端点，不新增Relay。目标认证、设备凭据和出口不变。自转发/环路/占用/能力/精确ACK/失败回滚、来源隔离与恢复有回归测试。

管理API增加source/source_node_id/来源列表，additive迁移9012ab34cd56；Node新增managed-node-relay-v1、原认证REST/RPyC完整快照与独立转发进程。固定Xray26.3.27，原证书、控制/API端口、用户、.env与数据卷保留。首版VLESS TCP/RAW REALITY、IPv4/DNS-only入口、单跳选择，不是所有协议或任意UDP转发；每源512个配置不是吞吐承诺。

本地最终代码和独立发布副本再次复测：主控164/164、Node60/60（准备固定Xray，无跳过）、前端47/47、类型/生产构建、依赖/diff通过。干净Linux CI与两镜像双架构发布核对完成；真实跨服务器mTLS、公网吞吐、多引擎数据库、实际原组件UI截图仍待验收，不标稳定版。UI截图因浏览器策略blocked，未绕过。

主控revision 93bfbb5b17dd8ee731449976df1a4af4e0f57ca5，Actions37657985804；Node revision 7b45fc0dc3b4451045a06123b52ccdaaa5911b8d，Actions37657976968。scripts合并ed274ba82410f9e6f580cbec59b2a15a89ab81ea，Actions37657994843成功，脚本运行时不变。先在承担来源的Node运行marzban-node update，再在主控运行marzban update；仅作目标的既有配对Node不强制更新。新Node沿用仓库install，现在拉取新latest；旧机不重装、不删卷、不重复adopt。源业务入口TCP需放行，客户端刷新订阅。

[精确配对SHA、index/架构/config摘要、接口与SSH验收证据](https://github.com/kissow/Marzban/blob/master/docs/NODE_RELAY_SOURCES_RELEASE.md)。下方旧记录只描述各自日期的阶段，不代替本轮最新状态；文档[skip ci]提交不改变已核对的运行时镜像revision。


## MR-20261003-EGRESS-UDP：配对部署文档（2026-10-03）

- scripts 仅更新文档；Bash 运行时、命令、镜像来源、固定核心 v26.3.27、证书、端口和数据路径无变化，不构建新的 scripts 容器。
- 配对主面板 `10f46df8e52ad24c79a1d4a1aafc020a7f7ad335` / Node `ff3ed8affb43a7c0be84b7404b25ba149cd9c805` 新增 `udp_mode` 和 `managed-outbounds-udp-v1`；新模式需要两边更新，先 Node 后主面板。既有 Fork 继续 update，不重复 adopt/reinstall。
- UDP DNS TCP 兼容、供应商限制和待验收项目均在 README 和两边协议文档登记；代码推送、Actions、镜像发布与服务器验收是不同状态，以配对仓库发布证据为准。

本文件记录相对 [Gozargah/Marzban-scripts](https://github.com/Gozargah/Marzban-scripts) 的新增与调整。感谢原作者和贡献者，保留上游 Git 历史与许可证。

## 正式版核心一致性闸门（2026-09-30，未发布）

- `install_latest_xray.sh` 安装前校验下载的 Xray 二进制版本必须与显式请求的版本一致。
- 正式安装和更新继续以 `v26.3.27` 为唯一默认核心，错误版本会中止，不会静默覆盖现有核心。

## 开发中（尚未发布）

- 安装和更新脚本改为从 `kissow/Marzban`、`kissow/Marzban-node` 与 `kissow/Marzban-scripts` 读取文件，并拉取 `ghcr.io/kissow/` 的 Fork 镜像。
- 新增 `marzban adopt` 与 `marzban-node adopt`：已有官方安装可在原目录切换镜像，保留 `.env`、数据库、证书和 Compose 的其他配置。
- `update` 会先备份并验证原数据目录，再拉取自己的镜像；不执行 `down -v`。
- `install` 遇到已有目录会退出，防止覆盖现有配置和用户数据。
- 手动 `backup` 不再清空整个旧备份目录，每次使用独立临时目录。

发布前仍需在隔离 Linux 服务器验证 SQLite/MySQL/MariaDB 的数据保留、Node 证书、镜像拉取和 `marzban update` 的实际行为。
