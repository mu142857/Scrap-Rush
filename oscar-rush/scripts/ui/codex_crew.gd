class_name CodexCrew
extends Control
## 总图鉴的"人物"一册（10-19 作者："图鉴这里加一个人物的栏"）：四个船员各一页。立绘添加会话做的。
## 左边是梧桐画的大立绘（放大两倍，只露上半身，会眨眼）；右边上面一排四张小脸选人，下面名字、身份、介绍。
## 介绍是剧情会话（游戏剧情主题讨论）写的。小鸟还没有立绘：先用它游戏里的小人放大，底下写"立绘绘制中"。

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const LIT_FILL := Color(0.19, 0.175, 0.18)

const PIC := Rect2(14, 54, 240, 188)
const DETAIL := Rect2(268, 54, 200, 188)
const TILE := Vector2(44, 44)
const TILE_GAP := 7.0
## 大立绘：原图 96×96 只取上面 92 行，放大 2 倍
const PIC_SRC := Rect2(0, 0, 96, 92)
const BLINK_EVERY := 3.2
const BLINK_TIME := 0.13

## [船员, 名字, 身份, 介绍]（英文，也是 text.csv 的键）
const CREW := [
	["red", "RED", "Lantern bearer",
		"The youngest aboard, always first with the lantern. She pressed record on the tape; she wants to press play too."],
	["robot", "ROBOT", "Copper-plated mechanic",
		"Kept the old ship flying with tape and hope. Talks like a manual. When its dial eyes spin, it's worried."],
	["dino", "DINO", "The gentle giant",
		"Biggest of the crew, softest heart. Runs the stores and patches the lantern. Hates noise, but always stands in front."],
	["bird", "BIRD", "Lookout and mimic",
		"Watches from the porthole and copies any sound. It remembers every voice from home, and plays them back when the crew is homesick."],
]
## 贴图用 preload 常量拿着（在 _draw 里现 load() 的贴图会被提前放掉，画成白块）
const PORTRAITS := {
	"red": [preload("res://art/chars/red_portrait.png"), preload("res://art/chars/red_portrait_blink.png")],
	"robot": [preload("res://art/chars/robot_portrait.png"), preload("res://art/chars/robot_portrait_blink.png")],
	"dino": [preload("res://art/chars/dino_portrait.png"), preload("res://art/chars/dino_portrait_blink.png")],
}
const BIRD := preload("res://art/chars/bird_body.png")

var embedded := true
var _sel := 0
var _time := 0.0
var _ready_for_input := false

var _base: Control
var _name: Label
var _role: Label
var _bio: Label
var _wip: Label


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = Control.new()
	_base.size = size
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.draw.connect(_draw_base)
	add_child(_base)
	var x := DETAIL.position.x + 8
	var w := DETAIL.size.x - 16
	_name = _label(x, DETAIL.position.y + 56, w, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_role = _label(x, DETAIL.position.y + 70, w, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_bio = _label(x, DETAIL.position.y + 92, w, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio.label_settings.line_spacing = Lang.tight_line()
	_wip = _label(PIC.position.x, PIC.end.y - 18, PIC.size.x, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_wip.text = tr("Portrait in progress")
	_select(0)
	await get_tree().process_frame
	_ready_for_input = true


func _label(x: float, y: float, w: float, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(color)
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, 15)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _tile_rect(i: int) -> Rect2:
	var total := CREW.size() * TILE.x + (CREW.size() - 1) * TILE_GAP
	var x0 := DETAIL.position.x + (DETAIL.size.x - total) / 2.0
	return Rect2(roundf(x0 + i * (TILE.x + TILE_GAP)), DETAIL.position.y + 6, TILE.x, TILE.y)


func _process(delta: float) -> void:
	_time += delta
	_base.queue_redraw()


func _select(i: int) -> void:
	_sel = clampi(i, 0, CREW.size() - 1)
	var c: Array = CREW[_sel]
	_name.text = tr(c[1])
	_role.text = tr(c[2])
	_bio.text = tr(c[3])
	_bio.size = Vector2(DETAIL.size.x - 16, 0)
	_wip.visible = not PORTRAITS.has(c[0])


## 总图鉴调：用掉了返回 true
func handle(event: InputEvent) -> bool:
	if not _ready_for_input:
		return false
	if event is InputEventMouseMotion:
		var m := get_local_mouse_position()
		for i in CREW.size():
			if i != _sel and _tile_rect(i).has_point(m):
				_select(i)
		return false
	var to := _sel
	if event.is_action_pressed("ui_left", true):
		to = maxi(_sel - 1, 0)
	elif event.is_action_pressed("ui_right", true):
		to = mini(_sel + 1, CREW.size() - 1)
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true) \
			or event.is_action_pressed("ui_accept"):
		return true
	else:
		return false
	if to != _sel:
		_select(to)
		Game.sfx("ui_move", -12.0)
	return true


func _draw_base() -> void:
	var c := _base
	UiStyle.panel(c, PIC, false, 0.0)
	UiStyle.panel(c, DETAIL, true, 0.0)
	var id: String = CREW[_sel][0]
	if PORTRAITS.has(id):
		var frames: Array = PORTRAITS[id]
		var blink := fmod(_time + _sel * 0.7, BLINK_EVERY) > BLINK_EVERY - BLINK_TIME
		var tex: Texture2D = frames[1] if blink else frames[0]
		var sz := PIC_SRC.size * 2.0
		var at := Vector2(PIC.position.x + (PIC.size.x - sz.x) / 2.0, PIC.end.y - 2.0 - sz.y).round()
		c.draw_texture_rect_region(tex, Rect2(at, sz), PIC_SRC)
	else:
		# 小鸟：游戏里的小人放大 7 倍，站在面板中间
		var sz := Vector2(16, 20) * 7.0
		var at := Vector2(PIC.position.x + (PIC.size.x - sz.x) / 2.0, PIC.position.y + 12.0).round()
		c.draw_texture_rect_region(BIRD, Rect2(at, sz), Rect2(0, 0, 16, 20))
	for i in CREW.size():
		var r := _tile_rect(i)
		UiStyle.panel(c, r, i == _sel, _time, WARM, LIT_FILL)
		CrewLine.draw_face(c, r.position + Vector2(2, 2), CREW[i][0])
	c.draw_rect(Rect2(DETAIL.position.x + 18, DETAIL.position.y + 86, DETAIL.size.x - 36, 1), UiStyle.BAR_OFF)
