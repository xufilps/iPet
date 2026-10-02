# 阶段5G：原生DIY链接、应用和文件入口 — 2026-10-02

源码基线1a06c598 MainWindow.cs375–510 LoadDIY/RunDIY、WinDesign/DIYViewer.xaml.cs名称/内容/删除/置顶置底。原RunDIY按Windows路径、含://的URL、SendKeys按键内容分流；LoadDIY还包含多实例与C#插件入口。本阶段还原可独立工作的本机自定义列表、名称/目标编辑、删除和首尾排序、菜单与随宠工具栏直接执行。macOS用NSWorkspace打开应用/文件/文件夹和系统注册URL，不执行shell或猜测Windows键语法；Windows按键、多开与插件是独立后续兼容任务，不能宣称完整DIY迁移。

纯Swift PetShortcutEntry/List/Edit模型，稳定单调ID，最多1000项，名称1...100字、目标1...4096字，拒绝控制字符。明确区分URL与绝对本机路径；URLComponents检查完整URL，http/https需要host，拒绝file/data/javascript入口（本机文件通过明确路径选择）；其它注册scheme交由NSWorkspace报告结果，不保证每种scheme已安装。支持Unicode文件名和标准URL编码，不拼shell或传参数。WindowsKeys可保留记录但明确不可执行，本轮不提供新的Windows键编辑入口。

快捷列表独立Codable JSON v1置于原Application Support目录shortcuts.json，与宠物v7存档和恢复相互独立；原子保存/previous备份，拒绝覆盖未来v2与损坏主档，读错锁定编辑并保留原文件。显式确认恢复有效备份，先保留当前原件；未来主/备份不隐式覆盖。保存失败保留已提交列表，编辑副本只有成功写入才发布，打开动作从不触发保存或养成变化。隔离测试目录沿现有base，不打开真实目标或改用户数据。

新原生“快捷”页：添加/编辑/取消、名称和URL/路径、文件选择、打开、置顶/置底/删除、查看不支持记录、恢复备份/打开目录。菜单栏“自定义快捷”子菜单和随宠Menu列出按顺序项目并可管理；失败报告具体错误，缺失路径不删除记录，open返回true仅说明系统接受打开请求。将新视图接工程生成器。存档导入提示只恢复宠物、不替换本机快捷列表，防止错认JSON兼容。

测试RED→GREEN：名称/目标边界、Unicode与方案区分、不支持Windows键保留、CRUD稳定ID及失败原子性、排序与满容量；独立保存往返/备份、未来主或备份保护、损坏原件/显式恢复与写失败不破坏已有列表。完整Swift/Python、macOS/iOS共享模块、严格签名、工程再生成一致、原README7775字节后缀/LICENSE和diff检查。6.1-sol审查失败限额则明示自查不足。实机点击、实际跨应用打开与故障注入/压力留最后。产品仍v0.2.0，PetState及宠物存档v7不变；回滚本阶段时备份shortcuts.json/previous，新程序的独立文件可保留，旧程序不会读取；回滚v6宠物规则不变。

进度：模型、9项核心测试、独立存储、原生页面/菜单与随宠入口已实现；自动构建通过，真实跨应用操作尚待验。


验证：缺新模型/存储类型RED→GREEN9项，完整140核心+64渲染=204 Swift、17 Python、macOS Release/ad-hoc严格签名、iOS Simulator共享模块构建通过。日志phase5g-red/green/final-verify与tests.log。正式应用与真实目标未运行；不能由URL解析测试或open编译推断跨应用/原生Menu点击与权限行为已验收。新6.1-sol审查仍被工具代理线程限额拒绝，单独自查事务副本、主/备份未来保护、原件恢复、路径字面值与不执行键/shell、独立测试base和不修改宠物存档，未发现阻止提交的问题；不声称独立审查完成。工程重生成及README/LICENSE完整性提交前检查，最终实机/压力保持待验。
