extends Node2D
func _ready() -> void:
	_label("SCRAP RUSH", 86.0, 33, Hud.WARM, 4)
	_label("LUDUM DARE 60  /  OLD TECH", 126.0, 11, Hud.DIM, 2)
func _label(text: String, y: float, size: int, color: Color, outline: int) -> void:
	var l := Label.new()
	var st := Hud.small_text(color)
	st.font_size = size
	st.outline_size = outline
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(480, size + 6)
	add_child(l)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color8(8, 8, 10))
	var lantern := ["..#..", ".###.", "#ooo#", "#oOo#", "#ooo#", "#####"]
	var cols := {"#": Color8(90, 80, 70), "o": Color8(255, 190, 90), "O": Color8(255, 240, 200)}
	for y in lantern.size():
		for x in 5:
			var ch: String = lantern[y][x]
			if cols.has(ch):
				draw_rect(Rect2(235 + x * 2, 64 + y * 2, 2, 2), cols[ch])
