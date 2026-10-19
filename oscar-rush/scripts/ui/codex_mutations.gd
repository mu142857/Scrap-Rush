class_name CodexMutations
extends Control
## 总图鉴的"变异与升级"一册（codex_menu.gd 里用）：上面两排 8 个变异（10-18 作者加了保险丝、真空管、显像管残影、倒带磁带），
## 下面一排 4 个装备升级（格子里只放图标，英文名字太长放不下）。
## 右边是大图标、名字、价钱和规矩、效果说明（带实际数值）。都是商店里的东西，直接全部显示。
## 数值照 mutations.gd、upgrades.gd、player.gd 和策划案第十节"变异的实现和系数"（10-18 武器第三版后复核的表）；
## 新四个的数字直接读 Mutations 的常量（说明里的 %d / %s 在 _select 里填）。
## 改了系数记得改这里的说明（text.csv 的中文也要跟着改）。

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const LIT_FILL := Color(0.19, 0.175, 0.18)

## [id（同时是图标名）, 名字（和商店一样）, 效果说明（一句一条，各自翻译）]
const MUTATIONS := [
	["rage", "RAGE", ["Damage x1 when calm, up to x2 in panic. Shots turn redder the angrier you get.", "At full panic, every hit does double damage."]],
	["slave", "SLAVE FLASH", ["While the lantern sits on the ground, it fires a small orb at the nearest enemy within 150 each time you attack.", "Orb damage: Flash %d, Rivet %d (every %dth rivet), Hammer %d."]],
	["echo", "TAPE ECHO", ["0.3 s after each attack, it plays again from where you stand, at 50% damage.", "The Rivet Gun echoes every 3rd rivet. Echoes never echo."]],
	["dynamo", "DYNAMO", ["Every 10 kills: lantern +5.", "The 10 notches under the lantern bar show your progress. More enemies, more healing."]],
	["fuse", "BLOWN FUSE", ["Every %dth attack does x%s damage and turns orange.", "Its first hit sets off a small blast: %d dmg within %d."]],
	["valve", "WARM VALVE", ["Keep hitting the same target: +%d%% each hit, up to +%d%%.", "Switch targets and it cools back down."]],
	["burnin", "CRT BURN-IN", ["Enemies you kill leave a burned-in ghost that blows up %s s later.", "Blast: %d%% of the killing blow (at least %d) within %d. Ghost kills leave no ghosts."]],
	["rewind", "REWIND TAPE", ["When the lantern breaks, you and the lantern rewind %s s instead.", "Once per level. The lantern comes back with at least %d%%."]],
]
const GEAR := [
	# 快充对 7 把武器各不一样（10-19 作者觉得只写老三把有迷惑性）：每把一行，数字在 _quick_lines 里从各武器脚本现读
	["charge", "QUICK CHARGE", ["Per level, for the weapon in your hand:"]],
	["fuel", "BIG TANK", ["Per level: +0.35 s of rocket boot fuel.", "Base fuel is 1.0 s, or 0.7 s while you carry the lantern."]],
	["plating", "PLATING", ["Blocks one hit on the lantern every 20 / 15 / 10 s (Lv1 / Lv2 / Lv3)."]],
	["damping", "DAMPER", ["Per level: emotion rises 20% slower over time.", "At Lv3 it climbs at 40% speed."]],
]

const COLS := 4
## 8 个变异排两排、装备一排：格子矮一点（放 2 倍图标）
const TILE := Vector2(56, 40)
const TILE_GAP := 5.0
const ROW_Y := [66.0, 110.0, 172.0]
const GRID_X := 14.0
const DETAIL := Rect2(268, 54, 200, 188)

var embedded := true
var _sel := 0
var _time := 0.0
var _ready_for_input := false

