class_name AlarmRow
extends PanelContainer

signal changed
signal delete_requested(row: AlarmRow)

@onready var drag_handle: DragHandle = $HBox/DragHandle
@onready var hour_spin: SpinBox = $HBox/HourSpin
@onready var minute_spin: SpinBox = $HBox/MinuteSpin
@onready var ampm_option: OptionButton = $HBox/AmPmOption
@onready var name_edit: LineEdit = $HBox/NameEdit
@onready var enabled_toggle: CheckButton = $HBox/EnabledToggle
@onready var delete_button: Button = $HBox/DeleteButton

func _ready() -> void:
	hour_spin.value_changed.connect(func(_v): changed.emit())
	minute_spin.value_changed.connect(func(_v): changed.emit())
	ampm_option.item_selected.connect(func(_i): changed.emit())
	name_edit.text_changed.connect(func(_t): changed.emit())
	enabled_toggle.toggled.connect(func(_p): changed.emit())
	delete_button.pressed.connect(func(): delete_requested.emit(self))
	
	drag_handle.row = self
	drag_handle.token = &"alarm"
	
	name_edit.focus_entered.connect(func(): set_process_input(true))
	name_edit.focus_exited.connect(func(): set_process_input(false))
	set_process_input(false)                  # 평소엔 _input 처리 안 함

# Data -> UI
func setup(alarm: Alarm) -> void:
	var h12 := alarm.hour % 12
	if h12 == 0:
		h12 = 12
	hour_spin.value = h12
	minute_spin.value = alarm.minute
	ampm_option.select(1 if alarm.hour >= 12 else 0)
	name_edit.text = alarm.label
	enabled_toggle.button_pressed = alarm.enabled
	
# UI -> Data
func get_data() -> Alarm:
	var a := Alarm.new()
	a.hour = int(hour_spin.value) % 12
	if ampm_option.selected == 1:    # PM
		a.hour += 12
	a.minute = int(minute_spin.value)
	a.enabled = enabled_toggle.button_pressed
	a.label = name_edit.text
	return a
