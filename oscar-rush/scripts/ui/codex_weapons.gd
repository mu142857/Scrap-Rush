class_name CodexWeapons
extends Control
## 总图鉴的"武器图鉴"一册（codex_menu.gd 里用）：开局 7 把武器（闪光灯、铆钉枪、蒸汽锤、废铁霰弹枪、显像管激光、
## 唱片回旋镖、特斯拉电钳；顺序和 WeaponRegistry 一样）。新四把的打法一句话直接用登记表的 card + trait。
## 左上一排格子选武器（只放图标，名字在右边大字），左下是出招示意（主角对着三只齿轮爬虫打），右边是名字、发不发光、三条数值格（和选武器界面同一套）、
## 实际数值和一句打法。三把开局就能选，所以都直接显示，不按"用没用过"点亮。
##
## 示意动画照游戏里的真实表现做（作者 10-18："图鉴的武器使用和真实的不符"），对照网页版实拍逐项核过：
## - 数值不抄：打开时从 player.gd / orb.gd / rivet.gd / steam_blast.gd / casing.gd / crawler.gd 里读常量，
##   以后调了武器，动画和右边的数字自动跟着变
## - 画法照抄各脚本的 _draw：蓄力圈（一圈 12 个点从正上方顺时针亮、满了整圈变白呼吸）、光球（十字形 + 6 格拖尾）、
##   铆钉（2×2 亮头 + 拖尾，射程尽头分三档变淡）、枪口火光（十字星 / 尖火一发一换，只亮一两帧）、
##   弹壳（往身后上方抛、落地弹两下）、蒸汽锤（两圈像素环、中心一团白、喷出去的蒸汽方块、脚下冷却弧、冷却好时人身上一圈白）
## - 靶子是真的齿轮爬虫（100 血）：挨打发白、往后退，打死冒灰色和橙色碎屑后消失；示意里每一轮开头再放回来
## - 唱片回旋镖（10-18 加，总机台/留声机会话做的武器）：唱片的飞法、割法、画法照 record.gd / record_disc.gd；
##   真实射程 130 比舞台（120）长，所以舞台右边立一堵墙，正好演"碰墙弹一次"：去程割、弹回来、停一下、飞回手里再割
## - 霰弹枪 / 激光 / 电钳（10-18 加）：照 shotgun.gd + shotgun_pellet.gd、laser.gd + laser_beam.gd、tongs.gd + tesla_arc.gd；
##   霰弹枪贴脸那只会被轰飞（爬虫离地再落下），电钳的电弧每步重折、被电的爬虫发蓝发抖；
##   激光是第二版（10-18 游戏设计会话改，作者嫌和闪光灯太像）：显像管开机式充能、充满自动开火、一道持续扫的 RGB 扫描线光束、关电视式收束
## 放大 2 倍画在舞台里（舞台坐标 0~119 × 0~64），一步一步按 1/60 秒模拟，和游戏里的物理帧一样。

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const LIT_FILL := Color(0.19, 0.175, 0.18)

## [id, 名字, 图标, 威力, 射速, 射程（1~5 格，和 weapon_select.gd 一样）, 发光说明, 打法]
const WEAPONS := [
	["flash", "FLASH LAMP", "charge", 4, 2, 5, "Glows: moths chase the light",
		"Hold, then release. Auto-aims and homes in a little."],
	["rivet", "RIVET GUN", "rivet", 1, 5, 3, "No light: moths ignore it",
		"Hold to fire nonstop. Rivets fade out at the end of their range."],
	["hammer", "STEAM HAMMER", "hammer", 5, 1, 2, "No light: moths ignore it",
		"Tap to blast all around you. Best when surrounded."],
	["shotgun", "SCRAP SHOTGUN", "shotgun", 4, 3, 2, "No light: moths ignore it", ""],
	["laser", "CRT LASER", "laser", 5, 1, 5, "Glows: moths chase the light", ""],
	["record", "RECORD SLINGER", "record", 3, 3, 4, "No light: moths ignore it",
		"Throw a record. It flies back and cuts both ways."],
	["tongs", "TESLA TONGS", "tongs", 2, 4, 3, "Glows: moths chase the light", ""],
]
const STAT_NAMES := ["POWER", "RATE", "REACH"]

const TILE_Y := 58.0
## 7 格排一行（240 宽）：格子里只放 1 倍的图标，名字在右边大字
const TILE := Vector2(30, 40)
const TILE_GAP := 5.0
const STAGE := Rect2(14, 112, 240, 130)
const DETAIL := Rect2(268, 54, 200, 188)

const DEMO_SCALE := 2.0
const FLOOR_Y := 52.0
const STEP := 1.0 / 60.0
## 红衣的条纹色（player.gd 的 STRIP_COLORS["red"]）：光球、铆钉尾巴、蒸汽第二圈都是这个颜色
const STRIP := Color8(255, 192, 192)
## 每把的示意：一轮多长、什么时候按下 / 松开攻击键、三只靶子站哪（相对主角）
const DEMO := {
	"flash": {"loop": 2.4, "press": 0.25, "release": 0.95, "hero": 14.0, "bugs": [42.0, 66.0, 90.0]},
	"rivet": {"loop": 2.8, "press": 0.25, "release": 2.2, "hero": 14.0, "bugs": [42.0, 66.0, 90.0]},
	"hammer": {"loop": 3.4, "press": 0.3, "press2": 2.1, "hero": 50.0, "bugs": [-30.0, 30.0, 62.0], "respawn": 1.5},
	# 扔两张（最多 2 张在外面），第一张接住后马上扔第三张（接住后 0.2 秒内扔的快 20%）
	# 按住连喷三发：第一只贴脸（会被轰飞），远的只吃到扇面中间几颗
	# 第三版（贴脸打小怪 ×2.5、溢出伤害接着飞）：三只挤在枪口前，一枪全轰死、尸体轰飞；
	# 放回来以后再喷一枪（后坐 150，人站右一点，退两步还在舞台里）
	"shotgun": {"loop": 2.5, "press": 0.3, "release": 1.6, "hero": 50.0, "bugs": [14.0, 27.0, 40.0], "respawn": 1.2},
	# 充满 0.9 秒、松手一道光束横穿三只
	"laser": {"loop": 2.3, "press": 0.2, "release": 1.7, "hero": 14.0, "bugs": [42.0, 66.0, 90.0]},
	# 按住放电：每道从钳口劈最近那只，再一只跳一只
	"tongs": {"loop": 2.3, "press": 0.25, "release": 1.65, "hero": 14.0, "bugs": [36.0, 64.0, 92.0]},
	"record": {"loop": 2.1, "press": 0.25, "press2": 0.55, "hero": 14.0, "bugs": [42.0, 66.0, 90.0], "respawn": 1.35, "wall": 112.0},
}

var embedded := true
var _sel := 0
var _ready_for_input := false
var _icons: Texture2D
var _body: Texture2D
var _strip: Texture2D
var _bug: Texture2D
## 从游戏脚本里读的常量
var _k := {}

var _base: Control
var _stage: Control
var _caption: Label
var _tile_names: Array[Label] = []
var _name: Label
var _glow: Label
var _stat_labels: Array[Label] = []
var _facts: Label
var _tip: Label
## 舞台左上角一行小字：这把由哪只精英掉落（weapon_pickup.gd 的 DROPS）
var _drop: Label

