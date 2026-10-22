class_name UnlockAllInventory
extends InventoryPort
## Testing (--unlock-all): every catalog item counts as owned for this run.
## Real unlocks still go to the wrapped inventory, so nothing is faked on disk.

var _inner: InventoryPort


func _init(inner: InventoryPort) -> void:
	_inner = inner


func owns(_id: String) -> bool:
	return true


func grant(id: String) -> bool:
	return _inner.grant(id)


func owned_ids() -> Array[String]:
	return Catalog.all_ids()
