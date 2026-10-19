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
	"refresh": ["REFRESH", "restock + new mutations"],
	"flash": ["FLASH LAMP", "hold to charge, full shot pierces"],
	"hammer": ["STEAM HAMMER", "steam blast all around you"],
	"tongs": ["SHOCK TONGS", "arc jumps 3 (5 when full)"],
	"horn": ["GRAMOPHONE HORN", "pierces, knocks back hard"],
	"rivet": ["RIVET GUN", "hold to fire nonstop"],
	"rage": ["RAGE", "damage x1 when calm, x2 in panic"],
	"slave": ["SLAVE FLASH", "the lantern on the ground shoots too"],
	"echo": ["TAPE ECHO", "each attack repeats at 50%"],
	"dynamo": ["DYNAMO", "every 10 kills: lantern +5"],
	"fuse": ["BLOWN FUSE", "every 5th attack: x3 and a small blast"],
	"valve": ["WARM VALVE", "keep hitting one target: up to +50%"],
	"burnin": ["CRT BURN-IN", "kills leave a ghost that blows up"],
	"rewind": ["REWIND TAPE", "lantern breaks: rewind 5s, once a level"],
}

## 修一次马灯加多少：和别的回血一样乘难度倍率（困难 ×0.7，Run.heal_mult）。
## 不走 Run.heal_crystal：那里会发"回血了"的信号，新手提示和回血特效会在商店里跳
func _repair_amount() -> float:
	return Upgrades.REPAIR_AMOUNT * Run.heal_mult()


## 名字和一行说明：武器从武器登记表（WeaponRegistry）读，别的从 NAMES 读（游戏设计会话 10-18，7 把武器）
func _names(id: String) -> Array:
	if WeaponRegistry.has(id):
		return [WeaponRegistry.name_of(id), str(WeaponRegistry.value(id, "shop", ""))]
	return NAMES[id]


## 出口通往哪里
static var next_scene := "res://scenes/title.tscn"

## 信息框（屏幕坐标，480×270）：屏幕上方正中。放在下面会挡住站在地上的主角；上面这块是洞洞板的边框，
## 挡不到货（货的图标在屏幕 y 70 以下），也让开了左上角的马灯血条和零件数
## 高 56：底边在屏幕 y 58，洞洞板那排卡片顶在 y 60 左右，选中的角标不会碰到
const INFO_RECT := Rect2(96, 2, 288, 56)
## 每把武器的数值（POWER / RATE / REACH），信息卡上照样画格子条。10-18 起从武器登记表读（游戏设计会话：7 把武器），
## 格式和原来选武器界面的 CARDS 一样：[id, 名字, 图标, 说明, 威力, 射速, 射程]
static func _weapon_cards() -> Array:
	var out := []
	for w in WeaponRegistry.LIST:
		var st: Array = w["stats"]
		out.append([w["id"], w["name"], w["icon"], w["card"], st[0], st[1], st[2]])
	return out

