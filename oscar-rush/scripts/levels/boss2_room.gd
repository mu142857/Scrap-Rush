extends BossArena
## 第二关 Boss 房「总机室」：总机 THE OPERATOR。竞技场 320×180，镜头固定 1.5 倍。
## 通用流程在 BossArena；这里填参数、造 Boss、铺三块会通电的铜地板。
## 打完：显示几句别人没打完的最后一通电话 → 商店 → 第三关。美术见 tools/draw_boss2.py。

const BOSS_X := 262.0
const PLATES := [Vector2(8, 80), Vector2(80, 152), Vector2(152, 224)]
const LAST_CALLS := [
	"\"...hello? is anyone—\"",
	"\"...tell them I tried to come home—\"",
	"\"...can you hear me? the line is—\"",
]


func _configure() -> void:
	bg_tex = preload("res://art/boss/room2_bg.png")
	fg_tex = preload("res://art/boss/room2_fg.png")
	gate_tex = preload("res://art/boss/gate2.png")
	platforms = [Vector3(26, 82, 126), Vector3(112, 168, 100), Vector3(36, 92, 74)]
	# 吊灯：暖黄，不像第一关那样红色警报
	lamps = [Vector2(60, 24), Vector2(220, 24)]
	lamp_color = Color(1.0, 0.72, 0.35)
	lamp_energy = 0.5
	darkness = Color(0.3, 0.27, 0.28)
	darkness_hot = Color(0.42, 0.3, 0.22)
	boss_name = "THE OPERATOR"
	card_sub = "It keeps every voice it ever heard."
	defeat_line = "Somebody else's last call."
	clear_banner = "SWITCHBOARD CLEARED"
	next_shop = "res://scenes/level3.tscn"


func _make_boss() -> Node2D:
	var b := Operator.new()
	b.position = Vector2(BOSS_X, floor_y)
	b.arena = arena
	b.floor_y = floor_y
	b.bullet_parent = self
	return b


func _build_extras() -> void:
	for r in PLATES:
		var p := Operator.ElectricPlate.new()
		p.x0 = r.x
		p.x1 = r.y
		p.floor_y = floor_y
		add_child(p)
		(boss as Operator).plates.append(p)


## 打完先一句句冒出别人没打完的最后一通电话，再接通用流程（定格那句、掉零件、开门）
func _after_defeat() -> void:
	for line in LAST_CALLS:
		_card_sub.modulate.a = 1.0
		_card.text = ""
		_card_sub.text = ""
		for i in line.length():
			_card_sub.text = line.substr(0, i + 1)
			await get_tree().create_timer(0.035).timeout
		Game.sfx("dial", -12.0, 0.6)
		await get_tree().create_timer(0.9).timeout
	await super._after_defeat()
