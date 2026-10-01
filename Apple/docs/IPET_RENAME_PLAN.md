# iPet 更名与 GitHub 发布计划 — 2026-10-01

目标仓库 https://github.com/xufilps/iPet，默认分支 main，目前基线1a06c598。将已完成的 Swift 原生版统一命名 iPet，不改动原C#工程与素材。范围包含应用/菜单名称、Swift Package名、Xcode工程/scheme、构建/验证脚本和文档；PetCore/PetRendering模块名保留。

根 README 新增详细的中文 iPet 说明，完整原 README.md 原始字节追加在末尾并验证；原多语言README保留。LICENSE原文不变，新增NOTICE说明派生关系与修改，保留并随应用打包原代码许可证、素材来源与动画图片授权；原作者及原作品名称保留。

保留已有VPetApple存档目录防止丢失旧数据。新bundle ID为org.xufilps.iPet，仅对未设置的偏好导入旧bundle偏好，原值不删除。生成资源、构建产物与DS_Store不推送。代码标注派生修改说明。

验证：全套16项测试、macOS Release构建及签名、iOS Simulator共享模块构建；检查原README后缀字节相同及原LICENSE哈希相同；审查名称/链接/授权，无secret与生成二进制入暂存区。检查GitHub main仍为已确认基线后，普通git push HEAD:main（不得force），并核对远端SHA与README。

先提交计划，再提交更名与文档。保留原origin为source-fork，origin指向iPet。回滚可通过revert更名提交恢复，存档目录与原文件不受更名影响；不创建Release、PR或商店发行。
