class_name WeaponHandler
extends RefCounted
## 新武器的出招脚本都继承这个（10-18，7 把武器）。每个主角身上一份（双人各拿各的，各一份），换武器时重新建。
## Player 每个物理帧调 attack(delta)，画主角时调 draw(c)，挨打 / 被眩晕 / 换武器时调 cancel()。
##
## 写法约定（多个会话一起写武器，照这个来就不会打架）：
## - 一把武器一个文件：scripts/combat/weapons/<id>.gd（handler）+ 需要的子弹脚本 scripts/combat/weapons/<id>_*.gd。
## - 不要 class_name 引用 Player（player.gd 会加载这里，互相引用 Godot 会卡死）。主角用下面的 p，类型写成 CharacterBody2D，
##   调它的公开接口（见 player.gd 里"给新武器用的公开接口"那一段）：
##     p.attack_held() / p.attack_pressed()     攻击键按住 / 刚按下（被眩晕时都是 false）
##     p.action_held("down")                     别的键（down、jump……）按着没有
##     p.find_target() -> Node2D                 自动瞄准找最近的怪（和老武器同一套规则，会画准星），找不到返回 null
##     p.clear_target()                          不瞄了（准星消失）
##     p.aim_dir(from: Vector2) -> Vector2       从 from 指向当前目标的方向；没有目标就是正前方；顺手把 facing 转过去
##     p.target_point(n: Node2D) -> Vector2      怪的瞄准点
##     p.muzzle(dx := 6.0, dy := -10.0)          枪口位置（会跟着朝向翻）
##     p.recoil(v: Vector2)                      后坐力：直接加到速度上
##     p.pop(squash := 0.3, light := 0.5)        出手时身子压一下、身上灯亮一下
##     p.quick_level() -> int                    "快充"升级等级 0~3（每把武器自己决定怎么变快）
##     p.facing、p.strip_color、p.is_on_floor()、p.global_position、p.get_parent()
##   要让扑灯蛾被引过来、走路变慢：蓄力时设 p.charging = true、p.charge = 0~1（松手时设回 false / 0）。
## - 出招以后调 Mutations.on_weapon_fire(p, id, shots, refire)，变异（怒火、磁带回声、从闪）就自动生效：
##     shots 是这一发打出来的子弹节点数组（怒火会给它们的 damage 乘倍率）；
##     refire 是 Callable(damage_mult: float, color: Color)：回声 0.3 秒后会调它，在主角现在的位置按原方向再打一发
##     （打出来的节点记得 set_meta("mutation_copy", true)，免得回声再回声）。
## - 打中怪以后调 HitFx.after_hit(body, pos, dir, power)（power 0~1），命中星、溅射、击杀爆裂、连杀音高都有了。
## - 新文字用英文写，同时加进 localization/text.csv（中文），键名就是英文原文。

## 拿着这把武器的主角
var p: CharacterBody2D
## 武器 id（注册表里的）
var id := ""


## 每个物理帧都调（拿着这把武器时）
func attack(_delta: float) -> void:
	pass


## 画主角时调：c 就是主角自己（坐标是主角本地坐标，脚底 (0, 0)，身体中间约 (0, -10)）。画枪口火光、蓄力圈之类
func draw(_c: CanvasItem) -> void:
	pass


## 挨打、被眩晕、换武器、离开场景时调：停掉蓄力、停掉循环音效
func cancel() -> void:
	if is_instance_valid(p):
		p.set("charging", false)
		p.set("charge", 0.0)


## 身上发多亮（0~1）：主角的灯和荧光条跟着变
func glow() -> float:
	return 0.0


## p.charging 为真时走路速度乘多少
func move_mult() -> float:
	return 0.8
