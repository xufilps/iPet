# 第五阶段扩展与生态研究 — 2026-10-02

本结论针对原版基线 `1a06c5981330564bab05a098d2d7969a4b119dd3` 与 iPet v0.2.0 当前实现。研究说明接口、依赖和保留限制，不代表已经接入 Steam、工坊、云端、联机或 C# 插件；以下候选架构均为提案。当前养成、排程、统计、快捷配置和报告独立本机运行；用户点击链接会交给系统浏览器，不应将此表述为应用绝无网络行为。

## Steam 身份、统计与成就

原版 [MainWindow.xaml.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/MainWindow.xaml.cs) 94/96 行初始化 Demo/正式 AppID 2293870/1920960；[MainWindow.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/MainWindow.cs) 将部分统计同步到 Steam，`eval_*` 属于本地记录。iPet保留本机计数，未提供 Steam 登录、成就或排行榜，不借用原 AppID 或声明原用户授权适用于新应用。

技术上不是“Steam不支持Mac”：官方提供同时包含x64/arm64的 `libsteam_api.dylib`，要求链接和随包复制；接口使用前必须初始化成功，AppID、客户端和用户许可证状态属于初始化条件。[Steamworks API](https://partner.steamgames.com/doc/sdk/api)。候选方案是单独可选的C/C++桥接模块，不能把Windows DLL放进Swift工程当作实现。未下载SDK、验证账户、配置应用或执行客户端测试；SDK分发条件和iPet独立应用权限仍须单独确认。

未来接入门槛：明确应用与发布权限、确认SDK条款/版本、验证回调生命周期与退出、区分本地统计和远端成就；客户端未启动、未登录、拒绝或断网时继续本地养成，明确显示集成不可用。身份与票据不写入宠物JSON、快捷目标或诊断报告，服务端密钥不打进应用；计数上传须去重，不能在失败重试时重复奖励。此为保留限制，不是完成了Steam适配。

## 工坊与数据型 MOD

原版 [CoreMOD.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/Function/CoreMOD.cs) 加载数据目录和代码程序集，[winGameSetting.xaml.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/WinDesign/winGameSetting.xaml.cs) 包含工坊上传/条目操作。iPet仅转换选定内置配置，运行时不加载第三方LPS；下载目录不等于内容兼容，照片、字体、主题、代码插件有各自依赖和许可。

官方工坊接口提供订阅、查询、安装通知及本地安装位置；下载成功回调和运行应用ID需要检查。[工坊实现指南](https://partner.steamgames.com/doc/features/workshop/implementation)。可先做阶段4的独立本地数据导入，再研究可选工坊来源。需建立内容类型/版本清单、来源署名、路径与资源大小校验、冲突优先级、缺失依赖和禁用回滚；不自动执行DLL。未经验证的第三方作品不随iPet重新分发。

工坊断网/更新损坏/取消订阅时使用上次已验证本地副本或显式禁用内容，保留存档中的未知ID并报告，不能自动改成其它商品或收取第二次费用。尚无下载、订阅、发布、工坊登录或验证样例；不修改用户Steam目录。未来需要AppID/访问权限和实际MOD样例，不能承诺跨应用工坊生态兼容。

## 云存档与多设备

原版MainWindow.cs352...367写 `VPetCloud/Save{PrefixSave}_*.lps`，原 [winSaveManager](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/WinDesign/winSaveManager.xaml.cs) 枚举/读取 SteamRemoteStorage。iPet为JSON v7、独立快捷v2和本机偏好，不直接覆盖LPS或把窗口坐标当通用养成数据。现有原子保存、导出和确认恢复是本机替代，尚无自动云同步。

Steam Cloud需要应用侧路径配置或API读写，用户也可以关闭同步；不能因存在JSON文件就认定已获得云能力。[Steam Cloud](https://partner.steamgames.com/doc/features/cloud)。候选协议需先设计档案ID、内容版本/修订、设备无关字段、冲突双副本与用户选择。未来提供者可为独立Steam模块或其它经单独规格化的服务，未选择/实现CloudKit或自建服务。

离线时只写本机，重新联网后不能仅靠最后修改时间静默覆盖另一端；保留原件、未来版本拒绝写、恢复日程保持暂停、不补算离线状态。账号退出/换号、容量不足、同时编辑、失败重试、跨时区及旧格式转换必须有固定样例。凭据不进入存档或仓库；远端恢复前仍需本机检查点，关闭提供者不删本机档。

## C#代码插件与原生扩展

原 [MainPlugin](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/MainPlugin.cs) 持有IMainWindow并提供LoadPlugin/GameLoaded/EndGame/Save/Setting/LoadDIY生命周期；CoreMOD.cs395...410通过Assembly.LoadFrom/反射创建派生类型，且含证书/信任检查。TalkBox和大量接口直接引用WPF。WPF只运行于Windows，.NET可跨平台不使这些UI程序集变成Mac控件。[Microsoft WPF说明](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/overview/)。

iPet不兼容C# ABI、WPF界面、CLR事件或这些插件的私有存档；数据型MOD不等于代码插件。可选研究方向为版本化声明式命令/事件协议、显式权限的新Swift扩展，或独立进程RPC；它们都要求插件作者适配，不承诺运行旧DLL。嵌入CLR也不会自动解决WPF和原IMainWindow依赖，目前未做桥接原型。

未来扩展应只通过核心事务改变金币/物品，不直接共享可变状态；保存钩子需确定顺序、超时和异常隔离，退出/崩溃不影响主档原子保存。插件身份、数据来源和许可独立记录，未知/失败插件可禁用并保留数据；新权限与签名方案未实现，不能声称通过原认证。此为独立研究限制，不能阻塞基础养成。

## 联机、网络聊天与反馈

原MainWindow.xaml.cs的GetVPetRoom向上游服务发送Steam身份及验证键；MutiPlayer具有好友/房间和外部资源加载路径。原 [TalkBox](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/TalkBox.xaml.cs) 是WPF抽象插件接口，Responded由具体实现提供，不能据此称原内置全部AI服务已迁移。iPet只有本地671条文本及对应效果，无房间、好友联动、AI服务或网络聊天。

保留离线文本与本机报告作为当前替代。未来需明确服务所有者、协议/账号授权、配额与数据处理，先建独立网络客户端、取消/超时和认证边界；不复用上游验证键或擅自向原反馈服务发送iPet数据。用户单独选择提供者并配置密钥，密钥使用系统凭据存储且不导出；聊天文本、截图或存档不能因打开界面而上传。未选择服务、实现Keychain存储或验证任何上游服务接口。

断网/认证失败/费用或配额不足必须退回本地入口，并保留未发送文本；流式取消不得重复应用状态奖励，远端互动不能绕过事务/存档规则。此为候选方案，尚无协议、服务和真实客户端测试。阶段5J报告只本机导出，无上传、联系信息或Steam身份收集；原Steam反馈中心不复用。

## 图库资源与授权边界

不是缺少资源：当前源码保留 `mod/0000_core/file` 六个ZIP型 `.zlps`。只读检查压缩目录得到下表，没有解压、解锁或重分发；条目数不等于图库配置照片数。

| 容器 | 文件条目 | 文件字节数 | ZIP加密条目 |
| --- | ---: | ---: | ---: |
| 2025.zlps | 39 | 52549722 | 0 |
| 2026.zlps | 25 | 35213111 | 0 |
| Thumbnail.zlps | 15 | 1502577 | 0 |
| expression.zlps | 72 | 3156918 | 0 |
| gif.zlps | 9 | 15189365 | 0 |
| illustration.zlps | 39 | 51664531 | 0 |

原 [Photo.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Mod/Photo.cs) 从FileSources找 `.zlps`/`.zip` 条目；解锁含等级/突破、金币持有量、好感、心情、日期/时刻/节日与统计条件，另有Lock/SellBoth/售价。玩家解锁时间/收藏按照片名称保存在 `photo` 数据中。原图库还有分类/标签/搜索、购买/自动解锁、复制/GIF/导出，不能以动画列表或所有图片直接开放代替。

iPet没有照片玩家数据、等级突破和原LPS兼容，未实现图库规则或窗口。当前应用包资源检查未发现 `.zlps`/`.zip` 图库容器，转换器也不读取图库。此阶段继续保留图库不打包；没有删除源码原件或更改角色授权。[原素材声明](../ANIMATION_LICENSE.md)明确“Zip 照片图库禁止商用”，代码Apache 2.0不是这些图片的独立授权。此处仅记录仓库声明，不给出新的法律授权判断；商业/重新分发范围未向权利人另行确认。

后续图库须单立非商业使用/分发规格与原条件固定样例，先支持用户明确选择合法来源，验证ZIP路径、展开大小、解码/缓存、GIF生命周期和原件导出；缺文件显示缺失而不虚构解锁，DLC锁不绕过。补Photo保存模型前做版本升级/回滚和名称冲突说明；如果分发范围不明确，只交付框架或用户自备资源，不擅自变更授权。

## 控制台、多实例与阶段归属

诊断/预览报告是已交付原生替代，原Console任意Graph播放、播放队列、说话流和调试状态修改仍未迁移。保留此限制是因为选定资源/原生调度不支持原全部Graph和WPF调用，不能把渲染诊断当完整控制台；候选方案是独立隔离预览场景，之后再规格化调试命令，避免与正式活动结算共用未知入口。现有隔离验收模式属于测试工具，未等同于用户可用完整控制台。

原多档/多实例、配置导入仍缺，当前本机导出/确认恢复不等于多档列表。未来先在阶段4定义档案身份、目录锁、单写入者及切档/复制规则，再考虑原生多实例；当前不提供启动其它宠物实例的DIY目标，以免共享Application Support和偏好。阶段3中的移动区域、RaisePoint、活动中互动、说话动画和完整工具栏等继续属于体验还原；阶段4的数据MOD、多角色、主题和LPS导入继续属于数据兼容。不为本次收尾把这些改称已完成或移入iOS阶段。

研究状态：上述集成各自已确定当前替代/保留限制及候选门槛，没有生态接入成功证据。研究结论可回滚文档提交，运行存档/资源/偏好不变；实际集成需新实现规格与测试，不通过目录或方案文字宣称兼容完成。
