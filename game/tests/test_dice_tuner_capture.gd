extends SceneTree

# Launches the test_dice_tuner scene with rendering enabled (X11/opengl3),
# auto-triggers a roll, waits long enough for the spin+land animation to
# complete, captures the viewport to a PNG, and quits.
#
# Usage (inside the export Docker container):
#   Xvfb :99 -screen 0 1470x956x24 &
#   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 \
#       --path /workspace/game -s res://tests/test_dice_tuner_capture.gd

const TUNER_SCENE := preload("res://scenes/test_dice_tuner.tscn")
const CAPTURE_PATH := "/workspace/dist/dice_tuner_textured.png"


func _init() -> void:
	# Defer to main loop so the SceneTree is fully initialized.
	root.ready.connect(_run, CONNECT_ONE_SHOT)


func _initialize() -> void:
	# Called by SceneTree once the engine main loop is up.
	_run()


func _run() -> void:
	_run_async()


func _run_async() -> void:
	var tuner: Node = TUNER_SCENE.instantiate()
	root.add_child(tuner)
	# Wait one process frame so the tuner's _ready builds the overlays.
	await process_frame
	await process_frame

	# Trigger Roll All via the tuner's API.
	if tuner.has_method("_do_roll"):
		tuner._do_roll()
		print("triggered _do_roll")
	else:
		printerr("tuner has no _do_roll method")
		quit(1)
		return

	# Wait long enough for stagger + spin + float-down. Tuner defaults give
	# stagger=0.08, spin=0.3, plus float-down 0.25 → ~0.95s for 4 dice.
	# Pad to 2.0s for safety.
	var seconds := 2.0
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		elapsed += get_root().get_process_delta_time()
		if elapsed <= 0.0:
			# Fallback if delta is zero (paranoid)
			elapsed += 1.0 / 60.0

	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		printerr("could not capture viewport image")
		quit(2)
		return
	var err := img.save_png(CAPTURE_PATH)
	if err != OK:
		printerr("save_png failed: %s" % err)
		quit(3)
		return
	print("saved screenshot to %s" % CAPTURE_PATH)
	quit(0)
