# LPS 兼容夹具来源

合成样例由 `Apple/scripts/legacy_lps_oracle/Program.cs` 运行 NuGet LinePutScript **1.11.9** 生成，不含用户数据。源码依据为 [v1.11.9 / 69ea42f7](https://github.com/LorisYounger/LinePutScript/tree/69ea42f7f213be2669879705035a77a1804c457a)，重点为 Structure/FInt64.cs、Sub.cs、Line.cs、LpsDocument.cs；已在忽略构建目录保留源码用于核对，应用不链接.NET或该库。

重生成（需.NET 8 SDK；标准输出为JSON，首次构建日志另行保留）：
```sh
dotnet build Apple/scripts/legacy_lps_oracle/LegacyLPSOracle.csproj --configuration Release
dotnet Apple/scripts/legacy_lps_oracle/bin/Release/net8.0/LegacyLPSOracle.dll > Apple/Tests/Fixtures/legacy-lps-v1.11.9.json
```

当前生成环境.NET8.0.425、InvariantCulture。包含9组结构样例、8组实际FInt64存储/回读数值、4个Int64边界哨兵观察。结构覆盖中文/emoji、字面转义、多行延续、重复字段与根行、大小写、空末文本、缺分隔符、首个#及首个///分割、分隔符后组合字符、Unicode规范等价但原版名称不同的匹配。固定点回读并非读取原value的普通字符串，例如100对应存储100000000000。

原FInt64.ToDouble只特殊处理NaN；名为Infinity的两种哨兵在库中实际返回有限Double（约±9.22e9）。iPet纯解码明确拒绝三种命名特殊哨兵（max、max−1、min+1），保留普通min的源除法值，不猜溢出修复。非规范数字（地区分组、小数、指数、前导符号/零等）也拒绝；原库Parse有依赖Culture的后备路径，但实际ToStoreString输出规范整数。后续导入必须报告拒绝原因，不静默改数值，不声称全格式兼容。

夹具只证明结构/编码；尚不能证明宠物字段、库存参数、统计、hash或Data迁移。参见[阶段4B规格](../../docs/specs/PHASE-4B.md)。

夹具SHA-256：`98b7545f6b2d3f7bd80a3d23a84450c22b5eb2d6c98fb1c32f8e5b6b74979d5c`。每组包含实际原库Find返回值，测试比较同名首次匹配和Unicode精确匹配。

## 宠物字段夹具（阶段4C）
legacy-pet-fields.json由同一生成器加`--pet-fields`生成。DTO复制固定GameSave_VPet的序列化注解、名称和标量类型（包含protected属性与mode四值枚举），样例完整序列化后用实际库反序列化取预期值。LikabilityMax为普通double150.25，money/exp等为固定点整数；DTO不包含原增长setter、不运行WPF，升级预期仍依据原setter与PetDesktopGrowth固定回归。实际库对mode#Bogus抛ArgumentException，夹具记录该结果。
```sh
dotnet Apple/scripts/legacy_lps_oracle/bin/Release/net8.0/LegacyLPSOracle.dll --pet-fields > Apple/Tests/Fixtures/legacy-pet-fields.json
```
宠物夹具SHA-256：`ab0b27cacb7f93b961a7b05056d5e66e9d666c9be6d8a6182767768d16e5284d`。

## 完整性夹具（阶段4D）
legacy-integrity.json用同一实际库生成5组LpsDocument.ToString字节样例，以及根SHA512 ver2、旧根MD5 ver0、旧根SHA512回退ver1、旧vpet MD5四组源算法结果。MD5加权代码按原GameSave_v2逐项复制公式并明确unchecked，SHA512调用实际Sub.GetHashCode；little-endian Int64预期包括负值。样例包含中文/emoji、转义、注释、CRLF/延续及旧宠物路径优先于未知根版本。旧宠物样例的raw头部Info和尾Text为空；非空时的独立加权回归尚未补，源码审查确认实现用raw值。
```sh
dotnet build Apple/scripts/legacy_lps_oracle/LegacyLPSOracle.csproj --configuration Release
dotnet Apple/scripts/legacy_lps_oracle/bin/Release/net8.0/LegacyLPSOracle.dll --hashes > Apple/Tests/Fixtures/legacy-integrity.json
```
完整性夹具SHA-256：`15bd106e2d1ae7d0d4ccb1e70ee4a8e2e6b5a88237d96d2f064a71192324d6d0`。先确认构建成功再运行生成器，避免旧二进制输出被误用。

## 阶段4E库存序列化证据（Task 1）

`legacy-item-fields.json`由同一固定NuGet1.11.9生成，SHA-256 `8b3d752fe78f73a18db592efe2010554b277b1d921f238e3a2529459f4872aa9`。生成命令：先成功构建Release，再运行 `legacy_lps_oracle/bin/Release/net8.0/LegacyLPSOracle.dll --items`；文化固定Invariant，连续两次输出逐字节相同。DTO复制1a06c598 Item/Food的属性类型、继承、默认值与Line标注，不含WPF方法、插件或用户数据；不能代替原SavesLoad整个过程。

两个完整记录分别覆盖基类与派生食物，原对象/反序列化快照完全相同；Food未重复标注的ItemType/Star仍由实际库序列化。七个加载样例证明IgnoreCase字段能读取两种大小写，枚举Drink有效而drink拒绝，数字4映射Drink，布尔0拒绝，原始/null是null但/!null解码为字面/null。普通Double保存12.5/21.75和负效果，不能使用宠物FInt64缩放。

MainWindow.ItemsAdd（3086行）仅按Name合并Count并保留首条参数，未检查ItemType/IsSingle或效果差异；Food的LoadImageSource/LoadEatTimeSource在商店路径更新收藏/说明；库存SavesLoad调用继承的Item.LoadSource，不调用上述方法，保留序列化Star/Data。类型化Swift库存映射、冲突报告和整档导入仍未完成。

## 阶段4G统计证据（Task1）
`legacy-statistics.json` SHA-256 `3bf5ecb3e5ba6f3919ce3884c410be0ee5c837627edd25c7621824999db500ef`，同一固定NuGet1.11.9，构建成功后运行Oracle `--statistics`生成。模拟Statistics.ToSubs（SortedDictionary、null跳过、Sub(key,SetObject)）和AddRange（原info重新添加），不调用用户数据或原WPF运行时。Invariant序列化10项记录：普通Double/Int32/Int64、日期ticks、FInt64、bool、已转义文字；日期/固定点/bool/文本为codec能力例，不是已确认的原内置统计键。
原实际库读取证明：大Int64 9007199254740993转Double变9007199254740992；普通1.25整数接口截断到1，2147483648的Int32读取溢出为负，bad读Double归0；fr-FR写1,25在Invariant读取变125。未知值不能凭数字形态推测类型。Statistics.GetString保留原info转义，未自动解码（与Sub.Info便利接口不同）。重复字典键抛ArgumentException。
连续统计生成逐字节一致；items/hash/pet-fields旧夹具再生仍逐字节一致。首次C#构建因ISub.info为string误调用GetDouble失败，set-e阻止旧DLL生成；改为显式SetObject后构建/生成成功，不采用失败版本输出。
