extends CanvasLayer
## This layer keeps processing while the game, timers, tweens and audio pause.
signal begin_requested
signal resume_requested
signal pause_requested
signal abort_requested
signal quit_requested
signal skip_cutscene_requested
signal sensitivity_changed(value: float)

enum Mode { MAIN, PLAYING, PAUSE, TRANSITION }
const SETTINGS_PATH := "user://settings.cfg"
@export var slide_duration := 0.4
@export var fade_duration := 1.2
var sensitivity_value := 5.0
var mode := Mode.TRANSITION
var _animation: Tween
var _fade_animation: Tween
var _master_volume_db := 0.0
var _focused := true
@onready var panel: PanelContainer = $Screen/Menu
@onready var primary: Button = $Screen/Menu/Margin/Items/Primary
@onready var secondary: Button = $Screen/Menu/Margin/Items/Secondary
@onready var skip: Button = $Screen/Menu/Margin/Items/SkipCutscene
@onready var sensitivity: HSlider = $Screen/Menu/Margin/Items/Sensitivity/Slider
@onready var value_label: Label = $Screen/Menu/Margin/Items/Sensitivity/Header/Value
@onready var fade: ColorRect = $Screen/Fade

func _ready() -> void:
	_master_volume_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, -80.0)
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		sensitivity_value = clampf(float(settings.get_value("camera", "sensitivity", 5.0)), 1.0, 10.0)
	sensitivity.set_value_no_signal(sensitivity_value)
	value_label.text = str(int(sensitivity_value))
	sensitivity.value_changed.connect(_on_sensitivity_changed)
	primary.pressed.connect(_on_primary_pressed)
	secondary.pressed.connect(_on_secondary_pressed)
	skip.pressed.connect(_on_skip_pressed)
	get_window().focus_exited.connect(_focus_lost)
	get_window().focus_entered.connect(_focus_gained)
	panel.hide()
	fade.modulate.a = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_STOP

func _exit_tree() -> void:
	AudioServer.set_bus_volume_db(0, _master_volume_db)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_lost()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_gained()

func _focus_lost() -> void:
	_focused = false
	request_pause()

func _focus_gained() -> void:
	_focused = true

func _process(_delta: float) -> void:
	# Browser Escape can release pointer lock without delivering a key event.
	if mode == Mode.PLAYING and get_parent().menu_expects_mouse_capture():
		if not _focused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			request_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode == Mode.PLAYING:
			request_pause()
		elif mode == Mode.PAUSE:
			_on_primary_pressed()
		get_viewport().set_input_as_handled()

func show_main() -> void:
	mode = Mode.MAIN
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	primary.text = "Begin"
	secondary.text = "Quit"
	secondary.visible = not OS.has_feature("web")
	skip.hide()
	_slide_in()
	_fade_in()

func request_pause() -> void:
	if mode != Mode.PLAYING:
		return
	mode = Mode.PAUSE
	primary.text = "Resume"
	secondary.text = "Abort"
	secondary.show()
	skip.visible = get_parent().menu_can_skip_cutscene()
	pause_requested.emit()
	_slide_in()

func _slide_in() -> void:
	if _animation != null:
		_animation.kill()
	panel.position.x = -panel.size.x - 48.0
	panel.show()
	_animation = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_property(panel, "position:x", 32.0, slide_duration)
	_animation.tween_callback(primary.grab_focus)

func _on_primary_pressed() -> void:
	if mode not in [Mode.MAIN, Mode.PAUSE] or fade.modulate.a > 0.001:
		return
	var beginning := mode == Mode.MAIN
	mode = Mode.TRANSITION
	# Pointer lock must be requested synchronously inside the user's click on web.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	primary.release_focus()
	if _animation != null:
		_animation.kill()
	_animation = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_animation.tween_property(panel, "position:x", -panel.size.x - 48.0, slide_duration)
	_animation.tween_callback(_finish_primary.bind(beginning))

func _finish_primary(beginning: bool) -> void:
	panel.hide()
	mode = Mode.PLAYING
	if beginning:
		begin_requested.emit()
	else:
		resume_requested.emit()
	if not _focused:
		request_pause()

func _on_skip_pressed() -> void:
	if mode != Mode.PAUSE or not get_parent().menu_can_skip_cutscene():
		return
	mode = Mode.TRANSITION
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skip.release_focus()
	if _animation != null:
		_animation.kill()
	_animation = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_animation.tween_property(panel, "position:x", -panel.size.x - 48.0, slide_duration)
	_animation.tween_callback(_finish_skip)

func _finish_skip() -> void:
	panel.hide()
	skip_cutscene_requested.emit()
	mode = Mode.PLAYING
	resume_requested.emit()
	if not _focused:
		request_pause()

func _on_secondary_pressed() -> void:
	if mode not in [Mode.MAIN, Mode.PAUSE] or fade.modulate.a > 0.001:
		return
	var quitting := mode == Mode.MAIN
	if quitting and OS.has_feature("web"):
		return
	mode = Mode.TRANSITION
	primary.release_focus()
	secondary.release_focus()
	if _animation != null:
		_animation.kill()
	if _fade_animation != null:
		_fade_animation.kill()
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_animation = create_tween().set_parallel(true)
	_fade_animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_animation.tween_property(fade, "modulate:a", 1.0, fade_duration)
	_fade_animation.tween_method(_set_master_volume, AudioServer.get_bus_volume_db(0), -80.0, fade_duration)
	_fade_animation.chain().tween_callback(_finish_fade_out.bind(quitting))

func _finish_fade_out(quitting: bool) -> void:
	panel.hide()
	if quitting:
		quit_requested.emit()
	else:
		abort_requested.emit()

func _fade_in() -> void:
	if _fade_animation != null:
		_fade_animation.kill()
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_animation = create_tween().set_parallel(true)
	_fade_animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_animation.tween_property(fade, "modulate:a", 0.0, fade_duration)
	_fade_animation.tween_method(_set_master_volume, AudioServer.get_bus_volume_db(0), _master_volume_db, fade_duration)
	_fade_animation.chain().tween_callback(_finish_fade_in)

func _finish_fade_in() -> void:
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_master_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(0, volume)

func _on_sensitivity_changed(value: float) -> void:
	sensitivity_value = value
	value_label.text = str(int(value))
	sensitivity_changed.emit(value)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("camera", "sensitivity", value)
	settings.save(SETTINGS_PATH)
