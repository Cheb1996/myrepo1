extends Node3D

const BALL_RADIUS := 0.72
const BASE_FORCE := 22.0
const BASE_TORQUE := 10.5
const JOYSTICK_RADIUS := 125.0
const RESPAWN_DELAY := 0.35

var ball: RigidBody3D
var ball_mesh: MeshInstance3D
var follow_camera: Camera3D
var hud_speed: Label
var hud_checkpoint: Label
var hud_time: Label
var hud_message: Label
var stick_base: Panel
var stick_knob: Panel

var checkpoint_positions: Array[Vector3] = []
var current_checkpoint := 0
var elapsed_time := 0.0
var finished := false
var respawning := false

var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_current := Vector2.ZERO
var mobile_input := Vector2.ZERO

var move_force_multiplier := 1.0
var torque_multiplier := 1.0
var ball_mode := "BALANCED"

var moving_platform: AnimatableBody3D
var moving_platform_origin := Vector3.ZERO
var sweeper: AnimatableBody3D
var level_time := 0.0

var mat_floor: StandardMaterial3D
var mat_floor_alt: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_checkpoint: StandardMaterial3D
var mat_goal: StandardMaterial3D
var mat_ball_balanced: StandardMaterial3D
var mat_ball_light: StandardMaterial3D
var mat_ball_heavy: StandardMaterial3D

func _ready() -> void:
    _make_materials()
    _setup_environment()
    _build_level()
    _create_ball()
    _create_camera()
    _create_ui()
    checkpoint_positions = [
        Vector3(0, 2.2, 2.0),
        Vector3(0, 2.2, -20.0),
        Vector3(0, 6.2, -42.0),
        Vector3(-2.4, 6.2, -58.0),
        Vector3(0, 6.2, -78.0)
    ]
    _set_checkpoint(0, false)
    set_process_input(true)

func _make_materials() -> void:
    mat_floor = _material(Color("#b18b5b"), 0.82, 0.0)
    mat_floor_alt = _material(Color("#7b8f72"), 0.88, 0.0)
    mat_dark = _material(Color("#303845"), 0.92, 0.0)
    mat_checkpoint = _material(Color("#48c6e8"), 0.45, 0.12)
    mat_goal = _material(Color("#ffd45a"), 0.3, 0.25)
    mat_ball_balanced = _material(Color("#d49a62"), 0.58, 0.02)
    mat_ball_light = _material(Color("#d8edf3"), 0.42, 0.08)
    mat_ball_heavy = _material(Color("#656d78"), 0.9, 0.0)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func _setup_environment() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#8bb2c7")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#cfe0e7")
    env.ambient_light_energy = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
    add_child(sun)

func _build_level() -> void:
    _static_box(Vector3(0, 0, 2), Vector3(9, 1, 11), Vector3.ZERO, mat_floor)
    _static_box(Vector3(0, 0, -8.5), Vector3(3.2, 1, 10), Vector3.ZERO, mat_floor_alt)
    _static_box(Vector3(0, 0, -18.0), Vector3(8, 1, 9), Vector3.ZERO, mat_floor)

    _static_box(Vector3(0, 1.7, -27.0), Vector3(5.2, 0.9, 11.5), Vector3(18, 0, 0), mat_floor_alt)
    _static_box(Vector3(0, 4.0, -37.0), Vector3(8.5, 1, 9.0), Vector3.ZERO, mat_floor)

    _static_box(Vector3(2.2, 4.0, -47.0), Vector3(3.2, 1, 10), Vector3(0, -18, 0), mat_floor_alt)
    _static_box(Vector3(-2.2, 4.0, -56.0), Vector3(3.0, 1, 10), Vector3(0, 18, 0), mat_floor)
    _static_box(Vector3(-2.0, 4.0, -63.0), Vector3(4.2, 1, 5.0), Vector3.ZERO, mat_floor_alt)

    moving_platform_origin = Vector3(0, 4.0, -68.7)
    moving_platform = _anim_box(moving_platform_origin, Vector3(4.6, 0.9, 5.2), mat_checkpoint)
    _static_box(Vector3(0, 4.0, -74.0), Vector3(7.5, 1, 5.0), Vector3.ZERO, mat_floor)
    _static_box(Vector3(0, 4.0, -81.0), Vector3(8.5, 1, 9.0), Vector3.ZERO, mat_floor_alt)
    _static_box(Vector3(0, 4.0, -90.0), Vector3(10.0, 1, 9.0), Vector3.ZERO, mat_floor)

    sweeper = _anim_box(Vector3(0, 5.1, -80.0), Vector3(8.0, 0.55, 0.65), mat_dark)

    for p in [Vector3(-5, 2.5, -18), Vector3(5, 2.5, -18), Vector3(-5, 6.5, -38), Vector3(5, 6.5, -38), Vector3(-6, 6.5, -90), Vector3(6, 6.5, -90)]:
        _static_box(p, Vector3(1.1, 6, 1.1), Vector3.ZERO, mat_dark)

    _checkpoint_gate(Vector3(0, 1.3, -20), 1)
    _checkpoint_gate(Vector3(0, 5.3, -42), 2)
    _checkpoint_gate(Vector3(-2.2, 5.3, -58), 3)
    _checkpoint_gate(Vector3(0, 5.3, -78), 4)
    _goal_gate(Vector3(0, 5.3, -92.0))

    var kill_area := Area3D.new()
    kill_area.position = Vector3(0, -9, -45)
    var kill_shape := CollisionShape3D.new()
    var kill_box := BoxShape3D.new()
    kill_box.size = Vector3(180, 2, 220)
    kill_shape.shape = kill_box
    kill_area.add_child(kill_shape)
    kill_area.body_entered.connect(_on_kill_body_entered)
    add_child(kill_area)

