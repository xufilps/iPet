# iPet 阶段2实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 交付接近原版的活动、金币、物品与库存闭环，并安全升级旧原生存档。
**Architecture:** 构建前生成确定的玩法目录和资源；PetCore独占状态修改和经济结算，PetRendering消费动画请求，macOS页面只发送命令。规则、目录、持久化和界面分别实现，先通过数值/恢复检查再整合。
**Tech Stack:** Swift6、Foundation、SpriteKit、AppKit、SwiftUI、Python3标准库、现有确定性Xcode工程生成器。
**Spec:** [PHASE-2.md](../specs/PHASE-2.md)，已获用户确认；本计划已确认，采用Native顺序实施。

## Global Constraints

- 最低macOS14 / 共享模块iOS17；纯Swift核心不依赖AppKit/UIKit/SpriteKit，无新增第三方运行依赖。
- 原版基线1a06c5981330564bab05a098d2d7969a4b119dd3；目标应用v0.2.0、JSON v2；不恢复原C#目录。
- 13内置活动；118原物品配置记录；timelimit.lps的4条记录排除；记录去重和字段校验后才确定目录条目数。
- 活动按活跃时间推进，退出/睡眠不追补；加载会话暂停等待继续；隐藏时逻辑继续。
- 原README后缀、LICENSE、原素材、署名和图片/动画授权保持；不使用正式存档进行测试。
- 实机验收暂缓；不能用构建/注入时钟模拟代替实机两小时、多屏、睡眠和输入检查。
- 每任务执行RED→GREEN、有意义回归及Git检查点；最终独立整分支审查、普通push并核对远端SHA。

## Review Focus

1. 快速连点购买和使用：每个命令仅扣款/消耗一次，保存失败不触发重试经济效果（任务3、6）。
2. 完成临界点同时生病/切换活动：实际奖金最多一次，按原状态失败顺序决定是否有完成奖金（任务2）。
3. 旧主档正常但备份来自未来版本：不得在自动迁移时覆盖未来备份或主文件（任务4）。
4. 存档含不可识别商品/活动：原数据保留、不可用内容可见，不丢弃或伪装成正常内容（任务4、6）。
5. 图片/活动状态资源缺失以及旧动作回调：明确回退和诊断，不能修改活动进度或重复结算（任务5、6）。

## 文件与接口分工

- `scripts/convert_gameplay.py`：内置活动/物品转换、平衡修正、图片映射、来源哈希；`scripts/convert_assets.py`：新增活动Graph动画。
- `Sources/PetCore/PetCatalog.swift`：ActivityKind、ActivityDefinition、ItemCategory、ItemDefinition、PetCatalog；目录模型及校验。
- `Sources/PetCore/PetActivityRules.swift`：ActivitySession、ActivityStopReason与活动数值/生命周期；`PetItemRules.swift`：PurchaseMode、PetEconomyCommand、PetCommandResult、PetEvent与食用规则。
- `PetState.swift`：新增持久字段及正负值校验；`PetEngine.swift`：计时、命令事务、事件队列和核心状态所有权；现有公开send(PetCommand)接口保留给历史测试，但免费命令不再进入用户页面。
- `PetSaveStore.swift`及新增`PetSaveMigration.swift`：版本分流、v1精确校验、不可覆盖迁移备份、v2安全读写。
- `PetRendering/Manifest.swift`、`PetScene.swift`：活动Graph识别、物品纹理与动作反馈，不承担养成计算。
- `iPetMac/AppModel.swift`：目录加载/命令/保存/页面与动画协调；`ControlsView.swift`和新增`ActivityView.swift`、`ShopView.swift`、`InventoryView.swift`：原生页面。
- `Tests/PetCoreTests/`、`Tests/PetRenderingTests/`及`scripts/tests/`：独立固定输入、数值、恢复、资源检查；`Tests/Fixtures/`：来源说明、原v1JSON与源码推导预期JSON。
- 工程生成器、构建/验证脚本、README、BEHAVIOR、UPSTREAM_COMPARISON、HANDOFF：接入、版本与证据；每次改工程同时更新生成器。

