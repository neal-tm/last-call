extends Control
## The shift itself: arrivals, orders, pouring, payment, and scoring.
##
## Tap a customer to take their order, make the drink at the station,
## tap them again to serve, and once more to collect the tab.

const SeatScene := preload("res://scenes/seat.tscn")

@onready var seats_row: HBoxContainer = %SeatsRow
@onready var tips_label: Label = %TipsLabel
@onready var clock_label: Label = %ClockLabel
@onready var walkouts_label: Label = %WalkoutsLabel
@onready var hand_label: Label = %HandLabel
@onready var drinks_row: HBoxContainer = %DrinksRow
@onready var ice_bar: ProgressBar = %IceBar
@onready var ice_button: Button = %IceButton
@onready var prep_bar: ProgressBar = %PrepBar
@onready var toast_label: Label = %ToastLabel
@onready var banner_label: Label = %BannerLabel
@onready var start_panel: PanelContainer = %StartPanel
@onready var start_button: Button = %StartButton
@onready var result_label: Label = %ResultLabel

var running := false
var elapsed := 0.0
var customers: Array[Customer] = []      ## one slot per seat, null when empty
var dirty_glasses: Array[String] = []    ## one slot per seat, "" when clean
var hand: Array[String] = []
var ice := Config.ICE_MAX
var prep := {}                           ## {"kind": "drink"/"ice", "drink": key, "elapsed": s, "duration": s}
var spawn_timer := 1.2
var tips := 0.0
var served := 0
var walkouts := 0
var combo := 0
var best_combo := 0
var last_serve := -99.0
var seat_nodes: Array = []
var toast_timer := 0.0
var end_delay := -1.0


func _ready() -> void:
	randomize()
	for i in Config.SEAT_COUNT:
		var seat := SeatScene.instantiate()
		seat.index = i
		seat.tapped.connect(_on_seat_tapped)
		seats_row.add_child(seat)
		seat_nodes.append(seat)
		customers.append(null)
		dirty_glasses.append("")
	for key in Config.DRINKS:
		var button := Button.new()
		button.text = "%s\n$%d" % [Config.DRINKS[key]["label"], int(Config.DRINKS[key]["price"])]
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_drink_pressed.bind(key))
		drinks_row.add_child(button)
	ice_button.pressed.connect(_on_ice_pressed)
	start_button.pressed.connect(_start_shift)
	_render()


func _start_shift() -> void:
	elapsed = 0.0
	customers = []
	dirty_glasses = []
	for i in Config.SEAT_COUNT:
		customers.append(null)
		dirty_glasses.append("")
	hand.clear()
	ice = Config.ICE_MAX
	prep = {}
	spawn_timer = 1.2
	tips = 0.0
	served = 0
	walkouts = 0
	combo = 0
	best_combo = 0
	last_serve = -99.0
	end_delay = -1.0
	running = true
	start_panel.visible = false
	_toast("Doors are open")


func _process(delta: float) -> void:
	if running:
		_simulate(delta)
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.text = ""
	_render()


func _simulate(delta: float) -> void:
	elapsed += delta

	if end_delay > 0.0:
		end_delay -= delta
		if end_delay <= 0.0:
			_end_shift("Sent home early")
			return
	elif elapsed >= Config.SHIFT_SECONDS:
		_end_shift("Last call!")
		return

	if not prep.is_empty():
		prep["elapsed"] += delta
		if prep["elapsed"] >= prep["duration"]:
			if prep["kind"] == "ice":
				ice = Config.ICE_MAX
				_toast("Ice bin is full")
			else:
				var key: String = prep["drink"]
				ice = maxi(0, ice - int(Config.DRINKS[key]["ice"]))
				hand.append(key)
			prep = {}

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_customer()
		spawn_timer = Config.next_spawn_gap(elapsed)

	for i in customers.size():
		var c: Customer = customers[i]
		if c == null:
			continue
		match c.state:
			Customer.State.DRINKING:
				c.timer -= delta
				if c.timer <= 0.0:
					c.state = Customer.State.WANTS_PAY
					c.patience_max = Config.CUSTOMER_TYPES[c.type_key]["patience"] * Config.PAY_PATIENCE_FACTOR
					c.patience = c.patience_max
			Customer.State.LEAVING:
				c.timer -= delta
				if c.timer <= 0.0:
					customers[i] = null
			_:
				c.patience -= delta
				if c.patience <= 0.0:
					_walkout(i)


func _spawn_customer() -> void:
	var free: Array[int] = []
	for i in customers.size():
		if customers[i] == null and dirty_glasses[i] == "":
			free.append(i)
	if free.is_empty():
		return
	customers[free.pick_random()] = Customer.new(elapsed)


