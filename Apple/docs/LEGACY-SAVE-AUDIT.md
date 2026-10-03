# Windows LPS 旧存档迁移前审计 — 2026-10-03

固定源头：上游1a06c598；本文件记录源码证据和迁移依赖，**当前尚不能导入Windows LPS**；阶段4B/4C已提供有原库合成样例验证的解码及只读宠物字段候选。现有“从JSON恢复”只处理iPet JSON。阶段2B已纠正桌面养成运行时与JSON升级；下一步仍须核对LPS数值编码和原字段，不能直接把资源转换器当存档解析器。

## 实际加载路径与差异
MainWindow.SavesLoad创建GameSave_v2（或叠加已有旧数据），取其GameSave_VPet并赋给Core.Save。GameSave_v2.load读取vpet和statistics，将其余LPS放入Data；保存ToLPS写Data、GameSave.ToLine、statistics及hash。MainWindow保存把Items逐项序列化为item0、item1…，读取按item前缀重建。项目使用LinePutScript1.11.9；其ConvertType.ToFloat使用FInt64，**不能在尚未核对编码前把Info直接当普通十进制Double**。

桌面GameSave_VPet.Exp是剩余经验，Level和LevelMax另存；旧共享GameSave.Exp是累计经验、Level=sqrt(Exp)/10+1。阶段2B已让iPet采用前者，并实现v1～v7累计经验到v8剩余经验的迁移。新建金币100，旧iPet余额保留；运行时状态、活动资格、统计、文字和界面已接入动态上限。LPS解析/导入尚未实现。

## 字段映射与依赖
| 原字段/行 | 原含义与源码依据 | 当前iPet / 必须完成的映射 | 状态 |
| --- | --- | --- | --- |
| vpet/name、hostname | 宠物名、主人称呼，GameSave_VPet属性 | 名称/主人称呼可只读预览；原生主人字段与界面仍未接入 | 部分实现 |
| vpet/Level、LevelMax、exp | 等级/突破次数/当前级剩余经验；setter可连续升级且负值不降级 | 原生模型/v8及LPS字段预览已实现；没有整档导入 | 部分实现 |
| vpet/strength、strengthFood、strengthDrink、feeling | 受随等级/突破增长的StrengthMax/FeelingMax约束 | 原生动态上限/历史保留与LPS字段预览已实现，不静默截断 | 部分实现 |
| vpet/health、likability、LikabilityMax | 健康0…100、好感及独立历史上限 | 原生独立上限及LPS普通Double字段预览已实现；缺项保留Exp增量 | 部分实现 |
| vpet/StoreStrength、StoreStrengthFood、StoreStrengthDrink | 缓释队列，可含负值 | 固定点字段/负值/边界已在合成LPS预览验证，源字节保留 | 部分实现 |
| vpet/money | 钱包，ToFloat编码 | 固定点钱包预览保留原值，非法数值阻断，原溢出补偿未迁移 | 部分实现 |
| vpet/mode | 保存的原可变模式 | 原模式名读取与重算差异已报告；未知名称阻断 | 部分实现 |
| itemN | Item/Food包含name、count、itemtype、参数及Star/Data/CanUse等 | 已有只读完整参数/标记/Data预览和同名冲突报告，v9已支持原生参数持久化/使用；尚无整档确认导入 | 部分实现 |
| statistics | SortedDictionary统计键/SetObject及多种值类型 | counters仅有限Double；日期/字符串、原名称键映射和重复键需单列 | 待实现 |
| Data中的套餐/排程/日期/自定义值 | GameSave_v2保留未识别行，插件可扩展 | 必须逐项核对结构，不能仅转vpet就宣称完整旧档兼容 | 待审计 |
| hash（ver=2）及vpet/hash旧路径 | 原完整性/反修改标志，两种hash路径 | hash不是存档总版本；不能忽略后声称验证成功，阶段4D已实现原根SHA512/MD5及宠物MD5，范围与缺失/不匹配/不支持状态明确 | 已实现只读校验 |
| 原溢出修复与round标志 | MainWindow对极低Exp/Money及旧溢出补偿会改数值 | 一次性导入预览须明确解释，未核对统计/编码时不能自动套用 | 待审计 |

## 导入门槛与恢复合同
先完成桌面模型运行时接入与iPet旧JSON升级，再用与LinePutScript1.11.9一致的序列化样例证明字符转义、换行、浮点/整数/布尔及重复字段行为。不得读取用户文件猜格式；测试使用合成固定样例并记录生成依据。多角色和第三方MOD尚无加载接口，不在数据导入时执行C#或插件内容。

UI先只读预览，列出准确保留、明确转换、未支持内容、原hash检查状态及是否存在溢出修复。确认后保存当前最新内存JSON、独立保留其原件及完整LPS源字节，再写新版JSON；任何解析/备份/保护未来版本失败不得发布新运行状态。不修改所选原LPS，不自动扫描Windows目录，不补算离线状态。回滚保留整个Application Support目录和导入原件；新版JSON格式变更必须提供上一版本原件与恢复路径。