const INTRO_TIME := 6.0
## 第一次进店：进门提示多两页（零件是什么、买什么划算、拉杆是刷新），每页 4 秒。
## 站到货前面时照常显示那件货，走开后接着翻没看完的页
const GUIDE_PAGE := 4.0
const GUIDE := [
	["SPEND YOUR PARTS", "parts: one drops after every fight", "", "part"],
	["WHAT'S WORTH IT", "gear (1 part): small boost, up to Lv3", "mutation (2): changes every attack", "charge"],
	["LEVER: REFRESH", "first pull free: new mutations", "sold-out items come back too", "refresh"],
]
## 这一局里是不是已经带着看过一次了（只有第一次进店多翻两页）
static var guided := false

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
var _guide := false
var _guide_t := 0.0
var _card_icon := "part"
var _card_kind := ""
var _card_pop := 0.0
var _card_deny := 0.0
var _key := "V"
var _counter: PartsCounter
## 换武器 / 换变异要按两次（作者 10-18 试玩："买武器的时候要提示会丢掉之前的武器"）：
## 第一次按只是"预备"，信息卡写"再按 V 确认更换"；CONFIRM_TIME 秒内在同一件货前再按一次才换，走开或超时就取消
const CONFIRM_TIME := 2.5
var _confirm_st: ShopStand = null
var _confirm_t := 0.0
## 是谁按的预备：只有同一个人再按才算确认（双人时 2P 不能替 1P 确认，夜间质检报的）
var _confirm_p: Player = null
## 信息卡上武器对比用：货架上那把、按的人现在拿着的那把
var _card_item := ""
var _card_cur := ""
var _ui: CanvasLayer
## 进门小演出：篝火噗地亮一下、冒一把火星，围着火坐的船员挨个抬头看你（时间从进门算）
var _intro_t := 0.0
var _flared := false
var _flare := 0.0


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
	# 人走到 x 360 才亮：这时镜头已经到最右边（视野 240 宽），字在牌子原位；再早亮，字会被 HintSign 推进画面、压在变异货架上（质检 10-18）
	exit_sign.zone = Rect2(360, 150, 120, 120)
	# x 466："出口"不再贴着变异货架第 4 格的右边框（质检 10-18）；再往右会被 HintSign 的离屏 6 像素推回来
	exit_sign.position = Vector2(466, 236)
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
	_counter = counter
	_ui = ui
	if not Run.players.is_empty():
		_key = Controls.key_name(Run.players[0]["input"], "crystal")
	# 玩家中途换了键盘 / 手柄，"V 买"跟着变成对应的键（信息卡每帧都会重写，换完下一帧就生效）
	Controls.device_changed.connect(_on_device_changed)
	if not guided:
		guided = true
		_guide = true
		_info_intro = GUIDE_PAGE * GUIDE.size()
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
			sp.set_meta("seat", seat)
			sp.set_meta("base", s["pos"])
			add_child(sp)
			_crew.append(sp)
		seat += 1


func _add_stands() -> void:
	for i in Upgrades.GEAR.size():
		var st := _stand(Upgrades.GEAR[i], Vector2(HOOKS[i], HOOK_Y + 2))
		st.icon = st.id
	var rep := _stand("repair", Vector2(REPAIR_X, BENCH_Y - 8))
	rep.icon = "repair"
	# 10-18 作者："商店不卖武器"（武器改成打精英掉，布谷鸟钟会话做）：架子上 4 格全卖变异
	for i in 4:
		var st := _stand("mutation", Vector2(SHELF_X[i], SHELF_Y + 10))
		st.zone_half = 13.0
		_mutation_slots.append(st)
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


## 变异 4 格：从身上没有的里面随机挑（8 个去掉身上的还剩 7 个）。
## 刷新时先放刚才没摆出来的，保证至少换出新的，不会花了零件还是原样；买走的那格补回来
func _restock() -> void:
	var m := Upgrades.MUTATIONS.filter(func(x): return x != Upgrades.mutation)
	var shown: Array = []
	for st in _mutation_slots:
		if st.item != "":
			shown.append(st.item)
	var fresh := m.filter(func(x): return not x in shown)
	var old := m.filter(func(x): return x in shown)
	fresh.shuffle()
	old.shuffle()
	var pick: Array = fresh + old
	for i in _mutation_slots.size():
		_mutation_slots[i].item = pick[i] if i < pick.size() else ""
	_update_all()