# ---- 示意动画的模拟状态（每一轮开头重置）
var _time := 0.0
var _acc := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _hero := {}
var _bugs: Array = []
var _orbs: Array = []
var _rivets: Array = []
var _casings: Array = []
var _sparks: Array = []
var _puffs: Array = []
var _blasts: Array = []
var _pellets: Array = []
var _discs: Array = []
var _scrap: Array = []
var _beams: Array = []
var _arcs: Array = []
## 全屏一闪的颜色（电钳是蓝的）
var _flash_col := Color.WHITE
## 10-18 打击感（游戏设计会话加的）：命中星、机油点、击杀碎铁片、扬尘、全屏白闪
var _stars: Array = []
var _oil: Array = []
var _chunks: Array = []
var _dust: Array = []
var _screen_flash := 0.0
## 顿帧（Game.hitstop）：打中时整个画面停一下，这段时间模拟不走
var _freeze := 0.0


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons = ShopStand.ICONS
	_body = load("res://art/chars/red_body.png")
	_strip = load("res://art/chars/red_strip.png")
	_bug = load("res://art/enemies/crawler.png")
	_read_constants()
	_base = _layer()
	_base.draw.connect(_draw_base)
	# 舞台：裁掉画出框的部分（蒸汽圈顶上会超出去）
	_stage = Control.new()
	_stage.position = STAGE.position + Vector2(1, 1)
	_stage.size = STAGE.size - Vector2(2, 2)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_caption = _label(14, 33, 452, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	# 10-18 起商店不卖武器了：开局选一把，打倒某些精英会掉落武器（按"下"换上）
	_caption.text = tr("Pick one before level 1. Some elites drop weapons you can switch to.")
	var x := DETAIL.position.x + 8
	var w := DETAIL.size.x - 16
	_name = _label(x, DETAIL.position.y + 6, w, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_glow = _label(x, DETAIL.position.y + 19, w, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	for k in 3:
		var l := _label(x, DETAIL.position.y + 36 + k * 12, 60, DIM, HORIZONTAL_ALIGNMENT_LEFT)
		l.text = tr(STAT_NAMES[k])
		_stat_labels.append(l)
	_facts = _label(x, DETAIL.position.y + 76, w, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facts.label_settings.line_spacing = Lang.tight_line()
	_drop = _label(STAGE.position.x + 6, STAGE.position.y + 4, STAGE.size.x - 12, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_tip = _label(x, 0, w, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.label_settings.line_spacing = Lang.tight_line()
	_select(maxi(WEAPONS.map(func(e): return e[0]).find(Upgrades.weapon), 0))
	await get_tree().process_frame
	_ready_for_input = true


## 武器数值直接从游戏脚本的常量里读（不写类名，免得和 player.gd 循环引用）
func _read_constants() -> void:
	var p: Dictionary = load("res://scripts/player/player.gd").get_script_constant_map()
	var o: Dictionary = load("res://scripts/combat/orb.gd").get_script_constant_map()
	var r: Dictionary = load("res://scripts/combat/rivet.gd").get_script_constant_map()
	var b: Dictionary = load("res://scripts/combat/steam_blast.gd").get_script_constant_map()
	var c: Dictionary = load("res://scripts/combat/casing.gd").get_script_constant_map()
	var cr: Dictionary = load("res://scripts/enemies/crawler.gd").get_script_constant_map()
	var rh: Dictionary = load("res://scripts/combat/weapons/record.gd").get_script_constant_map()
	var rd: Dictionary = load("res://scripts/combat/weapons/record_disc.gd").get_script_constant_map()
	var sg: Dictionary = load("res://scripts/combat/weapons/shotgun.gd").get_script_constant_map()
	var sp: Dictionary = load("res://scripts/combat/weapons/shotgun_pellet.gd").get_script_constant_map()
	var lz: Dictionary = load("res://scripts/combat/weapons/laser.gd").get_script_constant_map()
	var lb: Dictionary = load("res://scripts/combat/weapons/laser_beam.gd").get_script_constant_map()
	var ta: Dictionary = load("res://scripts/combat/tesla_arc.gd").get_script_constant_map()
	_k = {
		"charge_time": p["CHARGE_TIME"], "dots": p["CHARGE_DOTS"], "ring_r": p["CHARGE_RING_R"],
		"rivet_interval": p["RIVET_INTERVAL"], "rivet_spread": p["RIVET_SPREAD"], "rivet_move": p["RIVET_MOVE_MULT"],
		"rivet_recoil": p["RIVET_RECOIL"], "hammer_cd": p["HAMMER_COOLDOWN"], "hammer_windup": p["HAMMER_WINDUP"],
		"orb_speed": o["FULL_SPEED"], "orb_damage": o["FULL_DAMAGE"], "orb_trail": o["TRAIL"],
		"rivet_speed": r["SPEED"], "rivet_life": r["LIFETIME"], "rivet_damage": r["DAMAGE"], "rivet_fade": r["FADE_TIME"],
		"blast_r": b["RADIUS"], "blast_damage": b["DAMAGE"], "blast_grow": b["GROW_TIME"], "blast_life": b["LIFE"],
		"casing_gravity": c["GRAVITY"], "casing_life": c["LIFE"],
		"bug_hp": cr["MAX_HP"],
		"rec_damage": rh["DAMAGE"], "rec_max": rh["MAX_OUT"], "rec_gap": rh["MIN_GAP"], "rec_boost": rh["CATCH_BOOST"],
		"rec_window": rh["CATCH_WINDOW"], "rec_dist": rd["OUT_DIST"], "rec_speed": rd["OUT_SPEED"], "rec_back_accel": rd["BACK_ACCEL"],
		"rec_back_speed": rd["BACK_SPEED"], "rec_turn": rd["BACK_TURN"], "rec_hang": rd["HANG"], "rec_catch": rd["CATCH_R"],
		"rec_snap": rd["SNAP_R"], "rec_same_gap": rd["SAME_GAP"],
		"vinyl": rd["VINYL"], "groove": rd["GROOVE"], "shine": rd["SHINE"], "label_dark": rd["LABEL_DARK"], "label": rd["LABEL"],
		"disc_shape": rd["SHAPE"],
		"sg_interval": sg["INTERVAL"], "sg_pellets": sg["PELLETS"], "sg_spread": sg["SPREAD"], "sg_damage": sg["PELLET_DAMAGE"],
		"sg_kick": sg["GROUND_KICK"], "sg_speed_min": sg["SPEED_MIN"], "sg_speed_max": sg["SPEED_MAX"], "sg_life": sp["LIFE"], "sg_fade": sp["FADE"], "sg_point_blank": sp["POINT_BLANK"],
		"sg_full": sp["FULL_RANGE"], "sg_far": sp["FAR_RANGE"], "sg_far_mult": sp["FAR_MULT"],
		"sg_pb_small": sp["POINT_BLANK_SMALL"],
		"lz_charge": lz["CHARGE_TIME"], "lz_cooldown": lz["COOLDOWN"], "lz_damage": lz["TICK_DAMAGE"], "lz_range": lz["RANGE"],
		"lz_tick": lb["TICK"], "lz_life": lb["MAX_LIFE"], "lz_end": lb["END_TIME"], "lz_half": lb["HALF_WIDTH"],
		"tg_interval": ta["INTERVAL"], "tg_range": ta["RANGE"], "tg_jump": ta["JUMP"], "tg_jumps": ta["JUMPS"],
		"tg_damage": ta["DAMAGE"], "tg_stun": ta["STUN"], "tg_hop": ta["HOP_DELAY"], "tg_glow": ta["GLOW"],
		"tg_edge": ta["EDGE"], "tg_spark": ta["SPARK"], "tg_smoke": ta["SMOKE"],
	}


## 右边的数值：都用读到的常量填
func _facts_for(id: String) -> PackedStringArray:
	var k := _k
	match id:
		"flash":
			return [tr("Full: %d dmg, pierces a row") % k["orb_damage"],
				tr("Partial: 35-80 dmg, drops down"),
				tr("Charge time: %s s") % _num(k["charge_time"])]
		"rivet":
			return [tr("%d dmg a rivet, %d a second") % [k["rivet_damage"], roundi(1.0 / k["rivet_interval"])],
				tr("Sweeps up and down, no pierce"),
				tr("Range: about %s") % (roundi(k["rivet_speed"] * k["rivet_life"] / 10.0) * 10),
				tr("You walk at %d%% while firing") % roundi(k["rivet_move"] * 100.0)]
		"shotgun":
			return [tr("%d pellets, %d dmg each") % [k["sg_pellets"], k["sg_damage"]],
				tr("One blast every %s s") % _num(k["sg_interval"]),
				tr("Full within %d, %d%% at %d") % [k["sg_full"], roundi(k["sg_far_mult"] * 100.0), k["sg_far"]],
				tr("Point blank: ×%s on small fry") % _num(k["sg_pb_small"]),
				tr("Leftover damage flies on")]
		"laser":
			return [tr("%d dmg every %s s, pierces all") % [k["lz_damage"], str(snappedf(k["lz_tick"], 0.001))],
				tr("Charge time: %s s") % _num(k["lz_charge"]),
				tr("Fires itself when charged"),
				tr("Beam lasts %s s, then cools %s s") % [_num(k["lz_life"]), _num(k["lz_cooldown"])]]
		"tongs":
			var dm: PackedStringArray = []
			for v in k["tg_damage"]:
				dm.append(str(roundi(v)))
			return [tr("%s dmg along the chain") % " / ".join(dm),
				tr("Jumps up to %d times, %d apart") % [k["tg_jumps"], k["tg_jump"]],
				tr("Range: about %s") % roundi(k["tg_range"]),
				tr("Stuns small fry for %s s") % _num(k["tg_stun"])]
		"record":
			return [tr("%d dmg a cut, out and back") % k["rec_damage"],
				tr("Up to %d records out at once") % k["rec_max"],
				tr("Range: about %s") % roundi(k["rec_dist"]),
				tr("Bounces off a wall once")]
		_:
			return [tr("%d dmg to all within %d") % [k["blast_damage"], k["blast_r"]],
				tr("Blows away boss bullets"),
				tr("Cooldown: %s s") % _num(k["hammer_cd"]),
				tr("Wind-up: %s s") % _num(k["hammer_windup"])]


func _num(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _layer() -> Control:
	var c := Control.new()
	c.size = Vector2(480, 270)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _label(x: float, y: float, w: float, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(color)
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, 15)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	_time += delta
	# 一步 1/60 秒地模拟（和游戏的物理帧一样）；卡了最多补 8 步
	_acc = minf(_acc + delta, STEP * 8.0)
	while _acc >= STEP:
		_acc -= STEP
		_step()
	_base.queue_redraw()
	_stage.queue_redraw()


func _tile_rect(i: int) -> Rect2:
	return Rect2(STAGE.position.x + i * (TILE.x + TILE_GAP), TILE_Y, TILE.x, TILE.y)


func _select(i: int) -> void:
	_sel = clampi(i, 0, WEAPONS.size() - 1)
	var e: Array = WEAPONS[_sel]
	_name.text = tr(e[1])
	_glow.text = tr(e[6])
	# 会发光的武器（扑灯蛾会扑）这行用暖色：发不发光读登记表
	_glow.label_settings.font_color = WARM if WeaponRegistry.get_def(e[0]).get("glows", false) else DIM
	for j in _tile_names.size():
		_tile_names[j].label_settings.font_color = WARM if j == _sel else DIM
	_facts.text = "\n".join(_facts_for(e[0]))
	_tip.text = tr(e[7]) if e[7] != "" else _registry_tip(e[0])
	_drop.text = _drop_line(e[0])
	_tip.size = Vector2(DETAIL.size.x - 16, 0)
	_tip.size.y = _tip.get_minimum_size().y
	_tip.position.y = DETAIL.end.y - 6 - _tip.size.y
	_reset()


## 哪些精英掉这把：第一、二关按图鉴里的精英名字，第三关按 level3_mobs.gd 的 elite_name
func _drop_line(id: String) -> String:
	var l3: Dictionary = load("res://scripts/levels/level3_mobs.gd").get_script_constant_map()["MOBS"]
	var names: PackedStringArray = []
	for key: String in WeaponPickup.DROPS:
		if WeaponPickup.DROPS[key] != id:
			continue
		# 先找第一、二关的精英（留声机、放映机这些名字第三关也有同名的小怪，不能先查第三关）
		var nm := ""
		for e: Dictionary in Bestiary.entries():
			if e["id"] == key and e["kind"] == "elite" and e.get("chapter", "") != "3":
				nm = e["name"]
		if nm == "" and l3.has(key):
			nm = l3[key].get("elite_name", "")
		if nm != "":
			names.append(tr(nm))
	if names.is_empty():
		return ""
	return tr("Dropped by: %s") % ("、" if Lang.is_zh() else ", ").join(names)


## 新几把的打法一句：登记表的 card（选武器界面那三行，换行去掉）+ trait
func _registry_tip(id: String) -> String:
	var def := WeaponRegistry.get_def(id)
	if def.is_empty():
		return ""
	return tr(def["card"]).replace("\n", "" if Lang.is_zh() else " ") + ("" if Lang.is_zh() else " ") + tr(def["trait"])


## 截图、测试用：把示意动画快进到第 t 秒
func seek(t: float) -> void:
	_reset()
	while _t < t - STEP * 0.5:
		_step()


## 总图鉴调：用掉了返回 true
func handle(event: InputEvent) -> bool:
	if not _ready_for_input:
		return false
	if event is InputEventMouseMotion:
		var m := get_local_mouse_position()
		for i in WEAPONS.size():
			if i != _sel and _tile_rect(i).has_point(m):
				_select(i)
		return false
	if event.is_action_pressed("ui_left", true):
		if _sel > 0:
			_select(_sel - 1)
			Game.sfx("ui_move", -12.0)
		return true
	if event.is_action_pressed("ui_right", true):
		if _sel < WEAPONS.size() - 1:
			_select(_sel + 1)
			Game.sfx("ui_move", -12.0)
		return true
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true) \
			or event.is_action_pressed("ui_accept"):
		return true
	return false


# ---------------------------------------------------------------- 示意动画：模拟

func _demo() -> Dictionary:
	return DEMO[WEAPONS[_sel][0]]


func _reset() -> void:
	var d := _demo()
	_t = 0.0
	_acc = 0.0
	_freeze = 0.0
	_rng.seed = 7
	_hero = {"x": d["hero"], "vx": 0.0, "charging": false, "charge": 0.0, "full": false, "gather": 0.0, "ring": 0.0,
		"muzzle": 0.0, "fmuzzle": 0.0, "fmuzzle_full": false, "flash": 0.0, "squash": 0.0, "rivet_t": 0.0, "rivet_n": 0, "cd": 0.0, "windup": 0.0, "anim": 0.0,
		"fling": 0.0, "catch_t": 0.0, "caught": 0.0, "thrown3": false, "sg_muzzle": 0.0, "tg_t": 0.0, "hold": 0.0, "firing": false}
	_bugs.clear()
	for off in d["bugs"]:
		_bugs.append(_new_bug(d["hero"] + off))
	_orbs.clear()
	_rivets.clear()
	_casings.clear()
	_sparks.clear()
	_puffs.clear()
	_blasts.clear()
	_pellets.clear()
	_discs.clear()
	_scrap.clear()
	_beams.clear()
	_arcs.clear()
	_flash_col = Color.WHITE
	_stars.clear()
	_oil.clear()
	_chunks.clear()
	_dust.clear()
	_screen_flash = 0.0
	if WEAPONS[_sel][0] == "hammer":
		# Boss 打过来的三颗弹丸，在主角身边慢慢飘，蒸汽圈扫到就散
		for off in [Vector2(26, -24), Vector2(-24, -26), Vector2(40, -6)]:
			_pellets.append({"p": Vector2(d["hero"], FLOOR_Y - 10) + off, "home": off})


func _new_bug(x: float) -> Dictionary:
	# y / vy / lx：被霰弹枪贴脸轰飞时离地（y 往上是负）；stun / shake：被电钳电麻
	return {"x": x, "home": x, "hp": float(_k["bug_hp"]), "flash": 0.0, "knock": 0.0, "vx": 0.0, "dead": false,
		"y": 0.0, "vy": 0.0, "lx": 0.0, "stun": 0.0, "shake": 0.0}


func _step() -> void:
	if _freeze > 0.0:
		_freeze -= STEP
		return
	var d := _demo()
	_t += STEP
	if _t >= d["loop"]:
		_reset()
		return
	var id: String = WEAPONS[_sel][0]
	var h := _hero
	h["anim"] += STEP
	h["ring"] = maxf(h["ring"] - STEP * 5.0, 0.0)
	h["gather"] = maxf(h["gather"] - STEP / 0.18, 0.0)
	h["muzzle"] = maxf(h["muzzle"] - STEP / 0.035, 0.0)
	h["fmuzzle"] = maxf(h["fmuzzle"] - STEP / 0.06, 0.0)
	_screen_flash = maxf(_screen_flash - STEP / 0.06, 0.0)
	h["flash"] = maxf(h["flash"] - STEP / 0.15, 0.0)
	h["squash"] = maxf(h["squash"] - STEP / 0.16, 0.0)
	# 后坐：往后退一点，慢慢停（站在地上，摩擦很大）
	h["x"] += h["vx"] * STEP
	h["vx"] = move_toward(h["vx"], 0.0, 600.0 * STEP)
	match id:
		"flash":
			_step_flash(d)
		"rivet":
			_step_rivet(d)
		"hammer":
			_step_hammer(d)
		"record":
			_step_record(d)
		"shotgun":
			_step_shotgun(d)
		"laser":
			_step_laser(d)
		"tongs":
			_step_tongs(d)
	_step_shots()
	_step_scrap()
	_step_arcs()
	_step_beams()
	for b in _bugs:
		b["flash"] = maxf(b["flash"] - STEP * 8.0, 0.0)
		if b["knock"] > 0.0:
			b["knock"] -= STEP
			b["x"] += b["vx"] * STEP
		# 被轰飞：抛起来再落地
		if b["y"] < 0.0 or b["vy"] != 0.0:
			b["vy"] += 600.0 * STEP
			b["y"] += b["vy"] * STEP
			b["x"] += b["lx"] * STEP
			if b["y"] >= 0.0:
				b["y"] = 0.0
				b["vy"] = 0.0
				b["lx"] = 0.0
		b["stun"] = maxf(b["stun"] - STEP, 0.0)
		b["shake"] = maxf(b["shake"] - STEP, 0.0)
	if d.has("respawn") and absf(_t - d["respawn"]) < STEP * 0.5:
		for i in _bugs.size():
			if _bugs[i]["dead"]:
				_bugs[i] = _new_bug(_bugs[i]["home"])
		for p in _pellets:
			p["p"] = Vector2(d["hero"], FLOOR_Y - 10) + p["home"]
			p.erase("gone")


func _step_flash(d: Dictionary) -> void:
	var h := _hero
	var ct: float = _k["charge_time"]
	if _t >= d["press"] and _t < d["release"]:
		if not h["charging"]:
			h["charging"] = true
			h["charge"] = 0.0
			h["squash"] = 0.35
			h["gather"] = 0.5
		h["charge"] = minf(h["charge"] + STEP / ct, 1.0)
		if h["charge"] >= 1.0 and not h["full"]:
			h["full"] = true
			h["ring"] = 0.5
	elif h["charging"]:
		# 松手：从枪口打出光球；蓄满的往后顶一下
		h["charging"] = false
		var muzzle := Vector2(h["x"] + 5, FLOOR_Y - 11)
		_orbs.append({"p": muzzle, "v": Vector2(_k["orb_speed"], 0), "full": h["full"], "trail": [], "hit": [], "life": 0.0})
		# 出手：枪口一大团火光（蓄满白芯 + 长尖 + 斜刺，没蓄满小十字星），蓄满的往后顶得更狠、灯头冒一股热气
		h["fmuzzle"] = 1.0
		h["fmuzzle_full"] = h["full"]
		if h["full"]:
			h["vx"] -= 75.0
			h["squash"] = 0.3
			_spark_burst(muzzle, Color(0.75, 0.75, 0.8), 4, 35.0, Vector2.UP)
		h["flash"] = 1.0 if h["full"] else 0.4
		h["full"] = false
		h["charge"] = 0.0


func _step_rivet(d: Dictionary) -> void:
	var h := _hero
	if _t < d["press"] or _t >= d["release"]:
		h["rivet_n"] = 0
		return
	h["rivet_t"] -= STEP
	if h["rivet_t"] > 0.0:
		return
	h["rivet_t"] += _k["rivet_interval"]
	if h["rivet_t"] < 0.0:
		h["rivet_t"] = 0.0
	var muzzle := Vector2(h["x"] + 6, FLOOR_Y - 10)
	# 和 player.gd 一样：有规律地上下扫（散布的 75%）加一点小抖动；自动瞄最近那只（示意里它们都在正前方）
	var sweep: float = sin(h["rivet_n"] * 0.9) * _k["rivet_spread"] * 0.75 + _rng.randf_range(-1.5, 1.5)
	var dir := Vector2.RIGHT.rotated(deg_to_rad(sweep))
	_rivets.append({"p": muzzle, "v": dir * _k["rivet_speed"], "life": 0.0})
	h["rivet_n"] += 1
	h["muzzle"] = 1.0
	h["flash"] = maxf(h["flash"], 0.35)
	h["vx"] -= dir.x * _k["rivet_recoil"]
	# 弹壳往身后上方抛
	_casings.append({"p": Vector2(h["x"] + 2, FLOOR_Y - 10),
		"v": Vector2(-_rng.randf_range(30.0, 60.0), -_rng.randf_range(70.0, 110.0)), "t": 0.0, "bounces": 0, "spin": 0})


func _step_hammer(d: Dictionary) -> void:
	var h := _hero
	var was: float = h["cd"]
	h["cd"] = maxf(h["cd"] - STEP, 0.0)
	if was > 0.0 and h["cd"] <= 0.0:
		h["ring"] = 0.25   # 冷却好了：人身上一圈白
	if h["windup"] > 0.0:
		h["windup"] -= STEP
		if h["windup"] <= 0.0:
			_blast()
		return
	for key in ["press", "press2"]:
		if d.has(key) and absf(_t - d[key]) < STEP * 0.5 and h["cd"] <= 0.0:
			h["windup"] = _k["hammer_windup"]
			h["squash"] = 0.45


## 唱片回旋镖（record.gd 的 attack / _throw / caught）：按一下扔一张，最多 2 张在外面；
## 第一张接住就马上再扔一张（接住后 CATCH_WINDOW 秒内扔的那张快 CATCH_BOOST 倍）
func _step_record(d: Dictionary) -> void:
	var h := _hero
	h["cd"] = maxf(h["cd"] - STEP, 0.0)
	h["catch_t"] = maxf(h["catch_t"] - STEP, 0.0)
	h["fling"] = maxf(h["fling"] - STEP / 0.12, 0.0)
	h["caught"] = maxf(h["caught"] - STEP / 0.25, 0.0)
	for key in ["press", "press2"]:
		if absf(_t - d[key]) < STEP * 0.5:
			_throw_disc()
	if h["catch_t"] > 0.0 and not h["thrown3"]:
		h["thrown3"] = true
		_throw_disc()
	for disc in _discs.duplicate():
		_step_disc(disc, d)


func _throw_disc() -> void:
	var h := _hero
	if h["cd"] > 0.0 or _discs.size() >= _k["rec_max"]:
		return
	h["cd"] = _k["rec_gap"]
	var speed := 1.0
	if h["catch_t"] > 0.0:
		speed = _k["rec_boost"]
		h["catch_t"] = 0.0
	var dist: float = _k["rec_dist"] * (1.0 + 0.5 * (speed - 1.0))
	_discs.append({"p": Vector2(h["x"] + 6, FLOOR_Y - 10), "v": Vector2(_k["rec_speed"] * speed, 0), "v0": _k["rec_speed"] * speed,
		"dist": dist, "travel": 0.0, "back": false, "hang": -1.0, "bounced": false, "spin": 0.0, "life": 0.0,
		"trail": [], "cut": {}, "last": {}})
	h["fling"] = 1.0
	h["squash"] = maxf(h["squash"], 0.18)
	h["vx"] += 20.0   # 出手往前一倾（p.recoil）


## 一张唱片一步（record_disc.gd 的 _fly_out / _fly_back / _cut_overlaps）
func _step_disc(disc: Dictionary, d: Dictionary) -> void:
	var h := _hero
	disc["life"] += STEP
	var v: Vector2 = disc["v"]
	disc["spin"] += STEP * (10.0 + v.length() * 0.06)
	if disc["hang"] >= 0.0:
		# 去程到头：停一下（还在转），然后往回飞
		disc["hang"] -= STEP
		if disc["hang"] < 0.0:
			disc["back"] = true
			disc["cut"] = {}
			disc["v"] = Vector2.ZERO
	elif not disc["back"]:
		# 去程：匀减速，飞满射程就停；碰墙弹一次（第二次就直接往回飞）
		var decel: float = disc["v0"] * disc["v0"] / (2.0 * disc["dist"])
		var speed := maxf(v.length() - decel * STEP, 0.0)
		v = v.normalized() * speed
		var step := v * STEP
		var wall: float = d["wall"]
		if v.x > 0.0 and disc["p"].x + step.x >= wall - 6.0:
			_spark_burst(Vector2(wall, disc["p"].y), Color(1.0, 0.85, 0.6), 4, 70.0, Vector2.LEFT)
			if disc["bounced"]:
				disc["hang"] = 0.0
			else:
				disc["bounced"] = true
				v.x = -v.x
			disc["v"] = v
			return
		disc["p"] += step
		disc["travel"] += step.length()
		disc["v"] = v
		if speed <= 1.0 or disc["travel"] >= disc["dist"]:
			disc["hang"] = _k["rec_hang"]
	else:
		# 回程：朝手里加速飞，快到手边直接飞进去
		var home := Vector2(h["x"], FLOOR_Y - 10)
		var to: Vector2 = home - disc["p"]
		if to.length() < _k["rec_catch"]:
			# 接住：身上闪一圈白点，接下来 CATCH_WINDOW 秒内扔的那张更快
			_discs.erase(disc)
			h["caught"] = 1.0
			h["catch_t"] = _k["rec_window"]
			h["cd"] = 0.0
			return
		if to.length() < _k["rec_snap"]:
			v = to.normalized() * maxf(v.length(), 320.0)
			disc["p"] += v * STEP if (v * STEP).length() < to.length() else to
		else:
			var sp := move_toward(v.length(), _k["rec_back_speed"], _k["rec_back_accel"] * STEP)
			var dir := v.normalized() if v.length() > 1.0 else to.normalized()
			dir = dir.rotated(clampf(dir.angle_to(to), -_k["rec_turn"] * STEP, _k["rec_turn"] * STEP))
			v = dir * sp
			disc["p"] += v * STEP
		disc["v"] = v
	disc["trail"].push_front(disc["p"])
	if disc["trail"].size() > 4:
		disc["trail"].pop_back()
	# 割：判定框 10×9；每趟每只一下，同一只两刀至少隔 SAME_GAP 秒；不顿帧，切线方向迸一串火星
	var hit := Rect2(disc["p"] - Vector2(5, 4.5), Vector2(10, 9))
	for i in _bugs.size():
		var b: Dictionary = _bugs[i]
		if b["dead"] or disc["cut"].has(i) or not hit.intersects(_bug_rect(b)):
			continue
		if disc["life"] < float(disc["last"].get(i, -1.0)) + _k["rec_same_gap"]:
			continue
		disc["cut"][i] = true
		disc["last"][i] = disc["life"]
		var dir2: Vector2 = disc["v"].normalized() if disc["v"].length() > 1.0 else Vector2.RIGHT
		var keep := _freeze
		_hurt(b, _k["rec_damage"], signf(dir2.x), false, disc["p"], dir2, 0.3)
		_freeze = keep   # 唱片一直在飞，割到不顿帧（击杀的短顿帧也不要）
		_spark_burst(disc["p"], Color(1.0, 0.8, 0.45), 5, 110.0, dir2)


## 废铁霰弹枪（shotgun.gd 的 attack / _fire）：按住每 INTERVAL 秒喷一扇 PELLETS 颗（±SPREAD°），地上往后推 GROUND_KICK；
## 枪口一扇火 3 帧、一团灰烟往前、一颗红色大弹壳往后上方抛
func _step_shotgun(d: Dictionary) -> void:
	var h := _hero
	h["cd"] = maxf(h["cd"] - STEP, 0.0)
	h["sg_muzzle"] = maxf(h["sg_muzzle"] - STEP / 0.05, 0.0)
	if _t >= d["press"] and _t < d["release"] and h["cd"] <= 0.0:
		h["cd"] = _k["sg_interval"]
		var from := Vector2(h["x"] + 7, FLOOR_Y - 10)
		var volley := {"total": 0}
		var n: int = _k["sg_pellets"]
		for i in n:
			var a: float = lerpf(-_k["sg_spread"], _k["sg_spread"], float(i) / (n - 1)) + _rng.randf_range(-2.0, 2.0)
			_scrap.append({"p": from, "start": from, "damage": _k["sg_damage"], "passed": [], "v": Vector2.RIGHT.rotated(deg_to_rad(a)) * _rng.randf_range(_k["sg_speed_min"], _k["sg_speed_max"]),
				"life": 0.0, "trail": [], "volley": volley})
		h["sg_muzzle"] = 1.0
		h["squash"] = maxf(h["squash"], 0.45)
		h["flash"] = maxf(h["flash"], 0.9)
		h["vx"] -= _k["sg_kick"]
		# 一团灰烟、一把橙色火星往前喷；开火那一下定格一帧
		_spark_burst(from + Vector2(4, 0), Color(0.62, 0.6, 0.62), 8, 70.0, Vector2.RIGHT)
		_spark_burst(from + Vector2(6, 0), Color(1.0, 0.75, 0.3), 6, 160.0, Vector2.RIGHT)
		_freeze = maxf(_freeze, 0.035)
		_casings.append({"p": Vector2(h["x"] - 2, FLOOR_Y - 10), "v": Vector2(-_rng.randf_range(40.0, 70.0), -_rng.randf_range(90.0, 130.0)),
			"t": 0.0, "bounces": 0, "spin": 0, "big": true, "brass": Color8(190, 52, 40), "dark": Color8(214, 160, 70)})


## 碎铁弹（shotgun_pellet.gd）：直线飞、最后 FADE 秒掉速，LIFE 秒没了；打中一只就没。
## 同一发里打中的颗数越多顿得越久；贴脸（POINT_BLANK 内）算重击，把小怪轰飞
func _step_scrap() -> void:
	var h := _hero
	for s in _scrap.duplicate():
		s["life"] += STEP
		if s["life"] > _k["sg_life"]:
			_scrap.erase(s)
			continue
		if s["life"] > _k["sg_life"] - _k["sg_fade"]:
			s["v"] *= 1.0 - 8.0 * STEP
		s["trail"].push_front(s["p"])
		if s["trail"].size() > 6:
			s["trail"].pop_back()
		s["p"] += s["v"] * STEP
		for i in _bugs.size():
			var b: Dictionary = _bugs[i]
			# 已经死了的（前面几颗刚打死）、这颗打穿过的：直接穿过去
			if b["dead"] or s["passed"].has(i) or not _bug_rect(b).grow(2.5).has_point(s["p"]):
				continue
			var vol: Dictionary = s["volley"]
			var n: int = vol.get(i, 0) + 1
			vol[i] = n
			vol["total"] += 1
			var close: bool = s["p"].distance_to(Vector2(h["x"], FLOOR_Y)) < _k["sg_point_blank"]
			# 伤害按飞过的距离衰减：FULL_RANGE 内满伤，到 FAR_RANGE 剩 FAR_MULT；贴脸打小怪再 ×POINT_BLANK_SMALL
			var flown: float = s["p"].distance_to(s["start"])
			var fall := 1.0 if flown <= _k["sg_full"] else lerpf(1.0, _k["sg_far_mult"], clampf((flown - _k["sg_full"]) / (_k["sg_far"] - _k["sg_full"]), 0.0, 1.0))
			var dealt: float = s["damage"] * fall * (_k["sg_pb_small"] if close else 1.0)
			var hp_before: float = b["hp"]
			_hurt(b, dealt, 1.0, close or n >= 3, s["p"], s["v"].normalized(), 0.35 + 0.1 * minf(n, 4))
			_spark_burst(s["p"], Color(1.0, 0.7, 0.3), 3, 90.0, -s["v"].normalized())
			if close and dealt >= hp_before:
				# 贴脸打死：尸体整个轰飞（往后上方），白剪影跟着飞一会儿
				b["vy"] = -130.0
				b["lx"] = 380.0
				b["sil"] = 0.3
			elif not b["dead"]:
				# 没打死：每颗往后推一点（不轰飞，不然后面几颗打空）
				b["knock"] = maxf(b["knock"], 0.06)
				b["vx"] = maxf(b["vx"], 0.0) + 40.0
			if vol["total"] >= 2:
				_freeze = maxf(_freeze, minf(0.018 * vol["total"], 0.1))
			# 溢出：这一颗打死了它还有剩，就带着剩下的伤害接着往前飞
			if dealt > hp_before + 0.5:
				s["passed"].append(i)
				s["damage"] = (dealt - hp_before) / maxf(fall, 0.01) / (_k["sg_pb_small"] if close else 1.0)
				continue
			_scrap.erase(s)
			break

## 显像管激光第二版（laser.gd）：按住充能 CHARGE_TIME 秒，充满自动开火（不用松手）；光束开始收束就进冷却 COOLDOWN
func _step_laser(d: Dictionary) -> void:
	var h := _hero
	var held: bool = _t >= d["press"] and _t < d["release"]
	var live: Dictionary = {}
	for bm in _beams:
		if not bm["ending"]:
			live = bm
	if not live.is_empty():
		# 开火中：松手就收
		h["charging"] = true
		h["charge"] = 1.0
		if not held:
			live["ending"] = true
		return
	if h["firing"]:
		# 光束刚开始收：进冷却
		h["firing"] = false
		h["cd"] = _k["lz_cooldown"]
		h["charging"] = false
		h["charge"] = 0.0
	h["cd"] = maxf(h["cd"] - STEP, 0.0)
	if held and h["cd"] <= 0.0:
		h["charging"] = true
		h["charge"] = minf(h["charge"] + STEP / _k["lz_charge"], 1.0)
		if h["charge"] >= 1.0:
			_fire_beam()
		return
	h["charging"] = false
	h["charge"] = 0.0


## 开火（laser.gd 的 _fire）：后坐、人压一下；不再全屏白闪
func _fire_beam() -> void:
	var h := _hero
	var from := Vector2(h["x"] + 7, FLOOR_Y - 11)
	_beams.append({"from": from, "len": minf(_k["lz_range"], 124.0 - from.x), "t": 0.0, "tick_t": 0.0,
		"ending": false, "end_t": 0.0, "hit_once": {}, "n_first": 0})
	h["firing"] = true
	h["vx"] -= 50.0
	h["squash"] = maxf(h["squash"], 0.3)
	h["flash"] = maxf(h["flash"], 0.4)


## 光束（laser_beam.gd 的 _process）：每 TICK 秒结算一下，最多 MAX_LIFE 秒，然后 END_TIME 秒的"关电视"收束
func _step_beams() -> void:
	var h := _hero
	for bm in _beams.duplicate():
		bm["t"] += STEP
		bm["from"] = Vector2(h["x"] + 7, FLOOR_Y - 11)
		bm["len"] = minf(_k["lz_range"], 124.0 - bm["from"].x)
		if not bm["ending"]:
			bm["tick_t"] -= STEP
			if bm["tick_t"] <= 0.0:
				bm["tick_t"] += _k["lz_tick"]
				_beam_tick(bm)
			if bm["t"] > _k["lz_life"]:
				bm["ending"] = true
		else:
			bm["end_t"] += STEP
			if bm["end_t"] > _k["lz_end"]:
				_beams.erase(bm)


## 结算一下（laser_beam.gd 的 _tick / _hit）：线上每只各吃 TICK_DAMAGE；第一次扫到的那只闪白、顿帧（一只比一只长），之后每下只冒火星
func _beam_tick(bm: Dictionary) -> void:
	var from: Vector2 = bm["from"]
	var half: float = _k["lz_half"]
	var hit: Array = []
	for i in _bugs.size():
		var r := _bug_rect(_bugs[i])
		if not _bugs[i]["dead"] and r.end.x > from.x and r.position.y - half <= from.y and r.end.y + half >= from.y:
			hit.append(i)
	hit.sort_custom(func(a, b): return _bugs[a]["x"] < _bugs[b]["x"])
	for i in hit:
		var b: Dictionary = _bugs[i]
		var on_line := Vector2(b["x"], from.y)
		var first: bool = not bm["hit_once"].has(i)
		_hurt(b, _k["lz_damage"], 1.0, first, on_line, Vector2.RIGHT, 0.6 if first else 0.2)
		_spark_burst(on_line, [Color(1.0, 0.3, 0.4), Color(0.4, 1.0, 0.5), Color(0.4, 0.6, 1.0)][_rng.randi() % 3], 3, 90.0, Vector2.RIGHT)
		if first:
			bm["hit_once"][i] = true
			bm["n_first"] += 1
			_freeze = minf(0.03 + 0.015 * (bm["n_first"] - 1), 0.09)


## 特斯拉电钳（tongs.gd + tesla_arc.gd）：按住每 INTERVAL 秒放一道，钳口 RANGE 内最近的那只，
## 再跳 JUMP 内最近的下一只，最多跳 JUMPS 次，伤害一跳降一档；小怪被电麻 STUN 秒
func _step_tongs(d: Dictionary) -> void:
	var h := _hero
	var held: bool = _t >= d["press"] and _t < d["release"]
	h["charging"] = held
	h["charge"] = 0.6 if held else 0.0
	if not held:
		h["tg_t"] = 0.0
		h["hold"] = 0.0
		return
	h["hold"] += STEP
	h["tg_t"] -= STEP
	if h["tg_t"] > 0.0:
		return
	h["tg_t"] = _k["tg_interval"]
	var muzzle := Vector2(h["x"] + 8, FLOOR_Y - 10)
	var chain: Array = []
	var at := muzzle
	for j in _k["tg_jumps"] + 1:
		var r: float = _k["tg_range"] if j == 0 else _k["tg_jump"]
		var best := -1
		var bd := INF
		for i in _bugs.size():
			if _bugs[i]["dead"] or chain.has(i):
				continue
			var dd := at.distance_to(_bug_aim(_bugs[i]))
			if dd <= r and dd < bd:
				best = i
				bd = dd
		if best < 0:
			break
		chain.append(best)
		at = _bug_aim(_bugs[best])
	if chain.is_empty():
		_spark_burst(muzzle, _k["tg_spark"], 2, 40.0, Vector2.ZERO)
		return
	var pts: Array = [muzzle]
	for i in chain:
		pts.append(_bug_aim(_bugs[i]))
	var arc := {"from": muzzle, "targets": chain, "pts": pts, "t": 0.0, "done": 0, "seed": _rng.randi()}
	_arcs.append(arc)
	_screen_flash = 1.0
	_flash_col = Color(0.55, 0.75, 1.0)
	h["flash"] = maxf(h["flash"], 0.55)
	_spark_burst(muzzle, _k["tg_spark"], 3, 60.0, (pts[1] - muzzle).normalized())
	_arc_hit(arc, 0)


func _step_arcs() -> void:
	for arc in _arcs.duplicate():
		arc["t"] += STEP
		while arc["done"] < arc["targets"].size() and arc["t"] >= arc["done"] * _k["tg_hop"]:
			_arc_hit(arc, arc["done"])
		for i in arc["targets"].size():
			var b: Dictionary = _bugs[arc["targets"][i]]
			if not b["dead"]:
				arc["pts"][i + 1] = _bug_aim(b)
		if arc["t"] > _k["tg_glow"] + _k["tg_hop"] * arc["targets"].size():
			_arcs.erase(arc)


func _arc_hit(arc: Dictionary, i: int) -> void:
	arc["done"] = i + 1
	var b: Dictionary = _bugs[arc["targets"][i]]
	if b["dead"]:
		return
	var pos := _bug_aim(b)
	var dir: Vector2 = (pos - arc["pts"][i]).normalized()
	var dmgs: Array = _k["tg_damage"]
	_hurt(b, dmgs[mini(i, dmgs.size() - 1)], signf(dir.x), false, pos, dir, 0.25)
	_spark_burst(pos, _k["tg_spark"], 3, 70.0, dir)
	if i == 0:
		_freeze = maxf(_freeze, 0.02)
	if b["dead"]:
		_spark_burst(pos, _k["tg_smoke"], 5, 30.0, Vector2.UP)
		return
	# 麻：原地停住、抖、发蓝
	b["stun"] = _k["tg_stun"]
	b["shake"] = 0.08
	b["knock"] = 0.0


func _bug_aim(b: Dictionary) -> Vector2:
	return Vector2(b["x"], FLOOR_Y - 8 + b["y"])


func _blast() -> void:
	var h := _hero
	var center := Vector2(h["x"], FLOOR_Y - 10)
	_blasts.append({"c": center, "t": 0.0})
	h["cd"] = _k["hammer_cd"]
	h["flash"] = 0.6
	h["ring"] = 0.35
	var r: float = _k["blast_r"]
	var hits := 0
	# 站在地上砸：两边扬尘、迸 6 块碎石
	var foot := Vector2(h["x"], FLOOR_Y)
	for side in [-1.0, 1.0]:
		for i in 8:
			_dust.append({"p": foot + Vector2(side * 2.0, -1.0), "v": Vector2(side, -0.35).rotated(deg_to_rad(_rng.randf_range(-18, 18))) * _rng.randf_range(20.0, 55.0),
				"t": 0.0, "s": 1 + _rng.randi() % 2})
	for i in 6:
		_chunks.append({"p": foot + Vector2(_rng.randf_range(-10, 10), -1), "v": Vector2(_rng.randf_range(-110.0, 110.0), -_rng.randf_range(90.0, 160.0)),
			"t": 0.0, "bounces": 0, "spin": 0, "shape": 0, "c": [Color8(90, 86, 84), Color8(120, 112, 100), Color8(70, 66, 66)][i % 3]})
	for b in _bugs:
		if b["dead"]:
			continue
		# 和 steam_blast.gd 一样：怪的身体只要和圆有交叠就算
		var body := _bug_rect(b)
		var nearest := Vector2(clampf(center.x, body.position.x, body.end.x), clampf(center.y, body.position.y, body.end.y))
		if nearest.distance_to(center) <= r:
			hits += 1
			var at := Vector2(b["x"], FLOOR_Y - 8)
			_hurt(b, _k["blast_damage"], signf(b["x"] - center.x), true, at, (at - center).normalized(), 1.0)
	if hits > 0:
		# 一锤砸中越多越重：顿帧、全屏白闪
		_freeze = minf(0.06 + 0.015 * (hits - 1), 0.11)
		_screen_flash = 1.0
	for p in _pellets:
		if not p.has("gone") and p["p"].distance_to(center) < r:
			p["gone"] = true
			_spark_burst(p["p"], Color(1.0, 0.6, 0.5), 4, 50.0, Vector2.ZERO)
	# 往外喷的蒸汽方块：36 个，3 格大，往四周喷、很快减速
	for i in 36:
		var a := _rng.randf_range(-PI, PI)
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(120.0, 190.0)
		_puffs.append({"p": center, "v": v, "t": 0.0, "damp": _rng.randf_range(260.0, 340.0)})


func _step_shots() -> void:
	# 光球：蓄满的直线飞、穿透一排（每只打一次）；拖尾 6 格
	for o in _orbs.duplicate():
		o["life"] += STEP
		o["trail"].push_front(o["p"])
		if o["trail"].size() > _k["orb_trail"]:
			o["trail"].pop_back()
		o["p"] += o["v"] * STEP
		for b in _bugs:
			if b["dead"] or o["hit"].has(b) or not _bug_rect(b).grow(4.0).has_point(o["p"]):
				continue
			o["hit"].append(b)
			# 第一只顿得最久，后面的短顿一下（orb.gd）
			_freeze = 0.07 if o["hit"].size() == 1 else 0.03
			_hurt(b, _k["orb_damage"], 1.0, true, o["p"], Vector2.RIGHT, 1.0)
			_spark_burst(o["p"], STRIP.lerp(Color.WHITE, 0.5), 10, 90.0, Vector2.ZERO)
			_spark_burst(o["p"], Color.WHITE, 6, 120.0, Vector2.RIGHT)
		if o["p"].x > 130.0 or o["life"] > 1.6:
			_orbs.erase(o)
	# 铆钉：直线飞，打中第一只就停（不穿透）
	for r in _rivets.duplicate():
		r["life"] += STEP
		if r["life"] > _k["rivet_life"]:
			_rivets.erase(r)
			continue
		r["p"] += r["v"] * STEP
		for b in _bugs:
			if not b["dead"] and _bug_rect(b).grow(3.0).has_point(r["p"]):
				_hurt(b, _k["rivet_damage"], 1.0, false, r["p"], r["v"].normalized(), 0.0)
				_spark_burst(r["p"], Color(1.0, 0.85, 0.6), 4, 80.0, Vector2.LEFT)
				_rivets.erase(r)
				break
	# 弹壳：抛物线，落地弹两下以后躺着淡掉
	for c in _casings.duplicate():
		c["t"] += STEP
		if c["bounces"] < 2:
			c["v"].y += _k["casing_gravity"] * STEP
			c["p"] += c["v"] * STEP
			c["spin"] += 1
			if c["p"].y >= FLOOR_Y - 1 and c["v"].y > 0.0:
				c["p"].y = FLOOR_Y - 1
				c["bounces"] += 1
				c["v"] = Vector2(c["v"].x * 0.45, -absf(c["v"].y) * 0.35)
				if c["bounces"] >= 2:
					c["v"] = Vector2.ZERO
		if c["t"] > _k["casing_life"]:
			_casings.erase(c)
	for s in _sparks.duplicate():
		s["t"] += STEP
		s["v"].y += 260.0 * STEP
		s["p"] += s["v"] * STEP
		if s["t"] > 0.35:
			_sparks.erase(s)
	for p in _puffs.duplicate():
		p["t"] += STEP
		p["v"] = p["v"].move_toward(Vector2.ZERO, p["damp"] * STEP)
		p["p"] += p["v"] * STEP
		if p["t"] > 0.55:
			_puffs.erase(p)
	for b in _blasts.duplicate():
		b["t"] += STEP
		if b["t"] > _k["blast_life"] + 0.3:
			_blasts.erase(b)
	for st in _stars.duplicate():
		st["t"] += STEP
		if st["t"] > 0.045:
			_stars.erase(st)
	for o in _oil:
		if not o["landed"]:
			o["v"].y += 520.0 * STEP
			o["p"] += o["v"] * STEP
			if o["p"].y >= FLOOR_Y - 1 and o["v"].y > 0.0:
				o["p"].y = FLOOR_Y - 1
				o["landed"] = true
	for c in _chunks.duplicate():
		c["t"] += STEP
		if c["bounces"] < 2:
			c["v"].y += 560.0 * STEP
			c["p"] += c["v"] * STEP
			c["spin"] += 1
			if c["p"].y >= FLOOR_Y - 1 and c["v"].y > 0.0:
				c["p"].y = FLOOR_Y - 1
				c["bounces"] += 1
				c["v"] = Vector2(c["v"].x * 0.4, -absf(c["v"].y) * 0.3)
				if c["bounces"] >= 2:
					c["v"] = Vector2.ZERO
		if c["t"] > 1.1:
			_chunks.erase(c)
	for d in _dust.duplicate():
		d["t"] += STEP
		d["v"] = d["v"].move_toward(Vector2.ZERO, 140.0 * STEP) + Vector2(0, -20.0 * STEP)
		d["p"] += d["v"] * STEP
		if d["t"] > 0.35:
			_dust.erase(d)
	for b in _bugs:
		if b.has("sil"):
			b["sil"] -= STEP


func _bug_rect(b: Dictionary) -> Rect2:
	return Rect2(b["x"] - 12, FLOOR_Y - 15 + b.get("y", 0.0), 24, 15)


## 齿轮爬虫挨打：发白、往后退；血打光了留一个白剪影 3 帧、冒灰色和橙色碎屑后消失（crawler.gd 的 hurt / _die），
## 再加武器那边的击杀反馈（hit_fx.gd）：碎铁片顺着攻击方向迸出去落地弹两下、机油溅、一小股火花、短顿帧。
## 每一下还有命中星（越痛刺越长）和几滴机油。power：铆钉 0、没蓄满的光球 0.45、蓄满和蒸汽锤 1
func _hurt(b: Dictionary, dmg: float, dir: float, full: bool, at := Vector2.ZERO, hit_dir := Vector2.RIGHT, power := 0.0) -> void:
	if b["dead"]:
		return
	b["hp"] -= dmg
	b["flash"] = 1.0
	b["knock"] = 0.12 if full else 0.06
	b["vx"] = dir * (90.0 if full else 40.0)
	if at == Vector2.ZERO:
		at = Vector2(b["x"], FLOOR_Y - 8)
	_stars.append({"p": at.round(), "t": 0.0, "arm": 2 + int(round(power * 3.0))})
	_spray(at, hit_dir, 1 + int(round(power * 3.0)), 0.8 + 0.4 * power, 40.0)
	if b["hp"] <= 0.0:
		b["dead"] = true
		b["sil"] = 0.05
		var c := Vector2(b["x"], FLOOR_Y - 8)
		_spark_burst(c, Color8(150, 140, 125), 14, 110.0, Vector2.ZERO)
		_spark_burst(c, Color8(255, 190, 120), 6, 80.0, Vector2.ZERO)
		var d := hit_dir.normalized() if hit_dir.length() > 0.1 else Vector2.RIGHT
		_spray(at, d, 8, 1.2, 35.0)
		for i in 4:
			_chunks.append({"p": at + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)),
				"v": Vector2(d.x * _rng.randf_range(90.0, 200.0) + _rng.randf_range(-25.0, 25.0), minf(d.y, 0.0) * 120.0 - _rng.randf_range(70.0, 150.0)),
				"t": 0.0, "bounces": 0, "spin": 0, "shape": 2 if i == 3 else (1 if i < 2 else 0),
				"c": [Color8(120, 115, 110), Color8(150, 140, 125), Color8(200, 160, 90), Color8(90, 86, 84)][i % 4]})
		_spark_burst(at, Color(1.0, 0.8, 0.45), 6, 150.0, d)
		if _freeze <= 0.0:
			_freeze = 0.035


## 机油溅（splatter.gd）：往攻击方向溅一道弧，落地摊成一小块斑
func _spray(at: Vector2, dir: Vector2, n: int, speed: float, spread: float) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var pal := [Color8(30, 26, 24), Color8(54, 46, 38), Color8(40, 34, 30), Color8(96, 82, 58)]
	for i in n:
		var v := d.rotated(deg_to_rad(_rng.randf_range(-spread, spread))) * _rng.randf_range(60.0, 170.0) * speed
		v.y -= _rng.randf_range(30.0, 90.0)
		_oil.append({"p": at + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)), "v": v, "landed": false,
			"c": pal[_rng.randi() % pal.size()], "size": 2 if _rng.randf() < 0.25 else 1})


## Game.sparks 的样子：1 格的点，往一个方向（或四面）喷，受重力，0.35 秒淡掉
func _spark_burst(at: Vector2, col: Color, n: int, speed: float, dir: Vector2) -> void:
	for i in n:
		var a: float
		if dir == Vector2.ZERO:
			a = _rng.randf_range(-PI, PI)
		else:
			a = dir.angle() + deg_to_rad(_rng.randf_range(-50.0, 50.0))
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * _rng.randf_range(speed * 0.5, speed), "t": 0.0, "c": col})


