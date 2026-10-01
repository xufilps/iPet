# iPet 图标与还原路线实施计划 — 2026-10-01

本轮交付：原创小宠物头像、macOS AppIcon接入、原版差异矩阵、分阶段还原路线与README入口。养成接口、存档格式和功能不变；阶段1–6仅作后续规划，不在本轮实施。

## 图标
imagegen生成圆脸短耳、温暖白色小宠物，湖蓝圆角背景、柔和阴影，无文字/Windows/Apple标志。展示正式候选后检查1024PNG母图及16/32/64/128缩略图；记录生成来源，保留原vpeticon和授权。Apple/Design保存母图及说明；Apple/Resources/Assets.xcassets添加AppIcon，资源变更同时进入工程生成脚本。

## 文档
Apple/docs/UPSTREAM_COMPARISON.md以原版1a06c598和当前iPet为基线，记录原版/iPet行为、原因、六种状态、源码依据和阶段。Apple/docs/ROADMAP.md使用0–6阶段：品牌基线、稳定性、养成经济、动作界面、数据兼容、扩展集成、iOS发行。先尽量还原Windows原版，再推进iOS；插件/Steam/工坊单列研究，不承诺直接兼容。每阶段有成果、验收、依赖、兼容和回滚要求，无虚构日期。

## 验证和交付
检查母图/所有AppIcon尺寸、小尺寸辨识度、工程重新生成一致、AppIcon进入产物、Finder显示、16项测试、macOS构建、iOS模块编译和签名。保持原README后缀与LICENSE字节一致；保留素材授权。提交阶段检查点，以普通push推送origin/main并核对远端SHA。真实两小时/多屏/睡眠等待验内容继续明确标记。回滚图标与文档提交可恢复旧配置，原项目图标、素材和用户存档不删除。
