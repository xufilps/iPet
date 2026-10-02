# 阶段3R：移动结束后的侧挂衔接 — 2026-10-02

基线Main.xaml.cs订阅Event_MoveEnd调用MoveSideHideCheck；GraphHelper.Move.StopMoving在C结束后发事件，再DisplayToNomal。侧挂阈值左右越界严格大于50逻辑像素，Main定位left219/right281。当前仅拖动释放检查侧挂，移动C回调先回正造成墙动作结束不能侧挂。本批在正常移动C完成、回正前尝试已迁移侧挂；成功保留新动作所有权，不再执行通用回基础。失败沿用可见区域恢复。

PetScene新增正常移动结束接管回调，解码失败仍走原通用完成通知且不调用接管；人工动作取消、隐藏、睡眠、关闭自主移动和输入期间拒绝侧挂，屏幕沿用移动启动时区域。没有侧挂资源回基础；不改养成、保存或素材。先覆盖C完成接管、拒绝后通用恢复、缺帧不接管，再接AppModel；完整回归/双平台/原文完整性和工程生成后提交推送。

原StopMoving的RePositionActive/CheckPosition自动回正策略仍未完整还原，macOS继续visibleFrame安全恢复；跨屏和真实裁剪/输入未验证，压力最后。回滚源码重建，保存v2不变，正式存档退出备份。