# ---------------------------------------------------------------- 画

func _draw_base() -> void:
	var c := _base
	for i in WEAPONS.size():
		var r := _tile_rect(i)
		UiStyle.panel(c, r, i == _sel, _time, WARM, LIT_FILL)
		var idx := maxi(ShopStand.ICON_NAMES.find(WEAPONS[i][2]), 0)
		UiStyle.icon(c, _icons, idx, (r.position + (r.size - Vector2(16, 16)) / 2).round(), 1)
	UiStyle.panel(c, STAGE, false, 0.0)
	UiStyle.panel(c, DETAIL, true, 0.0)
	var e: Array = WEAPONS[_sel]
	var x := DETAIL.position.x + 8
	for k in 3:
		UiStyle.bars(c, Vector2(x + 64, DETAIL.position.y + 41 + k * 12), int(e[3 + k]), 5, 18.0, 4.0, 3.0)
	c.draw_rect(Rect2(x + 10, DETAIL.position.y + 72, DETAIL.size.x - 36, 1), UiStyle.BAR_OFF)


func _draw_stage() -> void:
	var c := _stage
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(DEMO_SCALE, DEMO_SCALE))
	c.draw_rect(Rect2(0, FLOOR_Y, 120, 20), Color(0.11, 0.1, 0.11))
	c.draw_rect(Rect2(0, FLOOR_Y, 120, 1), Color(0.24, 0.22, 0.22))
	var dm := _demo()
	if dm.has("wall"):
		var wx: float = dm["wall"]
		c.draw_rect(Rect2(wx, 0, 120 - wx, FLOOR_Y), Color(0.11, 0.1, 0.11))
		c.draw_rect(Rect2(wx, 0, 1, FLOOR_Y), Color(0.24, 0.22, 0.22))
	for p in _pellets:
		if not p.has("gone"):
			var drift := Vector2(0, roundf(sin(_t * 3.0 + p["home"].x)))
			c.draw_rect(Rect2((p["p"] + drift - Vector2(1, 1)).round(), Vector2(3, 3)), UiStyle.POOR)
			_px(c, p["p"] + drift, Color(1, 0.8, 0.6))
	# 地上的机油斑：摊开 2~3 格宽、1 格高
	for o in _oil:
		if o["landed"]:
			c.draw_rect(Rect2(o["p"].round() + Vector2(-1, 0), Vector2(2 + o["size"], 1)), o["c"])
	for b in _bugs:
		_draw_bug(c, b)
	_draw_hero(c)
	for o in _orbs:
		_draw_orb(c, o)
	for r in _rivets:
		_draw_rivet(c, r)
	for disc in _discs:
		_draw_disc(c, disc)
	for sc in _scrap:
		_draw_scrap(c, sc)
	for bm in _beams:
		_draw_beam(c, bm)
	for arc in _arcs:
		_draw_arc(c, arc)
	for k in _casings:
		_draw_casing(c, k)
	for b in _blasts:
		_draw_blast(c, b)
	for p in _puffs:
		var k: float = p["t"] / 0.55
		var col := Color(1, 1, 1, 0.95) if k < 0.45 else (Color(0.9, 0.9, 0.93, 0.65) if k < 0.8 else Color(0.8, 0.8, 0.85, 0.3))
		c.draw_rect(Rect2((p["p"] - Vector2(1, 1)).round(), Vector2(3, 3)), col)
	for s in _sparks:
		var a: float = 1.0 - s["t"] / 0.35
		var col: Color = s["c"]
		_px(c, s["p"], Color(col.r, col.g, col.b, a).lerp(Color(col.r * 0.4, col.g * 0.3, col.b * 0.3, 0.0), 1.0 - a))
	# 扬尘（Game.dust）：贴地往两边扬，1~2 格，淡掉
	for d in _dust:
		var k: float = d["t"] / 0.35
		c.draw_rect(Rect2(d["p"].round(), Vector2(d["s"], d["s"])), Color(0.72, 0.68, 0.64, 0.85).lerp(Color(0.4, 0.38, 0.38, 0.0), k))
	# 飞着的机油点
	for o in _oil:
		if not o["landed"]:
			_px(c, o["p"], o["c"])
			if o["size"] == 2:
				_px(c, o["p"] - o["v"].normalized().round(), o["c"])
	for k in _chunks:
		_draw_chunk(c, k)
	# 命中星：白芯 + 四个方向的短刺，越痛刺越长（hit_fx.gd）
	for st in _stars:
		var at: Vector2 = st["p"]
		c.draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
		for i in range(1, int(st["arm"]) + 1):
			var col := Color.WHITE if i <= 1 else Color(1.0, 0.9, 0.7)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				c.draw_rect(Rect2((at + d * (i + 0.5) - Vector2(0.5, 0.5)).round(), Vector2.ONE), col)
	# 激光开着时整个场景蒙一层冷青色的光（游戏里是光束上的 PointLight2D），亮度跟着抖
	for bm in _beams:
		if not bm["ending"]:
			c.draw_rect(Rect2(0, 0, 120, 70), Color(0.45, 0.95, 0.95, 0.06 + 0.02 * float(int(_time * 60.0) % 2)))
			break
	if _screen_flash > 0.0:
		c.draw_rect(Rect2(0, 0, 120, 70), Color(_flash_col, (0.06 if _flash_col == Color.WHITE else 0.12) * _screen_flash))
	c.draw_set_transform(Vector2.ZERO)


