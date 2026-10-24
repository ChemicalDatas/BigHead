extends Node
## Stages the store screenshots and saves them at the window's size.
## Development builds only. Run with a throwaway user folder so nothing of
## yours is touched, at 1920 x 1080:
##
##   HOME=/tmp/bighead-shots godot --path . --resolution 1920x1080 -- \
##       --reset --reset-inventory --unlock-all --no-steam --fake-friends=19 --store-screenshots
##
## Built heads only: no Steam avatar pop, so the screenshots never spoil it.
## Output: steam/screenshots/NN_name.png

const OUT_DIR := "res://steam/screenshots/"

var _shot := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	# Customize
	var builder := await _scene_with_method("_on_done")
	var b: HeadBuild = builder._build
	b.player_name = "Sam"
	builder._name_edit.text = "Sam"
	b.face_shape = 1
	b.hair = 3
	b.hair_color = Color("#b5532d")
	b.eyes = 1
	b.mouth = 1
	b.accessory = 5
	b.accessory_variant = 1
	b.body_shape = 3
	b.body_variant = 1
	builder._refresh_all()
	builder._layout()
	await _wait(0.6)
	await _save("customize")
	builder._on_done()

	# The playground, after the reveal
	var game := await _playground()
	await _wait(1.5)
	_set_background(game, 0)
	game.launch_fireworks(Vector2(520, 230))
	await _wait(0.35)
	game.launch_fireworks(Vector2(780, 260))
	await _wait(0.95)
	await _save("fireworks")

	# Shelves, gifts and confetti
	await _wait(2.5)
	_set_background(game, 4)
	var ids := ["accessory/crown/1", "body/hoodie/2", "hair/mohawk", "accessory/party_hat/3", "body/goat/3",
		"face_shape/square", "accessory/glasses/1", "body/robe/3", "eyes/angry", "accessory/unicorn_horn/0"]
	for i in ids.size():
		game._spawn_gift(ids[i], ids[i].begins_with("accessory/unicorn"), Vector2(400, 0), true)
	game._burst_confetti(Vector2(640, 260), 120)
	await _wait(0.9)
	await _save("gifts_and_shelves")
	for child in game._drops.get_children():
		child.queue_free()

	# The unicorn set
	var u: HeadBuild = game._head.build
	u.face_shape = 4
	u.hair = 5
	u.accessory = 6
	u.accessory_variant = 0
	u.body_shape = 5
	u.body_variant = 0
	game._layout()
	_set_background(game, 1)
	await _wait(1.0)
	game.launch_fireworks(Vector2(640, 200))
	await _wait(1.05)
	await _save("unicorn")

	# Balloon, caught mid-pop
	u.face_shape = 1
	u.hair = 2
	u.accessory = 3
	u.body_shape = 1
	u.body_variant = 2
	u.rig = HeadView.BALLOON_RIG
	_set_background(game, 2)
	await _wait(2.5)
	game._layout()
	var head: HeadView = game._head
	# Leftover rockets pop balloons: wait for a clear sky and a full balloon.
	while not game._fireworks.rocket_positions().is_empty() or head._balloon != HeadView.Balloon.INFLATED:
		await get_tree().process_frame
	await _wait(0.5)
	head.pop_balloon(head.head_center() + Vector2(0.5, -0.85) * head.radius(), "screenshot")
	while head._balloon != HeadView.Balloon.POPPING:
		await get_tree().process_frame
	# Freeze the tear a third of the way through (slow machines skip past it).
	head.set_process(false)
	head._balloon_t = HeadView.POP_SECONDS * 0.4
	head.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("balloon_pop")
	head.set_process(true)

	# Marionette, swinging
	u.rig = HeadView.MARIONETTE_RIG
	u.accessory = 2
	u.body_shape = 2
	_set_background(game, 3)
	await _wait(1.0)
	game._layout()
	await _wait(0.5)
	var puppet: MarionetteState = head._puppet
	puppet.dragging = true
	var t := 0.0
	while t < 1.6:
		t += get_process_delta_time()
		puppet.drag_target = Vector2(sin(t * 3.2) * 150.0, -120.0 * minf(t / 0.5, 1.0))
		await get_tree().process_frame
	await _save("marionette")
	puppet.dragging = false

	print("[screenshots] Saved %d screenshots to %s" % [_shot, OUT_DIR])
	get_tree().quit()


func _set_background(game: Node, index: int) -> void:
	game._background.style.background = index
	game._background.queue_redraw()


func _save(name: String) -> void:
	await get_tree().process_frame
	_shot += 1
	var path := OUT_DIR + "%02d_%s.png" % [_shot, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[screenshots] %s" % path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _scene_with_method(method: String) -> Node:
	while true:
		var scene := get_tree().current_scene
		if scene != null and scene.has_method(method):
			await _wait(0.5)
			return scene
		await get_tree().process_frame
	return null


func _playground() -> Node:
	while true:
		var scene := get_tree().current_scene
		if scene != null and "_playground" in scene and scene._playground:
			return scene
		await get_tree().process_frame
	return null
