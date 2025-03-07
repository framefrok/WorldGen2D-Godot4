extends TileMap

@export var map_width = 312
@export var map_height = 312
@export var noise_seed = 0
@export var noise_scale = 50.0

# Тайлы (настройте под свои индексы)
enum TILES {
	GRASS = 0,
	SAND = 1,
	WATER = 5,
	FOREST = 2,
	ROAD = 3,
	CITY = 4
}

var noise = FastNoiseLite.new()
var city_noise = FastNoiseLite.new()
var forest_noise = FastNoiseLite.new()
var cities = []

func _ready():
	generate_world()

func generate_world():
	# Настройка основного шума
	noise.seed = noise_seed if noise_seed != 0 else randi()
	noise.frequency = 0.005
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	# Настройка шума для лесов
	forest_noise.seed = randi()
	forest_noise.frequency = 0.03
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	
	# Генерация базовой карты
	for x in range(map_width):
		for y in range(map_height):
			var noise_value = noise.get_noise_2d(x, y)
			
			if noise_value < -0.3:
				set_cell(0, Vector2i(x, y), TILES.WATER, Vector2i(0, 0))
			elif noise_value < 0:
				set_cell(0, Vector2i(x, y), TILES.SAND, Vector2i(0, 0))
			else:
				set_cell(0, Vector2i(x, y), TILES.GRASS, Vector2i(0, 0))
	
	# Генерация лесов
	generate_forests()
	
	# Генерация городов
	generate_cities(10) # 10 городов
	
	# Генерация дорог
	connect_cities()
	
	
func generate_forests():
	var biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = 0.03
	biome_noise.fractal_octaves = 3
	
	var detail_noise = FastNoiseLite.new()
	detail_noise.seed = randi()
	detail_noise.frequency = 0.15
	detail_noise.fractal_octaves = 3
	
	var grass_cells = []
	for x in range(map_width):
		for y in range(map_height):
			if get_cell_source_id(0, Vector2i(x, y)) == TILES.GRASS:
				grass_cells.append(Vector2i(x, y))
	
	for pos in grass_cells:
		var x = pos.x
		var y = pos.y
		
		var base_value = forest_noise.get_noise_2d(x * 2, y * 2) * 1.2
		var biome_value = biome_noise.get_noise_2d(x * 0.8, y * 0.8)
		var detail_value = detail_noise.get_noise_2d(x * 4, y * 4) * 0.4
		
		var forest_chance = remap(base_value, -1.0, 1.0, 0.0, 1.0)
		var biome_modifier = smoothstep(0.2, 0.8, biome_value)
		var density = clamp(forest_chance * biome_modifier + detail_value, 0.0, 1.0)
		
		var water_neighbors = 0
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var neighbor_pos = Vector2i(x + dx, y + dy)
				if get_cell_source_id(0, neighbor_pos) == TILES.WATER:
					water_neighbors += 1
		
		if density > 0.4 && water_neighbors < 4:
			var variant = randi() % 100
			
			if density > 0.6:
				set_cell(0, pos, TILES.FOREST, Vector2i.ZERO)
			elif density > 0.45 && variant < 85:
				set_cell(0, pos, TILES.FOREST, Vector2i.ZERO)
			elif density > 0.45 && variant < 98:
				set_cell(0, pos, TILES.GRASS, Vector2i.ZERO)
				if x < map_width - 1:
					set_cell(0, pos + Vector2i.RIGHT, TILES.FOREST, Vector2i.ZERO)
		
		elif density > 0.3 && randi() % 100 < 30:
			set_cell(0, pos, TILES.FOREST, Vector2i.ZERO)

func generate_cities(num_cities):
	var rng = RandomNumberGenerator.new()
	var min_distance = 75  # Минимальное расстояние между городами
	
	for _i in num_cities:
		var valid = false
		var attempts = 0
		while not valid and attempts < 100:
			var pos = Vector2i(
				rng.randi_range(100, map_width - 100),
				rng.randi_range(100, map_height - 100)
			)
			
			# Проверяем условия для города
			if is_valid_city_location(pos, min_distance):
				create_city(pos.x, pos.y)
				cities.append(pos)
				valid = true
			attempts += 1