func _px(c: CanvasItem, p: Vector2, col: Color, s := 1.0) -> void:
	c.draw_rect(Rect2(p.round(), Vector2(s, s)), col)


func _draw_hero(c: CanvasItem) -> void:
	var h := _hero
	var f := int(h["anim"] / 0.2) % 4
	# 缩一下：先猛地压扁，再带一点回弹恢复（player.gd 的 _squash）
	var k: float = h["squash"]
	var sq := Vector2.ONE.lerp(Vector2(1.25, 0.72), k * k) if k > 0.35 else Vector2.ONE.lerp(Vector2(0.92, 1.1), sin(k / 0.35 * PI))
	var size := Vector2(16, 20) * sq
	var at := Vector2(roundf(h["x"]) - 8 * sq.x, FLOOR_Y - size.y)
	var glow: float = h["charge"] if h["charging"] else 0.0
	var pulse := 0.0
	if h["full"]:
		pulse = 0.08 + 0.08 * sin(h["anim"] * 10.0)
	var body_mod := Color.WHITE.lerp(Color(1.7, 1.6, 1.5), clampf(glow * 0.35 + pulse + h["ring"] * 0.4, 0.0, 1.0))
	var strip_mod := Color.WHITE.lerp(Color(2.2, 2.2, 2.2), clampf(glow * 0.6 + h["ring"] * 0.6, 0.0, 1.0))
	c.draw_texture_rect_region(_body, Rect2(at, size), Rect2(f * 16, 0, 16, 20), body_mod)
	c.draw_texture_rect_region(_strip, Rect2(at, size), Rect2(f * 16, 0, 16, 20), strip_mod)
	var o := Vector2(roundf(h["x"]), FLOOR_Y - 10)
	# 蓄力开始：一圈光点从外往里收
	if h["gather"] > 0.0:
		var gr := lerpf(3.0, 14.0, h["gather"])
		for i in 12:
			var a: float = TAU * i / 12.0 + h["gather"]
			_px(c, o + Vector2(cos(a), sin(a)) * gr, Color(STRIP, 0.9 * h["gather"]))
	if h["ring"] > 0.0:
		var r: float = 5.0 + (1.0 - h["ring"]) * 10.0
		for i in 20:
			var a := TAU * i / 20.0
			_px(c, o + Vector2(cos(a), sin(a)) * r, Color(1, 1, 1, h["ring"]))
	match WEAPONS[_sel][0]:
		"flash":
			if h["fmuzzle"] > 0.0:
				_draw_flash_muzzle(c, o)
			if h["charging"]:
				if not h["full"]:
					var n := 2 + int(h["charge"] * 3.0)
					for i in n:
						var ph := fmod(h["anim"] * 1.4 + float(i) / n, 1.0)
						var a: float = float(i) * 2.399 + h["anim"] * 0.7
						_px(c, o + Vector2(cos(a), sin(a)) * lerpf(16.0, 4.0, ph), Color(STRIP, 0.2 + 0.5 * ph))
				var dots: int = _k["dots"]
				var lit := int(h["charge"] * dots)
				for i in dots:
					if not h["full"] and i >= lit:
						continue
					var a := -PI / 2.0 + TAU * i / dots
					var col := STRIP.lerp(Color.WHITE, 0.3)
					if h["full"]:
						col = Color(1, 1, 1, 0.85 + 0.15 * sin(h["anim"] * 8.0))
					_px(c, o + Vector2(cos(a), sin(a)) * _k["ring_r"], col)
		"rivet":
			if h["muzzle"] > 0.0:
				# 枪口火光：十字星 / 往前喷的尖火，一发一换
				var m := o + Vector2(8, 0)
				var hot := Color(1.0, 0.95, 0.75)
				var warm := Color(1.0, 0.7, 0.3)
				c.draw_rect(Rect2(m + Vector2(-1, -1), Vector2(2, 2)), Color.WHITE)
				if h["rivet_n"] % 2 == 0:
					for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
						_px(c, m + d * 2, hot)
						_px(c, m + d * 3, warm)
					_px(c, m + Vector2(4, 0), warm)
				else:
					for i in range(2, 6):
						_px(c, m + Vector2(i, 0), hot if i < 4 else warm)
					for p in [Vector2(2, -1), Vector2(2, 1), Vector2(3, -2), Vector2(3, 2)]:
						_px(c, m + p, warm)
		"record":
			_draw_record_hand(c)
		"shotgun":
			_draw_shotgun_muzzle(c)
		"laser":
			_draw_laser_charge(c)
		"tongs":
			_draw_tongs_jaw(c)
		"hammer":
			if h["cd"] > 0.0:
				# 冷却：脚下一道弧，冷却完就补满
				var k2: float = 1.0 - h["cd"] / _k["hammer_cd"]
				for i in 9:
					if float(i) / 9 >= k2:
						continue
					var a := PI + PI * i / 8.0
					_px(c, Vector2(roundf(h["x"]), FLOOR_Y - 1) + Vector2(cos(a) * 8.0, sin(a) * 2.0 + 2.0), Color(STRIP, 0.5))


