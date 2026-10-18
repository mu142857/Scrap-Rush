extends Node
## 重画启动画面 art/ui/boot_splash.png（project.godot 的 application/boot_splash/image，网页版加载页也用它）。
## 用游戏里同一套字（Hud.small_text）在 480×270 的 SubViewport 里画，再最近邻放大到 960×540。画什么在 splash_art.gd。
## 跑法（要开窗口，headless 画不出来）：
##   ART=res://tools/splash/splash_art.gd OUT=$PWD/art/ui/boot_splash.png \
##     Godot --windowed --path . -s ... （或者做一个只挂这个脚本的临时场景）
## 2026-10-17 夜间打磨（游戏细节讨论会话）
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
func _run() -> void:
	Lang.apply("en")
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var art = load(OS.get_environment("ART")).new()
	vp.add_child(art)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	img.save_png(OS.get_environment("OUT"))
	print("[S] ", img.get_size())
	get_tree().quit()
