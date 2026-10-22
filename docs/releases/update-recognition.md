# 更新镜像识别：历史发布记录

[当前说明](../UPDATE_IMAGE_RECOGNITION.md) · [历史索引](README.md)

本文按功能保留原始发布证据。记录中的「当前」「最新」「未发布」「待验收」仅指原记录形成时的状态，不能替代当前说明或新的验收记录。旧流程和旧接口描述不是现行使用指引；重复正文合并并保留来源。整理日期：2026-10-15。

## 历史片段 1

原位置：[FORK_FEATURES.md](https://github.com/heyinkcode/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/FORK_FEATURES.md)。

---

## 安全更新识别

update按Docker Compose解析后的目标服务镜像检查Fork来源，不依赖yq、不误用其他服务或运行中容器的镜像。读取失败明确停止，失败阶段不报成功；已有Fork不重复adopt。合同、边界和发布状态见[更新识别说明](../UPDATE_IMAGE_RECOGNITION.md)。

基于 Gozargah/Marzban-scripts 的开源扩展，保留上游历史、作者致谢与许可证。提供 Fork 镜像的一键install、原安装adopt与保留数据update；不使用重装或删卷来更新已有服务器。

## 历史片段 2

原位置：[CHANGELOG.md](https://github.com/heyinkcode/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/CHANGELOG.md)。

---

## MR-20261015-UPDATE-RECOGNITION（脚本已发布，故障机验收待完成）

修复update因缺少/不兼容yq误报官方镜像；主控和Node使用相同的目标Compose服务只读识别，保留标签、摘要、备份和原安装。识别失败与官方/自定义镜像分开报错，阶段失败明确中止。仅脚本，无业务镜像/API/证书/端口变化；测试与发布见[专页](../UPDATE_IMAGE_RECOGNITION.md)。首页只留产品与文档导航，历史维护记录迁入docs。

## 历史片段 3

原位置：[RELEASE_CHECKLIST.md](https://github.com/heyinkcode/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/RELEASE_CHECKLIST.md)。

---

## MR-20261015-UPDATE-RECOGNITION

- [x] 主控/Node更新识别统一，update不依赖yq，数据/证书/端口/标签与摘要保持。
- [x] 新增静态合同与Linux真实Bash/Compose/tar回归；Windows只运行静态项，明确跳过Linux项。
- [x] Ubuntu22.04/24.04各三轮31/31回归、真实Compose/tar与语法检查成功；分支38692092775、PR38692104130、正式38692284027成功。
- [x] PR3源e881580e合入a26b6af3，原始master脚本与Git blob及SHA256核对；完整摘要见专页。
- [ ] 故障Node刷新脚本和升级，备份、revision、证书端口及面板连接验收。

仅脚本发布，不重建主控/Node镜像。主页不放检测和发布明细，统一记录到[功能发布专页](../UPDATE_IMAGE_RECOGNITION.md)。
