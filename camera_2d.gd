extends Camera2D

@export var move_speed: float = 1500.0
@export var zoom_speed: float = 0.15
@export var min_zoom: float = 0.3
@export var max_zoom: float = 100.0

var _target_zoom := Vector2.ONE

func _ready():
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	make_current()
	zoom = _target_zoom

func _process(delta):
	handle_movement(delta)
	handle_zoom()

func handle_movement(delta):
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += input.normalized() * move_speed * delta

func handle_zoom():
	var zoom_direction = 0
	if Input.is_action_just_released("ui_zoom_in"):
		zoom_direction -= 1
	if Input.is_action_just_released("ui_zoom_out"):
		zoom_direction += 1
	
	if zoom_direction != 0:
		_target_zoom *= (1.0 + zoom_direction * zoom_speed)
		_target_zoom = _target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		zoom = _target_zoom

func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			var zoom_factor = 1.0 + (-event.factor * 0.1 * zoom_speed)
			
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom *= zoom_factor
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom /= zoom_factor
			
			_target_zoom = _target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			zoom = _target_zoom
