# 第五阶段开发与研究交付 — 2026-10-02 / iPet v0.2.0

第五阶段按原路线交付本机排程、统计、快捷和诊断，并逐项确定生态能力的原生替代/保留限制。**开发与研究已收尾，整体实机验收及完整原版还原尚未完成。** 用户要求第五阶段结束后停下，不进入第六阶段；因此本检查点暂停继续开发，不启动iOS应用、发行或最终压力测试。恢复工作前按下方未完成项重新选择批次，不把整体目标标为已完成。

## 逐项交付依据

| 批次 | 当前能力与主要依据 | 实现提交 | 判定与限制 |
| --- | --- | --- | --- |
| 5A 本地统计/历史 | [PetProgress](../Sources/PetCore/PetProgress.swift)、PetProgressTests；最近200条活动结束、实际购买/使用/收益 | 0f97b99e | 已实现；旧历史不推算，UI实机未完整验证 |
| 5B 原统计键 | [统计测试](../Tests/PetCoreTests/PetOriginalStatisticsTests.swift)、PetEngine采样/触摸/物品钩子 | 4c178006 | 已实现纳入键；平台/联网统计未完整映射 |
| 5C 倍率 | [PetActivityMultiplier](../Sources/PetCore/PetActivityMultiplier.swift)、对应固定场景测试 | 13110e12 | 原需求/等级/平衡规则与会话倍率保存；运行体验待验 |
| 5D 套餐 | [PetPackages](../Sources/PetCore/PetPackages.swift)、14定义及PetPackageTests | 3e4ee454 | 签署/退款/到期一次续费；不编造基线无触发的佣金扣除；0授权负价拒绝 |
| 5E 日程 | PetScheduleQueue/Access、[PetEngine](../Sources/PetCore/PetEngine.swift)、ScheduleView及三组测试 | e5186faa / be1ae3b3 / 012de25d | 队列/等待/循环/暂停/30秒衔接/半程门槛与保存保护；原版界面不直接复制；真实财务写失败仍待验 |
| 5F 汇总 | [PetScheduleSummary](../Sources/PetCore/PetScheduleSummary.swift)、SummaryTests | bcc7a752 | 原整数分钟与>71%提示；自然完成参考另列，不当实际进度 |
| 5G 快捷目标 | [PetShortcuts](../Sources/PetCore/PetShortcuts.swift)、ShortcutView及ShortcutTests | c4401847 | 系统链接/应用/文件/文件夹、独立保存/备份；原DIY LPS未导入 |
| 5H 原生按键替代 | PetKeyboardMacro、[PetKeyboardSender](../Sources/PetMacInput/PetKeyboardSender.swift)、录制编辑器与6项适配测试 | f93efcc0 / da917700 | 显式录制/权限/投递/取消，未来嵌套版本保护；Windows语法不兼容，真实权限/焦点/跨应用尚未验 |
| 5I 本地评价统计 | [PetEvaluation](../Sources/PetCore/PetEvaluation.swift)、7项日期/启动/结束回归、StatisticsView | 49f86a29 | 活跃日/连续/日月时长/最长会话/完成率；Play按原口径归Study；无Steam上传/旧历史回填 |
| 5J 诊断/报告 | [PetDiagnostics](../Sources/PetCore/PetDiagnostics.swift)、3项回归、DiagnosticsView/生命周期钩子 | 8f5236c3 | 本机日志/预览/原子导出，默认不附原始日志/存档；不复用Steam报告服务，不是完整动画控制台 |
| 5K 扩展研究 | [ECOSYSTEM_RESEARCH](ECOSYSTEM_RESEARCH.md)、原版Git源码与官方文档 | 本交接提交 | Steam/工坊/云/插件/联机/聊天/图库/控制台/多实例逐项形成方案和限制；没有生态兼容成功声明 |

“已实现”仅指上表限定功能与源码/自动测试证据，不提升差异矩阵中的整个大类为完成。原路线要求每项确定原生实现、替代方案或保留限制，研究项依此收尾；不是通过研究文字宣称已实现那些接口。各批规格及边界见 `specs/PHASE-5A.md` 至 `PHASE-5K.md`。

## 最后验证与产物

2026-10-02当前宿主为arm64 macOS27.0 (26A428)、Xcode27.0 (27A266a)、Swift6.4；部署目标macOS14、共享模块iOS17。最终执行 `bash Apple/scripts/verify.sh`：161核心+64渲染+6macOS按键适配=231 Swift测试，17 Python；macOS Release/ad-hoc构建、严格签名、arm64 iOS Simulator PetRendering/PetCore编译通过。日志为忽略目录 `Apple/build/verification/phase5-closeout.log` 及 tests/conversion-tests/macos-build/ios-build.log，代码不依赖这些本机日志；克隆后可重新执行命令。

工程生成器重复运行字节一致，README末尾原7775字节和LICENSE与1a06c598一致，文档本地链接/diff检查通过；最终推送核对GitHub main与本地HEAD。独立6.1-sol审查因线程上限无法启动，后续批次采用作者自查，这一证据弱于独立审查；未用Astra代替。通过构建不证明实机输入、界面、权限或长期稳定性。

本机可再生产物 `Apple/build/Build/Products/Release/iPet.app`；没有Developer ID签名/公证/正式安装包。资源为147组合、4248独立PNG约555.1MiB，13活动、118物品、14套餐、671条文本。缓存48MiB是估算上限，不是整个应用RSS或GPU占用；没有新CPU/内存/长时间性能结论。应用包未包含六个图库ZIP型zlps，原素材声明与项目来源随包保留。

## 未完成、恢复与回滚

最终验收：新增日程/套餐/统计/快捷/录制/报告页面真实输入，发送权限与不同布局/目标程序、取消/故障写入恢复；真实睡眠/唤醒、显示器热插拔/缩放、至少两小时持续运行与内存/CPU记录，macOS14最低版本/Intel验证仍未完成。历史局部体验记录不追认为当前全部版本通过，也不将加速逻辑模拟当真实两小时。

阶段3仍有完整动画变体、活动中互动、说话动画/选项、智能移动范围/跨屏、RaisePoint定位、动态透明度/全屏及完整工具栏等；阶段4仍有多角色、数据MOD、主题/本地化、LPS旧档导入和完整多档管理。四个限时物品仍未纳入；图库/完整调试控制台、Windows SendKeys语法、多实例及生态接入继续按研究说明保留限制。第六阶段iOS完整应用、签名公证与发行尚未开始。iOS共享模块编译不是iOS应用交付。

存档仍宠物JSON v7、快捷配置v2、按键宏v1；Application Support/VPetApple目录历史沿用。先退出应用、复制整个目录并保留损坏/未来版本。回滚到旧宠物格式前移开新主档/previous，恢复相应 `pet.vN-before-upgrade-*` 原件；回滚shortcut v1程序先移开v2主档/previous并恢复 `shortcuts.v1-before-upgrade-*`。备份缺失时不猜测转换或静默覆盖。报告是独立用户文件；诊断内存日志退出后不保留，不参与养成恢复。加载/导入日程保持暂停、不补算退出/睡眠、不自动重放财务或按键。

这次研究/交接只改文档，回滚对应Git提交即可；不变更存档、资源包或正式运行数据。后续继续须保持许可证、原README后缀、分步规格/固定场景验证和明确回滚说明；用户恢复前维持暂停，不进入第六阶段。
