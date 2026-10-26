extends SceneTree

const DB := preload("res://scripts/core/ConfigDB.gd")
const FishMiniGameScript := preload("res://scripts/fishing/FishMiniGame.gd")


func _initialize() -> void:
	DB.load_all()
	for fish_id: String in ["topmouth_gudgeon", "crucian", "carp", "koi", "catfish_placeholder"]:
		var fish := DB.get_fish(fish_id)
		if fish.is_empty():
			continue
		var wins := 0
		var success_time := 0.0
		var reasons: Dictionary = {}
		var attempts := 30
		for seed_value in range(1, attempts + 1):
			var game := FishMiniGameScript.new()
			game.start(fish, {"rng_seed": seed_value, "rod_id": "silver_rod"})
			var holding := true
			var steps := 0
			while game.running and steps < 5000:
				if game.is_fish_pulling:
					holding = false
				elif game.tension >= 0.70:
					holding = false
				elif game.tension <= 0.40:
					holding = true
				game.advance(0.016, holding)
				steps += 1
			if bool(game.last_result.get("success", false)):
				wins += 1
				success_time += float(game.config.get("time_limit", 25.0)) - game.time_left
			var reason := str(game.last_result.get("reason", "?"))
			reasons[reason] = int(reasons.get(reason, 0)) + 1
			game.free()
		var avg := success_time / float(wins) if wins > 0 else 0.0
		print("%-18s win %2d/%d  avg=%.1fs  %s" % [fish_id, wins, attempts, avg, str(reasons)])
	quit()
