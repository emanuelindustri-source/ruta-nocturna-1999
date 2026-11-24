class_name WorldSectorData
extends Resource
## Sector de terreno de 800 m (F4.2). Recurso de datos cargado en streaming con
## ResourceLoader.load_threaded_request() desde los sectores horneados.
##
## No contiene mallas ni colisión: WorldSectorBuilder construye la ArrayMesh y
## los ConcavePolygonShape3D en el hilo principal con presupuesto por frame.

@export var format_version: int = 1
@export var sector_x: int = 0
@export var sector_z: int = 0
@export var sector_size_m: float = 800.0
@export var grid_resolution: int = 33
@export var grid_spacing_m: float = 25.0
@export var origin_x: float = 0.0
@export var origin_z: float = 0.0
@export var heights: PackedFloat32Array = PackedFloat32Array()
@export var road_vertices: PackedVector3Array = PackedVector3Array()
@export var marking_vertices: PackedVector3Array = PackedVector3Array()
@export var road_edge_ids: PackedStringArray = PackedStringArray()
@export var road_length_m: float = 0.0
@export var height_min_m: float = 0.0
@export var height_max_m: float = 0.0
@export var terrain_triangle_count: int = 0
@export var road_triangle_count: int = 0
@export var source_attribution: String = "© OpenStreetMap contributors · ODbL 1.0"


func key() -> String:
	return "%d_%d" % [sector_x, sector_z]


func is_valid() -> bool:
	return (
		format_version == 1
		and grid_resolution >= 3
		and heights.size() == grid_resolution * grid_resolution
		and sector_size_m > 0.0
		and road_vertices.size() % 3 == 0
		and marking_vertices.size() % 3 == 0
		and terrain_triangle_count == (grid_resolution - 1) * (grid_resolution - 1) * 2
	)
