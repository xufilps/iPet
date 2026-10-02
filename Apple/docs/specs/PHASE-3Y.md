# 阶段3Y：活动收藏与检索 — 2026-10-02

来源：原版1a06c598的winWorkMenu.xaml.cs 71、107—108、277、315—331行，收藏由work_star按Work.Name持久化，另有收藏类别及菜单入口。本批在现有原生活动页增加按名称搜索、类别筛选、只看收藏、默认/名称/时长/等级升降序；收藏使用目录稳定ID存本机UserDefaults，测试模式不读写正式偏好，不进入JSON v4。默认保持目录顺序，筛选/排序不改变当前会话；空列表显示明确提示，仍展示暂停/继续/结束入口。开始按钮沿现有等级/生病限制并明确关闭养成不可开始。不实现排程、DIY、任务套餐或跨机收藏。

实施文件：PetActivityQuery.swift纯核心查询及测试；ActivityView.swift筛选工具和收藏按钮；AppModel.swift收藏持久化；README及行为、矩阵、路线、交接同步。无需新增应用源文件，核心按Swift Package自动发现。先固定输入验证筛选组合、同值ID稳定排序、所有排序方向、无结果与不修改目录，再接UI；完整Swift/Python、macOS/iOS编译、签名、工程重生成及原README/LICENSE字节完整性检查后提交推送。真实页面检查与压力留最后。回滚代码及本阶段本机favoriteActivities偏好，不触及正式存档。

## 同批Windows存档审计结果

GameSave_VPet.cs 48—75、125及133—273行：原Exp为当前等级内余量，升级需求200*Level-100，LevelMax扩展等级机制；当前iPet累计经验sqrt(exp)/10+1仅普通无扩展等级可用100*(Level-1)^2+Exp转换，不能直接复制Exp。原体力/饱腹/饮水上限StrengthMax和FeelingMax随等级增长，iPet当前上限100；原LikabilityMax独立存储，iPet推导上限。原GameSave_v2.load含哈希/版本和Data根字段，不能把资源转换器正则当完整存档解析器。本仓库无实存档样例，未验证转义和类型序列化，不接入猜测型LPS导入。后续4B须先形成实际导出样例和明确拒绝/转换/损失报告，再开放确认导入；原件始终保留。当前JSON恢复保持现状。
