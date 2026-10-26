extends Node
## 跨系统信号总线（Autoload：EventBus）。
##
## 按《代码架构规范》第四章：
##   - 跨系统通信用 EventBus，同系统内部直接连信号
##   - 信号只传必要参数，不传节点引用
##   - 命名：对象_动作 / 对象_状态变化
##
## 谁都可以 emit，谁都可以 connect。EventBus 自己不持有任何状态。

# ---------- 时间 ----------
signal day_changed(new_day: int)
signal season_changed(new_season: String)
signal weather_changed(new_weather: String)
signal time_paused(is_paused: bool)

# ---------- 物品与金钱 ----------
signal item_picked(item_id: String, count: int)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal money_changed(new_amount: int)
signal stamina_changed(new_value: float, max_value: float)

# ---------- 农业 / 畜牧 ----------
signal crop_harvested(crop_id: String, quality: String, is_rare: bool)
signal animal_fed(animal_id: String)
signal animal_product(animal_id: String, product_id: String)
signal fish_caught(fish_id: String, quality: String, is_rare: bool)

# ---------- 社交 ----------
signal npc_talked(npc_id: String)
signal npc_gift(npc_id: String, item_id: String, delta: int)
signal quest_completed(quest_id: String)
signal festival_started(festival_id: String)
signal festival_ended(festival_id: String, rank: int)
signal achievement_unlocked(achievement_id: String)

# ---------- 系统 ----------
signal save_completed
signal save_failed(reason: String)
signal bgm_changed(bgm_key: String)
signal inventory_full
signal skill_level_up(skill: String, level: int)
signal tutorial_step_changed(step: int)
