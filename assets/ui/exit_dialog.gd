extends CanvasLayer

signal exit_confirmed
signal exit_cancelled

@onready var confirm_button = $Control/MarginContainer/Panel/VBoxContainer/ButtonConfirm
@onready var cancel_button = $Control/MarginContainer/Panel/VBoxContainer/ButtonCancel
@onready var panel = $Control/MarginContainer/Panel
var buttons: Array[Button] = []
var current_button_index: int = 0

func _ready():
	panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	buttons = [confirm_button, cancel_button]
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
		current_button_index = 1
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
		elif event.button_index == JOY_BUTTON_B and event.pressed:
			_on_cancel_pressed()
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
	if button == confirm_button:
		_on_confirm_pressed()
	elif button == cancel_button:
		_on_cancel_pressed()

func _on_confirm_pressed() -> void:
	emit_signal("exit_confirmed")
	get_tree().quit()

func _on_cancel_pressed() -> void:
	emit_signal("exit_cancelled")
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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_initial_focus()

func _on_touch_screen_button_confirm_pressed() -> void:
	_on_confirm_pressed()
	
func _on_touch_screen_button_cancel_pressed() -> void:
	_on_cancel_pressed()
