extends WeaponHandler
## 特斯拉电钳 TESLA TONGS 的出招（接线：游戏设计会话写的薄壳；电弧本身——找链、伤害、麻痹、画法、音效——全在
## 布谷鸟钟会话写的 scripts/combat/tesla_arc.gd 里，调手感改那边）。
## 按住：每 0.3 秒放一道（"快充"每级 -0.03，最快 0.18）；钳口 120 内没有怪就只冒火花、不算一道。按着时发光（扑灯蛾会扑）。

const INTERVAL_UPGRADE := 0.03

var _t := 0.0
var _hold_t := 0.0


func attack(delta: float) -> void:
	_t -= delta
	var held: bool = p.attack_held()
	p.set("charging", held)
	p.set("charge", 0.6 if held else 0.0)
	if not held:
		_t = 0.0
		_hold_t = 0.0
		p.clear_target()
		return
	_hold_t += delta
	if _t > 0.0:
		return
	_t = maxf(TeslaArc.INTERVAL - INTERVAL_UPGRADE * p.quick_level(), 0.18)
	var muzzle: Vector2 = p.muzzle(8.0, -10.0)
	var t: Node2D = TeslaArc.target_from(p, muzzle)
	if t == null:
		TeslaArc.fizzle(p.get_parent(), muzzle)
		return
	p.set("facing", 1 if TeslaArc._aim(t).x > p.global_position.x else -1)
	var arc := TeslaArc.new()
	arc.setup(p, p.muzzle(8.0, -10.0), p.strip_color)
	# 电弧一进场景就找链、结算伤害，所以怒火要在 add_child 之前乘上
	if Upgrades.mutation == "rage":
		arc.damage_mult *= Mutations.rage_mult()
	p.get_parent().add_child(arc)
	# 回声（0.3 秒后同一条链再电一次）、从闪：走通用入口，频率读登记表（tongs：回声每 3 道、从闪每 4 道）
	if Upgrades.mutation != "rage":
		Mutations.on_weapon_fire(p, id, [], func(m: float, col: Color) -> void:
			TeslaArc.echo(p, Vector2(int(p.facing) * 8, -10), m, col))


func glow() -> float:
	return 0.5 + 0.3 * absf(sin(_hold_t * 18.0)) if _hold_t > 0.0 else 0.0


func move_mult() -> float:
	return 0.8


## 钳口：两片钳嘴之间一直有一两颗小电火花跳（按着时更多、更亮）
func draw(c: CanvasItem) -> void:
	var m := Vector2(int(p.facing) * 8, -10)
	var on := _hold_t > 0.0
	var n := 2 if on else 1
	for i in n:
		if randf() < (0.8 if on else 0.15):
			var q := m + Vector2(randi_range(-1, 1), randi_range(-2, 2))
			c.draw_rect(Rect2(q, Vector2.ONE), Color(0.75, 0.9, 1.0) if i == 0 else Color.WHITE)
