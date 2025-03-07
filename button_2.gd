# Скрипт для кнопки
extends Button

@export var world_generator: TileMap

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	if world_generator:
		world_generator._ready()
	else:
		push_error("World Generator not assigned!")
