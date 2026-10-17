class_name SceneFade
extends CanvasLayer
## 切场景的黑幕：先在当前场景里慢慢淡到全黑，切场景，等新场景搭好，再淡开。
## 黑幕挂在根节点上（不是当前场景下面），切场景时不会被删掉，所以全程不会闪一下、也不会黑太久。
## 用法：SceneFade.go(get_tree(), "res://scenes/boss2.tscn")
## 第二关出口 → Boss2 用的就是它；别的关卡想统一，把 change_scene_to_file 换成这个就行。

const LAYER := 60

var _rect: ColorRect


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
	var tw2 := create_tween().set_ignore_time_scale(true)
	tw2.tween_property(_rect, "color:a", 0.0, in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished
	queue_free()
