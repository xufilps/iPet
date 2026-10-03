# 阶段4F：原生库存参数持久化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让原生库存保存并使用独立物品参数/标记，不因当前目录变化丢失旧效果，为Windows整档导入建立持久化基础。
**Architecture:** PetInventoryMetadata保存数量以外的Item/Food参数和标记；数量仍由PetState.inventory唯一管理。可选metadata按库存ID保存，解析优先库存元数据、未存在则旧目录回退。商店购买始终读取目录，入包不覆盖已有元数据；Food使用沿现有规则并每件消费。JSON v9安全迁移v1…v8，原件保留，未来根/嵌套版本保护。UI接入库存参数、可用/可见/收藏，独立配置与商品目录不混淆。
**Tech Stack:** Swift6/Foundation/Codable、macOS SwiftUI，既有JSON原子保存与实际原LPS夹具。
**Spec:** 本文及固定1a06c598 Item/Food、MainWindow.ItemsAdd/TakeItem、MainWindow.xaml.cs 350行Food UseAction、winInventory.xaml/.cs。

## Global Constraints
- 数量唯一来源inventory；metadata不能持有第二个可变化数量。同名冲突不由本批自动导入处理，保留4E记录/诊断。
- 基础Food实际每次Consume一件，不因IsSingle免消费；CanUse控制原生使用入口，Visibility控制列表；其它ItemType保留但不能执行原C#行为。
- 原版冷却按名称，而本机目前按ID；本批不偷偷合并不同ID冷却，导入buytime映射另核对。
- 图片/Graph原来源文字保留但不作为本机文件路径读取；实际渲染仅使用已校验的本机相对资源路径，缺图不显示白块。
- main上游镜像、原README7775字节/许可不变；用户原存档/原素材不改，压力/阶段6留后。

## 接口与边界
PetInventoryMetadata为Codable/Equatable/Sendable，version=1，保存name/itemType/price/image/description/data/canUse/star/isSingle/visibility及可选Food参数（复用4E Food的Codable表示）。init(legacy:)忽略数量；validate()拒绝未知元数据版本、非法参数/空名称/类型及超过原生承载边界的字符串，不截断。普通负价格可保留，商店价格准入仍沿当前目录。source image只是数据，不访问路径。
原生名称/type最多300字符，描述/Data/Image/Graph总UTF8不超过8MiB；Food效果有限abs≤1e12，Exp为Int32，类别仅原八种。保存全档仍16MiB导入/导出上限；批量元数据条目最多10000，ID遵循现有库存≤300字符。
PetState可选inventoryMetadata字典用于向后解码；解析未知metadata存在时不能回退成同ID目录食物。旧档v1…v8不允许携带新字段冒充旧格式，v9要求growth。未来nested metadata版本必须阻止主档/备份/导入覆盖，不当普通损坏回收。

## Review Focus
- 同ID目录改动、商店买入/即用、库存使用三条路径不能串用旧参数或覆盖新参数。
- unknown ItemType及CanUse=false不得执行Food效果；Food IsSingle=true仍单件消费，失败不得扣款/扣件。
- 元数据无数量双份；最后一件消耗后元数据保留策略须明确，后续同ID入包可更新为新目录参数，不复活旧效果。
- v8→v9原件/旧版本合法性及未来嵌套版本保护，主/备份/恢复覆盖均需测试。
- 库存收藏/可见与本机旧收藏偏好正确合并，未知/不可见条目仍保留且价值统计不随过滤变化。

## Task 1：可保存的物品元数据
- [x] 先写PetInventoryMetadataTests，观察RED；实现纯元数据类型与4E Food的Codable/Equatable，不改变当前PetState/版本/运行时。
- [x] 用原库记录验证Codable往返、全部参数/标记/Data保留、数量不进入JSON、未知类型、负价、非法/未来版本及字符串边界。

## Task 2：v9与使用规则
- [x] RED后接入PetState metadata/解析器、版本v9/原件迁移保护和元数据未来版本错误；测试当前v8迁移、v1…v7保持已有增长转换，future10及nested保护各写路径。
- [x] RED后接入库存解析/逐件使用，商店购买继续catalog。验证同ID不同效果/目录变更、拒用/未知、标记、最后一件与再购、保存后重启一致和失败事务回滚。

## Task 3：原生UI与交付
- [x] 库存查询/显示/价格/动画/批量入口使用库存解析，商店保持目录；收藏在存档元数据中持久化，旧本机偏好兼容。JSON恢复摘要准确区分可用/未知。
- [x] 源码对照/README/交接/恢复说明；全套Swift/Python/macOS/iOS共享编译/签名、工程再生/许可原文检查，独立6.1-sol整批审查和必要一次RED→GREEN修复，推送ipet-dev。

## 回滚
Task1纯类型可直接回滚；v9接入后退出并备份整个存档目录，移开v9主/previous，恢复独立v8-before-upgrade原件；不得只编辑版本头冒充旧档。v9原件保留但旧版不读取。WindowsLPS完整导入仍需统计/Data/主人映射及双原件确认流程，不因元数据能保存而开放半档导入。

Task1检查点：纯PetInventoryMetadata与Food Codable/Equatable已实现，5项新增回归RED→GREEN。PetState/实际存档仍v8；没有导入或运行时切换，也不表示v9已完成。下一步Task2接入状态、未来嵌套版本保护及原件升级，再验证购买/使用不同路径。

任务2/3实现裁定：旧本机收藏与保存Star取并集，未有metadata的未知旧ID仍只有本机收藏；已有v8库存无历史参数则目录回退，新入包或已知收藏操作才冻结当前参数。Food源Data保留，倍率动态显示；原名称冷却与本机ID冷却差异保留。resourceImagePath是独立安全本机相对图片，源Image不赋予访问权。无法精确表示Int32经验的目录入包拒绝而不扣款。审查两项Important一次RED→GREEN修复，摘要准确性按绑定规格同批修正。

最终交付验证：363 Swift/23 Python/macOS Release/iOS共享模块/严格签名通过，原文与许可/工程再生/链接及diff检查通过。没有Windows整档导入、真实UI/压力或阶段6完成声明；回滚v8依上述独立原件合同。