func is_valid_city_location(pos: Vector2i, min_dist: int) -> bool:
	# Проверяем базовые условия
	if get_cell_source_id(0, pos) in [TILES.WATER, TILES.FOREST]:
		return false
	
	# Проверяем расстояние до других городов
	for city in cities:
		if pos.distance_to(city) < min_dist:
			return false
	
	# Проверяем наличие nearby ресурсов (вода/песок)
	var water_tiles = 0
	for dx in range(-30, 30):
		for dy in range(-30, 30):
			var check_pos = pos + Vector2i(dx, dy)
			if get_cell_source_id(0, check_pos) == TILES.WATER:
				water_tiles += 1
	return water_tiles > 10 && water_tiles < 50

func create_city(center_x, center_y):
	var size = randi() % 6 + 6  # Размер города 6-12
	var city_shape = []
	
	# Генерация органичной формы города
	for x in range(center_x - size, center_x + size):
		for y in range(center_y - size, center_y + size):
			var distance = Vector2(x, y).distance_to(Vector2(center_x, center_y))
			var noise_val = noise.get_noise_2d(x, y)
			
			# Плавное уменьшение плотности к краям
			if distance < size * (0.6 + noise_val * 0.2):
				var pos = Vector2i(x, y)
				if get_cell_source_id(0, pos) != TILES.WATER:
					# Центр города более плотный
					if distance < size * 0.3:
						set_cell(0, pos, TILES.CITY, Vector2i(0, 0))
					else:
						# Случайные участки зелени внутри города
						if randi() % 100 < 20:
							set_cell(0, pos, TILES.GRASS, Vector2i(0, 0))
						else:
							set_cell(0, pos, TILES.CITY, Vector2i(0, 0))
	
	# Генерация кольцевой дороги
	generate_ring_road(center_x, center_y, size)

func generate_ring_road(center_x, center_y, size):
	var road_radius = size * 1.2  # Увеличен радиус
	var prev_pos = null
	
	# Генерация более плотного кольца
	for angle in range(0, 360, 2):  # Уменьшен шаг до 2 градусов
		var dir = Vector2.from_angle(deg_to_rad(angle))
		var pos = Vector2(center_x, center_y) + dir * road_radius
		var grid_pos = Vector2i(pos.round())
		
		# Проверка границ и типа местности
		if grid_pos.x < 0 || grid_pos.y < 0: continue
		if grid_pos.x >= map_width || grid_pos.y >= map_height: continue
		if get_cell_source_id(0, grid_pos) == TILES.WATER: continue
		
		# Соединение с предыдущей точкой
		if prev_pos != null:
			var connect_path = _bresenham_line(prev_pos, grid_pos)
			for p in connect_path:
				if get_cell_source_id(0, p) != TILES.WATER:
					set_cell(0, p, TILES.ROAD, Vector2i.ZERO)
		
		# Добавление случайного смещения
		var jitter = Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
		var final_pos = grid_pos + Vector2i(jitter.round())
		set_cell(0, final_pos, TILES.ROAD, Vector2i.ZERO)
		prev_pos = grid_pos

# Вспомогательная функция для рисования линии
func _bresenham_line(start, end):
	var points = []
	var dx = absi(end.x - start.x)
	var dy = -absi(end.y - start.y)
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var err = dx + dy
	
	var x = start.x
	var y = start.y
	
	while true:
		points.append(Vector2i(x, y))
		if x == end.x && y == end.y: break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	
	return points

