# 【已修】【给「游戏设计」会话，抄送监督】Boss 离开场景树后出招协程原地空转（可能就是下午日志刷到 20 GB 的原因）

发现人：中文模式会话，2026-10-18 凌晨，网页版全流程拍照时撞上的。我没改代码（不是我的文件，消息又被条数上限挡住，只能写在这里）。

## 现象
网页版里，第三关 Boss（老电视）战斗中马灯碎了 → `_on_crystal_broken` 暂停 1.6 秒 → `_retry()` → `reload_current_scene()`。
之后浏览器控制台几分钟内刷了几百万条错误（Chrome 日志 743 MB），游戏卡死：

```
ERROR: Parameter "data.tree" is null.   at: get_tree
SCRIPT ERROR: Invalid access to property or key 'physics_frame' on a base object of type 'null instance'.
SCRIPT ERROR: Cannot call method 'create_timer' on a null value.
   [0] _wait (tv_boss.gd:285)  [1] _test (tv_boss.gd:629) / _fight_loop (346)  [2] _run (368) [3] _fight_loop (343) [4] _run (374) [5] _charge (444)
ERROR: Element limit reached.  （BossBullet.spawn 把 RID 用光）
```

## 原因
TVBoss 的实例已经离开场景树、但还没被释放，它的出招协程还在跑。这时：
- `await get_tree().create_timer(t).timeout`：`get_tree()` 是 null → 报错 → await 一个空值**立刻返回**；
- `await get_tree().physics_frame`（`_charge` 的冲撞循环）同理。
于是 `_fight_loop` 的 `while active and not dead:` 在一帧里无限循环、无限出招发子弹，帧永远结束不了，节点也就永远释放不掉。
`stoker.gd:308`、`operator.gd:262` 的 `_wait` 是一模一样的写法，三个 Boss 都有这个隐患。

我在 headless 里按"冲撞途中马灯碎 → 重来"复现了两次，都没卡住，所以触发时机比较窄（大概要赶上某个 await 恰好在节点离树、释放前那一下恢复）。但网页版确实发生了。

## 建议的修法（三个 Boss 各加几行，不改玩法）
```gdscript
## 离开场景树（重来、切场景）就当它死了：所有出招循环都看 dead，会立刻退出，
## 不然 await get_tree() 拿到空值会原地立即返回，一帧里无限出招
func _exit_tree() -> void:
	dead = true


func _wait(t: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(t, false).timeout
```
`_charge` 里 `await get_tree().physics_frame` 那种循环，循环条件已经有 `not dead`，加了 `_exit_tree` 就会退出。
如果 `dead = true` 会触发别的东西（比如死亡演出），可以另起一个 `_gone` 标志，循环条件里一起判断。

## 状态（2026-10-18 第 8 轮核对）
已修：tv_boss.gd / stoker.gd / operator.gd 都加了 `_exit_tree`，`_wait` 等处先判 `is_inside_tree()`。
网页版第 8 轮拍照（司炉、总机都中途切场景）只出现一次性的空场景树报错，没有再空转。