func _update_all() -> void:
	for st in _stands:
		st.info = _info(st)
		match st.id:
			"weapon", "mutation":
				# 闪光灯没有单独的货架图标，借快充的灯泡
				st.icon = str(WeaponRegistry.value(st.item, "icon", "part")) if st.item != "" else "part"
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
			var price: int = Upgrades.gear_price(lv)
			return {"title": tr("%s  Lv%d > %d") % [tr(n[0]), lv, lv + 1], "detail": _gear_detail(st.id, lv + 1),
					"price": price, "can_buy": parts >= price}
		"repair":
			var price: int = Upgrades.PRICE["repair"]
			var full := Run.crystal_hp >= Run.crystal_max
			return {"title": NAMES["repair"][0],
					"detail": "lantern is fine" if full else tr("lantern +%d   (%d/%d)") % [roundi(_repair_amount()), ceili(Run.crystal_hp), int(Run.crystal_max)],
					"price": 0 if full else price, "can_buy": not full and parts >= price}
		"refresh":
			var price: int = 0 if not _refresh_used else Upgrades.PRICE["refresh"]
			return {"title": NAMES["refresh"][0], "detail": NAMES["refresh"][1],
					"price": price, "can_buy": parts >= price}
		"weapon", "mutation":
			if st.item == "":
				return {"title": "SOLD", "detail": ""}
			var n: Array = _names(st.item)
			var ready := st.item in (Upgrades.implemented_weapons if st.id == "weapon" else Upgrades.implemented_mutations)
			if not ready:
				return {"title": n[0], "detail": "COMING SOON", "dim": true}
			var price: int = Upgrades.PRICE[st.id]
			var detail: String = n[1]
			if st.id == "weapon":
				detail = tr("replaces your %s") % tr(_names(_weapon_of(_buyer(st)))[0])
			elif st.id == "mutation" and Upgrades.mutation != "":
				detail = tr("replaces your %s") % tr(NAMES[Upgrades.mutation][0])
			return {"title": n[0], "detail": detail, "price": price, "can_buy": parts >= price,
					"swap": st.id == "weapon" or Upgrades.mutation != ""}
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
		# 零件不够：左上角零件数也变红抖一下，告诉你缺的是零件
		if _counter and int(info.get("price", 0)) > Run.parts:
			_counter.deny()
		Game.sfx("ui_back", -8.0)
		return
	if st.id == "weapon" and _weapon_of(p) == st.item:
		st.deny()
		_card_deny = 1.0
		Game.sfx("ui_back", -8.0)
		return
	# 会换掉身上东西的货：第一次按只预备，再按一次才换
	if info.get("swap", false) and (_confirm_st != st or _confirm_t <= 0.0 or _confirm_p != p):
		_confirm_st = st
		_confirm_p = p
		_confirm_t = CONFIRM_TIME
		_card_pop = 0.6
		Game.sfx("ui_move", -6.0, 0.8)
		return
	_confirm_st = null
	_confirm_p = null
	_confirm_t = 0.0
	var price: int = info.get("price", 0)
	match st.id:
		"charge", "fuel", "plating", "damping":
			Upgrades.levels[st.id] += 1
			for n in get_tree().get_nodes_in_group("player"):
				Upgrades.apply(n as Player)
		"repair":
			Achievements.on_heal()   # 成就"省电模式"：修马灯也算回血（立绘添加会话，10-18）
			Run.crystal_hp = minf(Run.crystal_hp + _repair_amount(), Run.crystal_max)
			Run.crystal_changed.emit(Run.crystal_hp, Run.crystal_max)
		"refresh":
			_refresh_used = true
		"weapon":
			# 双人各拿各的武器：换按的那个人自己的（游戏设计会话的 Player.set_weapon）；还没有时就是全局那一把
			if p.has_method("set_weapon"):
				p.call("set_weapon", st.item)
			else:
				Upgrades.weapon = st.item
			st.item = ""
		"mutation":
			Achievements.on_mutation(st.item)   # 成就"磁带收藏"：买过几种变异（立绘添加会话，10-18）
			Upgrades.mutation = st.item
			st.item = ""
	if price > 0:
		Run.add_part(-price)
		_fly_parts(p, st, price)
	if st.id == "refresh":
		_restock()
	st.pop()
	_card_pop = 1.0
	Game.sfx("ui_confirm", -4.0)
	Game.sfx("lantern_pick", -10.0, 1.2)
	Game.sparks(self, st.global_position, Color8(255, 211, 138), 8, 60.0)
	_update_all()


func _on_device_changed(_using_pad: bool) -> void:
	if not Run.players.is_empty():
		_key = Controls.key_name(Run.players[0]["input"], "crystal")


## 买到东西：零件一颗颗从人身上飞到货上，每落下一颗"叮"一声（越来越高）。
## 左上角零件数旁边飘的"-N"由 PartsCounter 自己出
func _fly_parts(p: Player, st: ShopStand, price: int) -> void:
	for i in price:
		var f := PartFly.new()
		f.from = p.global_position + Vector2(0, -14)
		f.to = st.global_position
		f.delay = i * 0.09
		var last := i == price - 1
		f.on_arrive = func():
			Game.sfx("ding", -16.0, 1.5 + 0.12 * i)
			if last and is_instance_valid(st):
				st.pop()
		add_child(f)


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
	if _guide:
		var page: Array = GUIDE[mini(int(_guide_t / GUIDE_PAGE), GUIDE.size() - 1)].duplicate()
		# 装备按等级涨价打开时，"装备（1 个零件）"改成"1 个零件起"
		if Upgrades.tiered_gear_price and page[1] == "gear (1 part): small boost, up to Lv3":
			page[1] = "gear (1+ parts): small boost, up to Lv3"
		_card_icon = page[3]
		var third: String = page[2] if page[2] != "" else tr("%s: BUY      EXIT: KEEP RIGHT") % _key
		_set_info([page[0], page[1], third], [UiStyle.WARM, UiStyle.TEXT, UiStyle.WARM if page[2] == "" else UiStyle.TEXT])
		return
	# 第三行顺便说出口在哪：进门时出口在画面外（夜间打磨：出口不好找）
	_set_info(["SPEND YOUR PARTS", "walk up to a glowing item", tr("%s: BUY      EXIT: KEEP RIGHT") % _key],
			[UiStyle.WARM, UiStyle.TEXT, UiStyle.WARM])