## 闪光灯出手的枪口火光（player.gd 的 _draw_flash_muzzle）：蓄满是白芯 + 往前的长尖 + 四道斜刺，没蓄满是小十字星
func _draw_flash_muzzle(c: CanvasItem, o: Vector2) -> void:
	var h := _hero
	var m := o + Vector2(6, -1)
	var hot := Color(1.0, 0.97, 0.85)
	var glow := STRIP.lerp(Color.WHITE, 0.45)
	var f: float = h["fmuzzle"]
	if h["fmuzzle_full"]:
		var core := 2 if f > 0.5 else 1
		c.draw_rect(Rect2(m - Vector2(core, core), Vector2(core * 2 + 1, core * 2 + 1)), Color.WHITE)
		var reach := 9 if f > 0.5 else 6
		for i in range(core + 1, reach):
			_px(c, m + Vector2(i, 0), hot if i < 6 else glow)
		for i in range(core + 1, 5):
			_px(c, m + Vector2(0, -i), glow)
			_px(c, m + Vector2(0, i), glow)
			_px(c, m + Vector2(-(i - 1), 0), glow)
		for d in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			_px(c, m + d * 3, glow)
			if f > 0.5:
				_px(c, m + d * 4, Color(glow, 0.6))
	else:
		c.draw_rect(Rect2(m - Vector2.ONE, Vector2(2, 2)), Color.WHITE)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_px(c, m + d * 2, glow)
		_px(c, m + Vector2(3, 0), hot)


