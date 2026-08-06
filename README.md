# 突破轮回

Godot 4.7 制作的骰子计分构筑游戏。

当前版本采用五轮计分玩法：投掷骰子、使用卡牌改变骰型与倍率，同时管理会随出牌推进的敌方意图，在轮数耗尽前达到目标分数。

## 运行

使用 Godot 4.7 打开 `project.godot`，运行主场景即可。

## 规则与测试

- 唯一正式规则：`docs/game-design-document.md`
- 逻辑测试：`tests/RuleLogicSmoke.tscn`
- 流程测试：`tests/RunFlowSmoke.tscn`
- 战斗UI测试：`tests/BattleUISmoke.tscn`

旧版大话骰存档只能迁移永久进度，不能继续旧战斗。
