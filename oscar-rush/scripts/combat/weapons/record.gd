extends WeaponHandler
## 唱片回旋镖 RECORD SLINGER（10-18，总机台/留声机会话写；设计见 夜间打磨/新武器设计.md 第 3 节）。
## 手摇留声机的转盘拆下来改成的发射器，扔出去的是一张黑胶唱片（record_disc.gd）。
## 按一下（按住也行）扔一张：往前飞 130 像素慢慢减速，飞回来回到手上。最多 MAX_OUT 张在外面，接住一张就能马上再扔。
## 独特特性：回来的路也会割——把怪夹在"你和唱片之间"就挨两刀；扔向墙会弹一次，路线变"之"字。
## 打击感：出手人往前一倾、"嗖"+唱针"嚓——"；飞的时候"呜呜"转盘声跟着速度变调；割一下"唰"+切线火星（不顿帧）；
## 接住"咔哒"、身上闪一圈白点，接住后 CATCH_WINDOW 秒内扔出的那张快 20%；连杀时唱片亮一下、"呜"声往上抬一档。

const DISC := preload("res://scripts/combat/weapons/record_disc.gd")
const MAX_OUT := 2
## 两次出手最少隔多久（按住时的自动连扔也照这个）
const MIN_GAP := 0.16
const DAMAGE := 32.0
const CATCH_WINDOW := 0.2
const CATCH_BOOST := 1.2
## "快充"每级扔得快多少
const QUICK_SPEED := 0.08
## 回声唱片的伤害倍率由 Mutations 给（0.5），这里只管它不回来、不占名额

var _out: Array = []
var _cd := 0.0
var _catch_t := 0.0
## 手上一圈白点（接住时闪）
var _ring := 0.0
## 出手那一下手往前甩
var _fling := 0.0
var _kills := 0
var _kill_t := 0.0


func attack(delta: float) -> void:
	_cd -= delta
	_catch_t -= delta
	_ring = maxf(_ring - delta / 0.25, 0.0)
	_fling = maxf(_fling - delta / 0.12, 0.0)
	_kill_t -= delta
	if _kill_t <= 0.0:
		_kills = 0
	_prune()
	var pressed: bool = p.attack_pressed()
	var held: bool = p.attack_held()
	if held or pressed:
		p.find_target()
	else:
		p.clear_target()
	if (pressed or held) and _cd <= 0.0 and _out.size() < MAX_OUT:
		_cd = MIN_GAP
		_throw(1.0, Color.WHITE, false)


func _prune() -> void:
	var keep: Array = []
	for d in _out:
		if is_instance_valid(d):
			keep.append(d)
	_out = keep


## 扔一张。mult / col：磁带回声再扔时的伤害倍率和颜色；copy = 回声扔的幽灵唱片（不回来、不占名额）
func _throw(mult: float, col: Color, copy: bool) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var from: Vector2 = p.muzzle(6.0, -10.0)
	var dir: Vector2 = p.aim_dir(from)
	var speed: float = 1.0 + QUICK_SPEED * p.quick_level()
	if not copy and _catch_t > 0.0:
		speed *= CATCH_BOOST
		_catch_t = 0.0
	var d: Node2D = DISC.new()
	d.call("setup", from, dir, speed, DAMAGE * mult, p, null if copy else self)
	d.set("target", p.get("_target"))
	if copy:
		d.set("ghost", true)
		d.set_meta("mutation_copy", true)
	p.get_parent().add_child(d)
	if copy:
		Game.sfx("record_throw", -14.0, 1.25, 0.05)
		return
	_out.append(d)
	_fling = 1.0
	Game.sfx("record_throw", -6.0, 1.0 + 0.15 * (speed - 1.0), 0.06)
	p.pop(0.18, 0.0)
	p.recoil(Vector2(dir.x * 20.0, 0.0))
	Mutations.on_weapon_fire(p, id, [d], func(m: float, ecol: Color) -> void: _throw(m, ecol, true))


## 唱片回到手上（record_disc.gd 调）。lost = 没接住、散掉了（人跑太远、超时）
func caught(d: Node, lost := false) -> void:
	_out.erase(d)
	if lost or not is_instance_valid(p):
		return
	_catch_t = CATCH_WINDOW
	_ring = 1.0
	_cd = minf(_cd, 0.0)
	Game.sfx("record_catch", -8.0, 1.0, 0.05)


## 唱片割死了一只（record_disc.gd 调）：连杀时唱片亮一下、"呜"往上抬一档
func on_kill(d: Node) -> void:
	_kills += 1
	_kill_t = 1.2
	if _kills >= 2 and is_instance_valid(d):
		d.call("glint")
		Game.sfx("record_whir", -10.0, 1.0 + 0.12 * minf(_kills, 6))


func cancel() -> void:
	super()


## 手上的唱片：还有能扔的就在手边画一张（扔出去一张少一张）；出手那一下往前甩；接住时身上闪一圈白点
func draw(c: CanvasItem) -> void:
	var f := int(p.facing)
	var left := MAX_OUT - _out.size()
	if left > 0:
		var hx := f * (4 + int(round(3.0 * _fling)))
		var hy := -9
		var base := Vector2(hx - 2, hy - 1)
		c.draw_rect(Rect2(base + Vector2(0, 0), Vector2(5, 1)), DISC.VINYL)
		c.draw_rect(Rect2(base + Vector2(-1, 1), Vector2(7, 1)), DISC.VINYL)
		c.draw_rect(Rect2(base + Vector2(0, 2), Vector2(5, 1)), DISC.VINYL)
		c.draw_rect(Rect2(base + Vector2(2, 1), Vector2(1, 1)), DISC.LABEL)
		c.draw_rect(Rect2(base + Vector2(1, 0), Vector2(1, 1)), DISC.SHINE)
		if left > 1:
			# 第二张叠在后面，只露一条边
			c.draw_rect(Rect2(base + Vector2(-f, -1), Vector2(5, 1)), DISC.GROOVE)
	if _ring > 0.0:
		var r := 7.0 + 5.0 * (1.0 - _ring)
		for k in 10:
			var q := (Vector2(0, -10) + Vector2.from_angle(TAU * k / 10.0) * r).round()
			c.draw_rect(Rect2(q, Vector2.ONE), Color(1, 1, 1, _ring))
