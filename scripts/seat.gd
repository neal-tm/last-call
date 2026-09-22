extends Button
## One stool at the bar. Shows whoever is sitting there and what they need.

signal tapped(index: int)

@export var index: int = 0

@onready var bubble: Label = %Bubble
@onready var body: Panel = %Body
@onready var type_tag: Label = %TypeTag
@onready var patience_bar: ProgressBar = %Patience
@onready var glass_label: Label = %Glass

var _flash := 0.0

const CALM := Color(0.18, 0.62, 0.36)
const ANTSY := Color(0.85, 0.63, 0.10)
const ANGRY := Color(0.80, 0.24, 0.24)


func _ready() -> void:
	pressed.connect(func() -> void: tapped.emit(index))


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		modulate = Color(1, 1, 1).lerp(Color(1.4, 1.4, 1.4), _flash)


## Called every frame by main.gd with the current occupant (or null) and any dirty glass.
func render(customer: Customer, dirty_glass: String) -> void:
	var has_person := customer != null and customer.state != Customer.State.LEAVING
	body.visible = has_person
	type_tag.visible = has_person
	bubble.visible = has_person and customer.bubble_text() != ""
	patience_bar.visible = has_person and customer.is_waiting()

	if has_person:
		bubble.text = customer.bubble_text()
		type_tag.text = customer.type_label()
		body.modulate = Color(0.55, 0.55, 0.55) if customer.angry else Color.WHITE
		if customer.is_waiting():
			var f := customer.patience_fraction()
			patience_bar.value = f * 100.0
			var tint := ANGRY if f < 0.25 else (ANTSY if f < 0.5 else CALM)
			patience_bar.self_modulate = tint

	if has_person and customer.state == Customer.State.DRINKING:
		glass_label.text = Config.DRINKS[customer.drink]["label"]
		glass_label.self_modulate = Color.WHITE
	elif dirty_glass != "":
		glass_label.text = "empty"
		glass_label.self_modulate = Color(1, 1, 1, 0.45)
	else:
		glass_label.text = ""


func flash() -> void:
	_flash = 0.35
