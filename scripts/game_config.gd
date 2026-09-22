extends Node
## Every tunable number in the game lives here.
##
## This file is the bridge between your son's answers and the game.
## Each block notes which question in the questions doc it comes from.
## Nothing here should need code changes — just numbers.

const SHIFT_SECONDS := 120.0      ## Q1.1 — how long is a shift?
const SEAT_COUNT := 4             ## Q1.2 — how many people can you handle at once?
const HAND_MAX := 2               ## how many drinks you can carry
const ICE_MAX := 6                ## Q3.1 — how much ice before a restock
const ICE_PER_COCKTAIL := 2
const ICE_RESTOCK_SECONDS := 2.2  ## Q3.2 — how long a restock steals from you
const MAX_WALKOUTS := 3

## Q2.1 / Q2.2 — the menu, prep times in seconds, prices in dollars.
const DRINKS := {
	"beer":     {"label": "Beer",     "price": 6.0,  "prep": 1.2, "ice": 0},
	"wine":     {"label": "Wine",     "price": 9.0,  "prep": 0.8, "ice": 0},
	"shot":     {"label": "Shot",     "price": 7.0,  "prep": 0.4, "ice": 0},
	"cocktail": {"label": "Cocktail", "price": 12.0, "prep": 3.0, "ice": ICE_PER_COCKTAIL},
}

## Q2.7 — order weights shift as the night goes on (0.0 = open, 1.0 = last call).
const DRINK_WEIGHTS_EARLY := {"beer": 40.0, "wine": 22.0, "shot": 24.0, "cocktail": 10.0}
const DRINK_WEIGHTS_LATE := {"beer": 40.0, "wine": 22.0, "shot": 24.0, "cocktail": 32.0}

## Q4.1 — customer types. "patience" is seconds before they walk.
const CUSTOMER_TYPES := {
	"normal":  {"label": "",        "patience": 14.0, "tip_mult": 1.00, "chance": 0.68},
	"rusher":  {"label": "hurry",   "patience": 9.0,  "tip_mult": 1.60, "chance": 0.20},
	"regular": {"label": "regular", "patience": 20.0, "tip_mult": 1.25, "chance": 0.12},
}

const DRINKING_SECONDS := Vector2(3.5, 6.0)  ## how long they nurse it before paying
const PAY_PATIENCE_FACTOR := 0.8             ## Q5.4 — patience while waiting to settle up

## Q1.1 — arrivals speed up over the shift, and again during the rush.
const SPAWN_GAP_AT_OPEN := 5.2
const SPAWN_GAP_AT_CLOSE := 2.6
const RUSH_WINDOW := Vector2(0.45, 0.68)  ## fraction of the shift
const RUSH_MULTIPLIER := 0.55

## Q6.1 / Q6.2 — the tip formula.
const TIP_BASE_PCT := 0.10      ## tip on a barely-tolerable drink
const TIP_SPEED_PCT := 0.30     ## extra, scaled by how fast you were
const COMBO_WINDOW := 4.0       ## seconds between serves to keep a streak alive
const COMBO_BONUS_PER_STEP := 0.15
const COMBO_MAX := 5

## Q6.2 — end-of-shift grading, in tips earned.
const TWO_STAR_TIPS := 32.0
const THREE_STAR_TIPS := 55.0

## Bar clock, purely cosmetic: 8 PM to 2 AM.
const OPEN_HOUR := 20
const SHIFT_HOURS := 6.0


func shift_progress(elapsed: float) -> float:
	return clampf(elapsed / SHIFT_SECONDS, 0.0, 1.0)


func is_rush(elapsed: float) -> bool:
	var p := shift_progress(elapsed)
	return p > RUSH_WINDOW.x and p < RUSH_WINDOW.y


func next_spawn_gap(elapsed: float) -> float:
	var gap := lerpf(SPAWN_GAP_AT_OPEN, SPAWN_GAP_AT_CLOSE, shift_progress(elapsed))
	if is_rush(elapsed):
		gap *= RUSH_MULTIPLIER
	return gap * randf_range(0.7, 1.3)


func random_drink(elapsed: float) -> String:
	var p := shift_progress(elapsed)
	var total := 0.0
	var weights := {}
	for key in DRINKS:
		var w: float = lerpf(DRINK_WEIGHTS_EARLY[key], DRINK_WEIGHTS_LATE[key], p)
		weights[key] = w
		total += w
	var roll := randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return "beer"


func random_customer_type() -> String:
	var roll := randf()
	for key in CUSTOMER_TYPES:
		roll -= CUSTOMER_TYPES[key]["chance"]
		if roll <= 0.0:
			return key
	return "normal"


## Q6.1 — how a served drink turns into money.
func tip_for(drink: String, type_key: String, speed_fraction: float, combo: int) -> float:
	var price: float = DRINKS[drink]["price"]
	var type_mult: float = CUSTOMER_TYPES[type_key]["tip_mult"]
	var combo_mult := 1.0 + (mini(combo, COMBO_MAX) - 1) * COMBO_BONUS_PER_STEP
	var pct := TIP_BASE_PCT + TIP_SPEED_PCT * clampf(speed_fraction, 0.0, 1.0)
	return maxf(1.0, roundf(price * pct * type_mult * combo_mult))


func stars_for(tips: float, walkouts: int) -> int:
	if walkouts >= MAX_WALKOUTS:
		return 1
	if tips >= THREE_STAR_TIPS:
		return 3
	if tips >= TWO_STAR_TIPS:
		return 2
	return 1


func clock_text(elapsed: float) -> String:
	var minutes := int(OPEN_HOUR * 60 + shift_progress(elapsed) * SHIFT_HOURS * 60)
	minutes -= minutes % 5
	var hour := int(minutes / 60.0) % 24
	var minute := minutes % 60
	var suffix := "AM" if hour < 12 else "PM"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, suffix]
