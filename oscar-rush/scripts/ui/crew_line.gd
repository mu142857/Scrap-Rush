class_name CrewLine
extends CanvasLayer
## 船员说一句（10-19 作者："到了立绘部分，好像没怎么用到怎么办"）：左上角（马灯血条下面）一张小卡，
## 左边是梧桐画的立绘里裁出来的脸，右边是名字和一两行话，停 HOLD 秒自己淡掉。立绘添加会话做的。
## 不暂停、不吃输入、不挡操作。屏幕上有新手提示（Coach）时先等它走完再出（10-18 作者：文字不重叠）；
## 同时来好几句就排队。台词在 LINES 里，剧情会话（游戏剧情主题讨论）10-19 写的：录像封在马灯里、锅炉想把它烧了、
## 总机学全星球的声音、老电视是最后一台能放这盘带子的机器；Boss3 打完那句只埋"它还会亮"，不抢结局。
##
## 用法（一行）：CrewLine.say("boss1_start")
## 别处也能用 draw_face(画布, 左上角, 船员) 画一张小脸（新手提示、结算画面用）。

const HOLD := 3.5
const FADE := 0.3
const POS := Vector2(8, 30)
const FACE := Vector2(40, 40)
const TEXT_W := 196.0
## 每个船员的立绘裁哪一块当脸（40×40，原图 96×96）；鸟还没有立绘，用它游戏里的小人放大两倍
## 贴图用 preload 常量拿着：在 _draw 里现 load() 的贴图画完这一下就没人引用、被放掉，真正渲染时画出来是一块白
const FACES := {
	"red": {"tex": preload("res://art/chars/red_portrait.png"), "rect": Rect2(24, 4, 40, 40)},
	"robot": {"tex": preload("res://art/chars/robot_portrait.png"), "rect": Rect2(24, 0, 40, 40)},
	"dino": {"tex": preload("res://art/chars/dino_portrait.png"), "rect": Rect2(20, 4, 40, 40)},
	"bird": {"tex": preload("res://art/chars/bird_body.png"), "rect": Rect2(0, 0, 16, 20), "scale": 2},
}
const NAMES := {"red": "RED", "robot": "ROBOT", "dino": "DINO", "bird": "BIRD"}
## 台词：[谁说, 英文（也是 text.csv 的键）]
const LINES := {
	"boss1_end": ["dino", "Every photo it burned was somebody's home."],
	"boss2_end": ["red", "Whatever it is, tell me at home."],
	"boss3_end": ["dino", "Shh. Don't move. It's still on."],
	"shop": ["dino", "Catch your breath. I'll patch up the lantern."],
}
## 新手提示是谁的声音（Coach 画小脸用）
const COACH_VOICE := "robot"

static var _queue: Array = []   # [台词键, 位置]
static var _current: CrewLine = null

var key := ""
## 卡片左上角（默认在马灯血条下面；商店顶上有信息卡，传 Vector2(8, 64)）
var at := POS
var _t := 0.0
var _wait := 0.0
var _card: Control
var _name: Label
var _text: Label
var _who := "red"


## 说一句（正在说别的就排队）。没有这条台词就不出
static func say(line_key: String, pos := POS) -> void:
	if not LINES.has(line_key):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if is_instance_valid(_current):
		_queue.append([line_key, pos])
		return
	var c := CrewLine.new()
	c.key = line_key
	c.at = pos
	_current = c
	tree.root.add_child.call_deferred(c)


## 在 canvas 的 at 处画一张船员的小脸（40×40；鸟 32×40）
static func draw_face(canvas: CanvasItem, at: Vector2, who: String, alpha := 1.0) -> void:
	var f: Dictionary = FACES.get(who, FACES["red"])
	var tex: Texture2D = f["tex"]
	var r: Rect2 = f["rect"]
	var k: int = f.get("scale", 1)
	var size := r.size * k
	var off := ((FACE - size) * Vector2(0.5, 1.0)).round()
	canvas.draw_texture_rect_region(tex, Rect2(at + off, size), r, Color(1, 1, 1, alpha))