var _base: Control
var _headers: Array[Label] = []
var _name: Label
var _cost: Label
var _desc: Label
## 说明太长（快充 8 行）时详情卡改紧凑排法：大图标缩成 2 倍，名字、价钱、说明往上挪
var _compact := false
const COMPACT_UP := 38.0


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = Control.new()
	_base.size = Vector2(480, 270)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.draw.connect(_draw_base)
	add_child(_base)
	var h1 := _label(GRID_X, ROW_Y[0] - 15, 240, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	h1.text = tr("MUTATIONS") + "   " + tr("2 parts, one at a time")
	var h2 := _label(GRID_X, ROW_Y[2] - 15, 240, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	h2.text = tr("GEAR") + "   " + tr("1 part a level, up to Lv3")
	_headers = [h1, h2]
	var x := DETAIL.position.x + 8
	var w := DETAIL.size.x - 16
	_name = _label(x, DETAIL.position.y + 78, w, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_cost = _label(x, DETAIL.position.y + 91, w, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(x, DETAIL.position.y + 110, w, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.label_settings.line_spacing = Lang.tight_line()
	_select(0)
	await get_tree().process_frame
	_ready_for_input = true


## 快充每升一级，每把武器快多少：老三把读 player.gd，新四把读各自的出招脚本（不写类名，load 了读常量）
func _quick_lines() -> PackedStringArray:
	var pl: Dictionary = load("res://scripts/player/player.gd").get_script_constant_map()
	var sg: Dictionary = load("res://scripts/combat/weapons/shotgun.gd").get_script_constant_map()
	var lz: Dictionary = load("res://scripts/combat/weapons/laser.gd").get_script_constant_map()
	var rc: Dictionary = load("res://scripts/combat/weapons/record.gd").get_script_constant_map()
	var tg: Dictionary = load("res://scripts/combat/weapons/tongs.gd").get_script_constant_map()
	var wname := func(id: String) -> String: return tr(WeaponRegistry.get_def(id).get("name", id))
	return [
		tr("%s: charges %s s faster") % [wname.call("flash"), _num(pl["CHARGE_UPGRADE"])],
		tr("%s: %s s less between rivets") % [wname.call("rivet"), _num(pl["RIVET_UPGRADE"])],
		tr("%s: cools down %s s faster") % [wname.call("hammer"), _num(pl["HAMMER_UPGRADE"])],
		tr("%s: %s s less between blasts") % [wname.call("shotgun"), _num(sg["INTERVAL_UPGRADE"])],
		tr("%s: charges %s s faster") % [wname.call("laser"), _num(lz["CHARGE_UPGRADE"])],
		tr("%s: flies %d%% faster") % [wname.call("record"), roundi(rc["QUICK_SPEED"] * 100.0)],
		tr("%s: %s s less between arcs") % [wname.call("tongs"), _num(tg["INTERVAL_UPGRADE"])],
	]


func _num(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _label(x: float, y: float, w: float, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(color)
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, 15)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _count() -> int:
	return MUTATIONS.size() + GEAR.size()


func _entry(i: int) -> Array:
	return MUTATIONS[i] if i < MUTATIONS.size() else GEAR[i - MUTATIONS.size()]


func _tile_rect(i: int) -> Rect2:
	var row := i / COLS
	var col := i % COLS
	return Rect2(GRID_X + col * (TILE.x + TILE_GAP), ROW_Y[row], TILE.x, TILE.y)


func _process(delta: float) -> void:
	_time += delta
	_base.queue_redraw()


func _select(i: int) -> void:
	_sel = clampi(i, 0, _count() - 1)
	var e := _entry(_sel)
	_name.text = tr(e[1])
	if _sel < MUTATIONS.size():
		_cost.text = tr("MUTATION") + "  -  " + tr("2 PARTS")
	else:
		_cost.text = tr("GEAR") + "  -  " + tr("1 PART PER LEVEL")
	var lines: PackedStringArray = PackedStringArray(e[2].map(func(line): return tr(line)))
	match e[0]:
		"charge":
			lines.append_array(_quick_lines())
		"slave":
			lines[1] = lines[1] % [Mutations.SLAVE_DAMAGE, Mutations.SLAVE_RIVET_DAMAGE, Mutations.SLAVE_RIVET_EVERY, Mutations.SLAVE_HAMMER_DAMAGE]
		"fuse":
			lines[0] = lines[0] % [Mutations.FUSE_EVERY, _num(Mutations.FUSE_MULT)]
			lines[1] = lines[1] % [Mutations.FUSE_BLAST, Mutations.FUSE_RADIUS]
		"valve":
			lines[0] = lines[0] % [roundi(Mutations.VALVE_STEP * 100.0), roundi(Mutations.VALVE_STEP * Mutations.VALVE_MAX * 100.0)]
		"burnin":
			lines[0] = lines[0] % _num(Mutations.BURNIN_DELAY)
			lines[1] = lines[1] % [roundi(Mutations.BURNIN_RATIO * 100.0), Mutations.BURNIN_MIN, Mutations.BURNIN_RADIUS]
		"rewind":
			lines[0] = lines[0] % _num(Mutations.REWIND_SECONDS)
			lines[1] = lines[1] % roundi(Mutations.REWIND_MIN_HP * 100.0)
	_desc.text = "\n".join(lines)
	_desc.size = Vector2(DETAIL.size.x - 16, 0)
	_compact = 110.0 + _desc.get_minimum_size().y > DETAIL.size.y - 4.0
	var up := COMPACT_UP if _compact else 0.0
	_name.position.y = DETAIL.position.y + 78 - up
	_cost.position.y = DETAIL.position.y + 91 - up
	_desc.position.y = DETAIL.position.y + 110 - up


## 总图鉴调：用掉了返回 true
func handle(event: InputEvent) -> bool:
	if not _ready_for_input:
		return false
	if event is InputEventMouseMotion:
		var m := get_local_mouse_position()
		for i in _count():
			if i != _sel and _tile_rect(i).has_point(m):
				_select(i)
		return false
	var to := _sel
	if event.is_action_pressed("ui_left", true):
		to = _sel - 1 if _sel % COLS > 0 else _sel
	elif event.is_action_pressed("ui_right", true):
		to = _sel + 1 if _sel % COLS < COLS - 1 else _sel
	elif event.is_action_pressed("ui_up", true):
		to = _sel - COLS if _sel >= COLS else _sel
	elif event.is_action_pressed("ui_down", true):
		to = _sel + COLS if _sel + COLS < _count() else _sel
	elif event.is_action_pressed("ui_accept"):
		return true
	else:
		return false
	if to != _sel:
		_select(to)
		Game.sfx("ui_move", -12.0)
	return true


func _draw_base() -> void:
	var c := _base
	for i in _count():
		var r := _tile_rect(i)
		UiStyle.panel(c, r, i == _sel, _time, WARM, LIT_FILL)
		var idx := maxi(ShopStand.ICON_NAMES.find(_entry(i)[0]), 0)
		UiStyle.icon(c, ShopStand.ICONS, idx, (r.position + (r.size - Vector2(32, 32)) / 2).round(), 2)
	UiStyle.panel(c, DETAIL, true, 0.0)
	# 详情卡：大图标（4 倍），底下一圈暖光底
	var up := COMPACT_UP if _compact else 0.0
	var idx := maxi(ShopStand.ICON_NAMES.find(_entry(_sel)[0]), 0)
	var bob := roundf(sin(_time * 2.5)) if fmod(_time, 2.0) < 1.0 else 0.0
	if _compact:
		var small := Rect2(DETAIL.get_center().x - 18, DETAIL.position.y + 4, 36, 34)
		c.draw_rect(small, LIT_FILL)
		UiStyle.icon(c, ShopStand.ICONS, idx, Vector2(small.position.x + 2, small.position.y + 1 + bob), 2)
	else:
		var big := Rect2(DETAIL.get_center().x - 36, DETAIL.position.y + 6, 72, 68)
		c.draw_rect(big, LIT_FILL)
		UiStyle.icon(c, ShopStand.ICONS, idx, Vector2(big.position.x + 4, big.position.y + 2 + bob), 4)
	c.draw_rect(Rect2(DETAIL.position.x + 18, DETAIL.position.y + 106 - up, DETAIL.size.x - 36, 1), UiStyle.BAR_OFF)