## 击杀迸出来的碎片、蒸汽锤砸出的碎石（hit_fx.gd 的 Chunk）：飞着横竖交替，落地躺平，最后一闪一闪没掉
func _draw_chunk(c: CanvasItem, k: Dictionary) -> void:
	if k["t"] > 0.8 and int(k["t"] * 20.0) % 2 == 0:
		return
	var p: Vector2 = k["p"].round()
	var flying: bool = k["bounces"] < 2 and (int(k["spin"]) / 3) % 2 == 1
	var col: Color = k["c"]
	match int(k["shape"]):
		1:
			c.draw_rect(Rect2(p, Vector2(2, 3) if flying else Vector2(3, 2)), col)
			c.draw_rect(Rect2(p, Vector2.ONE), col.lightened(0.25))
		2:
			c.draw_rect(Rect2(p, Vector2(1, 3) if flying else Vector2(3, 1)), Color8(170, 165, 155))
			c.draw_rect(Rect2(p, Vector2.ONE), Color8(210, 205, 195))
		_:
			c.draw_rect(Rect2(p, Vector2(1, 2) if flying else Vector2(2, 1)), col)


func _draw_bug(c: CanvasItem, b: Dictionary) -> void:
	if b["dead"]:
		# 死的那一下留一个纯白剪影，亮 3 帧
		if b.get("sil", 0.0) > 0.0:
			# 死的那一下 3 帧；被霰弹枪贴脸轰飞的跟着飞一会儿
			var f2 := int(_t / 0.15) % 4
			c.draw_texture_rect_region(_bug, Rect2(Vector2(roundf(b["x"]) - 18, roundf(FLOOR_Y - 16 + b["y"])), Vector2(36, 16)), Rect2(f2 * 36, 0, 36, 16), Color(6, 6, 6))
		return
	var f := int(_t / 0.15) % 4
	var at := Vector2(roundf(b["x"]) - 18, roundf(FLOOR_Y - 16 + b["y"]))
	var mod := Color.WHITE.lerp(Color(4, 4, 4), b["flash"])
	# 被电麻：左右抖一格、蓝白一闪一闪（tesla_arc.gd 的 TeslaStun）
	if b["stun"] > 0.0 or b["shake"] > 0.0:
		var fr := int(_t * 60.0)
		at.x += 1.0 if fr % 2 == 0 else -1.0
		if fr % 4 < 2:
			mod = Color(0.6, 0.85, 1.6)
	c.draw_texture_rect_region(_bug, Rect2(at, Vector2(36, 16)), Rect2(f * 36, 0, 36, 16), mod)