func connect_cities():
	var center = Vector2(map_width/2, map_height/2)
	cities.sort_custom(func(a, b): return a.distance_to(center) < b.distance_to(center))
	
	# Основные магистрали
	for i in range(cities.size() - 1):
		create_curved_road(cities[i], cities[i + 1], true)
	
	# Дополнительные соединения
	var rng = RandomNumberGenerator.new()
	for i in range(cities.size()):
		for j in range(i + 2, cities.size()):
			if rng.randf() < 0.15:
				create_curved_road(cities[i], cities[j], false)
	
	# Добавляем случайные разветвления
	add_road_branches()

func create_curved_road(start, end, is_main_road):
	var path = find_path_around_water(start, end)
	if path.size() == 0:
		return
	
	# Сглаживание и добавление вариативности
	var smooth_path = []
	for i in range(path.size() - 1):
		var current = path[i]
		var next = path[i + 1]
		smooth_path.append(current)
		
		# Добавляем изгибы
		if (next - current).length() > 3:
			var dir = (next - current).normalized()
			var offset = Vector2(-dir.y, dir.x) * (randf() * 4 - 2)
			smooth_path.append((current + next) / 2 + offset)
	
	smooth_path.append(path[-1])
	
	# Прокладка дороги
	for pos in smooth_path:
		place_road_tile(pos, is_main_road)
	
	# Добавляем ответвления
	if is_main_road && randi() % 100 < 30:
		add_side_branch(smooth_path)

func find_path_around_water(start, end):
	var open_list = []
	var closed_list = {}
	var start_node = {pos = start, g = 0, h = start.distance_to(end), parent = null}
	open_list.append(start_node)
	
	while open_list.size() > 0:
		open_list.sort_custom(func(a, b): return (a.g + a.h) < (b.g + b.h))
		var current = open_list.pop_front()
		
		if current.pos.distance_to(end) < 10:
			return reconstruct_path(current)
		
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor_pos = current.pos + Vector2i(dx, dy)
				if neighbor_pos in closed_list:
					continue
				
				if neighbor_pos.x < 0 || neighbor_pos.y < 0 || neighbor_pos.x >= map_width || neighbor_pos.y >= map_height:
					continue
				
				# Исправленный тернарный оператор
				var water_penalty = 100 if get_cell_source_id(0, neighbor_pos) == TILES.WATER else 0
				var move_cost = 1 + water_penalty + (abs(dx) + abs(dy) - 1) * 0.5
				
				var neighbor_node = {
					pos = neighbor_pos,
					g = current.g + move_cost,
					h = neighbor_pos.distance_to(end),
					parent = current
				}
				
				open_list.append(neighbor_node)
				closed_list[neighbor_pos] = true
	
	return []

func reconstruct_path(node):
	var path = []
	while node != null:
		path.append(node.pos)
		node = node.parent
	path.reverse()
	return path

func place_road_tile(pos, is_main_road):
	if get_cell_source_id(0, pos) == TILES.WATER:
		return
	
	set_cell(0, pos, TILES.ROAD, Vector2i.ZERO)
	
	if is_main_road:
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = pos + dir
			if randf() < 0.3 && get_cell_source_id(0, neighbor) in [TILES.GRASS, TILES.SAND]:
				set_cell(0, neighbor, TILES.ROAD, Vector2i.ZERO)

func add_side_branch(main_path):
	var rng = RandomNumberGenerator.new()
	var branch_start = main_path[rng.randi_range(main_path.size()/4, main_path.size()*3/4)]
	var direction = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	
	for _i in range(20):
		branch_start += Vector2i(direction * 3)
		if branch_start.x < 0 || branch_start.y < 0 || branch_start.x >= map_width || branch_start.y >= map_height:
			break
		place_road_tile(branch_start, false)
		direction = direction.rotated(rng.randf_range(-0.5, 0.5))

func add_road_branches():
	var rng = RandomNumberGenerator.new()
	for _i in range(10):
		var start = Vector2i(rng.randi_range(50, map_width-50), rng.randi_range(50, map_height-50))
		if get_cell_source_id(0, start) == TILES.ROAD:
			add_side_branch([start])
