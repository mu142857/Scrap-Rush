class_name ShopRoom
extends Node2D
## 商店（升级房间，策划案第十节）。每关结尾进一次，三次都用这个场景。没有怪，情绪不动。
## 房间右半边是 Oscar 画的，左半边和图标见 tools/draw_shop.py（下面的坐标和它对上）。
## 马灯放在正中间当篝火，另外三个船员坐在旁边。货：
##   洞洞板上 4 件旧装备（每级 1 个零件，最多 3 级），工作台右头修灯（1 个，水晶 +25），
##   黑机箱正面 4 个小窗：武器 2（3 个）、变异 2（2 个），机箱左边的拉杆刷新（第一次免费，之后 1 个）。
## 走到东西前面按互动键（捡灯那个键）就买。出口在右边。
## 每件货下面常驻价签，买得起的四角一闪一闪；站到哪件前面，屏幕下方的信息框就显示它的名字、说明、价钱。
## 进门时信息框先提示一句该干什么。
##
## 进商店：ShopRoom.next_scene = "下一关的场景"，然后 change_scene_to_file("res://scenes/shop.tscn")。

const ROOM := preload("res://art/shop/room.png")
const ROOM_FG := preload("res://art/shop/room_fg.png")
const BOUNDS := Rect2(0, 0, 480, 270)
const FLOOR_LOW := 258.0
const FLOOR_HIGH := 252.0
const STEP_X := 281.0
const HOOKS: Array[float] = [36.0, 70.0, 104.0, 138.0]
const HOOK_Y := 176.0
const BENCH_Y := 226.0
const REPAIR_X := 160.0
const FIRE_X := 236.0
const CRATE_TOP := 248.0
const SHELF_Y := 206.0
const SHELF_X: Array[float] = [352.0, 380.0, 414.0, 442.0]
const REFRESH_X := 300.0
const SPAWN := Vector2(20, 258)
const EXIT_X := 474.0
## 船员坐的位置：脚底坐标、朝向、是不是坐在箱子上（不是就坐在台阶上，腿裁掉）
const CREW_SEATS := [
	{"pos": Vector2(204, 254), "face": 1, "crate": true},
	{"pos": Vector2(262, 254), "face": -1, "crate": true},
	{"pos": Vector2(290, 252), "face": -1, "crate": false},
]
const NAMES := {
	"charge": ["QUICK CHARGE", "faster charge / fire rate / hammer cooldown"],
	"fuel": ["BIG TANK", "rocket fuel +0.35s"],
	"plating": ["PLATING", "blocks a hit every %ds"],
	"damping": ["DAMPER", "emotion rises 20% slower"],
	"repair": ["REPAIR LANTERN", "lantern +25"],
	"refresh": ["REFRESH", "new weapons & mutations"],
	"flash": ["FLASH LAMP", "hold to charge, full shot pierces"],
	"hammer": ["STEAM HAMMER", "steam blast all around you"],
	"tongs": ["SHOCK TONGS", "arc jumps 3 (5 when full)"],
	"horn": ["GRAMOPHONE HORN", "pierces, knocks back hard"],
	"rivet": ["RIVET GUN", "hold to fire nonstop"],
	"rage": ["RAGE", "damage x1 when calm, x2 in panic"],
	"slave": ["SLAVE FLASH", "the lantern on the ground shoots too"],
	"echo": ["TAPE ECHO", "each attack repeats at 50%"],
	"dynamo": ["DYNAMO", "every 10 kills: lantern +5"],
}

## 出口通往哪里
static var next_scene := "res://scenes/title.tscn"

## 信息框（屏幕坐标，480×270）：屏幕上方正中。放在下面会挡住站在地上的主角；上面这块是洞洞板的边框，
## 挡不到货（货的图标在屏幕 y 70 以下），也让开了左上角的马灯血条和零件数
## 高 56：底边在屏幕 y 58，洞洞板那排卡片顶在 y 60 左右，选中的角标不会碰到
const INFO_RECT := Rect2(96, 2, 288, 56)
## 选武器界面那三把的数值（POWER / RATE / REACH），信息卡上照样画格子条；没有的武器不画
const WEAPON_CARDS := preload("res://scripts/ui/weapon_select.gd").CARDS
const INTRO_TIME := 6.0

