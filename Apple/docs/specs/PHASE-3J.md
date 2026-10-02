# 阶段3J：侧挂悬停探头 — 2026-10-02

依据1a06c598 Main.xaml.cs.MainGrid_MouseEnter/Leave：Main进入播放对应Rise A/B，离开播放Rise C后返回Main B；点击Main或Rise均回正并播放Main C。使用左右Rise及状态/阶段变体，不增加存档字段。

macOS使用已有30Hz输入检查，按窗口画布范围检测进入/离开（符合原MainGrid范围），不以当前动画alpha判定悬停，避免帧形状变化导致来回切换；透明区域仍保持点击穿透，不抢焦点。仅侧挂时启用，按键/拖动期间暂停悬停切换。离开结束返回Main循环，快速重新进入允许打断离开并重播Rise开始，为避免延迟的适配。点击任何探头阶段均播放Main结束；取消/解码失败使用既有安全回正，缺Rise保留Main并记录诊断。

文件范围：PetScene动画内部状态、AppModel悬停检测、convert_assets.py资源、渲染测试及文档。先验证Rise资源、进入/离开/快速打断/点击使用Main C/缺资源回退，记录失败后实现；完整Swift/Python/macOS/iOS模块构建，工程生成一致、原README/LICENSE完整性。真实输入、多屏/睡眠与压力留最终，不宣称物理鼠标通过。

养成/存档v2、清单v3、文本v1不变，回滚源码和转换器并重建，正式存档先退出备份。保留菜单重置，不推进原全部MoveEnd入口、顶部下落与跨屏。本规格作为本批执行与交接依据。
