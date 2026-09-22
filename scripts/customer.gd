class_name Customer
extends RefCounted
## One person at the bar, and the state they're in.

enum State { WANTS_ORDER, WAITING_DRINK, DRINKING, WANTS_PAY, LEAVING }

var type_key: String
var drink: String
var state: State = State.WANTS_ORDER
var patience_max: float
var patience: float
var timer: float = 0.0          ## counts down while drinking or leaving
var served_speed: float = 0.0   ## how much patience was left when served
var combo_at_serve: int = 1
var angry: bool = false


func _init(elapsed: float) -> void:
	type_key = Config.random_customer_type()
	drink = Config.random_drink(elapsed)
	patience_max = Config.CUSTOMER_TYPES[type_key]["patience"]
	patience = patience_max


func is_waiting() -> bool:
	return state == State.WANTS_ORDER or state == State.WAITING_DRINK or state == State.WANTS_PAY


func patience_fraction() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


func type_label() -> String:
	return Config.CUSTOMER_TYPES[type_key]["label"]


## What they want from you right now, shown in the speech bubble.
func bubble_text() -> String:
	match state:
		State.WANTS_ORDER:
			return "Hey!"
		State.WAITING_DRINK:
			return Config.DRINKS[drink]["label"]
		State.WANTS_PAY:
			return "Tab?"
		_:
			return ""
