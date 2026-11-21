extends Node
## 《情绪稳定》视频素材的摆拍录像入口（视频素材会话加的，不参与游戏本体）。
## 用法见 video/rec.sh：Godot --write-movie 某.avi --fixed-fps 60 --path . res://video/rec.tscn（镜头名放在环境变量 REC_SHOT）
## 这里只做一件事：把导演节点（director.gd）挂到根节点上（换场景不会被删），由它按镜头名摆拍，拍完自己退出。

func _ready() -> void:
	# 镜头名走环境变量 REC_SHOT，不走命令行：关卡里只要看到 "--" 开头的参数就不播开场动画
	var shot := OS.get_environment("REC_SHOT")
	var scr: GDScript = load("res://video/director.gd")
	if scr == null or not scr.can_instantiate():
		push_error("director.gd 编译不过")
		get_tree().quit(1)
		return
	var d: Node = scr.new()
	d.set("shot", shot)
	get_tree().root.add_child.call_deferred(d)
