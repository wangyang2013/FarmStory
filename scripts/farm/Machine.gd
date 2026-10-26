class_name ProcessingMachine
extends Node2D
## 1×1 加工机器：奶酪机 / 纺织机 / 腌菜桶 / 酿酒桶 / 加工台。
## 计时使用 TimeSystem 的绝对游戏分钟；工作时有烟雾，完成时显示提示。

const DB := preload("res://scripts/core/ConfigDB.gd")
const PixelTheme := preload("res://scripts/ui/PixelTheme.gd")

const TILE := 32

var machine_id := ""
var cell := Vector2i.ZERO
var product_id := ""
var output: Dictionary = {}
var ready_at := 0
var map_entity: MapEntity
var _phase := 0.0


func setup(p_machine_id: String, p_cell: Vector2i, data: Dictionary = {}) -> void:
	machine_id = p_machine_id
	cell = p_cell
	position = Vector2(cell) * TILE + Vector2(TILE * 0.5, TILE)
	product_id = str(data.get("product", ""))
	ready_at = int(data.get("ready_at", 0))
	var saved_output: Variant = data.get("output", {})
	output = saved_output.duplicate(true) if saved_output is Dictionary else {}
	_build_body()
	set_process(true)
	queue_redraw()


func _build_body() -> void:
	if get_node_or_null("Body") != null:
		return
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 18)
	shape.shape = rect
	shape.position = Vector2(0, -9)
	body.add_child(shape)
	add_child(body)


func get_display_name() -> String:
	return str(DB.get_machine(machine_id).get("name", machine_id))


func get_machine_config() -> Dictionary:
	return DB.get_machine(machine_id)


func now_minutes() -> int:
	var farm := get_parent()
	if farm != null and farm.time != null:
		return int(farm.time.get_absolute_minutes())
	return 0


func is_working() -> bool:
	return not product_id.is_empty() and now_minutes() < ready_at


func is_ready() -> bool:
	return not product_id.is_empty() and now_minutes() >= ready_at


func remaining_minutes() -> int:
	return maxi(0, ready_at - now_minutes())


func start(p_product_id: String, p_ready_at: int, p_output: Dictionary) -> void:
	product_id = p_product_id
	ready_at = p_ready_at
	output = p_output.duplicate(true)
	_phase = 0.0
	queue_redraw()


func clear_product() -> void:
	product_id = ""
	ready_at = 0
	output.clear()
	queue_redraw()


func get_save() -> Dictionary:
	return {
		"id": machine_id,
		"x": cell.x,
		"y": cell.y,
		"product": product_id,
		"ready_at": ready_at,
		"output": output.duplicate(true),
	}


func _process(delta: float) -> void:
	if is_working() or is_ready():
		_phase += delta
		queue_redraw()


func _draw() -> void:
	# 软阴影
	draw_rect(Rect2(-13, -4, 26, 4), Color(0, 0, 0, 0.10), true)
	draw_rect(Rect2(-10, -2, 20, 2), Color(0, 0, 0, 0.10), true)

	match machine_id:
		"cheese_maker":
			draw_rect(Rect2(-12, -24, 24, 20), Color("#8f969b"), true)
			draw_rect(Rect2(-12, -24, 24, 3), Color("#b7bec3"), true)
			draw_rect(Rect2(-13, -28, 26, 5), Color("#6f767b"), true)
			draw_rect(Rect2(-3, -30, 6, 3), Color("#c9d0d4"), true)
			draw_rect(Rect2(-8, -17, 16, 3), Color("#5f666b"), true)
		"loom":
			draw_rect(Rect2(-14, -26, 4, 22), Color("#8a5a3f"), true)
			draw_rect(Rect2(10, -26, 4, 22), Color("#8a5a3f"), true)
			draw_rect(Rect2(-14, -27, 28, 3), Color("#a9713f"), true)
			draw_rect(Rect2(-10, -21, 20, 12), Color("#e5d3b6"), true)
			for index in 4:
				draw_rect(Rect2(-8 + index * 5, -20, 1, 10), Color("#b9a98c"), true)
			draw_rect(Rect2(-12, -8, 24, 4), Color("#8a5a3f"), true)
		"workbench":
			draw_rect(Rect2(-14, -20, 28, 5), Color("#a9713f"), true)
			draw_rect(Rect2(-13, -15, 3, 12), Color("#8a5a3f"), true)
			draw_rect(Rect2(10, -15, 3, 12), Color("#8a5a3f"), true)
			draw_rect(Rect2(-8, -25, 6, 5), Color("#c9d0d4"), true)
			draw_rect(Rect2(2, -24, 7, 4), Color("#e5c065"), true)
		_:
			# 腌菜桶 / 酿酒桶
			draw_rect(Rect2(-11, -24, 22, 20), Color("#a9713f"), true)
			draw_rect(Rect2(-11, -24, 22, 2), Color("#c99d74"), true)
			draw_rect(Rect2(-12, -19, 24, 2), Color("#6b4423"), true)
			draw_rect(Rect2(-12, -9, 24, 2), Color("#6b4423"), true)
			draw_rect(Rect2(-2, -17, 4, 4), Color("#4a3b28"), true)

	if is_working():
		var puff := fmod(_phase * 1.6, 1.0)
		for index in 3:
			var rise := fmod(puff + float(index) * 0.33, 1.0)
			var px := -6.0 + float(index) * 6.0
			var py := -30.0 - rise * 14.0
			var alpha := (1.0 - rise) * 0.55
			draw_rect(Rect2(px, py, 3, 2), Color(0.95, 0.93, 0.88, alpha), true)
	elif is_ready():
		draw_rect(Rect2(-8, -42, 16, 11), Color("#fdf5e6"), true)
		draw_rect(Rect2(-8, -42, 16, 11), Color("#8b6d52"), false, 1.0)
		draw_string(PixelTheme.font(), Vector2(-6, -33), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color("#b5642f"))
