class_name Level3Camera
extends GameCamera
## 第三关的镜头：人在哪块屏幕里，就把这块屏幕居中摆在画面正中，不跟着人左右晃。
## 缩放挑能把整块屏幕（加一圈外壳）装下的最大一档：2、5/3、4/3、1。
## 窗口是游戏画面的 3 倍，这几档在窗口上正好是 6、5、4、3 个像素一格，像素不会糊。
## 不在任何屏幕里（起点的仓库地面、爬洞的半路上）就照常跟人（GameCamera 的做法），缩放保持上一块屏幕的。
## 多人不在同一块屏幕里时也照常跟人，并退到 4/3 倍，免得有人出画面。

const ZOOMS := [2.0, 5.0 / 3.0, 4.0 / 3.0, 1.0]
## 屏幕四周多看这么多（外壳、控制条）
const MARGIN := Vector2(14, 12)
const LOCK_SPEED := 7.0
const ZOOM_SPEED := 5.0

## [{rect: Rect2（屏幕玻璃）, floor: float}]，关卡填
var screens: Array = []

var _zoom_target := ZOOM


func _ready() -> void:
	super._ready()
	_zoom_target = zoom.x


func snap() -> void:
	super.snap()
	var s := _current_screen()
	if not s.is_empty():
		_zoom_target = _fit_zoom(s["rect"])
		zoom = Vector2(_zoom_target, _zoom_target)
		global_position = (s["rect"] as Rect2).get_center()


func _process(delta: float) -> void:
	var s := _current_screen()
	if s.is_empty():
		if _players().size() > 1 and not _all_in_one_screen():
			_zoom_target = minf(_zoom_target, ZOOMS[2])
		_apply_zoom(delta)
		super._process(delta)
		return
	var rect: Rect2 = s["rect"]
	_zoom_target = _fit_zoom(rect)
	_apply_zoom(delta)
	var target := rect.get_center()
	global_position = global_position.lerp(target, 1.0 - exp(-LOCK_SPEED * delta))
	if global_position.distance_to(target) < 0.25:
		global_position = target
	offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake / zoom.x * 2.0).round() / 2.0


func _apply_zoom(delta: float) -> void:
	var z := lerpf(zoom.x, _zoom_target, 1.0 - exp(-ZOOM_SPEED * delta))
	if absf(z - _zoom_target) < 0.002:
		z = _zoom_target
	zoom = Vector2(z, z)


func _fit_zoom(rect: Rect2) -> float:
	var view := get_viewport_rect().size
	var need := rect.size + MARGIN * 2.0
	for z in ZOOMS:
		if need.x <= view.x / z and need.y <= view.y / z:
			return z
	return ZOOMS[ZOOMS.size() - 1]


## 所有玩家都在同一块屏幕里，就返回那块；否则返回空
func _current_screen() -> Dictionary:
	var players := _players()
	if players.is_empty():
		return {}
	var found: Dictionary = {}
	for p in players:
		var s := _screen_at(p.global_position)
		if s.is_empty():
			return {}
		if found.is_empty():
			found = s
		elif found != s:
			return {}
	return found


func _all_in_one_screen() -> bool:
	return not _current_screen().is_empty()


## 脚底在屏幕玻璃里（地面那一行也算）
func _screen_at(feet: Vector2) -> Dictionary:
	for s in screens:
		var r: Rect2 = s["rect"]
		if feet.x >= r.position.x and feet.x <= r.end.x and feet.y >= r.position.y and feet.y <= float(s["floor"]) + 1.0:
			return s
	return {}
