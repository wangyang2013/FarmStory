class_name ActionAnimator
extends RefCounted
## 轻量动作动画工具（对应《动画效果清单》里的即时反馈类条目）。
##
## 原则：
## - 全部用 create_tween()，不用旧版 Tween 节点。
## - 幅度小、时间短，符合「治愈、不做华丽特效」的美术要求。
## - 不依赖任何外部资源，纯 Tween / 绘制实现。
##
## 用法：
##     ActionAnimator.bounce(node)
##     ActionAnimator.fly_to(node, from, to, on_done)

const DURATION_BOUNCE := 0.22
const DURATION_SHAKE := 0.2


## 拾取 / 收获：先上跳 8px 再回落（16px 网格下约半个身位）。
static func bounce(node: Node2D, height := 8.0, duration := DURATION_BOUNCE) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base := node.position
	var tween := node.create_tween()
	tween.tween_property(node, "position", base + Vector2(0, -height), duration * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", base, duration * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 角色使用工具：轻微前倾 + 回正（代替 4 方向挥动帧）。
static func tool_swing(node: Node2D, facing_vector: Vector2, distance := 3.0, duration := 0.16) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base := node.position
	var offset := facing_vector.normalized() * distance
	var tween := node.create_tween()
	tween.tween_property(node, "position", base + offset, duration * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", base, duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 浇水：水壶前倾一下。
static func water_pour(node: Node2D, duration := 0.25) -> void:
	tool_swing(node, Vector2.DOWN, 2.0, duration)


## 受击 / 体力耗尽：短暂闪红。
static func flash(node: CanvasItem, color := Color(1, 0.6, 0.6), duration := 0.35) -> void:
	if node == null or not node.is_inside_tree():
		return
	var original: Color = node.modulate
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.3)
	tween.tween_property(node, "modulate", original, duration * 0.7)


## 表情气泡 / 好感爱心：弹出 → 停留 → 淡出。
static func bubble(node: CanvasItem, duration := 1.2) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, 0.12)
	tween.tween_interval(duration)
	tween.tween_property(node, "modulate:a", 0.0, 0.25)


## 镜头震动：0.2 秒内随机偏移并衰减。
static func shake_camera(camera: Camera2D, strength := 3.0, duration := DURATION_SHAKE) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var base := camera.offset
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var steps := 6
	var tween := camera.create_tween()
	for index in steps:
		var falloff := 1.0 - float(index) / float(steps)
		var offset := Vector2(
			rng.randf_range(-strength, strength),
			rng.randf_range(-strength, strength)
		) * falloff
		tween.tween_property(camera, "offset", base + offset, duration / float(steps))
	tween.tween_property(camera, "offset", base, duration / float(steps))


## 面板滑入：从下方 20px 滑到原位。
static func slide_in(control: Control, distance := 20.0, duration := 0.2) -> void:
	if control == null or not control.is_inside_tree():
		return
	var base := control.position
	control.position = base + Vector2(0, distance)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "position", base, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, duration * 0.8)


## 按钮悬停 / 按下缩放（美术要求：用缩放和描边，不用渐变阴影）。
static func button_press(button: Control) -> void:
	if button == null or not button.is_inside_tree():
		return
	var base := button.scale
	var tween := button.create_tween()
	tween.tween_property(button, "scale", base * 0.95, 0.06)
	tween.tween_property(button, "scale", base, 0.08)


## 作物生长阶段切换：轻微弹一下。
static func grow_pop(node: Node2D, scale_up := 1.06, duration := 0.28) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base := node.scale
	var tween := node.create_tween()
	tween.tween_property(node, "scale", base * scale_up, duration * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, duration * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## 稀有个体提示：轻微放大（美术要求：金色柔光 + 轻微放大，不刺眼）。
static func rare_flash(node: Node2D, duration := 0.5) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base := node.scale
	var tween := node.create_tween()
	tween.tween_property(node, "scale", base * 1.18, duration * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, duration * 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
