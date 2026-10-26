class_name TutorialManager
extends RefCounted
## 新手引导（按《扩展系统设计合集》第二十一章）。
##
## 7 步：移动 → 锄地 → 播种 → 浇水 → 睡觉 → 收获 → 出货。
## 每一步用对话框提示，完成条件触发后自动进入下一步。
## 进度存在存档的 tutorial_step / tutorial_completed 里。
##
## 用法：
##     tutorial.on_step_changed = func(step): ...
##     tutorial.notify("till")

signal step_changed(step: int, text: String)
signal completed

const STEPS := [
	{"id": "move", "text": "用 WASD 或方向键走动一下。（按住 Shift 可以跑步）"},
	{"id": "till", "text": "选中锄头，对着脚下或面前的地块点鼠标左键翻地。"},
	{"id": "plant", "text": "选中种子，点翻好的地播种。"},
	{"id": "water", "text": "选中浇水壶，给种下的作物浇水。"},
	{"id": "sleep", "text": "走到门口按 E 进屋，再到床边按 E 睡觉。作物会在夜里生长。"},
	{"id": "harvest", "text": "作物成熟后，点击它就能收获。"},
	{"id": "ship", "text": "把收获物拿到出货箱或商店卖掉，就完成新手引导了。"},
]

var step := 0
var finished := false


func reset() -> void:
	step = 0
	finished = false


func get_current_id() -> String:
	if finished or step < 0 or step >= STEPS.size():
		return ""
	return str(STEPS[step]["id"])


func get_current_text() -> String:
	if finished or step < 0 or step >= STEPS.size():
		return ""
	return str(STEPS[step]["text"])


func get_step_text(index: int) -> String:
	if index < 0 or index >= STEPS.size():
		return ""
	return str(STEPS[index]["text"])


## 通知一个动作已完成。只有当前步骤匹配时才推进。
func notify(action_id: String) -> bool:
	if finished:
		return false
	if get_current_id() != action_id:
		return false
	step += 1
	if step >= STEPS.size():
		finished = true
		completed.emit()
		step_changed.emit(step, "")
		return true
	step_changed.emit(step, get_current_text())
	return true


## 跳过引导。
func skip() -> void:
	finished = true
	step = STEPS.size()
	step_changed.emit(step, "")
	completed.emit()


func to_save() -> Dictionary:
	return {"tutorial_step": step, "tutorial_completed": finished}


func from_save(data: Dictionary) -> void:
	step = clampi(int(data.get("tutorial_step", 0)), 0, STEPS.size())
	finished = bool(data.get("tutorial_completed", step >= STEPS.size()))