var _stands: Array[ShopStand] = []
var _weapon_slots: Array[ShopStand] = []
var _mutation_slots: Array[ShopStand] = []
var _refresh_used := false
var _leaving := false
var _crew: Array[Sprite2D] = []
var _time := 0.0
var _fire_light: PointLight2D
var _info_box: Control
var _info_lines: Array[Label] = []
var _info_focus: ShopStand = null
var _info_intro := INTRO_TIME
var _card_icon := "part"
var _card_kind := ""
var _card_pop := 0.0
var _card_deny := 0.0
var _key := "V"


func _ready() -> void:
	# 调试：在编辑器里直接运行这个场景（F6）时，手上没零件就先给 6 个，方便试买
	if OS.is_debug_build() and get_tree().current_scene == self and Run.parts == 0:
		Run.add_part(6)
	var bg := Sprite2D.new()
	bg.texture = ROOM
	bg.centered = false
	bg.z_index = -10
	add_child(bg)
	var fg := Sprite2D.new()
	fg.texture = ROOM_FG
	fg.centered = false
	fg.z_index = 6
	add_child(fg)
	_build_collision()

	# 篝火：马灯放在地上，外面再加一圈大一点、会抖的暖光
	var crystal := Crystal.new()
	crystal.position = Vector2(FIRE_X, FLOOR_LOW)
	add_child(crystal)
	_fire_light = PointLight2D.new()
	_fire_light.texture = Game.light_texture()
	_fire_light.color = Crystal.LIGHT_COLOR
	_fire_light.energy = 0.7
	_fire_light.texture_scale = 5.5
	_fire_light.position = Vector2(FIRE_X, FLOOR_LOW - 8)
	add_child(_fire_light)

	_add_crew()
	_add_stands()

	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = SPAWN + Vector2(i * 14, 0)
		add_child(p)
		Upgrades.apply(p)

	var exit_sign := HintSign.new()
	exit_sign.zone = Rect2(380, 150, 100, 120)
	exit_sign.position = Vector2(462, 236)
	exit_sign.text = "Exit"
	exit_sign.arrow = "right"
	add_child(exit_sign)

	var cam := GameCamera.new()
	cam.bounds = BOUNDS
	add_child(cam)
	cam.snap()

	var hud := Hud.new()
	add_child(hud)
	var ui := CanvasLayer.new()
	ui.layer = 11
	add_child(ui)
	var counter := PartsCounter.new()
	counter.position = Vector2(10, 24)
	ui.add_child(counter)
	if not Run.players.is_empty():
		_key = Controls.key_name(Run.players[0]["input"], "crystal")
	_build_info_box(ui)
	Run.crystal_changed.emit(Run.crystal_hp, Run.crystal_max)


func _build_collision() -> void:
	var floor_poly := PackedVector2Array([
		Vector2(-16, FLOOR_LOW), Vector2(STEP_X - 1, FLOOR_LOW), Vector2(STEP_X + 5, FLOOR_HIGH),
		Vector2(BOUNDS.end.x + 16, FLOOR_HIGH), Vector2(BOUNDS.end.x + 16, 300), Vector2(-16, 300),
	])
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionPolygon2D.new()
	shape.polygon = floor_poly
	body.add_child(shape)
	add_child(body)
	for r in [Rect2(-16, -40, 16, 340), Rect2(BOUNDS.end.x, -40, 16, 340), Rect2(0, -40, BOUNDS.end.x, 47)]:
		var b := StaticBody2D.new()
		b.collision_layer = 1
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = (r as Rect2).size
		cs.shape = rect
		cs.position = (r as Rect2).get_center()
		b.add_child(cs)
		add_child(b)


## 没被选中的船员围着篝火坐（多人时人少一些）
func _add_crew() -> void:
	var taken: Array[String] = []
	for pl in Run.players:
		taken.append(pl["skin"])
	var seat := 0
	for skin in Run.SKINS:
		if skin in taken or seat >= CREW_SEATS.size():
			continue
		var s: Dictionary = CREW_SEATS[seat]
		for part in ["body", "strip"]:
			var sp := Sprite2D.new()
			sp.texture = load("res://art/chars/%s_%s.png" % [skin, part])
			sp.hframes = 7
			sp.centered = false
			sp.offset = Vector2(-8, -Player.FRAME_SIZE.y)
			sp.position = s["pos"]
			sp.flip_h = s["face"] < 0
			sp.z_index = 2
			if not s["crate"]:
				# 坐在台阶上：裁掉腿
				sp.region_enabled = true
				sp.region_rect = Rect2(0, 0, 16 * 7, Player.FRAME_SIZE.y - 6)
				sp.offset.y += 6
			if part == "strip":
				var unshaded := CanvasItemMaterial.new()
				unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
				sp.material = unshaded
			sp.set_meta("phase", seat * 0.37)
			add_child(sp)
			_crew.append(sp)
		seat += 1


