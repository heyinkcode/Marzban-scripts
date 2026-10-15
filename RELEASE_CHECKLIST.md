# 部署脚本发布检查清单

每次从未勾选模板开始，实际结果写入对应功能专页；[历史清单](docs/releases/README.md)只作历史证据。

- [ ] 主控、Node、scripts 影响范围与命令兼容已说明；无运行时变化的组件已明确。
- [ ] install/adopt/update 分开验证；已有 Fork 不重复 adopt、不重装、不删除数据卷。
- [ ] 保留自定义命令名、目录、镜像标签/摘要、.env、数据库、证书与端口。
- [ ] Compose 解析后的目标服务来源正确；配置读取失败、官方、其他镜像分别报告。
- [ ] 缺失/不兼容 yq、多服务、环境变量、锚点及相似镜像前缀覆盖。
- [ ] 备份、拉取、启动、刷新失败返回非零且不假报成功；敏感配置不打印。
- [ ] Windows 静态检查与 Linux 真实 Bash/Compose/tar 回归区分，跳过项单列。
- [ ] 正式工作流、源/合并 SHA、线上脚本字节已核对，必要时核对配对镜像。
- [ ] 实际故障机升级、备份和业务范围已验收；容器 Up 不等于全部通过。
- [ ] 功能文档、CHANGELOG 摘要与索引同步；纯文档不触发业务镜像重建。

[更新识别修复与已知边界](docs/UPDATE_IMAGE_RECOGNITION.md) · [跨仓库发布流程](https://github.com/kissow/Marzban/blob/master/docs/REPOSITORY_UPDATE_FLOW.md)
