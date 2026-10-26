class_name Inventory
extends RefCounted
## 背包。只存物品实例（id / 分类 / 数量 / 稀有标记），不存任何配置数值。

signal changed

const DB := preload("res://scripts/core/ConfigDB.gd")

## 可堆叠的分类；工具 / 鱼竿 / 机器不堆叠。
const STACKABLE_CATEGORIES := [
	"seed", "crop", "fish", "fruit", "animal_product", "bee_product",
	"goods", "fertilizer", "feed", "forage", "bee_goods", "sapling", "mineral", "food",
	"pet_food",
]

var slots: Array = []
var max_slots := 24
var max_stack := 99


func _init(p_max_slots := 24, p_max_stack := 99) -> void:
	var rules := DB.get_inventory_rules()
	max_slots = maxi(1, int(rules.get("max_slots", p_max_slots)))
	max_stack = maxi(1, int(rules.get("max_stack", p_max_stack)))
	slots.resize(max_slots)


func clear() -> void:
	slots.clear()
	slots.resize(max_slots)
	changed.emit()


func is_stackable(item: Dictionary) -> bool:
	var category := str(item.get("category", ""))
	if category in ["tool", "rod"]:
		return false
	return category in STACKABLE_CATEGORIES


## 稀有状态不同的物品不堆叠（普通 / 超大 / 异色 分开）。
static func stack_key(item: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [
		str(item.get("item_id", "")),
		str(item.get("category", "")),
		str(item.get("is_rare", false)),
		str(item.get("rare_type", "")),
		str(item.get("is_rare_color", false)),
		str(item.get("is_giant", false)) + "|" + str(item.get("is_heavy", false)),
	]


func slot_key(index: int) -> String:
	var slot: Variant = slots[index] if index >= 0 and index < slots.size() else null
	if not (slot is Dictionary):
		return ""
	return stack_key(slot)


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	var slot: Variant = slots[index]
	return slot if slot is Dictionary else {}


func is_empty_slot(index: int) -> bool:
	return index >= 0 and index < slots.size() and not (slots[index] is Dictionary)


func empty_slot_count() -> int:
	var count := 0
	for slot: Variant in slots:
		if not (slot is Dictionary):
			count += 1
	return count


## 添加物品。count 默认取 item["count"]。
## 返回未能放入的数量（0 表示全部放入）。
func add_item(item: Dictionary, count := -1) -> int:
	var amount := int(item.get("count", 1)) if count < 0 else count
	if amount <= 0:
		return 0

	var entry := item.duplicate(true)
	entry["count"] = 0
	var remainder := amount

	if is_stackable(entry):
		var key := stack_key(entry)
		for index in slots.size():
			if remainder <= 0:
				break
			var slot: Variant = slots[index]
			if not (slot is Dictionary) or stack_key(slot) != key:
				continue
			var space: int = max_stack - int(slot.get("count", 0))
			if space <= 0:
				continue
			var moved: int = mini(space, remainder)
			slot["count"] = int(slot.get("count", 0)) + moved
			remainder -= moved

	while remainder > 0:
		var index := _first_empty_slot()
		if index < 0:
			break
		var moved: int = remainder
		if is_stackable(entry):
			moved = mini(max_stack, remainder)
		else:
			moved = 1
		var placed := entry.duplicate(true)
		placed["count"] = moved
		slots[index] = placed
		remainder -= moved

	changed.emit()
	return remainder


## 是否可以完整放入。
func can_add(item: Dictionary, count := -1) -> bool:
	var amount := int(item.get("count", 1)) if count < 0 else count
	if amount <= 0:
		return true
	if not is_stackable(item):
		return empty_slot_count() >= amount

	var space := 0
	var key := stack_key(item)
	for slot: Variant in slots:
		if not (slot is Dictionary):
			space += max_stack
		elif stack_key(slot) == key:
			space += max_stack - int(slot.get("count", 0))
	return space >= amount


## 按 id + 分类移除。返回实际移除数量。
func remove_item(item_id: String, count := 1, category := "") -> int:
	var remaining := count
	for index in slots.size():
		if remaining <= 0:
			break
		var slot: Variant = slots[index]
		if not (slot is Dictionary):
			continue
		if str(slot.get("item_id", "")) != item_id:
			continue
		if not category.is_empty() and str(slot.get("category", "")) != category:
			continue
		var taken: int = mini(int(slot.get("count", 0)), remaining)
		slot["count"] = int(slot.get("count", 0)) - taken
		remaining -= taken
		if int(slot.get("count", 0)) <= 0:
			slots[index] = null
	changed.emit()
	return count - remaining


func remove_slot(index: int, count := -1) -> int:
	if index < 0 or index >= slots.size():
		return 0
	var slot: Variant = slots[index]
	if not (slot is Dictionary):
		return 0
	var taken := int(slot.get("count", 0)) if count < 0 else mini(count, int(slot.get("count", 0)))
	slot["count"] = int(slot.get("count", 0)) - taken
	if int(slot.get("count", 0)) <= 0:
		slots[index] = null
	changed.emit()
	return taken


func count_item(item_id: String, category := "") -> int:
	var total := 0
	for slot: Variant in slots:
		if not (slot is Dictionary):
			continue
		if str(slot.get("item_id", "")) != item_id:
			continue
		if not category.is_empty() and str(slot.get("category", "")) != category:
			continue
		total += int(slot.get("count", 0))
	return total


func count_category(categories: Array) -> int:
	var total := 0
	for slot: Variant in slots:
		if slot is Dictionary and str(slot.get("category", "")) in categories:
			total += int(slot.get("count", 0))
	return total


## 找到第一个满足条件的槽位索引，找不到返回 -1。
func find_slot(category: String) -> int:
	for index in slots.size():
		var slot: Variant = slots[index]
		if slot is Dictionary and str(slot.get("category", "")) == category:
			return index
	return -1


func find_tool(tool_id: String) -> int:
	for index in slots.size():
		var slot: Variant = slots[index]
		if slot is Dictionary \
				and str(slot.get("category", "")) == "tool" \
				and str(slot.get("item_id", "")) == tool_id:
			return index
	return -1


func find_rod() -> String:
	for slot: Variant in slots:
		if slot is Dictionary and str(slot.get("category", "")) == "rod":
			return str(slot.get("item_id", ""))
	return "normal_rod"


## 出货箱 / 商店可收购的物品分类。
func get_sellable_stacks() -> Array:
	var result: Array = []
	var sellable := ["crop", "fish", "fruit", "animal_product", "bee_product", "forage", "mineral", "food"]
	for index in slots.size():
		var slot: Variant = slots[index]
		if not (slot is Dictionary):
			continue
		if not (str(slot.get("category", "")) in sellable):
			continue
		var unit_price := int(slot.get("price", -1))
		if unit_price < 0:
			unit_price = DB.get_item_base_price(str(slot.get("item_id", "")), str(slot.get("category", "")))
		result.append({
			"index": index,
			"slot": slot,
			"unit_price": unit_price,
			"count": int(slot.get("count", 0)),
		})
	return result


## 卖出指定槽位，返回获得的金币。
func sell_slot(index: int, count := -1) -> int:
	var slot: Variant = slots[index] if index >= 0 and index < slots.size() else null
	if not (slot is Dictionary):
		return 0
	var unit_price := int(slot.get("price", -1))
	if unit_price < 0:
		unit_price = DB.get_item_base_price(str(slot.get("item_id", "")), str(slot.get("category", "")))
	var sold := remove_slot(index, count)
	var multiplier := float(DB.get_shop_config().get("sell_multiplier", 1.0))
	return int(round(float(unit_price) * float(sold) * multiplier))


func sell_all() -> Dictionary:
	var total_money := 0
	var total_count := 0
	var names: Array[String] = []
	for stack: Dictionary in get_sellable_stacks():
		var slot: Dictionary = stack["slot"]
		var count := int(stack["count"])
		var unit_price := int(stack["unit_price"])
		names.append("%s×%d" % [DB.get_item_name(str(slot.get("item_id", "")), str(slot.get("category", ""))), count])
		total_money += int(round(float(unit_price) * float(count) * float(DB.get_shop_config().get("sell_multiplier", 1.0))))
		total_count += count
		slots[int(stack["index"])] = null
	if total_count > 0:
		changed.emit()
	return {"money": total_money, "count": total_count, "names": names}


# ============================================================
# 存档
# ============================================================

func to_save() -> Array:
	var result: Array = []
	for slot: Variant in slots:
		if slot is Dictionary and int(slot.get("count", 0)) > 0:
			result.append(slot.duplicate(true))
	return result


func from_save(data: Array) -> void:
	slots.clear()
	slots.resize(max_slots)
	for entry: Variant in data:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		var item_id := str(item.get("item_id", ""))
		if item_id.is_empty():
			continue
		var category := str(item.get("category", ""))
		var count := clampi(int(item.get("count", 1)), 1, max_stack)
		add_item({
			"item_id": item_id,
			"category": category,
			"count": count,
			"is_rare": bool(item.get("is_rare", false)),
			"rare_type": str(item.get("rare_type", "")),
			"rare_name": str(item.get("rare_name", "")),
			"price": int(item.get("price", -1)),
			"weight": float(item.get("weight", 0.0)),
			"is_rare_color": bool(item.get("is_rare_color", false)),
			"is_giant": bool(item.get("is_giant", false)),
			"is_heavy": bool(item.get("is_heavy", false)),
		})
	changed.emit()


func _first_empty_slot() -> int:
	for index in slots.size():
		if not (slots[index] is Dictionary):
			return index
	return -1