---

### Task 1: 原版目录与独立夹具

**Files:** 新增convert_gameplay.py、PetCatalog.swift、tests/test_convert_gameplay.py、PetCatalogTests.swift、Tests/Fixtures/phase2-original.json与SOURCE.md；修改build.sh、verify.sh、create_project.py转换阶段。
**Interfaces:** `convert_gameplay(source: Path, destination: Path) -> None`生成PetAssets/gameplay.json、items图片及gameplay-sources.sha256.json；`PetCatalog.load(from: URL) throws -> PetCatalog`，提供version、activities、items及按ID查找。ActivityDefinition包含id/name/kind/graphID、durationSeconds、levelLimit、moneyBase、strengthFood、strengthDrink、feeling、finishBonus；ItemDefinition包含id/name/category/price/description/imagePath/graphID及七个效果数值。ID为`core.activity.<原名称>`、`core.item.<原名称>`。

- [x] 写Python测试：原13活动/118记录计数与稳定ID、排除timelimit；默认仅IsOverLoad时FixOverLoad，保留C#有符号幂与ties-to-even舍入；重复ID/非法数字/未知必需字段拒绝；重复转换不重写输出，图片缺失给出明确诊断。
- [x] 运行`python3 -m unittest discover -s Apple/scripts/tests -v`确认新转换器未实现导致测试失败；从Git原源码独立记录活动/食用预期，注明“源码推导，未运行Windows程序”。
- [x] 实现转换器与Swift模型；目录version=1，明确类型/有限数值/相对图片路径，拒绝未来目录版本；为每个活动保存原始字段与修正结果来源；复用已有write_if_changed输出策略。
- [x] Swift测试`PetCatalogTests`校验真实生成目录、唯一ID和恶意路径/NaN拒绝；图片映射按原Image/Name及资源配置查找，不凭猜测文件名冒充成功。Python测试通过后运行`swift test --package-path Apple --filter PetCatalogTests`。
- [x] 提交目录/夹具及其构建接入，后续步骤消费同一模型，不另写一份商品常量。

### Task 2: 活动、收益和停止规则

**Files:** 新增PetActivityRules.swift、PetActivityTests.swift；修改PetState.swift、PetEngine.swift；新增测试时钟/固定随机夹具。
**Interfaces:** `ActivitySession`包含activityID、elapsedSeconds、earned、isPaused；`ActivityStopReason`为completed/manual/stateFailed；`PetEngine.perform(_ command: PetEconomyCommand) -> PetCommandResult`接收startActivity(id)、stopActivity、resumeActivity；引擎初始化新增可选catalog和wallClock，默认保持旧核心测试可构建。`drainEvents() -> [PetEvent]`返回一次性事件，activityStopped事件含实际已得收益与实际奖金。

- [x] 写`testWorkTickMatchesOriginal`：文案原参数、全属性100但feeling60、固定随机输出0，15秒后strength=99.91、food=99.8775、drink=99.9125、money=1000.68、experience=0.05；阈值25/60两侧与低体力路径用独立夹具核对。
- [x] 写生命周期测试：注入15秒测试活动，在elapsed=15时不完成，再推进1秒后只追加0.068奖金；手动停止不发奖金；启动等级不足/Ill拒绝；Study/Play改经验不改金币；状态失败与完成竞争仅发一次合法结算。
- [x] 执行`swift test --package-path Apple --filter PetActivityTests`观察缺类型/未实现或数值失败，再实现独立规则及PetEngine工作分支。储存释放顺序按原strength→drink→food，并记录与已有实现的顺序修正；工作分支后执行原公共尾部，不重复日常分支。
- [x] 测试暂停/继续、睡眠基准重置、长断层不追补、切换活动、同活动停止、休息结束活动；娱乐Feeling符号及原自动平衡后的参数按任务1有效目录使用。
- [x] 运行PetActivityTests与现有PetCoreTests，核对事件drain只消费一次，提交活动核心。

