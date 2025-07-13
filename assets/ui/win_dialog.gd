extends CanvasLayer

signal next_level_pressed
signal menu_pressed
@onready var next_button = $Control/MarginContainer/Panel/VBoxContainer/ButtonNext
@onready var menu_button = $Control/MarginContainer/Panel/VBoxContainer/ButtonMenu
@onready var panel = $Control/MarginContainer/Panel
@onready var title = $Control/MarginContainer/Panel/VBoxContainer/Title
var buttons: Array[Button] = []
var current_button_index: int = 0

func _ready():
	_show_victory_text()
	panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	buttons = [next_button, menu_button]
	for button in buttons:
		if button is Button:
			if not button.is_connected("pressed", Callable(self, "_on_button_pressed").bind(button)):
				button.connect("pressed", Callable(self, "_on_button_pressed").bind(button))
			if not button.is_connected("focus_entered", Callable(self, "_on_button_focused").bind(button)):
				button.connect("focus_entered", Callable(self, "_on_button_focused").bind(button))
	set_initial_focus()
	monitor_gamepad_connection()

func monitor_gamepad_connection():
	if not Input.is_connected("joy_connection_changed", Callable(self, "_on_joy_connection_changed")):
		Input.connect("joy_connection_changed", Callable(self, "_on_joy_connection_changed"))
	var devices = Input.get_connected_joypads()
	if devices.size() > 0:
		print("Обнаружен геймпад: ", Input.get_joy_name(devices[0]))
	else:
		print("Геймпад не подключён")

func _on_joy_connection_changed(device: int, connected: bool):
	if connected:
		print("Геймпад подключён: ", Input.get_joy_name(device))
		set_initial_focus()
	else:
		print("Геймпад отключён: ", device)

func set_initial_focus():
	if buttons.size() > 0 and buttons[0] is Button:
		current_button_index = 0
		buttons[current_button_index].grab_focus()
		print("Фокус установлен на ", buttons[current_button_index].name)
	else:
		push_error("Кнопки не найдены или не являются Button")

func _input(event: InputEvent):
	if not visible:
		return
	var viewport = get_viewport()
	if not viewport:
		return
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_DPAD_DOWN and event.pressed:
			_move_focus(1)
			viewport.set_input_as_handled()
		elif event.button_index == JOY_BUTTON_DPAD_UP and event.pressed:
			_move_focus(-1)
			viewport.set_input_as_handled()
		elif event.button_index == JOY_BUTTON_A and event.pressed:
			_on_button_pressed(buttons[current_button_index])
			viewport.set_input_as_handled()
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_Y:
			var axis_value = event.axis_value
			if axis_value > 0.5:
				_move_focus(1)
				viewport.set_input_as_handled()
			elif axis_value < -0.5:
				_move_focus(-1)
				viewport.set_input_as_handled()

func _move_focus(direction: int):
	var new_index = (current_button_index + direction) % buttons.size()
	if new_index < 0:
		new_index += buttons.size()
	current_button_index = new_index
	if buttons[current_button_index] is Button:
		buttons[current_button_index].grab_focus()
		print("Фокус перемещён на ", buttons[current_button_index].name)

func _on_button_pressed(button: Button):
	if button == next_button:
		_on_button_next_pressed()
	elif button == menu_button:
		_on_button_menu_pressed()

func _on_button_next_pressed() -> void:
	print("Next button pressed")
	next_level_pressed.emit()
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(Callable(self, "queue_free"))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_button_menu_pressed() -> void:
	print("Menu button pressed")
	menu_pressed.emit()
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(Callable(self, "queue_free"))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_button_focused(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func open_dialog():
	visible = true
	_show_victory_text()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_initial_focus()

func _show_victory_text() -> void:
	var score = Global.get_current_layer() if Global.has_method("get_current_layer") else 0
	title.text = "🏆 VICTORY! SCORE: " + str(score) + " 🏆"

func _on_touch_screen_button_next_pressed() -> void:
	_on_button_next_pressed()
	
func _on_touch_screen_button_menu_pressed() -> void:
	_on_button_menu_pressed()
