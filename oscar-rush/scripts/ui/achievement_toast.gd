class_name AchievementToast
extends CanvasLayer
## 解锁成就时屏幕右上角弹出的小卡（achievements.gd 的 unlock 调 pop）。立绘添加会话做的。
## 不挡操作（全部 MOUSE_FILTER_IGNORE、不吃输入），挂在根节点上，换场景也不断；暂停时也照走。
## 从右边滑进来、停 3 秒、滑出去；同时解锁好几个就排队一个一个弹。响一声铃。

const SIZE := Vector2(156, 30)
const MARGIN := 6.0
const SLIDE := 0.25
const HOLD := 3.0

static var _queue: Array[String] = []
static var _current: AchievementToast = null

var id := ""
var _t := 0.0
var _card: Control
var _title: Label
var _name: Label


## 弹一张（正在弹别的就排队）
static func pop(achievement_id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if is_instance_valid(_current):
		_queue.append(achievement_id)
		return
	var t := AchievementToast.new()
	t.id = achievement_id
	_current = t
	tree.root.add_child.call_deferred(t)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = Control.new()
	_card.size = SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	var a := Achievements.info(id)
	_title = _label(tr("ACHIEVEMENT UNLOCKED"), UiStyle.DIM, 4)
	_name = _label(tr(a[1]) if not a.is_empty() else "", UiStyle.WARM, 15)
	Game.sfx("bell", -10.0, 1.25)
	Game.sfx("ding", -16.0, 1.6)
	_place()


func _label(text: String, col: Color, y: float) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(col)
	l.text = text
	l.position = Vector2(38, y)
	l.size = Vector2(SIZE.x - 42, 13)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	_place()
	_card.queue_redraw()
	if _t > SLIDE * 2.0 + HOLD:
		queue_free()
		_current = null
		if not _queue.is_empty():
			AchievementToast.pop(_queue.pop_front())


## 从屏幕右边外面滑进来，最后滑出去（按整像素）
func _place() -> void:
	var k := 1.0
	if _t < SLIDE:
		k = _t / SLIDE
	elif _t > SLIDE + HOLD:
		k = 1.0 - (_t - SLIDE - HOLD) / SLIDE
	k = clampf(k, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	_card.position = Vector2(roundf(480.0 - (SIZE.x + MARGIN) * k), MARGIN)


func _draw_card() -> void:
	UiStyle.panel(_card, Rect2(Vector2.ZERO, SIZE), true, _t, UiStyle.WARM, Color(0.11, 0.1, 0.11))
	Achievements.draw_badge(_card, id, Vector2(7, 7), 1, true)
	# 刚弹出来时徽章外面闪一圈
	if _t < 0.6 and int(_t * 10.0) % 2 == 0:
		_card.draw_rect(Rect2(5, 5, 20, 1), UiStyle.WARM)
		_card.draw_rect(Rect2(5, 24, 20, 1), UiStyle.WARM)
		_card.draw_rect(Rect2(5, 5, 1, 20), UiStyle.WARM)
		_card.draw_rect(Rect2(24, 5, 1, 20), UiStyle.WARM)
