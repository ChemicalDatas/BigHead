class_name LocalInventory
extends InventoryPort
## Owned items in user://inventory.json. A new player starts with
## Catalog.starting_items(): the starting set, with random body styles.
## Local only: no trading, so nothing else needs to trust it.

const PATH := "user://inventory.json"

var _owned := {}


func _init() -> void:
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary and data.get("owned") is Array:
			for id in data["owned"]:
				_owned[str(id)] = true
			return
		push_warning("Inventory file is unreadable; starting from the starting set.")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for id in Catalog.starting_items(rng):
		_owned[id] = true
	_save()


func owns(id: String) -> bool:
	return _owned.has(id)


func grant(id: String) -> bool:
	if _owned.has(id):
		return false
	_owned[id] = true
	_save()
	return true


func owned_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _owned:
		ids.append(id)
	return ids


static func erase() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _save() -> void:
	var ids := owned_ids()
	ids.sort()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"owned": ids}, "\t"))