### Task 3: 购买、背包、食用衰减与药品

**Files:** 新增PetItemRules.swift、PetItemTests.swift；修改PetState.swift、PetEngine.swift。
**Interfaces:** `PurchaseMode`为useImmediately/inventory；PetEconomyCommand扩充buyItem(id:mode:)、useItem(id:)；`PetWallClock.now: Date`可注入；PetState新增money=1000、inventory:[String:Int]、itemCooldowns:[String:Date]、catalogVersion=1。PetCommandResult含accepted/message，物品使用通过`PetEvent.itemUsed(id:)`请求动画。目录/活动接口沿用任务1、2。

- [x] 写赊账测试：price=8、Exp<1000、money=0，购买后money=−8；price=1000且money=1000拒绝，money=1000.01允许；高Exp商品沿用相同门槛。拒绝不改变状态。
- [x] 写背包测试：买入只扣钱/加1件，使用才应用属性/减1件，零库存拒绝；快速重复命令每次仅产生一次合法变化，不自动重试。
- [x] 写衰减测试：h=5时普通buff=0.5、礼品buff=0.75；h=0时全部七个效果按原运算顺序生效；太阳系第一次用后经验−180、即时体力50、storedStrength=−50、健康增量受100截断，好感按原setter；固定墙钟核对新到期时间。
- [x] 运行PetItemTests确认失败，然后实现食用规则、目录查找及命令事务；正负储存可校验，未知ID拒绝且原状态不变，保存失败不重复应用命令；物品反馈不默默停止活动，Ill触发状态失败。
- [x] 对所有原物品目录执行固定合法状态使用/保存数据校验；运行PetItemTests及核心全套，提交经济/物品核心。

### Task 4: JSON v2、旧档迁移及恢复保护

**Files:** 新增PetSaveMigration.swift、PetSaveMigrationTests.swift和真实旧版v1JSON夹具；修改PetSaveStore.swift、PetState.swift、相关已有保存测试。
**Interfaces:** PetSaveDocument.version=2；`PetSaveMigration.decodeLegacy(_ data: Data) throws -> PetState`只按v1旧字段/边界校验再补新字段；PetPersistence.load/save既有签名保持。PetSaveStore暴露原recoveryMessage及新migrationBackupURL，写v2前按UUID独立保留有效v1原件。

- [x] 写真实v1夹具加载测试：旧字段完全保留，金币一次补1000，库存/食用历史为空，resting保留；保存再加载不再补金币。负储存v2和金币负数往返通过，v1负储存仍按旧格式拒绝。
- [x] 写原件备份测试：原v1字节保存在独立文件，正常previous轮换不能覆盖；备份创建失败时主档仍为原字节；损坏主档恢复有效v1备用也在升级前保留备用原件。
- [x] 写未来主/备份/目录版本、坏主/坏备份、I/O失败和未知物品ID保存测试；未知活动恢复暂停不可继续，但可无奖金结束，数据不静默消失。现有未来版本99保护用例保留。
- [x] 运行PetSaveMigrationTests观察失败，实现header版本分流和精确旧模型、新字段验证、原子写及迁移备份。加载进行中会话在内存暂停并重建时钟，不改已入账值。
- [x] 核对v2金额±1e12、库存0–1000000、储存±10000与有限时长/收益边界；运行全部核心测试并提交，补旧程序回滚需移开v2主/备份后使用独立v1副本的恢复说明。

### Task 5: 活动Graph与原物品渲染

**Files:** 修改convert_assets.py、Manifest.swift、PetScene.swift、PetState.swift中PetAction；新增/扩充脚本资源检查及PetRenderingTests。
**Interfaces:** PetAction新增activity；AnimationClip新增可选graphID，唯一键扩为(action,graphID,mood)；`PetManifest.resolveActivity(graphID:mood:) -> AnimationClip`；`PetScene.playActivity(graphID:mood:)`、`setFoodImage(path: String?)`消费已验证目录路径，不接收任意文件系统路径。manifest版本2兼容读取旧版本1，缺状态/阶段沿用明确回退。

