# 2026-10-23 分发命名空间迁移（已发布，服务器待验收）

## 范围和顺序

GitHub 所有者改为 heyinkcode；当前安装、更新、源码和构建链接同步。上游来源不变；历史 GHCR 镜像名和摘要保留为当时证据。主控/Node API、数据库、用户、证书、端口和 Xray v26.3.27 不变。旧 Fork latest 可由新版脚本验证并切换新命名空间，固定旧标签/摘要不擅自换 latest。

先上传并通过 PR 检查，发布主控/Node 镜像并匿名核对双架构制品，再于 2026-10-23（香港时间）合并 scripts PR7。最后用纯文档提交回写证据；纯文档不重建镜像，不改变镜像运行时 revision。

## 代码、CI 与脚本

| 仓库 | PR 与源提交 | 正式合并 / Actions |
| --- | --- | --- |
| Marzban | [PR26](https://github.com/heyinkcode/Marzban/pull/26)，7cecced5d74dd42a2372b95501b789cc4b82ee22 | ac566ff59aa9d79438b56931feba785ad469b688 / [39873094619](https://github.com/heyinkcode/Marzban/actions/runs/39873094619)，成功 |
| Node | [PR9](https://github.com/heyinkcode/Marzban-node/pull/9)，ed4f254b5720c3404ebdc30a7dab63a0ac685def | 46d473cbf9e06f9a35bc9e06a8db7f30efd417b4 / [39872894882](https://github.com/heyinkcode/Marzban-node/actions/runs/39872894882)，成功 |
| scripts | [PR7](https://github.com/heyinkcode/Marzban-scripts/pull/7)，8e2f5a9d6b99b6084e2bcd0ffb09401bca6bbd65 | 7e34ca6caeea1c4fc79e496393785839c114d049 / [39874550440](https://github.com/heyinkcode/Marzban-scripts/actions/runs/39874550440)，成功 |

本地固定 PS7/项目 Python + Xray v26.3.27：主控 226/226、Node 82/82、前端 65/65 各三轮无跳过；TypeScript、Vite 生产构建及 diff 检查通过。仅改前端项目链接常量，不改原组件布局、样式或交互。

脚本本地 6 项静态通过、44 项 Linux 专项明确跳过；PR 最新两次检查 39873308589/39873315797 及正式 Actions 均在 Ubuntu22.04/24.04 各执行三轮 50/50，无 Linux 跳过。包括真实 Compose 环境变量/锚点/引号、其他服务/端口/数据目录保留、预拉取失败、启动及恢复失败、固定摘要拒绝和文档原样一键命令的成功/下载失败/安装失败。此前 47 项检查后补加一键命令 3 项，最终版本已重跑。

两个公开 raw 脚本与本地 Git 源对象、API blob 和 SHA256 字节核对一致：

- marzban.sh blob 272ec12ade250875123c939522aa54ea6f37a3bf；SHA256 7090ffe539118e9ef1d538d8f1e8fe0d3a04b0fd151dffa482b3a4ba4535fc52。
- marzban-node.sh blob 72199322477ebf4579b1851352a9be9a669005c4；SHA256 fa0ffece45fbc5df70d066a3854ebbd7a2a69b50ccbc0ec5ec6d2ace64dbb761。

107 份用户文档、1135 个引用的路径、目录锚点和导航可达性通过；首页仅同步产品/安装地址，不添加发布长文。本地三个共享 origin 已切换，GitHub CLI 登录 heyinkcode 且新地址 fetch/push 实测成功；不修改凭据文件或全局 Git 授权，不把 URL 改动当成独立 OAuth 重新授权。
## 已公开镜像与匿名制品核对

- ghcr.io/heyinkcode/marzban:latest；index sha256:e079a278d85fbbf77dd31365165230fd067e98d843d1d37dba6f539b0b1666fc；OCI revision ac566ff59aa9d79438b56931feba785ad469b688。
  - linux/amd64 manifest sha256:502c888b85f95d8bfa7b7eab715c4d541cd5fa8951e636f6a5af10d0c426b5a7；config sha256:2f6dd8ebe1249be89a936e68e00132488e49bb2bd734d05650e13d5617ebb893。
  - linux/arm64 manifest sha256:03b27fa63a51dce60e4fe0cdb230f2824cd7f17fb526b61a3000ea64b2a33cc6；config sha256:c8dd869362c19c103761af50162025ff3b8c30e474bfd9b692c68d9332b59279。
- ghcr.io/heyinkcode/marzban-node:latest；index sha256:3de6c849962c1e53be86e9d856d301e6a55f9c6a04026a59dc8988d799e33ca3；OCI revision 46d473cbf9e06f9a35bc9e06a8db7f30efd417b4。
  - linux/amd64 manifest sha256:17ac1e9566db76a57dedec464483eaa49b4befedd22395574a6bb3182bb406d8；config sha256:0c0ccbf0f7bfd38380dc1540c01f6f24a39dbe02360a00521c348eb3a15792cc。
  - linux/arm64 manifest sha256:1e8656bcaf7b6171821716c01a04b150fad19e0b623e0da8892fe532d2813186；config sha256:a18aea4743e7ea3403ad51c9ebfa5901d35f4fa79b259aa4aa8128b9c328df2c。

匿名 GHCR token、index、双架构 manifest/config 原始字节摘要及 revision 均核对，latest 前后稳定；两包 visibility=public，已有服务器不需要新增仓库凭据。

## 生产服务器验收

本轮未登录或更改生产服务器。已部署的旧 CLI 必须先从新地址刷新再 update；迁移说明及一键命令见现行指南。新部署直接用新地址 install；不能把仅下载脚本、容器 running、CI 成功或镜像发布当作服务器已更新。

仍需各服务器确认：升级前备份、命令退出码、实际容器镜像/revision、原用户/订阅、证书/端口、Node 控制连接及业务出口。更新有正常备份和容器切换停顿。失败保留旧 Compose 和备份；恢复失败明确报告，不重装、不删卷，不擅自解除固定版本。
