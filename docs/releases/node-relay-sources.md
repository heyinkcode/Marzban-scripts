# Marzban 或 Node 中转到目标 Node：历史发布记录

[当前说明](https://github.com/heyinkcode/Marzban/blob/master/docs/NODE_RELAY_SOURCES.md) · [历史索引](README.md)

本文按功能保留原始发布证据。记录中的「当前」「最新」「未发布」「待验收」仅指原记录形成时的状态，不能替代当前说明或新的验收记录。旧流程和旧接口描述不是现行使用指引；重复正文合并并保留来源。整理日期：2026-10-15。

## 历史片段 1

原位置：[FORK_FEATURES.md](https://github.com/heyinkcode/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/FORK_FEATURES.md)、[CHANGELOG.md](https://github.com/heyinkcode/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/CHANGELOG.md)、[RELEASE_CHECKLIST.md](https://github.com/heyinkcode/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/RELEASE_CHECKLIST.md)。

---

## MR-20261008-NODE-RELAY-SOURCES（镜像已发布，服务器/视觉验收待完成）

连接方式采用原React/Chakra独立管理弹窗和原信息图标。可选择Marzban主服务器或另一台源Node中转到目标Node；保留原订阅别名、顺序、数量，只替换精确匹配的端点，不新增Relay。目标认证、设备凭据和出口不变。自转发/环路/占用/能力/精确ACK/失败回滚、来源隔离与恢复有回归测试。

管理API增加source/source_node_id/来源列表，additive迁移9012ab34cd56；Node新增managed-node-relay-v1、原认证REST/RPyC完整快照与独立转发进程。固定Xray26.3.27，原证书、控制/API端口、用户、.env与数据卷保留。首版VLESS TCP/RAW REALITY、IPv4/DNS-only入口、单跳选择，不是所有协议或任意UDP转发；每源512个配置不是吞吐承诺。

本地最终代码和独立发布副本再次复测：主控164/164、Node60/60（准备固定Xray，无跳过）、前端47/47、类型/生产构建、依赖/diff通过。干净Linux CI与两镜像双架构发布核对完成；真实跨服务器mTLS、公网吞吐、多引擎数据库、实际原组件UI截图仍待验收，不标稳定版。UI截图因浏览器策略blocked，未绕过。

主控revision 93bfbb5b17dd8ee731449976df1a4af4e0f57ca5，Actions37657985804；Node revision 7b45fc0dc3b4451045a06123b52ccdaaa5911b8d，Actions37657976968。scripts合并ed274ba82410f9e6f580cbec59b2a15a89ab81ea，Actions37657994843成功，脚本运行时不变。先在承担来源的Node运行marzban-node update，再在主控运行marzban update；仅作目标的既有配对Node不强制更新。新Node沿用仓库install，现在拉取新latest；旧机不重装、不删卷、不重复adopt。源业务入口TCP需放行，客户端刷新订阅。

[精确配对SHA、index/架构/config摘要、接口与SSH验收证据](https://github.com/heyinkcode/Marzban/blob/master/docs/NODE_RELAY_SOURCES_RELEASE.md)。下方旧记录只描述各自日期的阶段，不代替本轮最新状态；文档[skip ci]提交不改变已核对的运行时镜像revision。
