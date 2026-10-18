class_name CodexWeapons
extends Control
## 总图鉴的"武器图鉴"一册（codex_menu.gd 里用）：闪光灯、铆钉枪、蒸汽锤。
## 左上三格选武器，左下是出招示意（主角对着三只齿轮爬虫打），右边是名字、发不发光、三条数值格（和选武器界面同一套）、
## 实际数值和一句打法。三把开局就能选，所以都直接显示，不按"用没用过"点亮。
##
## 示意动画照游戏里的真实表现做（作者 10-18："图鉴的武器使用和真实的不符"），对照网页版实拍逐项核过：
## - 数值不抄：打开时从 player.gd / orb.gd / rivet.gd / steam_blast.gd / casing.gd / crawler.gd 里读常量，
##   以后调了武器，动画和右边的数字自动跟着变
## - 画法照抄各脚本的 _draw：蓄力圈（一圈 12 个点从正上方顺时针亮、满了整圈变白呼吸）、光球（十字形 + 6 格拖尾）、
##   铆钉（2×2 亮头 + 拖尾，射程尽头分三档变淡）、枪口火光（十字星 / 尖火一发一换，只亮一两帧）、
##   弹壳（往身后上方抛、落地弹两下）、蒸汽锤（两圈像素环、中心一团白、喷出去的蒸汽方块、脚下冷却弧、冷却好时人身上一圈白）
## - 靶子是真的齿轮爬虫（100 血）：挨打发白、往后退，打死冒灰色和橙色碎屑后消失；示意里每一轮开头再放回来
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
]
const STAT_NAMES := ["POWER", "RATE", "REACH"]