func _static_box(pos: Vector3, size: Vector3, rot_deg: Vector3, material: Material) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    body.rotation_degrees = rot_deg

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    var physics_mat := PhysicsMaterial.new()
    physics_mat.friction = 1.25
    physics_mat.bounce = 0.02
    body.physics_material_override = physics_mat
    add_child(body)
    return body

func _anim_box(pos: Vector3, size: Vector3, material: Material) -> AnimatableBody3D:
    var body := AnimatableBody3D.new()
    body.position = pos

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    return body

func _checkpoint_gate(pos: Vector3, index: int) -> void:
    _static_box(pos + Vector3(-2.6, 1.6, 0), Vector3(0.35, 3.2, 0.35), Vector3.ZERO, mat_checkpoint)
    _static_box(pos + Vector3(2.6, 1.6, 0), Vector3(0.35, 3.2, 0.35), Vector3.ZERO, mat_checkpoint)
    _static_box(pos + Vector3(0, 3.0, 0), Vector3(5.55, 0.35, 0.35), Vector3.ZERO, mat_checkpoint)

    var area := Area3D.new()
    area.position = pos + Vector3(0, 1.2, 0)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(5.0, 2.8, 1.6)
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_checkpoint_entered.bind(index))
    add_child(area)

func _goal_gate(pos: Vector3) -> void:
    _static_box(pos + Vector3(-3.0, 1.7, 0), Vector3(0.45, 3.4, 0.45), Vector3.ZERO, mat_goal)
    _static_box(pos + Vector3(3.0, 1.7, 0), Vector3(0.45, 3.4, 0.45), Vector3.ZERO, mat_goal)
    _static_box(pos + Vector3(0, 3.2, 0), Vector3(6.4, 0.45, 0.45), Vector3.ZERO, mat_goal)

    var area := Area3D.new()
    area.position = pos + Vector3(0, 1.2, 0)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(5.6, 3.0, 2.0)
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_goal_entered)
    add_child(area)

func _create_ball() -> void:
    ball = RigidBody3D.new()
    ball.position = Vector3(0, 2.2, 2.0)
    ball.mass = 1.25
    ball.linear_damp = 0.32
    ball.angular_damp = 0.28
    ball.continuous_cd = true
    ball.max_contacts_reported = 8
    ball.contact_monitor = true

    var physics_mat := PhysicsMaterial.new()
    physics_mat.friction = 1.25
    physics_mat.bounce = 0.08
    ball.physics_material_override = physics_mat

    ball_mesh = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = BALL_RADIUS
    sphere.height = BALL_RADIUS * 2.0
    sphere.radial_segments = 32
    sphere.rings = 16
    sphere.material = mat_ball_balanced
    ball_mesh.mesh = sphere
    ball.add_child(ball_mesh)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = BALL_RADIUS
    collision.shape = shape
    ball.add_child(collision)
    add_child(ball)

func _create_camera() -> void:
    follow_camera = Camera3D.new()
    follow_camera.fov = 68.0
    follow_camera.near = 0.12
    follow_camera.far = 180.0
    follow_camera.current = true
    follow_camera.position = Vector3(0, 8.5, 13.5)
    add_child(follow_camera)