func _add_stands() -> void:
	for i in Upgrades.GEAR.size():
		var st := _stand(Upgrades.GEAR[i], Vector2(HOOKS[i], HOOK_Y + 2))
		st.icon = st.id
	var rep := _stand("repair", Vector2(REPAIR_X, BENCH_Y - 8))
	rep.icon = "repair"
	for i in 4:
		var st := _stand("weapon" if i < 2 else "mutation", Vector2(SHELF_X[i], SHELF_Y + 10))
		st.zone_half = 13.0
		(_weapon_slots if i < 2 else _mutation_slots).append(st)
	var ref := _stand("refresh", Vector2(REFRESH_X - 3, FLOOR_HIGH - 12))
	ref.icon = "refresh"
	ref.get_child(0).visible = false        # 拉杆画在房间图里了，不再放图标
	ref.zone_half = 10.0
	ref.tag_y = -22.0                       # 拉杆的价签放在拉杆上面，地上放不下
	_restock()


func _stand(id: String, pos: Vector2) -> ShopStand:
	var st := ShopStand.new()
	st.id = id
	st.position = pos
	st.buy_pressed.connect(_on_buy)
	add_child(st)
	_stands.append(st)
	return st


## 武器 2 把、变异 2 个：从身上没有的里面随机挑
func _restock() -> void:
	var w := Upgrades.WEAPONS.filter(func(x): return x != Upgrades.weapon)
	var m := Upgrades.MUTATIONS.filter(func(x): return x != Upgrades.mutation)
	w.shuffle()
	m.shuffle()
	for i in 2:
		_weapon_slots[i].item = w[i]
		_mutation_slots[i].item = m[i]
	_update_all()


func _update_all() -> void:
	for st in _stands:
		st.info = _info(st)
		match st.id:
			"weapon", "mutation":
				# 闪光灯没有单独的货架图标，借快充的灯泡
				st.icon = ("charge" if st.item == "flash" else st.item) if st.item != "" else "part"
				st.get_child(0).visible = st.item != ""
			"charge", "fuel", "plating", "damping":
				st.pips = Upgrades.level(st.id)
		st.refresh_view()


func _info(st: ShopStand) -> Dictionary:
	var parts := Run.parts
	match st.id:
		"charge", "fuel", "plating", "damping":
			var lv := Upgrades.level(st.id)
			var n: Array = NAMES[st.id]
			if lv >= Upgrades.MAX_LEVEL:
				return {"title": tr("%s  MAX") % tr(n[0]), "detail": _gear_detail(st.id, lv), "maxed": true}
			var price: int = Upgrades.PRICE["gear"]
			return {"title": tr("%s  Lv%d > %d") % [tr(n[0]), lv, lv + 1], "detail": _gear_detail(st.id, lv + 1),
					"price": price, "can_buy": parts >= price}
		"repair":
			var price: int = Upgrades.PRICE["repair"]
			var full := Run.crystal_hp >= Run.crystal_max
			return {"title": NAMES["repair"][0],
					"detail": "lantern is fine" if full else tr("lantern +25   (%d/%d)") % [ceili(Run.crystal_hp), int(Run.crystal_max)],
					"price": 0 if full else price, "can_buy": not full and parts >= price}
		"refresh":
			var price: int = 0 if not _refresh_used else Upgrades.PRICE["refresh"]
			return {"title": NAMES["refresh"][0], "detail": NAMES["refresh"][1],
					"price": price, "can_buy": parts >= price}
		"weapon", "mutation":
			if st.item == "":
				return {"title": "SOLD", "detail": ""}
			var n: Array = NAMES[st.item]
			var ready := st.item in (Upgrades.implemented_weapons if st.id == "weapon" else Upgrades.implemented_mutations)
			if not ready:
				return {"title": n[0], "detail": "COMING SOON", "dim": true}
			var price: int = Upgrades.PRICE[st.id]
			var swap := ""
			if st.id == "weapon":
				swap = tr("  (drops %s)") % tr(NAMES[Upgrades.weapon][0])
			elif st.id == "mutation" and Upgrades.mutation != "":
				swap = tr("  (drops %s)") % tr(NAMES[Upgrades.mutation][0])
			return {"title": tr(n[0]) + swap, "detail": n[1], "price": price, "can_buy": parts >= price}
	return {}


