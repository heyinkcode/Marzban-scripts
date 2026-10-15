# 早期开发与发布流程：历史发布记录

[当前说明](../README.md) · [历史索引](README.md)

本文按功能保留原始发布证据。记录中的「当前」「最新」「未发布」「待验收」仅指原记录形成时的状态，不能替代当前说明或新的验收记录。旧流程和旧接口描述不是现行使用指引；重复正文合并并保留来源。整理日期：2026-10-15。

## 历史片段 1

原位置：[FORK_FEATURES.md](https://github.com/kissow/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/FORK_FEATURES.md)。

---

# Mr.shaw 部署脚本 Fork

## 历史片段 2

原位置：[CHANGELOG.md](https://github.com/kissow/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/CHANGELOG.md)。

---

# Mr.shaw Marzban-scripts Fork 更新记录

## 历史片段 3

原位置：[CHANGELOG.md](https://github.com/kissow/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/CHANGELOG.md)。

---

## 开发中（尚未发布）

- 安装和更新脚本改为从 `kissow/Marzban`、`kissow/Marzban-node` 与 `kissow/Marzban-scripts` 读取文件，并拉取 `ghcr.io/kissow/` 的 Fork 镜像。
- 新增 `marzban adopt` 与 `marzban-node adopt`：已有官方安装可在原目录切换镜像，保留 `.env`、数据库、证书和 Compose 的其他配置。
- `update` 会先备份并验证原数据目录，再拉取自己的镜像；不执行 `down -v`。
- `install` 遇到已有目录会退出，防止覆盖现有配置和用户数据。
- 手动 `backup` 不再清空整个旧备份目录，每次使用独立临时目录。

发布前仍需在隔离 Linux 服务器验证 SQLite/MySQL/MariaDB 的数据保留、Node 证书、镜像拉取和 `marzban update` 的实际行为。

## 历史片段 4

原位置：[RELEASE_CHECKLIST.md](https://github.com/kissow/Marzban-scripts/blob/21a85bfebbc6be49c8508ef2f35af639ee2cafff/RELEASE_CHECKLIST.md)。

---

# Mr.shaw deployment release checklist