func _create_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.add_child(root)

    var title := Label.new()
    title.text = "ROLLING BALANCE 16"
    title.position = Vector2(28, 22)
    title.add_theme_font_size_override("font_size", 30)
    root.add_child(title)

    hud_checkpoint = Label.new()
    hud_checkpoint.position = Vector2(30, 68)
    hud_checkpoint.add_theme_font_size_override("font_size", 22)
    root.add_child(hud_checkpoint)

    hud_speed = Label.new()
    hud_speed.position = Vector2(30, 98)
    hud_speed.add_theme_font_size_override("font_size", 22)
    root.add_child(hud_speed)

    hud_time = Label.new()
    hud_time.position = Vector2(30, 128)
    hud_time.add_theme_font_size_override("font_size", 22)
    root.add_child(hud_time)

    hud_message = Label.new()
    hud_message.text = "Reach the golden gate"
    hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_message.add_theme_font_size_override("font_size", 27)
    hud_message.set_anchors_preset(Control.PRESET_TOP_WIDE)
    hud_message.offset_top = 22
    hud_message.offset_left = 430
    hud_message.offset_right = -430
    root.add_child(hud_message)

    stick_base = Panel.new()
    stick_base.size = Vector2(190, 190)
    stick_base.position = Vector2(65, 810)
    stick_base.modulate = Color(1, 1, 1, 0.18)
    stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(stick_base)

    stick_knob = Panel.new()
    stick_knob.size = Vector2(78, 78)
    stick_knob.position = stick_base.position + Vector2(56, 56)
    stick_knob.modulate = Color(1, 1, 1, 0.38)
    stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(stick_knob)

    var reset_button := Button.new()
    reset_button.text = "RESPAWN"
    reset_button.size = Vector2(190, 72)
    reset_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    reset_button.position = Vector2(-235, -115)
    reset_button.add_theme_font_size_override("font_size", 21)
    reset_button.pressed.connect(_respawn)
    root.add_child(reset_button)

    var modes := HBoxContainer.new()
    modes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    modes.position = Vector2(-510, 32)
    modes.add_theme_constant_override("separation", 8)
    root.add_child(modes)

    var light_btn := Button.new()
    light_btn.text = "LIGHT"
    light_btn.custom_minimum_size = Vector2(135, 56)
    light_btn.pressed.connect(_set_ball_mode.bind("LIGHT"))
    modes.add_child(light_btn)

    var balanced_btn := Button.new()
    balanced_btn.text = "BALANCED"
    balanced_btn.custom_minimum_size = Vector2(155, 56)
    balanced_btn.pressed.connect(_set_ball_mode.bind("BALANCED"))
    modes.add_child(balanced_btn)

    var heavy_btn := Button.new()
    heavy_btn.text = "HEAVY"
    heavy_btn.custom_minimum_size = Vector2(135, 56)
    heavy_btn.pressed.connect(_set_ball_mode.bind("HEAVY"))
    modes.add_child(heavy_btn)

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and key.keycode == KEY_R:
            _respawn()
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        var viewport_size := get_viewport().get_visible_rect().size
        if touch.pressed and touch.position.x < viewport_size.x * 0.58 and touch_id == -1:
            touch_id = touch.index
            touch_origin = touch.position
            touch_current = touch.position
            _update_mobile_stick()
        elif not touch.pressed and touch.index == touch_id:
            touch_id = -1
            mobile_input = Vector2.ZERO
            _reset_stick_visual()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == touch_id:
            touch_current = drag.position
            _update_mobile_stick()

func _update_mobile_stick() -> void:
    var delta := touch_current - touch_origin
    if delta.length() > JOYSTICK_RADIUS:
        delta = delta.normalized() * JOYSTICK_RADIUS
    mobile_input = Vector2(delta.x / JOYSTICK_RADIUS, -delta.y / JOYSTICK_RADIUS)
    var center := stick_base.position + stick_base.size * 0.5 - stick_knob.size * 0.5
    stick_knob.position = center + Vector2(delta.x, delta.y) * 0.55

func _reset_stick_visual() -> void:
    stick_knob.position = stick_base.position + stick_base.size * 0.5 - stick_knob.size * 0.5

