# 阶段3O：普通待机池与概率循环 — 2026-10-02

依据1a06c598 MainDisplay.DisplayToIdel/DisplayBLoopingToNomal、GraphInfo路径解析及GraphCore.Config.GetDuration：有效Idel名字随机排列取首个A或Single，等价有效名字均匀选择；A→B循环，当Next(++looptimes)>duration才C结束，默认10，boring/squat20。Single只播一次，无A且只有B的amusement不可独立触发。无状态标签默认Nomal，happy_like520从路径推断Happy，不把未标Nomal的Bubbles漏掉。

本批转换全部内置IDEL有效动作、阶段/Single和变体；新增可选idleLoopLimit（清单v3兼容字段）存放原duration。纯核心计数器带注入随机源，渲染按B边界推进、退出到C；随机候选按当前状态实际可用Graph选择，不把计划池当已完成。人工动作、隐藏/睡眠等清理循环，新动作不执行旧完成。普通待机效果仍纯展示，模型不新增字段。StateONE/StateTWO及扩展池留后续独立规格，打盹20秒上限本批不改。

范围：资源转换/Python回归、PetCore计数器、PetScene池/循环、AppModel普通待机入口、测试和文档。先写计数阈值/固定随机、资源默认状态/Single/完整池与动画结束测试失败，再实现。完整Swift/Python/macOS/iOS、工程重复生成、原README/LICENSE和文档检查；实机/压力保持最后。回滚源码与转换器重建，无保存v2字段变化；退出备份正式存档，不降级保存。

源码补核：GraphCore.FindGraphs允许非Ill逐阶段相邻状态回退，故普通池按有效Graph而非精确状态子集；渲染合成各阶段，开心Squat借Nomal B。原Ill不借非Ill素材。旧C-only脚本夹具补A使它成为可触发动作，保留数字帧排序断言；旧侧挂打断测试改为显式结束新待机后检查，不再假定待机固定一轮。
