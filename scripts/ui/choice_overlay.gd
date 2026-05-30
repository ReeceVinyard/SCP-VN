extends Control

## Full-screen choice UI. Sits on UILayers.CHOICES CanvasLayer so map characters stay visible behind.

@onready var _dim: ColorRect = %ChoiceDim
@onready var _center: CenterContainer = %ChoiceCenter


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_center.mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
