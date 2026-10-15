# Mr.shaw deployment release checklist

## MR-20261015-UPDATE-RECOGNITION

- [x] 主控/Node更新识别统一，update不依赖yq，数据/证书/端口/标签与摘要保持。
- [x] 新增静态合同与Linux真实Bash/Compose/tar回归；Windows只运行静态项，明确跳过Linux项。
- [ ] Ubuntu22.04/24.04各三轮回归及语法检查成功。
- [ ] 源提交合并、正式Actions与线上脚本SHA256核对。
- [ ] 故障Node刷新脚本和升级，备份、revision、证书端口及面板连接验收。

仅脚本发布，不重建主控/Node镜像。主页不放检测和发布明细，统一记录到[功能发布专页](docs/UPDATE_IMAGE_RECOGNITION.md)。

## MR-20261008-NODE-RELAY-SOURCES（镜像已发布，服务器/视觉验收待完成）

连接方式采用原React/Chakra独立管理弹窗和原信息图标。可选择Marzban主服务器或另一台源Node中转到目标Node；保留原订阅别名、顺序、数量，只替换精确匹配的端点，不新增Relay。目标认证、设备凭据和出口不变。自转发/环路/占用/能力/精确ACK/失败回滚、来源隔离与恢复有回归测试。

管理API增加source/source_node_id/来源列表，additive迁移9012ab34cd56；Node新增managed-node-relay-v1、原认证REST/RPyC完整快照与独立转发进程。固定Xray26.3.27，原证书、控制/API端口、用户、.env与数据卷保留。首版VLESS TCP/RAW REALITY、IPv4/DNS-only入口、单跳选择，不是所有协议或任意UDP转发；每源512个配置不是吞吐承诺。

本地最终代码和独立发布副本再次复测：主控164/164、Node60/60（准备固定Xray，无跳过）、前端47/47、类型/生产构建、依赖/diff通过。干净Linux CI与两镜像双架构发布核对完成；真实跨服务器mTLS、公网吞吐、多引擎数据库、实际原组件UI截图仍待验收，不标稳定版。UI截图因浏览器策略blocked，未绕过。

主控revision 93bfbb5b17dd8ee731449976df1a4af4e0f57ca5，Actions37657985804；Node revision 7b45fc0dc3b4451045a06123b52ccdaaa5911b8d，Actions37657976968。scripts合并ed274ba82410f9e6f580cbec59b2a15a89ab81ea，Actions37657994843成功，脚本运行时不变。先在承担来源的Node运行marzban-node update，再在主控运行marzban update；仅作目标的既有配对Node不强制更新。新Node沿用仓库install，现在拉取新latest；旧机不重装、不删卷、不重复adopt。源业务入口TCP需放行，客户端刷新订阅。

[精确配对SHA、index/架构/config摘要、接口与SSH验收证据](https://github.com/kissow/Marzban/blob/master/docs/NODE_RELAY_SOURCES_RELEASE.md)。下方旧记录只描述各自日期的阶段，不代替本轮最新状态；文档[skip ci]提交不改变已核对的运行时镜像revision。


## MR-20261003-EGRESS-UDP (2026-10-03)

- [x] Paired documentation published at scripts revision `23c6dffe006eea30e117ffc86972f5fc94eab33d`; [syntax and Fork target checks](https://github.com/kissow/Marzban-scripts/actions/runs/37119329541) succeeded.
- [x] Scripts runtime unchanged: install/adopt/update, certificates, ports, data paths and pinned Xray `v26.3.27` retained. No scripts image build is required.
- [x] Panel image source `10f46df8e52ad24c79a1d4a1aafc020a7f7ad335` and Node image source `ff3ed8affb43a7c0be84b7404b25ba149cd9c805` built successfully. Both latest image architectures and OCI revisions verified; see [panel evidence](https://github.com/kissow/Marzban/blob/master/docs/EGRESS_UDP_RELEASE.md) and [Node evidence](https://github.com/kissow/Marzban-node/blob/master/docs/egress-udp-release.md).
- [x] Existing switched Fork servers use `marzban-node update` first, then `marzban update`; no repeated adopt/reinstall or volume deletion. Back up and verify existing data before updating.
- [x] Existing egress API paths/authentication retained; optional `udp_mode` and Node capability `managed-outbounds-udp-v1` documented in paired repositories. Old profiles default to legacy; TCP-only is not arbitrary UDP-to-TCP conversion.
- [ ] Actual server authenticated pairing, provider TCP53, residential exit IP, v2rayNG/Clash Meta behavior and UDP-capable provider regression accepted.
- [ ] Actual original-component desktop/mobile screenshots reviewed.
- [ ] Legacy rollback and non-DNS UDP application behavior accepted on the actual servers.

Images published and server acceptance are separate states. This checklist is not a stable-release claim. Later documentation-only commits use `[skip ci]`; they do not replace image source revisions or prior Actions evidence.