func _draw_orb(c: CanvasItem, o: Dictionary) -> void:
	var trail: Array = o["trail"]
	var n: int = _k["orb_trail"]
	# 尾巴：蓄满的 2 像素粗、前两格偏白；没蓄满 1 像素
	for i in trail.size():
		var a := 0.6 * (1.0 - float(i) / n)
		var col := Color(STRIP.r, STRIP.g, STRIP.b, a)
		if o["full"] and i < 2:
			col = Color(1, 1, 1, 0.8)
		c.draw_rect(Rect2((trail[i] as Vector2).round(), Vector2(2, 2) if o["full"] else Vector2.ONE), col)
	var p: Vector2 = o["p"].round()
	if o["full"]:
		c.draw_rect(Rect2(p + Vector2(-1, -3), Vector2(3, 7)), STRIP)
		c.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(7, 3)), STRIP)
		c.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 5)), STRIP.lerp(Color.WHITE, 0.5))
		c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), Color.WHITE)
	else:
		c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), STRIP.lerp(Color.WHITE, 0.3))
		c.draw_rect(Rect2(p, Vector2.ONE), Color.WHITE)


func _draw_rivet(c: CanvasItem, r: Dictionary) -> void:
	var p: Vector2 = r["p"].round()
	var d: Vector2 = r["v"].normalized()
	var step := clampi(ceili((_k["rivet_life"] - r["life"]) / _k["rivet_fade"] * 3.0), 1, 3)
	match step:
		3:
			for i in range(5, 0, -1):
				var col := Color(STRIP, 0.35) if i >= 3 else Color(1.0, 0.85, 0.6, 0.8)
				c.draw_rect(Rect2(p + (-d * i).round(), Vector2.ONE), col)
			c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), Color(1.0, 0.95, 0.85))
		2:
			for i in range(3, 0, -1):
				var col := Color(STRIP, 0.25) if i >= 3 else Color(1.0, 0.85, 0.6, 0.6)
				c.draw_rect(Rect2(p + (-d * i).round(), Vector2.ONE), col)
			c.draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.95, 0.85, 0.85))
		1:
			c.draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.85, 0.6, 0.45))


func _draw_casing(c: CanvasItem, k: Dictionary) -> void:
	var a := clampf((_k["casing_life"] - k["t"]) / 0.3, 0.0, 1.0)
	var brass := Color(k.get("brass", Color(0.86, 0.68, 0.32)), a)
	var dark := Color(k.get("dark", Color(0.55, 0.4, 0.18)), a)
	var p: Vector2 = k["p"].round()
	# 霰弹枪的是红色大弹壳：3 格长（casing.gd 的 big）
	var l := 3 if k.get("big", false) else 2
	if k["bounces"] < 2 and k["spin"] / 3 % 2 == 1:
		c.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, l)), brass)
		c.draw_rect(Rect2(p, Vector2.ONE), dark)
	else:
		c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(l, 1)), brass)
		c.draw_rect(Rect2(p, Vector2.ONE), dark)


## 蒸汽锤的一锤（steam_blast.gd 的 _draw）：两圈往外扩的像素环（白 + 条纹色），刚炸开时中心一团白
func _draw_blast(c: CanvasItem, b: Dictionary) -> void:
	var t: float = b["t"]
	var life: float = _k["blast_life"]
	if t > life:
		return
	var grow: float = _k["blast_grow"]
	var k := clampf(t / grow, 0.0, 1.0)
	var r := lerpf(6.0, _k["blast_r"], 1.0 - (1.0 - k) * (1.0 - k))
	var a := 1.0 - clampf((t - grow * 0.5) / (life - grow * 0.5), 0.0, 1.0)
	var center: Vector2 = b["c"]
	for ring in 2:
		var rr := r - ring * 5.0
		if rr <= 2.0:
			continue
		var n := int(rr * 1.6) + 8
		var col := Color(1, 1, 1, a) if ring == 0 else Color(STRIP.r, STRIP.g, STRIP.b, a * 0.6)
		for i in n:
			var ang := TAU * i / n
			var v := Vector2(cos(ang), sin(ang))
			c.draw_rect(Rect2(center + (v * rr).round(), Vector2.ONE), col)
			# 外圈刚炸开时 2 像素粗
			if ring == 0 and k < 1.0:
				c.draw_rect(Rect2(center + (v * (rr - 1.0)).round(), Vector2.ONE), col)
	# 中心一团白：大一圈，带十字
	if t < 0.08:
		var w := Color(1, 1, 1, 1.0 - t / 0.08)
		c.draw_rect(Rect2(center + Vector2(-7, -7), Vector2(14, 14)), w)
		c.draw_rect(Rect2(center + Vector2(-2, -11), Vector2(4, 22)), w)
		c.draw_rect(Rect2(center + Vector2(-11, -2), Vector2(22, 4)), w)


