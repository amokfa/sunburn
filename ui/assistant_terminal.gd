extends CanvasLayer
## Append messages or play a sequence. Each finished message waits for left click.
signal message_finished(index: int)
signal dialogue_finished

@export var animation_duration := 0.4
@export var characters_per_second := 30.0
@export var scroll_duration := 0.35
@export_multiline var sample_text := "The quick brown fox jumps over the lazy dog."
const COLLAPSED_SIZE := Vector2(12.0, 12.0)
var _is_open := false
var _animation: Tween
var _queue: Array = []
var _index := -1
var _typing: RichTextLabel
var _typed_characters := 0.0
var _waiting := false
var _progress_blocked := false
var _scroll_animation: Tween
var _scroll_pending := false
var _scroll_target := 0.0
var _message_rows: Array[HBoxContainer] = []
@onready var _panel: Panel = $Screen/Window
@onready var _content: MarginContainer = $Screen/Window/Content
@onready var _scroll: ScrollContainer = $Screen/Window/Content/Rows/Scroll
@onready var _messages: VBoxContainer = $Screen/Window/Content/Rows/Scroll/Messages
@onready var _hint: TextureRect = $Screen/ContinueHint
@onready var _bubble_style: StyleBox = preload("res://ui/message_box.tres")


func _ready() -> void:
	_set_window_size(COLLAPSED_SIZE)
	_panel.hide()
	_hint.hide()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_scroll.resized.connect(_resize_messages)
	play_dialogue([{ "speaker": "BX", "text": sample_text }], false)


func _process(delta: float) -> void:
	if not _is_open or _typing == null:
		return
	_typed_characters += delta * characters_per_second
	_typing.visible_characters = int(_typed_characters)
	if _typing.visible_characters >= _typing.get_total_character_count():
		_finish_typing()


func _finish_typing() -> void:
	if _typing == null:
		return
	_typing.visible_characters = -1
	_typing = null
	_waiting = true
	_hint.visible = _is_open and not _progress_blocked
	message_finished.emit(_index)
	_scroll_to_bottom.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _typing != null:
			_finish_typing()
		elif _waiting and not _progress_blocked:
			_waiting = false
			_hint.hide()
			if _index + 1 < _queue.size():
				_next_message()
			else:
				close()
				dialogue_finished.emit()


func play_dialogue(messages: Array, open_window := true, clear_history := true) -> void:
	if _typing != null:
		_typing.visible_characters = -1
	if clear_history:
		if _scroll_animation != null:
			_scroll_animation.kill()
		_scroll.scroll_vertical = 0
		_scroll_target = 0.0
	_typing = null
	_waiting = false
	_progress_blocked = false
	_hint.hide()
	if clear_history:
		for row in _message_rows:
			_messages.remove_child(row)
			row.queue_free()
		_message_rows.clear()
	_queue = messages.duplicate(true)
	_index = -1
	if not _queue.is_empty():
		_next_message()
	if open_window:
		open()


func show_message(message: String, speaker := "BX") -> void:
	_queue.append({ "speaker": speaker, "text": message })
	if _typing == null and not _waiting:
		_next_message()
	open()


func set_progress_blocked(blocked: bool) -> void:
	_progress_blocked = blocked
	_hint.visible = _is_open and (_typing != null or (_waiting and not blocked))


func resume_dialogue() -> void:
	set_progress_blocked(false)
	if _waiting and _index + 1 < _queue.size():
		_waiting = false
		_next_message()
		open()


func _next_message() -> void:
	_index += 1
	var entry: Dictionary = _queue[_index]
	var character_message: bool = entry.get("speaker", "BX") == "Lars"
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", _bubble_style)
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if character_message else HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = str(entry.get("text", ""))
	label.visible_characters = 0
	bubble.add_child(label)
	if character_message:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)
	_messages.add_child(row)
	_message_rows.append(row)
	_typing = label
	_typed_characters = 0.0
	_hint.visible = _is_open
	_resize_messages()
	_scroll_to_bottom.call_deferred()


func _resize_messages() -> void:
	var width := maxf(_scroll.size.x - _scroll.get_v_scroll_bar().size.x, 1.0) * 0.75
	for row in _message_rows:
		for child in row.get_children():
			if child is PanelContainer:
				child.custom_minimum_size.x = width
	_scroll_to_bottom.call_deferred()


func _scroll_to_bottom() -> void:
	# Deferred layout must settle before ScrollContainer knows the new content height.
	if _scroll_pending:
		return
	_scroll_pending = true
	await get_tree().process_frame
	_scroll_pending = false
	var bar := _scroll.get_v_scroll_bar()
	var target := maxf(bar.max_value - bar.page, 0.0)
	if is_equal_approx(target, _scroll_target) and _scroll_animation != null and _scroll_animation.is_running():
		return
	if _scroll_animation != null:
		_scroll_animation.kill()
	_scroll_target = target
	if is_equal_approx(float(_scroll.scroll_vertical), target):
		return
	_scroll_animation = create_tween()
	_scroll_animation.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scroll_animation.tween_property(_scroll, "scroll_vertical", int(target), scroll_duration)


func toggle() -> void:
	_animate(not _is_open)


func open() -> void:
	if not _is_open:
		_animate(true)


func close() -> void:
	if _is_open:
		_animate(false)


func _expanded_size() -> Vector2:
	var screen_size: Vector2 = $Screen.size
	return (screen_size * 0.375).max(COLLAPSED_SIZE)


func _set_window_size(value: Vector2) -> void:
	_content.size = _expanded_size()
	# Resize the panel rather than scaling it: the border keeps its width.
	_panel.offset_left = -value.x
	_panel.offset_top = -value.y
	_panel.offset_right = 0.0
	_panel.offset_bottom = 0.0
	_hint.offset_left = -value.x - 40.0
	_hint.offset_right = -value.x - 16.0


func _animate(expanding: bool) -> void:
	if _animation != null:
		_animation.kill()
	_is_open = expanding
	_panel.show()
	_hint.visible = expanding and (_typing != null or (_waiting and not _progress_blocked))
	var target := _expanded_size() if expanding else COLLAPSED_SIZE
	_animation = create_tween()
	_animation.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if expanding else Tween.EASE_IN)
	_animation.tween_method(_set_window_size, _panel.size, target, animation_duration)
	if not expanding:
		_animation.tween_callback(_panel.hide)


func _on_viewport_resized() -> void:
	if _animation != null:
		_animation.kill()
	_set_window_size(_expanded_size() if _is_open else COLLAPSED_SIZE)
	_panel.visible = _is_open
	_hint.visible = _is_open and (_typing != null or (_waiting and not _progress_blocked))
