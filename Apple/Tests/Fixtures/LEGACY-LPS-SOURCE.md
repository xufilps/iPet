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