func _physics_process(delta: float) -> void:
    if not is_instance_valid(ball):
        return

    if not finished and not respawning:
        var move := _get_move_input()
        if move.length() > 0.05:
            var direction := Vector3(move.x, 0.0, -move.y).normalized()
            ball.apply_central_force(direction * BASE_FORCE * move_force_multiplier * ball.mass)
            ball.apply_torque(Vector3(-direction.z, 0.0, direction.x) * BASE_TORQUE * torque_multiplier * ball.mass)
        else:
            ball.linear_velocity.x *= 0.992
            ball.linear_velocity.z *= 0.992

    level_time += delta
    if not finished:
        elapsed_time += delta

    if is_instance_valid(moving_platform):
        var mp := moving_platform_origin
        mp.x += sin(level_time * 1.15) * 2.7
        moving_platform.position = mp

    if is_instance_valid(sweeper):
        sweeper.rotation.y += delta * 1.35

    if ball.position.y < -13.0 and not respawning:
        _respawn()

    _update_camera(delta)
    _update_hud()

func _get_move_input() -> Vector2:
    var x := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
    var y := (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
    var keyboard := Vector2(x, y)
    if keyboard.length() > 0.05:
        return keyboard.normalized()
    return mobile_input

func _update_camera(delta: float) -> void:
    var velocity_flat := Vector3(ball.linear_velocity.x, 0, ball.linear_velocity.z)
    var behind := Vector3(0, 0, 1)
    if velocity_flat.length() > 1.3:
        behind = -velocity_flat.normalized()
    var desired := ball.global_position + behind * 11.5 + Vector3(0, 7.2, 0)
    follow_camera.global_position = follow_camera.global_position.lerp(desired, clamp(delta * 3.4, 0.0, 1.0))
    follow_camera.look_at(ball.global_position + Vector3(0, 0.45, 0), Vector3.UP)

func _update_hud() -> void:
    var speed := Vector3(ball.linear_velocity.x, 0, ball.linear_velocity.z).length()
    hud_checkpoint.text = "Checkpoint: %d / 4" % current_checkpoint
    hud_speed.text = "Speed: %.1f m/s   Mode: %s" % [speed, ball_mode]
    hud_time.text = "Time: %02d:%05.2f" % [int(elapsed_time / 60.0), fmod(elapsed_time, 60.0)]

func _on_checkpoint_entered(body: Node3D, index: int) -> void:
    if body != ball or finished:
        return
    if index > current_checkpoint:
        _set_checkpoint(index, true)

func _set_checkpoint(index: int, show_message: bool) -> void:
    current_checkpoint = clamp(index, 0, checkpoint_positions.size() - 1)
    if show_message:
        _flash_message("CHECKPOINT %d" % current_checkpoint)

func _on_goal_entered(body: Node3D) -> void:
    if body != ball or finished:
        return
    if current_checkpoint < 4:
        _flash_message("Find all checkpoints first")
        return
    finished = true
    ball.linear_damp = 2.0
    ball.angular_damp = 2.0
    hud_message.text = "FINISH!  %.2f s" % elapsed_time

func _on_kill_body_entered(body: Node3D) -> void:
    if body == ball and not respawning:
        _respawn()

func _respawn() -> void:
    if respawning or not is_instance_valid(ball):
        return
    respawning = true
    _flash_message("RESPAWN")
    await get_tree().create_timer(RESPAWN_DELAY).timeout
    ball.freeze = true
    ball.global_position = checkpoint_positions[current_checkpoint]
    ball.linear_velocity = Vector3.ZERO
    ball.angular_velocity = Vector3.ZERO
    ball.rotation = Vector3.ZERO
    ball.freeze = false
    respawning = false

func _set_ball_mode(mode: String) -> void:
    ball_mode = mode
    match mode:
        "LIGHT":
            ball.mass = 0.65
            move_force_multiplier = 1.16
            torque_multiplier = 1.15
            ball_mesh.material_override = mat_ball_light
        "HEAVY":
            ball.mass = 2.65
            move_force_multiplier = 0.84
            torque_multiplier = 0.82
            ball_mesh.material_override = mat_ball_heavy
        _:
            ball.mass = 1.25
            move_force_multiplier = 1.0
            torque_multiplier = 1.0
            ball_mesh.material_override = mat_ball_balanced
    _flash_message("Mode: %s" % mode)

func _flash_message(text: String) -> void:
    hud_message.text = text
    var token := Time.get_ticks_msec()
    hud_message.set_meta("message_token", token)
    _clear_message_later(token)

func _clear_message_later(token: int) -> void:
    await get_tree().create_timer(1.4).timeout
    if hud_message.get_meta("message_token", -1) == token and not finished:
        hud_message.text = "Reach the golden gate"