func _ready() -> void:
	# 和 HUD 同层（10；新手提示是 11、暂停菜单在更上面）：不盖暂停菜单。process_mode 用默认：暂停时跟着停
	layer = 10
	var line: Array = LINES[key]
	_who = line[0]
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = at
	_card.modulate.a = 0.0
	_card.draw.connect(_draw_card)
	add_child(_card)
	_name = _label(tr(NAMES[_who]), UiStyle.WARM, 3)
	_text = _label(tr(line[1]), UiStyle.TEXT, 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 自动换行的 Label 在 _ready 里量不出高度（还没排版），直接拿字体量一整行多宽，算要几行
	var ls := _text.label_settings
	var one_line := ls.font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x
	var rows := 1 if one_line <= TEXT_W - 4.0 else 2
	_text.size = Vector2(TEXT_W, rows * 13.0 + 2.0)
	_card.size = Vector2(FACE.x + 12 + TEXT_W + 6, maxf(FACE.y + 6, 16 + _text.size.y + 4))


func _label(text: String, col: Color, y: float) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(col)
	l.label_settings.line_spacing = Lang.tight_line()
	l.text = text
	l.position = Vector2(FACE.x + 10, y)
	l.size = Vector2(TEXT_W, 13)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(l)
	return l


func _process(delta: float) -> void:
	# 新手提示正开着：先等（最多 4 秒），不和它叠在一起
	if _t == 0.0 and _wait < 4.0 and _coach_busy(false):
		_wait += delta
		return
	# 说到一半新手提示挪到了顶上（人在屏幕下沿时它会挪到血条下面，正好是这张卡的位置）：先让开，等它走了接着说
	if _t > 0.0 and _wait < 8.0 and _coach_busy(true):
		_wait += delta
		_card.modulate.a = move_toward(_card.modulate.a, 0.0, delta * 6.0)
		return
	_t += delta
	var a := 1.0
	if _t < FADE:
		a = _t / FADE
	elif _t > FADE + HOLD:
		a = 1.0 - (_t - FADE - HOLD) / FADE
	_card.modulate.a = clampf(a, 0.0, 1.0)
	_card.queue_redraw()
	if _t > FADE * 2.0 + HOLD:
		queue_free()
		_current = null
		if not _queue.is_empty():
			var q: Array = _queue.pop_front()
			CrewLine.say(q[0], q[1])


## 新手提示开着没有：Hud 把它放在 _coach 里（不写 Coach 类名：coach.gd 也调这里，两边写类名会循环引用）
## only_top：只算挪到屏幕上半（和这张卡同一块地方）的提示
func _coach_busy(only_top: bool) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	for n in scene.get_children():
		var c = n.get("_coach")
		if not (c is Object and is_instance_valid(c) and c.has_method("busy") and c.call("busy")):
			continue
		var box = c.get("_box")
		if not only_top or (box is Control and (box as Control).position.y < 100.0):
			return true
	return false


func _draw_card() -> void:
	var r := Rect2(Vector2.ZERO, _card.size)
	_card.draw_rect(r, Color(0.03, 0.03, 0.045, 0.9))
	_card.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(0.55, 0.42, 0.28))
	_card.draw_rect(Rect2(Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0.55, 0.42, 0.28))
	_card.draw_rect(Rect2(Vector2.ZERO, Vector2(1, r.size.y)), Color(0.55, 0.42, 0.28))
	_card.draw_rect(Rect2(Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), Color(0.55, 0.42, 0.28))
	# 脸底下一块暖色底，说话时脸上下错一格（和对话框里一样的"在说话"）
	_card.draw_rect(Rect2(3, 3, FACE.x, FACE.y), Color(0.13, 0.1, 0.09))
	var bob := 1.0 if _t < 1.2 and int(_t * 8.0) % 2 == 0 else 0.0
	draw_face(_card, Vector2(3, 3 + bob), _who)


## Boss 房用（boss_arena.gd / boss3_room.gd 各一行）：按场景名找台词，boss1.tscn + "start" → "boss1_start"
static func boss(room: Node, when: String) -> void:
	say(room.scene_file_path.get_file().get_basename() + "_" + when)


## 新手提示框（coach.gd 的 _draw_box 一行调用）左边画机器人的小脸：box 是提示框的画布，r 是框在画布里的范围，
## origin 是画布在屏幕上的左上角。框在屏幕下半：脸坐在框左边、往上探出来；框贴在顶上（血条下面）：脸挂在框下面，不压血条
static func coach_face(box: CanvasItem, r: Rect2, origin: Vector2) -> void:
	var x := maxf(r.position.x - FACE.x - 2.0, -origin.x + 2.0)
	var y := r.end.y - FACE.y if origin.y > 100.0 else r.position.y
	box.draw_rect(Rect2(Vector2(x, y), FACE), Color(0.04, 0.035, 0.05, 0.82))
	draw_face(box, Vector2(x, y), COACH_VOICE)


## 结算画面（results_screen.gd 的 _ready 一行）：卡片左右两边站四个船员，半身像下沿贴着屏幕底。
## 鸟还没有立绘，用它游戏里的小人放大 3 倍顶着
static func results_row(parent: Node) -> void:
	var row := Control.new()
	row.size = Vector2(480, 270)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(_draw_row.bind(row))
	parent.add_child(row)


static func _draw_row(row: Control) -> void:
	row.draw_texture(FACES["robot"]["tex"], Vector2(4, 72))
	row.draw_texture(FACES["red"]["tex"], Vector2(4, 174))
	row.draw_texture_rect_region(FACES["bird"]["tex"], Rect2(404, 96, 48, 60), Rect2(0, 0, 16, 20))
	row.draw_texture(FACES["dino"]["tex"], Vector2(380, 174))