## 手上的唱片（record.gd 的 draw）：还能扔几张就在手边画几张，出手那一下往前甩；接住时身上闪一圈白点
func _draw_record_hand(c: CanvasItem) -> void:
	var h := _hero
	var foot := Vector2(roundf(h["x"]), FLOOR_Y)
	var left: int = _k["rec_max"] - _discs.size()
	if left > 0:
		var base := foot + Vector2(4 + roundf(3.0 * h["fling"]) - 2, -10)
		c.draw_rect(Rect2(base, Vector2(5, 1)), _k["vinyl"])
		c.draw_rect(Rect2(base + Vector2(-1, 1), Vector2(7, 1)), _k["vinyl"])
		c.draw_rect(Rect2(base + Vector2(0, 2), Vector2(5, 1)), _k["vinyl"])
		c.draw_rect(Rect2(base + Vector2(2, 1), Vector2.ONE), _k["label"])
		c.draw_rect(Rect2(base + Vector2(1, 0), Vector2.ONE), _k["shine"])
		if left > 1:
			# 第二张叠在后面，只露一条边
			c.draw_rect(Rect2(base + Vector2(-1, -1), Vector2(5, 1)), _k["groove"])
	if h["caught"] > 0.0:
		var r: float = 7.0 + 5.0 * (1.0 - h["caught"])
		for i in 10:
			_px(c, foot + Vector2(0, -10) + Vector2.from_angle(TAU * i / 10.0) * r, Color(1, 1, 1, h["caught"]))


## 飞着的唱片（record_disc.gd 的 _draw）：11×4 扁椭圆、浅灰边、黑胶、一圈纹路、一道 4 帧扫过的白反光、
## 中间 3×2 红标签（亮的那格跟着转），身后两道暖色残影
func _draw_disc(c: CanvasItem, disc: Dictionary) -> void:
	var at: Vector2 = disc["p"].round()
	var trail: Array = disc["trail"]
	for i in range(1, trail.size()):
		var ca := 0.34 - i * 0.08
		if ca > 0.0:
			c.draw_rect(Rect2((trail[i] as Vector2).round() + Vector2(-4, -1), Vector2(9, 2)), Color(1.0, 0.78, 0.55, ca))
	var rim := Color(_k["shine"], 0.75)
	c.draw_rect(Rect2(at + Vector2(-4, -3), Vector2(9, 1)), rim)
	c.draw_rect(Rect2(at + Vector2(-6, -2), Vector2(13, 4)), rim)
	c.draw_rect(Rect2(at + Vector2(-4, 2), Vector2(9, 1)), rim)
	for r in _k["disc_shape"]:
		c.draw_rect(Rect2(at + Vector2(r[0], r[1]), Vector2(r[2], 1)), _k["vinyl"])
	c.draw_rect(Rect2(at + Vector2(-4, -1), Vector2(1, 2)), _k["groove"])
	c.draw_rect(Rect2(at + Vector2(4, -1), Vector2(1, 2)), _k["groove"])
	var f := int(disc["spin"]) % 4
	c.draw_rect(Rect2(at + Vector2(-4 + f * 2, -2 if f < 2 else 1), Vector2(2, 1)), Color(1.0, 0.97, 0.9, 0.75))
	for i in 3:
		c.draw_rect(Rect2(at + Vector2(-1 + i, -1), Vector2(1, 2)), _k["label"] if i == f % 3 else _k["label_dark"])
	c.draw_rect(Rect2(at + Vector2(0, -1), Vector2.ONE), Color(1.0, 0.9, 0.75))


## 霰弹枪枪口火光（shotgun.gd 的 draw，第二版）：一整扇火，第 1 帧 20 格长、白芯 7×7，之后收短；近处白、中间暖黄、外沿橙
func _draw_shotgun_muzzle(c: CanvasItem) -> void:
	var h := _hero
	var mz: float = h["sg_muzzle"]
	if mz <= 0.0:
		return
	var m := Vector2(roundf(h["x"]) + 7, FLOOR_Y - 10)
	var hot := Color(1.0, 0.97, 0.85)
	var warm := Color(1.0, 0.78, 0.35)
	var edge := Color(1.0, 0.5, 0.2)
	var stage := 0 if mz > 0.66 else (1 if mz > 0.33 else 2)
	var reach: int = [20, 13, 6][stage]
	if stage == 0:
		c.draw_rect(Rect2(m - Vector2(3, 3), Vector2(7, 7)), Color.WHITE)
	else:
		c.draw_rect(Rect2(m - Vector2(2, 2), Vector2(5, 5)), Color.WHITE)
	for i in range(2, reach):
		var half := int(i * 0.36) + 1
		for j in range(-half, half + 1):
			var outer := absi(j) >= half and half > 1
			if outer and (i + j) % 2 == 0:
				continue
			var col := hot if i < reach * 0.35 else (edge if outer or i > reach * 0.8 else warm)
			c.draw_rect(Rect2(m + Vector2(i, j), Vector2.ONE), col)


## 碎铁弹（shotgun_pellet.gd 的 _draw，第二版）：2×2 黄白头（中心一格更白）+ 6 格橙色尾巴；最后掉速时只剩 1 格
func _draw_scrap(c: CanvasItem, s: Dictionary) -> void:
	var fading: bool = s["life"] > _k["sg_life"] - _k["sg_fade"]
	var trail: Array = s["trail"]
	for i in trail.size():
		c.draw_rect(Rect2((trail[i] as Vector2).round(), Vector2.ONE), Color(1.0, 0.55 + 0.05 * i, 0.15, (0.85 if not fading else 0.4) - i * 0.13))
	var p: Vector2 = s["p"].round()
	if fading:
		c.draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.8, 0.5))
	else:
		c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.85, 0.4))
		c.draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 1.0, 0.85))


## 激光充能 = 显像管开机（laser.gd 的 draw）：前 35% 管口一个白点一闪一闪；之后横着拉成一道线，
## 红 / 蓝在上下各错开一格，线上隔一格暗一格；快满时前面一条很淡的绿色扫描虚线
func _draw_laser_charge(c: CanvasItem) -> void:
	var h := _hero
	if not h["charging"] or h["firing"]:
		return
	var ch: float = h["charge"]
	var t: float = h["anim"]
	var m := Vector2(roundf(h["x"]) + 7, FLOOR_Y - 11)
	if ch < 0.35:
		if int(t * 20.0) % 2 == 0:
			c.draw_rect(Rect2(m, Vector2.ONE), Color.WHITE)
		return
	var k := (ch - 0.35) / 0.65
	var half := int(round(lerpf(1.0, 6.0, k)))
	for i in range(-half, half + 1):
		var q := m + Vector2(i, 0)
		var dim := 0.55 if (i + int(t * 30.0)) % 2 == 0 else 1.0
		c.draw_rect(Rect2(q, Vector2.ONE), Color(1, 1, 1, dim))
		if k > 0.3:
			c.draw_rect(Rect2(q + Vector2(0, 1), Vector2.ONE), Color(1.0, 0.25, 0.35, 0.8 * dim))
			c.draw_rect(Rect2(q - Vector2(0, 1), Vector2.ONE), Color(0.3, 0.55, 1.0, 0.8 * dim))
	if k > 0.6:
		for i in range(10, int(120.0 - m.x)):
			if (i + int(t * 40.0)) % 6 == 0:
				c.draw_rect(Rect2(m + Vector2(i, 0), Vector2.ONE), Color(0.35, 1.0, 0.5, 0.35))


## 光束（laser_beam.gd 的 _draw）：中间白芯，两侧各一格绿，再外侧下红上蓝；沿光束每 5 格暗一格、每帧滚动；
## 粗细每帧在两档之间跳。收束：往枪口缩成 1 像素线，最后一个 3×3 亮点
func _draw_beam(c: CanvasItem, bm: Dictionary) -> void:
	var from: Vector2 = bm["from"].round()
	var length: float = bm["len"]
	var roll := int(_time * 60.0)
	var width := 2 if roll % 2 == 0 else 1
	if bm["ending"]:
		var k: float = clampf(bm["end_t"] / _k["lz_end"], 0.0, 1.0)
		if k > 0.75:
			c.draw_rect(Rect2(from - Vector2.ONE, Vector2(3, 3)), Color.WHITE)
			return
		length *= 1.0 - k / 0.75
		width = 0
	for i in int(length):
		var p := from + Vector2(i, 0)
		var dim := 0.45 if (i + roll) % 5 == 0 else 1.0
		c.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, dim))
		if width >= 1:
			c.draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), Color(0.35, 1.0, 0.5, 0.9 * dim))
			c.draw_rect(Rect2(p - Vector2(0, 1), Vector2.ONE), Color(0.35, 1.0, 0.5, 0.9 * dim))
		var off := float(width + 1)
		c.draw_rect(Rect2(p + Vector2(0, off), Vector2.ONE), Color(1.0, 0.25, 0.35, 0.85 * dim))
		c.draw_rect(Rect2(p - Vector2(0, off), Vector2.ONE), Color(0.3, 0.55, 1.0, 0.85 * dim))


## 电钳钳口（tongs.gd 的 draw）：两片钳嘴之间跳一两颗小电火花，按着时更多更亮
func _draw_tongs_jaw(c: CanvasItem) -> void:
	var h := _hero
	var m := Vector2(roundf(h["x"]) + 8, FLOOR_Y - 10)
	var on: bool = h["hold"] > 0.0
	var r := RandomNumberGenerator.new()
	r.seed = int(_t * 60.0) * 7919
	for i in (2 if on else 1):
		if r.randf() < (0.8 if on else 0.15):
			_px(c, m + Vector2(r.randi_range(-1, 1), r.randi_range(-2, 2)), Color(0.75, 0.9, 1.0) if i == 0 else Color.WHITE)


## 电弧（tesla_arc.gd 的 _draw）：每一步重折一次的锯齿线（每 6 格一折、横偏 ±3），外圈淡蓝、白芯，落点一小团亮，钳口炸亮
func _draw_arc(c: CanvasItem, arc: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(arc["seed"]) + int(_t * 60.0)
	var fade := 1.0 if arc["t"] < _k["tg_glow"] else 0.6
	var pts: Array = arc["pts"]
	var edge: Color = _k["tg_edge"]
	for i in mini(arc["done"], arc["targets"].size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var line: Array[Vector2] = [a]
		var n := maxi(int(a.distance_to(b) / 6.0), 1)
		var nrm := (b - a).normalized().orthogonal()
		for k in range(1, n):
			line.append(a.lerp(b, float(k) / n) + nrm * r.randf_range(-3.0, 3.0))
		line.append(b)
		for k in line.size() - 1:
			_px_line(c, line[k], line[k + 1], Color(edge, 0.55 * fade), true)
		for k in line.size() - 1:
			_px_line(c, line[k], line[k + 1], Color(1, 1, 1, fade), false)
		c.draw_rect(Rect2(b.round() - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 1, 0.9 * fade))
	if arc["t"] < 0.06:
		var f: Vector2 = arc["from"].round()
		c.draw_rect(Rect2(f - Vector2(2, 2), Vector2(5, 5)), Color(edge, 0.8))
		c.draw_rect(Rect2(f - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)


## 一格一格画直线（Bresenham）；halo = 上下左右各偏一格画外圈
func _px_line(c: CanvasItem, a: Vector2, b: Vector2, col: Color, halo: bool) -> void:
	var x0 := int(roundf(a.x))
	var y0 := int(roundf(a.y))
	var x1 := int(roundf(b.x))
	var y1 := int(roundf(b.y))
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	for _guard in 400:
		if halo:
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				c.draw_rect(Rect2(Vector2(x0, y0) + o, Vector2.ONE), col)
		else:
			c.draw_rect(Rect2(Vector2(x0, y0), Vector2.ONE), col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
