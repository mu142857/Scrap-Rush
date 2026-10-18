class_name SceneFade
extends CanvasLayer
## 切场景的黑幕：先在当前场景里慢慢淡到全黑，切场景，等新场景搭好，再淡开。
## 黑幕挂在根节点上（不是当前场景下面），切场景时不会被删掉，所以全程不会闪一下、也不会黑太久。
## 用法：SceneFade.go(get_tree(), "res://scenes/boss2.tscn")
## 第二关出口 → Boss2 用的就是它；别的关卡想统一，把 change_scene_to_file 换成这个就行。

const LAYER := 60

var _rect: ColorRect
## 淡出、换场景、停顿这段时间里吞掉所有按键（2026-10-17 夜间，游戏细节讨论会话）：
## 不然这 1 秒里按 R / Esc / 确认，会在旧场景里重开、开暂停、点菜单，各个场景得各自去堵。
## 新场景开始淡开时就放行，玩家一进来就能动。
## 注意：这只挡"事件"（_input / _unhandled_input）。用 Input.is_action_just_pressed 轮询的地方，
## 想在切场景时不认，就自己判断 SceneFade.is_active(get_tree())。
var _blocking := true


static func go(tree: SceneTree, path: String, out_time := 0.7, hold := 0.2, in_time := 0.8) -> void:
	var f := SceneFade.new()
	tree.root.add_child(f)
	f._run(path, out_time, hold, in_time)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 0)
	add_child(_rect)


## 现在有没有黑幕在挡输入
static func is_active(tree: SceneTree) -> bool:
	for c in tree.root.get_children():
		if c is SceneFade and (c as SceneFade)._blocking:
			return true
	return false


## 挂在根节点最后面，_input 最先收到，在这里标成已处理，后面的节点就都收不到了
func _input(event: InputEvent) -> void:
	if _blocking and (event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventMouseButton or event is InputEventScreenTouch):
		get_viewport().set_input_as_handled()


func _run(path: String, out_time: float, hold: float, in_time: float) -> void:
	var tree := get_tree()
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_rect, "color:a", 1.0, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	Engine.time_scale = 1.0
	tree.paused = false
	tree.change_scene_to_file(path)
	# change_scene_to_file 在这一帧末尾才换；多等两帧，让新场景的 _ready 和镜头都就位
	await tree.process_frame
	await tree.process_frame
	await tree.create_timer(hold, true, false, true).timeout
	_blocking = false
	var tw2 := create_tween().set_ignore_time_scale(true)
	tw2.tween_property(_rect, "color:a", 0.0, in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished
	queue_free()
