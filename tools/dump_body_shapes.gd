extends SceneTree
## Prints every body's outlines as JSON, for tools/make_body_templates.py.
## Run: godot --headless --path . --script tools/dump_body_shapes.gd


func _init() -> void:
	var out := {"box": _rect(BodyShapes.TEXTURE_BOX), "bodies": []}
	for shape in Catalog.base_count("body"):
		var parts: Array = [_points(BodyShapes.outline(shape))]
		if not BodyShapes.bare_arms(shape):  # bare arms are skin, not texture
			for arm in BodyShapes.arms(shape):
				parts.append(_points(arm))
		for leg in BodyShapes.legs(shape):
			parts.append(_points(BodyShapes.rect_points(leg)))
		out["bodies"].append({"name": Catalog.label("body", shape), "parts": parts})
	print("BODY_SHAPES_JSON " + JSON.stringify(out))
	quit()


func _points(pts: PackedVector2Array) -> Array:
	var a := []
	for p in pts:
		a.append([p.x, p.y])
	return a


func _rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]