## 这个人现在拿着哪把武器（双人各拿各的以后，Player.weapon() 会返回他自己的）
func _weapon_of(p: Player) -> String:
	return p.weapon() if p else Upgrades.weapon


## 站在这件货前面的人（双人都站着时取第一个）
func _buyer(st: ShopStand) -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p and st.near(p):
			return p
	return null


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
	_confirm_t = maxf(_confirm_t - delta, 0.0)
	if _confirm_st != null and (focus != _confirm_st or _confirm_t <= 0.0):
		_confirm_st = null
	if focus:
		# 第一次进店：站到货前面先看货，走开后接着翻引导，不清掉
		if not _guide:
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
					else (tr("FREE REROLL      %s: PULL") % _key)
		else:
			var price: int = info.get("price", 0)
			price_line = (tr("NEED %d PARTS  (YOU HAVE %d)") if price > 1 else tr("NEED %d PART  (YOU HAVE %d)")) % [price, Run.parts] \
					if price > 0 else ""
			price_col = UiStyle.POOR
		var detail: String = info.get("detail", "")
		var detail_col := UiStyle.TEXT
		_card_item = focus.item
		_card_cur = ""
		if focus.id == "weapon" and focus.item != "" and tag != "SOON":
			_card_cur = _weapon_of(_buyer(focus))
			if _card_cur == focus.item:
				# 双人各拿各的武器时，货架上可能摆着按的人手上那把：写"已装备"，按了也不扣零件（_on_buy 里挡掉）
				detail = tr("you already have it")
				detail_col = UiStyle.DIM
				price_line = "EQUIPPED"
				price_col = UiStyle.DIM
			else:
				detail = tr("replaces your %s") % tr(_names(_card_cur)[0])
				detail_col = UiStyle.POOR
		elif focus.id == "mutation" and info.get("swap", false):
			detail_col = UiStyle.POOR
		if focus.id == "mutation":
			# 信息卡底部"★ 和你的 XX 很配"：看站在货架前那个人手上的枪
			_card_cur = _weapon_of(_buyer(focus))
		if _confirm_st == focus:
			price_line = tr("%s AGAIN: SWAP") % _key
			price_col = UiStyle.WARM if int(_time * 6.0) % 2 == 0 else UiStyle.POOR
		_set_info([info.get("title", ""), detail, price_line],
				[UiStyle.WARM, detail_col, price_col])
		_card_icon = focus.icon
		_card_kind = focus.id
		_info_box.visible = true
		_info_box.position = INFO_RECT.position + Vector2(roundf(sin(focus.shake * 60.0) * 2.0 * signf(focus.shake)), 0)
	elif _info_intro > 0.0:
		_info_intro -= delta
		if _guide:
			_guide_t += delta
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
			# 对比：每项数值名字后面竖着叠两条，上面暖黄是货架上这把（新），下面灰的是你手上那把（现在）；
			# 新的比现在多出来的格子一闪一闪。第三行右边一个小图例
			var new_c: Array = []
			var cur_c: Array = []
			for c in _weapon_cards():
				if c[0] == _card_item:
					new_c = c
				if c[0] == _card_cur:
					cur_c = c
			if new_c.is_empty():
				return
			var compare := not cur_c.is_empty() and cur_c != new_c
			var y1 := 41.0 if compare else 43.0
			var y2 := 46.0
			var font := Hud.font()
			if compare:
				# 图例从卡片右边往左排，按当前语言的字宽算位置，中英文都不挤
				var now_t: String = tr("NOW")
				var new_t: String = tr("NEW")
				var xr := 283.0 - roundf(font.get_string_size(now_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
				box.draw_string(font, Vector2(xr, 35), now_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
				box.draw_rect(Rect2(xr - 7, 31, 5, 3), UiStyle.DIM)
				xr -= 13.0 + roundf(font.get_string_size(new_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
				box.draw_string(font, Vector2(xr, 35), new_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
				box.draw_rect(Rect2(xr - 7, 31, 5, 3), UiStyle.WARM)
			var labs: Array = [tr("POWER"), tr("RATE"), tr("REACH")]
			var lw := 0.0
			for l in labs:
				lw = maxf(lw, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
			for k in 3:
				var x := 60.0 + k * 76.0
				box.draw_string(font, Vector2(x, 48), labs[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
				var bx := x + roundf(lw) + 3.0
				var nv: int = new_c[4 + k]
				if not compare:
					UiStyle.bars(box, Vector2(bx, y1), nv, 5, 5.0, 3.0, 1.0)
					continue
				var cv: int = cur_c[4 + k]
				UiStyle.bars(box, Vector2(bx, y1), mini(nv, cv), 5, 5.0, 3.0, 1.0)
				for j in range(cv, nv):
					box.draw_rect(Rect2(bx + j * 6.0, y1, 5, 3), UiStyle.BAR_OFF.lerp(UiStyle.WARM, 0.5 + 0.5 * sin(_time * 8.0)))
				UiStyle.bars(box, Vector2(bx, y2), cv, 5, 5.0, 3.0, 1.0, UiStyle.DIM)
		"mutation":
			if _card_item != "" and Mutations.combos_with(_card_item, _card_cur):
				var line: String = tr("★ great with your %s") % tr(_names(_card_cur)[0])
				box.draw_string(Hud.font(), Vector2(60, 48), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
						UiStyle.WARM.lerp(Color.WHITE, 0.15 + 0.15 * sin(_time * 4.0)))
		"charge", "fuel", "plating", "damping":
			var lv := Upgrades.level(_card_kind)
			box.draw_string(Hud.font(), Vector2(60, y + 5), tr("LEVEL"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
			UiStyle.bars(box, Vector2(98, y), lv, Upgrades.MAX_LEVEL, 16.0, 3.0, 2.0, UiStyle.WARM, _time,
					lv if lv < Upgrades.MAX_LEVEL else -1)
		"repair":
			var ratio := Run.crystal_hp / maxf(Run.crystal_max, 1.0)
			box.draw_string(Hud.font(), Vector2(60, y + 5), tr("LANTERN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
			box.draw_rect(Rect2(110, y, 120, 3), UiStyle.BAR_OFF)
			var add := clampf(_repair_amount() / maxf(Run.crystal_max, 1.0), 0.0, 1.0 - ratio)
			box.draw_rect(Rect2(110 + 120 * ratio, y, 120 * add, 3), UiStyle.BAR_OFF.lerp(UiStyle.WARM, 0.35 + 0.35 * sin(_time * 8.0)))
			box.draw_rect(Rect2(110, y, 120 * ratio, 3), UiStyle.WARM)


func _process(delta: float) -> void:
	_time += delta
	_update_info_box(delta)
	# 进门 0.5 秒（转场淡入差不多完了）篝火噗地亮一下
	_intro_t += delta
	if not _flared and _intro_t >= 0.5:
		_flared = true
		_flare = 1.0
		Game.sfx("embers", -8.0, 1.1)
		Game.sparks(self, Vector2(FIRE_X, FLOOR_LOW - 6), UiStyle.WARM, 14, 70.0, Vector2.UP)
	_flare = maxf(_flare - delta * 1.2, 0.0)
	# 篝火的光一抖一抖
	_fire_light.energy = 0.7 + 0.06 * sin(_time * 7.0) + 0.04 * sin(_time * 17.3) + 0.9 * _flare
	for sp in _crew:
		sp.frame = int((_time + float(sp.get_meta("phase"))) / 0.2) % 4
		# 火一亮，船员挨个抬头（往上 1 像素）看一眼
		var since := _intro_t - 0.65 - 0.12 * int(sp.get_meta("seat", 0))
		sp.position = sp.get_meta("base", sp.position) + Vector2(0, -1 if since > 0.0 and since < 0.35 else 0)


func _physics_process(_delta: float) -> void:
	if _leaving:
		return
	for n in get_tree().get_nodes_in_group("player"):
		if (n as Node2D).global_position.x >= EXIT_X:
			_leaving = true
			SceneFade.go(get_tree(), next_scene)
			return