func _gear_detail(id: String, lv: int) -> String:
	if id == "plating":
		return tr(NAMES[id][1]) % int(Upgrades.PLATING_INTERVAL[clampi(lv, 1, 3)])
	return NAMES[id][1]


func _on_buy(st: ShopStand, p: Player) -> void:
	var info := st.info
	if not info.get("can_buy", false):
		st.deny()
		_card_deny = 1.0
		Game.sfx("ui_back", -8.0)
		return
	var price: int = info.get("price", 0)
	match st.id:
		"charge", "fuel", "plating", "damping":
			Upgrades.levels[st.id] += 1
			for n in get_tree().get_nodes_in_group("player"):
				Upgrades.apply(n as Player)
		"repair":
			Run.crystal_hp = minf(Run.crystal_hp + Upgrades.REPAIR_AMOUNT, Run.crystal_max)
			Run.crystal_changed.emit(Run.crystal_hp, Run.crystal_max)
		"refresh":
			_refresh_used = true
		"weapon":
			Upgrades.weapon = st.item
			st.item = ""
		"mutation":
			Upgrades.mutation = st.item
			st.item = ""
	if price > 0:
		Run.add_part(-price)
	if st.id == "refresh":
		_restock()
	st.pop()
	_card_pop = 1.0
	Game.sfx("ui_confirm", -4.0)
	Game.sfx("lantern_pick", -10.0, 1.2)
	Game.sparks(self, st.global_position, Color8(255, 211, 138), 8, 60.0)
	_update_all()


## 信息卡：和开局选武器界面同一套画法（UiStyle）。左边一格放大 3 倍的图标，右边名字 / 说明 / 价钱三行，
## 底下一排格子条（武器：POWER / RATE / REACH；装备：LEVEL，下一级一闪一闪；修灯：马灯血量）。
## 切换货时"嘀"一声（ui_move），买到时卡片弹一下（ui_confirm），买不起时边变红、抖一下（ui_back）
func _build_info_box(ui: CanvasLayer) -> void:
	_info_box = Control.new()
	_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box.position = INFO_RECT.position
	_info_box.size = INFO_RECT.size
	_info_box.pivot_offset = INFO_RECT.size * 0.5
	_info_box.draw.connect(_draw_card)
	ui.add_child(_info_box)
	for i in 3:
		var l := UiStyle.label("", UiStyle.TEXT, Vector2(60, 2 + i * 12), INFO_RECT.size.x - 66)
		_info_box.add_child(l)
		_info_lines.append(l)
	_show_intro()


func _set_info(lines: Array, colors: Array) -> void:
	for i in 3:
		_info_lines[i].text = lines[i] if i < lines.size() else ""
		_info_lines[i].label_settings = Hud.small_text(colors[i] if i < colors.size() else UiStyle.DIM)


func _show_intro() -> void:
	_card_icon = "part"
	_card_kind = "intro"
	_set_info(["SPEND YOUR PARTS", "walk up to a glowing item", tr("%s: BUY") % _key],
			[UiStyle.WARM, UiStyle.TEXT, UiStyle.WARM])


## 站到哪件前面就显示哪件；都没站时，进门那几秒显示提示，之后收起来
func _update_info_box(delta: float) -> void:
	_card_pop = maxf(_card_pop - delta * 4.0, 0.0)
	_card_deny = maxf(_card_deny - delta * 2.5, 0.0)
	var focus: ShopStand = null
	for st in _stands:
		if st.focused:
			focus = st
			break
	if focus != _info_focus and focus != null:
		Game.sfx("ui_move", -12.0)
	if focus:
		_info_intro = 0.0
		var info := focus.info
		var price_line := ""
		var price_col := UiStyle.WARM
		var tag := focus.tag_text()
		if tag in ["MAX", "SOLD"]:
			price_line = "MAXED OUT" if tag == "MAX" else "SOLD OUT"
			price_col = UiStyle.DIM
		elif tag == "SOON":
			price_line = "NOT FOR SALE YET"
			price_col = UiStyle.DIM
		elif focus.can_buy():
			var price: int = info.get("price", 0)
			price_line = ((tr("%d PARTS      %s: BUY") if price > 1 else tr("%d PART      %s: BUY")) % [price, _key]) if price > 0 \
					else (tr("FREE      %s: PULL") % _key)
		else:
			var price: int = info.get("price", 0)
			price_line = (tr("NEED %d PARTS  (YOU HAVE %d)") if price > 1 else tr("NEED %d PART  (YOU HAVE %d)")) % [price, Run.parts] \
					if price > 0 else ""
			price_col = UiStyle.POOR
		_set_info([info.get("title", ""), info.get("detail", ""), price_line],
				[UiStyle.WARM, UiStyle.TEXT, price_col])
		_card_icon = focus.icon
		_card_kind = focus.id
		_info_box.visible = true
		_info_box.position = INFO_RECT.position + Vector2(roundf(sin(focus.shake * 60.0) * 2.0 * signf(focus.shake)), 0)
	elif _info_intro > 0.0:
		_info_intro -= delta
		_show_intro()
		_info_box.visible = true
		_info_box.position = INFO_RECT.position
	else:
		_info_box.visible = false
	# 买到：卡片往上弹 2 像素（整数像素，不缩放）
	_info_box.position.y -= roundf(sin(_card_pop * PI) * 2.0)
	_info_focus = focus
	_info_box.queue_redraw()


