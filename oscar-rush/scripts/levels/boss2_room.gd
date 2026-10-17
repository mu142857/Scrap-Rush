extends BossArena
## 第二关 Boss 房「总机室」：总机 THE OPERATOR。竞技场 320×180，镜头固定 1.5 倍。
## 通用流程在 BossArena；这里填参数、造 Boss、铺三块会通电的铜地板、摆总机的桌子。
## 场地：上半空是总机的天车道（它吊在缆绳上满屋追人、往下砸），所以没有吊平台，
##   只有两张立在地上的矮长凳和右边总机留下的桌子（台面能站）。躲砸线可以钻到长凳底下。
## 打完：显示几句别人没打完的最后一通电话 → 商店 → 第三关。美术见 tools/draw_boss2.py。

const BOSS_X := 262.0
const WALL_LAMP_L := 12.0
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
	# 两张长凳 + 桌子台面（桌子画在 operator_desk.png 里，台面 = 画布第 64 行）
	platforms = [Vector3(20, 70, 130), Vector3(108, 164, 124), Vector3(BOSS_X - 42, BOSS_X + 38, floor_y - 47)]
	# 没有转灯（天花板是天车道），两边墙上各一盏暖黄壁灯，由 _build_extras 打光
	lamps = []
	darkness = Color(0.42, 0.37, 0.36)
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
	b.platforms = platforms
	b.rail_y = ceil_y + 4.0
	return b


func _build_extras() -> void:
	var desk := Sprite2D.new()
	desk.texture = preload("res://art/boss/operator_desk.png")
	desk.centered = false
	desk.offset = -Operator.CANVAS_ORIGIN
	desk.position = Vector2(BOSS_X, floor_y)
	desk.z_index = -1
	add_child(desk)
	for sx in [WALL_LAMP_L, arena.size.x - WALL_LAMP_L]:
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.72, 0.35)
		l.energy = 0.8
		l.texture_scale = 2.6
		l.position = Vector2(sx, 56)
		l.range_item_cull_mask = 1 | 2
		add_child(l)
	for r in PLATES:
		var p := Operator.ElectricPlate.new()
		p.x0 = r.x
		p.x1 = r.y
		p.floor_y = floor_y
		add_child(p)
		(boss as Operator).plates.append(p)


## 打完先一句句冒出别人没打完的最后一通电话，再接通用流程（定格那句、掉零件、开门）
func _after_defeat() -> void:
	for en_line in LAST_CALLS:
		var line := tr(en_line)
		_card_sub.modulate.a = 1.0
		_card.text = ""
		_card_sub.text = ""
		for i in line.length():
			_card_sub.text = line.substr(0, i + 1)
			await get_tree().create_timer(0.035).timeout
		Game.sfx("dial", -12.0, 0.6)
		await get_tree().create_timer(0.9).timeout
	await super._after_defeat()
