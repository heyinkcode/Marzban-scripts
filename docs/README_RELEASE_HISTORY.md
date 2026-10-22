# README 历史发布记录

2026-10-15 从产品首页迁入，保留各日期的原发布与测试快照。下方状态只代表当时记录，不代表当前latest；现行信息见[文档中心](README.md)及[更新记录](../CHANGELOG.md)。

# Mr.shaw Marzban 更新脚本

## MR-20261008-NODE-RELAY-SOURCES（镜像已发布，服务器/视觉验收待完成）

连接方式采用原React/Chakra独立管理弹窗和原信息图标。可选择Marzban主服务器或另一台源Node中转到目标Node；保留原订阅别名、顺序、数量，只替换精确匹配的端点，不新增Relay。目标认证、设备凭据和出口不变。自转发/环路/占用/能力/精确ACK/失败回滚、来源隔离与恢复有回归测试。

管理API增加source/source_node_id/来源列表，additive迁移9012ab34cd56；Node新增managed-node-relay-v1、原认证REST/RPyC完整快照与独立转发进程。固定Xray26.3.27，原证书、控制/API端口、用户、.env与数据卷保留。首版VLESS TCP/RAW REALITY、IPv4/DNS-only入口、单跳选择，不是所有协议或任意UDP转发；每源512个配置不是吞吐承诺。

本地最终代码和独立发布副本再次复测：主控164/164、Node60/60（准备固定Xray，无跳过）、前端47/47、类型/生产构建、依赖/diff通过。干净Linux CI与两镜像双架构发布核对完成；真实跨服务器mTLS、公网吞吐、多引擎数据库、实际原组件UI截图仍待验收，不标稳定版。UI截图因浏览器策略blocked，未绕过。

主控revision 93bfbb5b17dd8ee731449976df1a4af4e0f57ca5，Actions37657985804；Node revision 7b45fc0dc3b4451045a06123b52ccdaaa5911b8d，Actions37657976968。scripts合并ed274ba82410f9e6f580cbec59b2a15a89ab81ea，Actions37657994843成功，脚本运行时不变。先在承担来源的Node运行marzban-node update，再在主控运行marzban update；仅作目标的既有配对Node不强制更新。新Node沿用仓库install，现在拉取新latest；旧机不重装、不删卷、不重复adopt。源业务入口TCP需放行，客户端刷新订阅。

[精确配对SHA、index/架构/config摘要、接口与SSH验收证据](https://github.com/heyinkcode/Marzban/blob/master/docs/NODE_RELAY_SOURCES_RELEASE.md)。下方旧记录只描述各自日期的阶段，不代替本轮最新状态；文档[skip ci]提交不改变已核对的运行时镜像revision。


## MR-20261003-EGRESS-UDP 配对更新（2026-10-03）

本次脚本运行时代码、install/adopt/update、镜像地址、证书、端口、数据目录与固定 Xray `v26.3.27` 均无变化，无需额外安装软件或开放端口。主面板源提交 `10f46df8e52ad24c79a1d4a1aafc020a7f7ad335`，Node 源提交 `ff3ed8affb43a7c0be84b7404b25ba149cd9c805`；两边新增每 Node UDP 处理合同。只有两个镜像发布证据齐全后才更新：已切换 Fork 的服务器先在每台 Node 执行 `marzban-node update` 并检查状态，再在主面板执行 `marzban update`。本轮不需要重复 adopt，不使用 reinstall，不删除数据卷。

新模式要求 Node 能力 `managed-outbounds-udp-v1`；旧模式 legacy 默认兼容，旧 Node 使用新模式返回主面板 409。TCP-only 仅处理默认 DNS 的 TCP 兼容并阻断其他默认 UDP，不是任意 UDP 转 TCP，也不保证所有手机应用可用。实际供应商 TCP53、v2rayNG/Clash Meta、UI 和服务器仍待验收。完整合同见 [主面板 UDP 文档](https://github.com/heyinkcode/Marzban/blob/master/docs/NODE_EGRESS_UDP.md) 和 [Node 线协议](https://github.com/heyinkcode/Marzban-node/blob/master/docs/egress-udp.md)；发布证据见各仓库 RELEASE_CHECKLIST，不复用历史镜像摘要。