func _draw_card() -> void:
	var box := _info_box
	var r := Rect2(Vector2.ZERO, INFO_RECT.size)
	var base := UiStyle.WARM
	if _info_focus != null:
		base = _info_focus.edge_color()
	var edge := base.lerp(UiStyle.POOR, clampf(_card_deny * 2.0, 0.0, 1.0))
	UiStyle.panel(box, r, true, _time, edge)
	# 图标格
	var ir := Rect2(4, 4, 50, 48)
	UiStyle.panel(box, ir, false, _time, UiStyle.WARM, Color(0.03, 0.03, 0.04, 0.9))
	var bob := roundf(sin(_time * 3.0) * 1.5)
	var dim := _info_focus != null and not _info_focus.can_buy()
	UiStyle.icon(box, ShopStand.ICONS, maxi(ShopStand.ICON_NAMES.find(_card_icon), 0), Vector2(5, 4 + bob), 3,
			UiStyle.DIM_MOD if dim else Color.WHITE)
	# 底下一排格子条
	var y := 43.0
	match _card_kind:
		"weapon":
			for c in WEAPON_CARDS:
				if c[0] == _card_icon:
					for k in 3:
						var x := 60.0 + k * 74.0
						var lab: String = tr(["POWER", "RATE", "REACH"][k])
						var lw := Hud.font().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
						box.draw_string(Hud.font(), Vector2(x, y + 5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
						UiStyle.bars(box, Vector2(x + lw + 4.0, y), c[4 + k], 5, 5.0, 3.0, 1.0)
		"charge", "fuel", "plating", "damping":
			var lv := Upgrades.level(_card_kind)
			box.draw_string(Hud.font(), Vector2(60, y + 5), tr("LEVEL"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
			UiStyle.bars(box, Vector2(98, y), lv, Upgrades.MAX_LEVEL, 16.0, 3.0, 2.0, UiStyle.WARM, _time,
					lv if lv < Upgrades.MAX_LEVEL else -1)
		"repair":
			var ratio := Run.crystal_hp / maxf(Run.crystal_max, 1.0)
			box.draw_string(Hud.font(), Vector2(60, y + 5), tr("LANTERN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
			box.draw_rect(Rect2(110, y, 120, 3), UiStyle.BAR_OFF)
			var add := clampf(Upgrades.REPAIR_AMOUNT / maxf(Run.crystal_max, 1.0), 0.0, 1.0 - ratio)
			box.draw_rect(Rect2(110 + 120 * ratio, y, 120 * add, 3), UiStyle.BAR_OFF.lerp(UiStyle.WARM, 0.35 + 0.35 * sin(_time * 8.0)))
			box.draw_rect(Rect2(110, y, 120 * ratio, 3), UiStyle.WARM)


func _process(delta: float) -> void:
	_time += delta
	_update_info_box(delta)
	# 篝火的光一抖一抖
	_fire_light.energy = 0.7 + 0.06 * sin(_time * 7.0) + 0.04 * sin(_time * 17.3)
	for sp in _crew:
		sp.frame = int((_time + float(sp.get_meta("phase"))) / 0.2) % 4


func _physics_process(_delta: float) -> void:
	if _leaving:
		return
	for n in get_tree().get_nodes_in_group("player"):
		if (n as Node2D).global_position.x >= EXIT_X:
			_leaving = true
			SceneFade.go(get_tree(), next_scene)
			return
