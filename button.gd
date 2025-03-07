extends Button

@export var tilemap: TileMap
@export var max_image_size = 32768
@export var padding = 10

func _ready():
	pressed.connect(save_map)

func save_map():
	if !is_instance_valid(tilemap):
		push_error("TileMap is invalid!")
		return
	
	if !tilemap.tile_set:
		push_error("TileSet not assigned in TileMap!")
		return
	
	var used_rect = tilemap.get_used_rect()
	if used_rect.size.x == 0 or used_rect.size.y == 0:
		push_error("Map is empty!")
		return
	
	var tile_size = Vector2(tilemap.tile_set.tile_size)
	var map_pixel_size = Vector2(
		(used_rect.size.x * tile_size.x) + padding * 2,
		(used_rect.size.y * tile_size.y) + padding * 2
	)
	
	if map_pixel_size.x > max_image_size or map_pixel_size.y > max_image_size:
		push_error("Map size exceeds limit: ", map_pixel_size)
		return
	
	var dir = DirAccess.open("user://")
	if dir.make_dir_recursive("MapResult") != OK:
		push_error("Failed to create directory!")
		return
	
	var viewport = SubViewport.new()
	viewport.size = map_pixel_size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	var map_copy = tilemap.duplicate()
	# Исправление умножения векторов
	map_copy.position = -Vector2(used_rect.position) * tile_size + Vector2(padding, padding)
	viewport.add_child(map_copy)
	
	get_tree().root.add_child(viewport)
	
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = viewport.get_texture().get_image()
	if img.is_empty():
		push_error("Failed to capture image!")
		viewport.queue_free()
		return
	
	img = crop_transparent_borders(img)
	var file_path = "user://MapResult/map_%s.png" % Time.get_datetime_string_from_system().replace(":", "_")
	
	match img.save_png(file_path):
		OK:
			print("Map saved successfully to: ", ProjectSettings.globalize_path(file_path))
		var err:
			push_error("Failed to save image with error code: ", err)
	
	viewport.queue_free()

func crop_transparent_borders(img: Image) -> Image:
	var rect = img.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return img
	
	var cropped = Image.create(rect.size.x, rect.size.y, false, img.get_format())
	cropped.blit_rect(img, rect, Vector2i.ZERO)
	return cropped
