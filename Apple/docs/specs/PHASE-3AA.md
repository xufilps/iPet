# 阶段3AA：提起阶段变体与关联审计 — 2026-10-03

沿用1a06c598 MainDisplay.DisplayRaising/Display(name,phase,type)和GraphCore.FindGraph依据。原版沿回调Graph名尝试同名同类型阶段，无匹配则按类型回退；内置当前Raise目录仅Raised_Dynamic和Raised_Static，不能据通用接口宣称有未复现的第三方特殊动作。动态Nomal已有两个Single变体；静态Happy有C_Happy/C_Happy_2，但转换器此前仅选第一个。

本批范围是导出静态提起各阶段候选，并按注入随机源选择放下变体；保持动态三次/静态悬挂、原锚点和移动阈值。先提交规格，再写转换/渲染回归并观察失败，再实现；不新增动作类型/存档格式或无来源的特殊动作。第三方Graph名称兼容仍归数据MOD接口研究。

验证Happy放下两候选都能到达、状态/阶段正确、缺资源回退和打断回归；全Swift/Python与macOS/iOS共享构建。原许可、README后缀和ipet-dev工作流保持；回滚本批后重新转换/构建，不改宠物v7。真实放下观感和压力仍留后。
