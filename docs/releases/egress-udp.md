# 出口 UDP 与 DNS：历史发布记录

[当前说明](https://github.com/kissow/Marzban/blob/master/docs/NODE_EGRESS_UDP.md) · [历史索引](README.md)

本文按功能保留原始发布证据。记录中的「当前」「最新」「未发布」「待验收」仅指原记录形成时的状态，不能替代当前说明或新的验收记录。旧流程和旧接口描述不是现行使用指引；重复正文合并并保留来源。整理日期：2026-10-15。

## 历史片段 1

原位置：[CHANGELOG.md](https://github.com/kissow/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/CHANGELOG.md)。

---

## MR-20261003-EGRESS-UDP：配对部署文档（2026-10-03）

- scripts 仅更新文档；Bash 运行时、命令、镜像来源、固定核心 v26.3.27、证书、端口和数据路径无变化，不构建新的 scripts 容器。
- 配对主面板 `10f46df8e52ad24c79a1d4a1aafc020a7f7ad335` / Node `ff3ed8affb43a7c0be84b7404b25ba149cd9c805` 新增 `udp_mode` 和 `managed-outbounds-udp-v1`；新模式需要两边更新，先 Node 后主面板。既有 Fork 继续 update，不重复 adopt/reinstall。
- UDP DNS TCP 兼容、供应商限制和待验收项目均在 README 和两边协议文档登记；代码推送、Actions、镜像发布与服务器验收是不同状态，以配对仓库发布证据为准。

本文件记录相对 [Gozargah/Marzban-scripts](https://github.com/Gozargah/Marzban-scripts) 的新增与调整。感谢原作者和贡献者，保留上游 Git 历史与许可证。

## 历史片段 2

原位置：[RELEASE_CHECKLIST.md](https://github.com/kissow/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/RELEASE_CHECKLIST.md)。

---

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