func _on_seat_tapped(index: int) -> void:
	if not running:
		return
	var c: Customer = customers[index]
	var seat = seat_nodes[index]

	if c == null or c.state == Customer.State.LEAVING:
		if dirty_glasses[index] != "":
			dirty_glasses[index] = ""
			seat.flash()
			_toast("Glass cleared")
		return

	match c.state:
		Customer.State.WANTS_ORDER:
			c.state = Customer.State.WAITING_DRINK
			c.patience_max = Config.CUSTOMER_TYPES[c.type_key]["patience"]
			c.patience = c.patience_max
			seat.flash()
			_toast("Order up: %s" % Config.DRINKS[c.drink]["label"])
		Customer.State.WAITING_DRINK:
			var slot := hand.find(c.drink)
			if slot == -1:
				_toast("They want a %s" % Config.DRINKS[c.drink]["label"].to_lower())
				return
			hand.remove_at(slot)
			c.served_speed = c.patience_fraction()
			c.state = Customer.State.DRINKING
			c.timer = randf_range(Config.DRINKING_SECONDS.x, Config.DRINKING_SECONDS.y)
			combo = combo + 1 if elapsed - last_serve < Config.COMBO_WINDOW else 1
			c.combo_at_serve = combo
			best_combo = maxi(best_combo, combo)
			last_serve = elapsed
			served += 1
			seat.flash()
			_toast("Combo x%d" % combo if combo > 1 else "Served")
		Customer.State.WANTS_PAY:
			var speed := (c.served_speed + c.patience_fraction()) * 0.5
			var tip := Config.tip_for(c.drink, c.type_key, speed, c.combo_at_serve)
			tips += tip
			c.state = Customer.State.LEAVING
			c.timer = 0.4
			dirty_glasses[index] = c.drink
			seat.flash()
			_toast("+$%d tip" % int(tip))
		_:
			pass


func _walkout(index: int) -> void:
	var c: Customer = customers[index]
	if c.state == Customer.State.WANTS_PAY:
		dirty_glasses[index] = c.drink
		_toast("Skipped the tab")
	else:
		_toast("Walked out")
	c.state = Customer.State.LEAVING
	c.timer = 0.5
	c.angry = true
	walkouts += 1
	combo = 0
	if walkouts >= Config.MAX_WALKOUTS and end_delay < 0.0:
		end_delay = 0.9


func _on_drink_pressed(key: String) -> void:
	if not running:
		return
	if not prep.is_empty():
		_toast("Still busy")
		return
	if hand.size() >= Config.HAND_MAX:
		_toast("Hands full — serve something first")
		return
	if int(Config.DRINKS[key]["ice"]) > ice:
		_toast("Out of ice")
		return
	prep = {"kind": "drink", "drink": key, "elapsed": 0.0, "duration": Config.DRINKS[key]["prep"]}


func _on_ice_pressed() -> void:
	if not running:
		return
	if not prep.is_empty():
		_toast("Still busy")
		return
	if ice >= Config.ICE_MAX:
		_toast("Bin is already full")
		return
	prep = {"kind": "ice", "elapsed": 0.0, "duration": Config.ICE_RESTOCK_SECONDS}
	_toast("Scooping ice...")


func _end_shift(reason: String) -> void:
	running = false
	var stars := Config.stars_for(tips, walkouts)
	result_label.text = "%s\n\n%s\n\nTips $%d   Served %d   Walkouts %d   Best combo x%d" % [
		reason, "*".repeat(stars), int(tips), served, walkouts, best_combo
	]
	start_button.text = "Work another shift"
	start_panel.visible = true


func _toast(message: String) -> void:
	toast_label.text = message
	toast_timer = 1.6


func _render() -> void:
	tips_label.text = "$%d" % int(tips)
	clock_label.text = Config.clock_text(elapsed)
	walkouts_label.text = "Walkouts %d/%d" % [walkouts, Config.MAX_WALKOUTS]
	banner_label.visible = running and Config.is_rush(elapsed)

	var carried: Array[String] = []
	for key in hand:
		carried.append(Config.DRINKS[key]["label"])
	hand_label.text = "In hand: %s" % (", ".join(carried) if carried.size() > 0 else "empty-handed")

	ice_bar.value = float(ice) / float(Config.ICE_MAX) * 100.0
	prep_bar.value = 0.0 if prep.is_empty() else prep["elapsed"] / prep["duration"] * 100.0

	for i in seat_nodes.size():
		seat_nodes[i].render(customers[i], dirty_glasses[i])
