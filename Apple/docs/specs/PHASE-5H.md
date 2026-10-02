# 阶段5H：macOS原生按键与文本替代 — 2026-10-02

依赖5G快捷列表。原版MainWindow.RunDIY使用Windows SendKeys.SendWait，DIYViewer录制^/%/+及{ENTER}/{TAB}/功能键；此语法与macOS Command/Option/Control不同，不自动转换或声称直接兼容。采用新macKeys目标，纯Swift PetKeyboardMacro记录有序组合键和文本，原WindowsKeys仍原样保留不可执行。

任务1：可验证的按键计划与配置兼容。键码0...127排除纯修饰键，明确Command/Option/Control/Shift、录制显示名和down/up发送所需数据；最多32步骤、文本合计2048 UTF16单位，拒绝其它控制字符，支持Tab/换行。文本拆成至多20 UTF16单位小块（iPet发送边界，不声称Apple公开保证固定容量），不拆代理对；Tab→原生48、CR/LF→36，CRLF合并一次Return，保持其余Unicode内容。宏JSON v1保存在target字段，字段仍限4096字。快捷文件v2支持原v1无写加载，首次改写保留独立v1原件，未来v3主或备份拒绝覆盖；宠物v7不变。此任务先交付模型/Codec/回归，发送器与录制UI在任务2接入；任务1阶段不可从菜单执行macKeys。

任务2：原生录制与投递。SwiftUI/NSView录制用户键码/修饰键、文本步骤及排序/删除，存录制名而非运行时猜键盘布局；只在编辑器局部捕获，不装全局监听。用户明确点击权限按钮才调用CGRequestPostEventAccess，CGPreflightPostEventAccess校验；无权限不投递、不隐式请求。从非激活随宠菜单或菜单栏触发到明确的前台其它应用PID，当前iPet前台时拒绝并提示操作方法；不切换到猜测应用。每个键同时预构建down/up，向原PID用CGEvent.postToPid成对投递，文本使用keyboardSetUnicodeString，每步/分块前检查取消、权限、原应用仍前台/存活；更换前台/隐藏/睡眠/退出则取消剩余。纯核心投递门槛用固定PID/权限/忙碌/目标退出测试，不向真实应用测试发送。

投递任务串行，提供停止剩余入口，不在启动/加载/计时器触发；打开其它快捷先取消按键任务。CGEvent投递不提供接收成功回执，状态只报告请求发送，不声称目标已执行；官方Unicode文档说明有些框架自行翻译事件，文本/系统全局快捷键需实机验证。不改剪贴板，不读目标文字。随宠工具栏仍非激活，但跨应用效果/权限/布局属于最终实机项。

验证与交付：RED→GREEN核心宏/Unicode/边界/协议/未来保护，完整Swift/Python、macOS/iOS、严格签名，工程再生成一致、原README/LICENSE和diff检查。独立审查使用6.1-sol，限额明确记录弱自查。配置v2回滚v1程序先退出、备份整个目录、移开v2主/previous，恢复独立shortcuts.v1-before-upgrade原件；宠物v7不变。代码/文档分任务提交推送，真实按键/权限操作与压力留最后，产品仍v0.2.0。

官方依据：[Unicode键事件](https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:))、[事件投递权限检查](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess())；当前macOS SDK CGEvent.h205/372/405/408核对Unicode setter、postToPid、preflight/request声明。不依赖第三方库，不由SDK可编译推断真实App权限已授予。

进度：任务1实现及自动验证完成，任务2待实施。

阶段5H任务1：原生组合键/文本有序计划与配置兼容已实现；录制UI和实际发送仍待任务2，macKeys菜单禁用。宏v1校验步骤/文本/键码边界，文本按UTF16分块且不拆代理对，Tab/CRLF映射键事件；纯核心PID/权限门槛不执行平台投递。快捷配置v2读取v1不写盘，首次改写及恢复v1备份前保留独立原件；根未来v3及嵌套未来宏保护主档/备份/恢复。修复合法Unicode格式字符（如家庭emoji）被误判控制字符，真实C0/C1限制保留。宠物存档仍v7；回滚旧版先退出并备份整个目录，移开v2主档/previous后恢复独立v1原件。151核心+64渲染=215 Swift、17 Python/macOS/iOS/签名验证；未请求权限、投递真实按键或修改正式配置。独立6.1-sol审查受线程限额阻止，采用作者自查，不能替代独立审查或实机验收。详情本规格。


RED→GREEN证据（忽略目录Apple/build/verification）：phase5h-core-red.log先缺模型；phase5h-unicode-red.log与phase5h-path-unicode-red.log复现合法emoji拒绝；phase5h-nested-future-red.log复现未来宏备份/恢复保护缺失。修复后完整验证见phase5h-core-final-verify.log；测试覆盖宏往返、分块、控制字符、固定投递门槛、v1原字节保留及根/嵌套未来版本保护。源码PetKeyboardMacro.swift、PetUnicodeControls.swift、PetShortcuts.swift及对应测试；发送器未实现不以模型测试宣称跨应用可用。