- [x] 写资源测试：13活动显式Graph映射，文案/学习/玩游戏存在真实动画；帧自然顺序/逐帧时长、开始/循环/结束和不同状态；目录中缺阶段明确报告，原物品图片可解析或显式占位诊断。
- [x] 写Timeline打断及恢复测试：旧完成回调不污染新动作，当前活动可恢复且不产生经济事件；缺Graph/状态、恶意图片路径、纹理释放均可观察。
- [x] 运行Python资源测试与PetRenderingTests确认失败，再实现活动转换/清单与图片注入。纹理仍懒加载，缓存48MiB估算上限保持，资源扩大后记录包体积和额外节点/GPU内存边界。
- [x] 运行脚本及渲染全套；确认现有27组合的兼容行为没有被新Graph覆盖，提交资源/渲染切片。

### Task 6: 原生页面、闭环与交接

**Files:** 新增ActivityView.swift、ShopView.swift、InventoryView.swift；修改ControlsView.swift、AppModel.swift、工程生成器/工程、build/verify脚本、核心闭环测试、README及docs。
**Interfaces:** AppModel公开catalog、perform(PetEconomyCommand)、当前selectedPage及itemMultiplier(id:)；页面使用这些入口，不直接写PetState。页面枚举status/activity/shop/inventory/settings；菜单进入对应页面。AppModel每次tick/命令刷新state并drainEvents，保存关键状态与显示错误，动画中断后恢复会话Graph。

- [x] 写`testOriginalStyleEconomyRoundTrip`：固定时钟/随机，活动收益→购买库存→使用→状态变化→存档/重载结果一致；保存失败后再次打开面板不重放命令；未知条目可保留且拒绝使用。先运行核心闭环测试确认失败。
- [x] 实现五页面：状态显示金币/等级/经验/好感；活动类别、锁定原因、进度和开始/继续/停止；商店搜索/分类、价格/正负属性/图片/当前食用倍率、购买即用/入包；背包数量及使用/未知项禁用；设置保留原偏好和授权。
- [x] 移除免费面包/饮料的用户按钮和菜单入口；保留休息、显示隐藏、位置重置/退出，新增活动/商店/背包入口。恢复/结束反馈来自核心实际事件，不由动画结束发奖金；隐藏、抚摸、拖动、进食反馈不误停活动或自主切换Graph。
- [x] 工程生成器加入新Swift文件，版本0.2.0/build2；转换器生成目录与资源进入同一PetAssets包。针对计时、恢复和反馈建立自动可验证的协调逻辑检查，UI仅构建不能视为实机已验。
- [x] 执行`Apple/scripts/verify.sh`；检查现有16Swift/6脚本及所有新增测试、macOS Release/签名、iOS模块编译、两次工程生成字节一致、资源映射/重复转换、原README后缀与LICENSE完整性；原始日志留build/verification。
- [x] 更新BEHAVIOR/UPSTREAM_COMPARISON/ROADMAP/HANDOFF及README，逐项注明已实现、剩余资源/验证限制、迁移恢复和源码推导证据；独立整分支审查后修复重要问题并重跑关联测试。提交实现与交接，普通推送origin/main并核对远端SHA。

## 完成与回滚

本阶段完成以规格验收矩阵为准，不以六个提交或目录建立计数。每任务提交后可独立回退；核心/目录/schema关联版本必须一起回退，已经升级的正式存档先整目录保留，再按规格用独立v1备份恢复。实施账本记录每个任务RED/GREEN、命令与结果、提交、偏离计划的裁决和未完成事项，避免跨上下文重复工作；账本保存在Apple/docs/PHASE-2-EXECUTION.md。

自审：全部规格条目已分配任务，Review Focus五项均落入测试/检查；原数据转换、公式、兼容、安全与UI相互依赖，建议采用Native方式顺序实现，最终一次独立审查。若选择逐任务子代理审查，则各任务同样遵守上述接口和提交门槛，不自行缩减规格范围。
