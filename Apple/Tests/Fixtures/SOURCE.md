# 阶段2原版夹具依据

基线1a06c598，MainLogic.FunctionSpend / WorkTimer / MainWindow.TakeItem / ExtensionFunction.EatFood，独立源码推导，未运行Windows程序。文案（8,3.5,2.5,1,60分钟,0.1），固定随机Next(1,3)=1，初始strength/food/drink/health=100、feeling=60，t=.05：体力先替代.0525+.0375，需求余.1225/.0875，efficiency=1.1；收益=.05×8×1.7=.68，经验公共尾部+.05。15秒测试活动正常完成奖金=.68×.1=.068；原文案真实时长3600秒不改变。普通物品h=5衰减.5，礼品.75。太阳系buff=1即时体力−50、储存−50、经验−180、健康+50、好感−4（setter截断）。夹具为固定原输入/源码推导预期，不使用Swift输出生成自身正确性证据。