## 可追溯源码
- [GameSave_v2](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/GameSave_v2.cs)：load/ToLPS/hash/Data。
- [GameSave_VPet](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/GameSave_VPet.cs)：属性、Exp/LevelUpNeed/CalMode/ToLine。
- [MainWindow](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/MainWindow.cs)：Save的item序列化、SavesLoad赋值及溢出修复。
- [Item](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Mod/Item.cs)、[Statistics](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Statistics.cs)、Interface.csproj的LinePutScript1.11.9引用。
- [本批规格](specs/PHASE-2A.md)、[PetDesktopGrowth](../Sources/PetCore/PetDesktopGrowth.swift)、[回归](../Tests/PetCoreTests/PetDesktopGrowthTests.swift)。

## 阶段4B：已验证的解码合同
固定LinePutScript1.11.9标签69ea42f7，实际NuGet库生成9组结构及8组FInt64数值样例。规范浮点存储为Int64/1e9，不按普通小数猜测；名称采用原版ordinal首次匹配，保留重复字段和行，转义在切分之后按源顺序解码。原库命名Infinity哨兵实际ToDouble为有限值，iPet明确拒绝三种命名特殊值及非规范/地区相关数字，后续预览需报告，不自行套溢出补偿。
[PetLegacyLPS](../Sources/PetCore/PetLegacyLPS.swift)限制8MiB、10000行、每行2000子字段，UTF8/BOM及源CRLF/延续规则已验证；[夹具来源](../Tests/Fixtures/LEGACY-LPS-SOURCE.md)保留生成器/哈希。解码层不映射PetState，不写档，不等于导入或通用MOD支持。下一批仍需原字段、库存参数、统计/Data/hash映射及完整预览/备份/发布流程。

## 阶段4C：宠物候选与未支持项诊断
[PetLegacySavePreview](../Sources/PetCore/PetLegacySavePreview.swift)保留完整sourceData/document，提供petState宠物子集、hostname、保存模式及最多200条诊断/额外计数，没有整档确认/保存API。真实库DTO样例证明字段编码，缺项默认依据原类初始化；LikabilityMax仅存在时覆盖Exp增长后的上限，缺项保留增量。原IgnoreCase仅strength/StoreStrength适用，其余严格匹配；重复匹配字段/根行明确阻断候选，非规范模式拒绝。库存、统计、hash及其它根Data全部列为未迁移，不用同名目录替换参数。主人称呼尚未接原生持久化/UI，预览核心也未接窗口。下一步完整库存/统计/Data/hash映射后才能定义整档导入合同。

## 阶段4D：原hash路径与范围
[PetLegacyIntegrity](../Sources/PetCore/PetLegacyIntegrity.swift)核对旧宠物MD5加权（仅宠物、优先）或根hash移除后的库序列化（ver2 SHA512；旧0/1 MD5后SHA512回退）。文档canonicalString按原StringBuilder序列化，不直接hash磁盘CRLF字节；字段顺序、原转义与注释按源处理。结果明确verified/mismatch/missing/unsupported、路径、范围及原值/计算值。仅宠物匹配不证明其它根行，缺hash不声称通过；-1标记仍按源算法比较。未知版本和重复路径明确不支持。
只读预览已接该结果；不匹配/不支持为blocking，缺失/仅宠物范围明确说明。尚无整档确认写入，不修改源LPS，不把hash当来源签名；JSONv8与正式数据不变。库存参数/统计/Data/套餐/排程及主人称呼持久化仍未迁移。

## 阶段4E Task 1：库存编码及合并审计
实际库库存样例和来源见[夹具记录](../Tests/Fixtures/LEGACY-LPS-SOURCE.md)。物品普通Double与宠物固定点编码不同；Food继承序列化ItemType/Star有效，数字枚举4等价Drink，大小写错误枚举和布尔0拒绝，null图片与字面/null可区分。原ItemsAdd只按名称累加数量并保留首件参数；导入预览必须保留原记录、报告同名参数冲突，不能用当前商品目录覆盖。原库存加载保留序列化Star/Data；商店目录另从设置/buytime更新收藏与说明，单个旧档不能证明独立收藏设置迁移。Swift类型化映射、冲突预览和导入窗口尚待Task 2，不改变JSONv8。

阶段4E类型化库存核心已实现，详见[规格](specs/PHASE-4E.md)和[PetLegacyInventoryPreview](../Sources/PetCore/PetLegacyInventoryPreview.swift)。原有只读原件保护保持，未发布新运行状态。

## 阶段4F Task1：原生元数据模型检查点
[PetInventoryMetadata](../Sources/PetCore/PetInventoryMetadata.swift)可Codable往返保存数量以外的旧物品参数，保留普通负价、收藏/可用/单件/可见标记、Image和Data及Food完整效果。数量只由inventory拥有，不在此模型重复保存。未知类型仅作为数据保留；原图片/Graph为不执行的来源字符串，不授权读取任意路径。原生承载上限、已定义类别/Int32经验和未来嵌套版本通过显式validate检查，失败不截断。5项新回归通过；PetState/实际JSON仍v8，元数据尚未进入正式保存/使用。Task2将接v9原件升级与版本保护，Task3接原生UI；详见[规格](specs/PHASE-4F.md)。

阶段4F已接v9库存参数持久化与使用，保存/恢复的输出大小及未来嵌套版本在改文件前校验。统计/Data/主人与完整LPS导入仍待实现，源档不写；回滚须用独立v8原件，不改版本头。详见[规格](specs/PHASE-4F.md)。
