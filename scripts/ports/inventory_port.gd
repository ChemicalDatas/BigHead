class_name InventoryPort
extends RefCounted
## Which catalog items the player owns. Scenes ask this port; they never read
## the save file directly.


func owns(_id: String) -> bool:
	return false


## Adds an item. Returns true if it was new, false if already owned.
func grant(_id: String) -> bool:
	return false


func owned_ids() -> Array[String]:
	var ids: Array[String] = []
	return ids
