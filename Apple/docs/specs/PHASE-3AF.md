# 阶段3AF：原版边缘检查时自动换屏 — 2026-10-03

依据1a06c598 MainLogic.MoveSideHideCheck首段、MWController.IfInActivateScreen/SetNowScreenActivate、Setting.AutoChangeWindow/GameScreenIndex：边缘检查时若角色不在已激活屏幕且自动换屏开启，检测当前显示器并将ScreenBorder固定到该屏幕；设置、购买、工作等原窗口打开时暂缓。不是持续追踪鼠标，也不是将角色瞬移到其他屏幕。

iPet在提起释放/正常移动C结束进入侧挂检查前执行对应策略，使用显示器稳定标识和可见points矩形；原生控制面板/区域选择器显示期间暂缓。新本机自动换屏开关默认关闭（原Setting构造函数从缺省false布尔值加载），首次激活屏幕沿既有有效移动范围所在屏幕初始化，避免升级时突然覆写自定义矩形；选择主屏/检测/保存自定义区域同步该范围对应屏幕标识。只有跨到不同显示器并进入检查才改为该屏幕固定范围；关闭保留当前设置。屏幕移除不立即改写原自定义偏好，既有临时回退保留；随后明确边缘检查的换屏可记录新范围。smoke不持久化，JSON v7不变。

纯Swift几何策略回归先失败再实现，覆盖同屏不切换、跨屏、关闭、面板暂缓、无屏/无交集及小屏不能容纳；接线需清除旧edgeScreen以免动作结束沿旧范围回正，切换后不瞬移、先按新边界尝试侧挂，再按原生安全结束。显示器标识缺失则不自动切换。原版DPI/整屏与macOS visibleFrame、ID/索引不同属平台适配；自动回正保护规则另立规格，不借本批宣称完成。

验证完整Swift/资源检查、macOS Release与iOS共享模块、工程重复生成、原README及LICENSE；6.1 Sol审查及文档交接推送ipet-dev。真实两屏拖动/缩放/边缘和睡眠/压力留后。回滚本批即可，新增本机偏好可忽略，存档无需转换，main镜像不动。

审查修订：提起跨屏但未入侧挂时不保留edgeScreen；正常取消无论needsEdgeRecovery是否开启均清除旧边界，避免随后手动修改范围仍使用旧屏。兼容动作衔接reposition=false继续保留原固定起始边界。此生命周期路径经源码追踪，实际窗口回归仍待实机。

身份审查修订：NSScreenNumber是运行会话数字，不能直接当持久身份。采用ColorSync CGDisplayCreateUUIDFromDisplayID转UUID；旧数字/非法偏好重新按已有有效范围初始化，不触发换屏覆写。新增持久身份回归已观察缺接口失败后实现。SDK声明核对ColorSyncDevice.h:270，生命周期依据[Apple CGDirectDisplayID说明](https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid)。

缺失UUID屏幕保留几何再按最大交集选定，选中身份缺失时跳过切换，不能先删掉屏幕而误选少量相交邻屏。混合屏幕回归已观察错误覆盖目标后修复。

默认值最终核对：Setting构造函数第41行将配置GetBool(autochangewindow)反转到内部字段，getter再次反转，缺字段为false；不能只看字段初始化判断为true。原生默认改为关闭，不主动改变既有固定区域。

## 交付记录

2026-10-03：新增6项屏幕切换/身份回归，260项Swift（171核心、83渲染、6输入）和21项资源检查通过；macOS Release、iOS Simulator共享模块及严格签名通过，完整日志Apple/build/verification/phase3af-complete.log。最终默认关闭修订再次macOS构建/签名通过，日志phase3af-default-final.log。工程重复生成一致，README尾部原7775字节和LICENSE保留。6.1 Sol只读审查发现并复核旧边界残留、持久UUID与缺失身份混合屏幕路径修复；身份/混合屏回归均观察失败后修复。没有运行正式应用或改动正式存档，版本v0.2.0/JSON v7不变。真实多屏、UUID跨重启、面板暂缓及动作观感仍待验，不用几何测试替代；自动回正保护为下一批。回滚实现提交即可，新本机偏好不影响旧存档，main镜像保持不动。