const TILE_Y := 54.0
const TILE := Vector2(76, 52)
const TILE_GAP := 6.0
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
	_caption.text = tr("Pick one before level 1. Swap at the shop for 3 parts.")
	for i in WEAPONS.size():
		var l := _label(_tile_rect(i).position.x, TILE_Y + 37, TILE.x, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.text = tr(WEAPONS[i][1])
		_tile_names.append(l)
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
	_facts.label_settings.line_spacing = -2
	_tip = _label(x, 0, w, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.label_settings.line_spacing = -2
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
	_k = {
		"charge_time": p["CHARGE_TIME"], "dots": p["CHARGE_DOTS"], "ring_r": p["CHARGE_RING_R"],
		"rivet_interval": p["RIVET_INTERVAL"], "rivet_spread": p["RIVET_SPREAD"], "rivet_move": p["RIVET_MOVE_MULT"],
		"rivet_recoil": p["RIVET_RECOIL"], "hammer_cd": p["HAMMER_COOLDOWN"], "hammer_windup": p["HAMMER_WINDUP"],
		"orb_speed": o["FULL_SPEED"], "orb_damage": o["FULL_DAMAGE"], "orb_trail": o["TRAIL"],
		"rivet_speed": r["SPEED"], "rivet_life": r["LIFETIME"], "rivet_damage": r["DAMAGE"], "rivet_fade": r["FADE_TIME"],
		"blast_r": b["RADIUS"], "blast_damage": b["DAMAGE"], "blast_grow": b["GROW_TIME"], "blast_life": b["LIFE"],
		"casing_gravity": c["GRAVITY"], "casing_life": c["LIFE"],
		"bug_hp": cr["MAX_HP"],
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
	_glow.label_settings.font_color = WARM if _sel == 0 else DIM
	for j in _tile_names.size():
		_tile_names[j].label_settings.font_color = WARM if j == _sel else DIM
	_facts.text = "\n".join(_facts_for(e[0]))
	_tip.text = tr(e[7])
	_tip.size = Vector2(DETAIL.size.x - 16, 0)
	_tip.size.y = _tip.get_minimum_size().y
	_tip.position.y = DETAIL.end.y - 6 - _tip.size.y
	_reset()


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
		"muzzle": 0.0, "flash": 0.0, "squash": 0.0, "rivet_t": 0.0, "rivet_n": 0, "cd": 0.0, "windup": 0.0, "anim": 0.0}
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
	if WEAPONS[_sel][0] == "hammer":
		# Boss 打过来的三颗弹丸，在主角身边慢慢飘，蒸汽圈扫到就散
		for off in [Vector2(26, -24), Vector2(-24, -26), Vector2(40, -6)]:
			_pellets.append({"p": Vector2(d["hero"], FLOOR_Y - 10) + off, "home": off})


func _new_bug(x: float) -> Dictionary:
	return {"x": x, "home": x, "hp": float(_k["bug_hp"]), "flash": 0.0, "knock": 0.0, "vx": 0.0, "dead": false}


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
	_step_shots()
	for b in _bugs:
		b["flash"] = maxf(b["flash"] - STEP * 8.0, 0.0)
		if b["knock"] > 0.0:
			b["knock"] -= STEP
			b["x"] += b["vx"] * STEP
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
		if h["full"]:
			h["vx"] -= 40.0
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


func _blast() -> void:
	var h := _hero
	var center := Vector2(h["x"], FLOOR_Y - 10)
	_blasts.append({"c": center, "t": 0.0})
	h["cd"] = _k["hammer_cd"]
	h["flash"] = 0.6
	h["ring"] = 0.35
	var r: float = _k["blast_r"]
	for b in _bugs:
		if b["dead"]:
			continue
		# 和 steam_blast.gd 一样：怪的身体只要和圆有交叠就算
		var body := _bug_rect(b)
		var nearest := Vector2(clampf(center.x, body.position.x, body.end.x), clampf(center.y, body.position.y, body.end.y))
		if nearest.distance_to(center) <= r:
			_hurt(b, _k["blast_damage"], signf(b["x"] - center.x), true)
			_freeze = 0.05
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
			_hurt(b, _k["orb_damage"], 1.0, true)
			# 第一只顿得最久，后面的短顿一下（orb.gd）
			_freeze = 0.07 if o["hit"].size() == 1 else 0.03
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
				_hurt(b, _k["rivet_damage"], 1.0, false)
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


func _bug_rect(b: Dictionary) -> Rect2:
	return Rect2(b["x"] - 12, FLOOR_Y - 15, 24, 15)


## 齿轮爬虫挨打：发白、往后退；血打光了冒灰色和橙色碎屑后消失（crawler.gd 的 hurt / _die）
func _hurt(b: Dictionary, dmg: float, dir: float, full: bool) -> void:
	if b["dead"]:
		return
	b["hp"] -= dmg
	b["flash"] = 1.0
	b["knock"] = 0.12 if full else 0.06
	b["vx"] = dir * (90.0 if full else 40.0)
	if b["hp"] <= 0.0:
		b["dead"] = true
		var at := Vector2(b["x"], FLOOR_Y - 8)
		_spark_burst(at, Color8(150, 140, 125), 14, 110.0, Vector2.ZERO)
		_spark_burst(at, Color8(255, 190, 120), 6, 80.0, Vector2.ZERO)


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
		UiStyle.icon(c, _icons, idx, Vector2(r.position.x + (r.size.x - 32) / 2, r.position.y + 4), 2)
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
	for p in _pellets:
		if not p.has("gone"):
			var drift := Vector2(0, roundf(sin(_t * 3.0 + p["home"].x)))
			c.draw_rect(Rect2((p["p"] + drift - Vector2(1, 1)).round(), Vector2(3, 3)), UiStyle.POOR)
			_px(c, p["p"] + drift, Color(1, 0.8, 0.6))
	for b in _bugs:
		_draw_bug(c, b)
	_draw_hero(c)
	for o in _orbs:
		_draw_orb(c, o)
	for r in _rivets:
		_draw_rivet(c, r)
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
		"hammer":
			if h["cd"] > 0.0:
				# 冷却：脚下一道弧，冷却完就补满
				var k2: float = 1.0 - h["cd"] / _k["hammer_cd"]
				for i in 9:
					if float(i) / 9 >= k2:
						continue
					var a := PI + PI * i / 8.0
					_px(c, Vector2(roundf(h["x"]), FLOOR_Y - 1) + Vector2(cos(a) * 8.0, sin(a) * 2.0 + 2.0), Color(STRIP, 0.5))


func _draw_bug(c: CanvasItem, b: Dictionary) -> void:
	if b["dead"]:
		return
	var f := int(_t / 0.15) % 4
	var at := Vector2(roundf(b["x"]) - 18, FLOOR_Y - 16)
	var mod := Color.WHITE.lerp(Color(4, 4, 4), b["flash"])
	c.draw_texture_rect_region(_bug, Rect2(at, Vector2(36, 16)), Rect2(f * 36, 0, 36, 16), mod)


func _draw_orb(c: CanvasItem, o: Dictionary) -> void:
	var trail: Array = o["trail"]
	var n: int = _k["orb_trail"]
	for i in trail.size():
		var a := 0.6 * (1.0 - float(i) / n)
		_px(c, trail[i], Color(STRIP.r, STRIP.g, STRIP.b, a))
	var p: Vector2 = o["p"].round()
	if o["full"]:
		c.draw_rect(Rect2(p + Vector2(-1, -3), Vector2(3, 7)), STRIP)
		c.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(7, 3)), STRIP)
		c.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 5)), STRIP.lerp(Color.WHITE, 0.5))
		c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), Color.WHITE)
	else:
		c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), STRIP.lerp(Color.WHITE, 0.4))


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
	var brass := Color(0.86, 0.68, 0.32, a)
	var dark := Color(0.55, 0.4, 0.18, a)
	var p: Vector2 = k["p"].round()
	if k["bounces"] < 2 and k["spin"] / 3 % 2 == 1:
		c.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 2)), brass)
		c.draw_rect(Rect2(p, Vector2.ONE), dark)
	else:
		c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 1)), brass)
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
			c.draw_rect(Rect2(center + (Vector2(cos(ang), sin(ang)) * rr).round(), Vector2.ONE), col)
	if t < 0.08:
		c.draw_rect(Rect2(center + Vector2(-5, -5), Vector2(10, 10)), Color(1, 1, 1, 1.0 - t / 0.08))
