extends Node3D

const BALL_RADIUS: float = 0.72
const RESPAWN_DELAY: float = 0.30
const MAX_SPEED: float = 16.5
const CAMERA_DISTANCE: float = 10.8
const CAMERA_HEIGHT: float = 6.8

var ball: RigidBody3D
var ball_mesh: MeshInstance3D
var follow_camera: Camera3D

var ui_root: Control
var hud_panel: Panel
var hud_title: Label
var hud_checkpoint: Label
var hud_speed: Label
var hud_time: Label
var hud_orbs: Label
var hud_message: Label
var stick_base: Panel
var stick_knob: Panel
var respawn_button: Button
var mode_buttons: HBoxContainer
var look_hint: Label

var checkpoint_positions: Array[Vector3] = []
var current_checkpoint: int = 0
var elapsed_time: float = 0.0
var finished: bool = false
var respawning: bool = false
var collected_orbs: int = 0
var total_orbs: int = 0

var move_touch_id: int = -1
var look_touch_id: int = -1
var touch_origin: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO
var mobile_input: Vector2 = Vector2.ZERO
var camera_yaw: float = 0.0
var last_look_time: float = -10.0

var move_force_multiplier: float = 1.0
var torque_multiplier: float = 1.0
var ball_mode: String = "BALANCED"

var moving_platform: AnimatableBody3D
var moving_platform_origin: Vector3 = Vector3.ZERO
var lift_platform: AnimatableBody3D
var lift_origin: Vector3 = Vector3.ZERO
var sweeper: AnimatableBody3D
var sweeper_two: AnimatableBody3D
var level_time: float = 0.0

var mat_wood: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_moss: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_dark_metal: StandardMaterial3D
var mat_checkpoint: StandardMaterial3D
var mat_goal: StandardMaterial3D
var mat_orb: StandardMaterial3D
var mat_ball_balanced: StandardMaterial3D
var mat_ball_light: StandardMaterial3D
var mat_ball_heavy: StandardMaterial3D

func _ready() -> void:
    _setup_environment()
    _make_materials()
    _build_level()
    _create_ball()
    _create_camera()
    _create_ui()

    checkpoint_positions = [
        Vector3(0.0, 2.2, 4.0),
        Vector3(0.0, 2.2, -21.0),
        Vector3(0.0, 6.0, -43.0),
        Vector3(-3.0, 6.0, -62.0),
        Vector3(0.0, 7.1, -85.0)
    ]
    _set_checkpoint(0, false)

    var viewport: Viewport = get_viewport()
    if not viewport.size_changed.is_connected(_layout_ui):
        viewport.size_changed.connect(_layout_ui)
    _layout_ui()
    print("ROLLING_BALANCE_READY")

func _setup_environment() -> void:
    var env: Environment = Environment.new()
    var sky: Sky = Sky.new()
    var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#456f91")
    sky_mat.sky_horizon_color = Color("#c9dde3")
    sky_mat.ground_bottom_color = Color("#25363e")
    sky_mat.ground_horizon_color = Color("#8ba49e")
    sky.sky_material = sky_mat

    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.72
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color("#b7ccd4")
    env.fog_density = 0.005

    var world_env: WorldEnvironment = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
    sun.light_color = Color("#fff1d7")
    sun.light_energy = 1.5
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 115.0
    add_child(sun)

func _make_materials() -> void:
    mat_wood = _textured_material(_make_wood_texture(), Color("#d6aa74"), 0.76, 0.0)
    mat_stone = _textured_material(_make_stone_texture(), Color("#b2b0a5"), 0.92, 0.0)
    mat_moss = _textured_material(_make_moss_texture(), Color("#8aa179"), 0.96, 0.0)
    mat_metal = _textured_material(_make_metal_texture(), Color("#a4adb5"), 0.34, 0.72)
    mat_dark_metal = _textured_material(_make_metal_texture(), Color("#3b4650"), 0.42, 0.80)
    mat_checkpoint = _material(Color("#42c7e8"), 0.28, 0.35, Color("#1689a5"), 1.5)
    mat_goal = _material(Color("#f6c94f"), 0.24, 0.50, Color("#c68b13"), 1.9)
    mat_orb = _material(Color("#8ceeff"), 0.15, 0.25, Color("#36d4ff"), 3.0)
    mat_ball_balanced = _textured_material(_make_ball_texture(Color("#d99657"), Color("#754522")), Color.WHITE, 0.50, 0.05)
    mat_ball_light = _textured_material(_make_ball_texture(Color("#dcecf0"), Color("#93b7c0")), Color.WHITE, 0.38, 0.10)
    mat_ball_heavy = _textured_material(_make_ball_texture(Color("#66717d"), Color("#252c34")), Color.WHITE, 0.30, 0.86)

func _material(color: Color, roughness: float, metallic: float, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    if emission_energy > 0.0:
        material.emission_enabled = true
        material.emission = emission
        material.emission_energy_multiplier = emission_energy
    return material

func _textured_material(texture: Texture2D, tint: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_texture = texture
    material.albedo_color = tint
    material.roughness = roughness
    material.metallic = metallic
    material.uv1_scale = Vector3(2.0, 2.0, 2.0)
    return material

func _make_wood_texture() -> ImageTexture:
    var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var fx: float = float(x)
            var fy: float = float(y)
            var wave: float = sin(fx * 0.20 + sin(fy * 0.11) * 1.7)
            var grain: float = sin(fy * 0.65 + fx * 0.04) * 0.08
            var value: float = 0.88 + wave * 0.08 + grain
            var color: Color = Color(0.63 * value, 0.39 * value, 0.20 * value, 1.0)
            if y % 24 < 2:
                color = color.darkened(0.18)
            img.set_pixel(x, y, color)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_stone_texture() -> ImageTexture:
    var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var cell_x: int = int(float(x) / 16.0)
            var cell_y: int = int(float(y) / 16.0)
            var mortar: bool = (x % 16 < 2) or (y % 16 < 2)
            var noise_value: float = sin(float(x * 17 + y * 31)) * 0.035
            var base_value: float = 0.58 + float((cell_x + cell_y) % 2) * 0.045 + noise_value
            var color: Color = Color(base_value, base_value * 0.98, base_value * 0.92, 1.0)
            if mortar:
                color = Color(0.28, 0.29, 0.29, 1.0)
            img.set_pixel(x, y, color)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_moss_texture() -> ImageTexture:
    var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var fx: float = float(x)
            var fy: float = float(y)
            var noise_value: float = (sin(fx * 0.43) + cos(fy * 0.39) + sin((fx + fy) * 0.17)) / 3.0
            var color: Color = Color(0.24 + noise_value * 0.035, 0.34 + noise_value * 0.05, 0.18 + noise_value * 0.03, 1.0)
            img.set_pixel(x, y, color)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_metal_texture() -> ImageTexture:
    var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var line: bool = (x % 16 < 2) or (y % 16 < 2)
            var scratch: float = absf(sin(float(x * 3 + y * 11))) * 0.06
            var value: float = 0.54 + scratch
            var color: Color = Color(value * 0.88, value * 0.93, value, 1.0)
            if line:
                color = color.darkened(0.28)
            img.set_pixel(x, y, color)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_ball_texture(a: Color, b: Color) -> ImageTexture:
    var img: Image = Image.create(128, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(128):
            var stripe: int = (int(float(x) / 16.0) + int(float(y) / 16.0)) % 2
            var color: Color = a if stripe == 0 else b
            var line: bool = (x % 16 < 2) or (y % 16 < 2)
            if line:
                color = color.darkened(0.22)
            img.set_pixel(x, y, color)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _build_level() -> void:
    _static_box(Vector3(0.0, 0.0, 4.0), Vector3(11.0, 1.0, 12.0), Vector3.ZERO, mat_stone)
    _add_rails(Vector3(0.0, 0.72, 4.0), 11.0, 12.0, false)
    _static_box(Vector3(0.0, 0.0, -8.5), Vector3(3.6, 1.0, 13.0), Vector3.ZERO, mat_wood)
    _static_box(Vector3(0.0, 0.0, -19.5), Vector3(9.0, 1.0, 9.0), Vector3.ZERO, mat_moss)
    _static_box(Vector3(0.0, 1.8, -29.5), Vector3(5.0, 0.9, 13.0), Vector3(18.0, 0.0, 0.0), mat_wood)
    _static_box(Vector3(0.0, 4.0, -40.5), Vector3(9.0, 1.0, 9.5), Vector3.ZERO, mat_stone)
    _add_rails(Vector3(0.0, 4.72, -40.5), 9.0, 9.5, true)
    _static_box(Vector3(2.8, 4.0, -51.0), Vector3(3.2, 1.0, 11.0), Vector3(0.0, -16.0, 0.0), mat_wood)
    _static_box(Vector3(-2.8, 4.0, -61.0), Vector3(3.2, 1.0, 11.0), Vector3(0.0, 16.0, 0.0), mat_wood)
    _static_box(Vector3(-3.0, 4.0, -68.0), Vector3(5.0, 1.0, 5.0), Vector3.ZERO, mat_stone)

    moving_platform_origin = Vector3(0.0, 4.0, -72.5)
    moving_platform = _anim_box(moving_platform_origin, Vector3(4.8, 0.9, 5.2), mat_metal)
    _static_box(Vector3(3.0, 4.0, -77.0), Vector3(5.0, 1.0, 5.0), Vector3.ZERO, mat_stone)

    lift_origin = Vector3(0.0, 4.0, -81.5)
    lift_platform = _anim_box(lift_origin, Vector3(4.6, 0.9, 4.6), mat_metal)
    _static_box(Vector3(0.0, 5.0, -86.0), Vector3(8.5, 1.0, 7.0), Vector3.ZERO, mat_moss)
    _static_box(Vector3(0.0, 5.0, -94.0), Vector3(4.0, 1.0, 9.0), Vector3.ZERO, mat_wood)
    _static_box(Vector3(0.0, 5.0, -103.0), Vector3(11.0, 1.0, 10.0), Vector3.ZERO, mat_stone)

    sweeper = _anim_box(Vector3(0.0, 6.1, -87.0), Vector3(8.0, 0.55, 0.65), mat_dark_metal)
    sweeper_two = _anim_box(Vector3(0.0, 6.1, -101.0), Vector3(9.0, 0.55, 0.65), mat_dark_metal)

    var pillars: Array[Vector3] = [
        Vector3(-5.8, 3.0, -19.0), Vector3(5.8, 3.0, -19.0),
        Vector3(-6.0, 7.0, -41.0), Vector3(6.0, 7.0, -41.0),
        Vector3(-7.0, 8.0, -103.0), Vector3(7.0, 8.0, -103.0)
    ]
    for p in pillars:
        _pillar(p)

    _checkpoint_gate(Vector3(0.0, 1.3, -21.0), 1)
    _checkpoint_gate(Vector3(0.0, 5.3, -43.0), 2)
    _checkpoint_gate(Vector3(-3.0, 5.3, -62.0), 3)
    _checkpoint_gate(Vector3(0.0, 6.3, -85.0), 4)
    _goal_gate(Vector3(0.0, 6.3, -106.0))

    var orb_positions: Array[Vector3] = [
        Vector3(-3.0, 1.45, 0.0), Vector3(0.0, 1.45, -11.0), Vector3(3.0, 1.45, -19.0),
        Vector3(0.0, 3.5, -31.0), Vector3(2.2, 5.45, -48.0), Vector3(-2.3, 5.45, -59.0),
        Vector3(-3.0, 5.45, -68.0), Vector3(2.8, 5.45, -77.0), Vector3(0.0, 6.45, -89.0),
        Vector3(0.0, 6.45, -101.0)
    ]
    for p in orb_positions:
        _add_orb(p)

    var kill_area: Area3D = Area3D.new()
    kill_area.position = Vector3(0.0, -9.0, -50.0)
    var kill_collision: CollisionShape3D = CollisionShape3D.new()
    var kill_shape: BoxShape3D = BoxShape3D.new()
    kill_shape.size = Vector3(220.0, 2.0, 270.0)
    kill_collision.shape = kill_shape
    kill_area.add_child(kill_collision)
    kill_area.body_entered.connect(_on_kill_body_entered)
    add_child(kill_area)

func _pillar(pos: Vector3) -> void:
    _static_box(pos, Vector3(1.2, 6.0, 1.2), Vector3.ZERO, mat_stone)
    _static_box(pos + Vector3(0.0, 3.35, 0.0), Vector3(1.65, 0.35, 1.65), Vector3.ZERO, mat_stone)

func _add_rails(center: Vector3, width: float, depth: float, only_sides: bool) -> void:
    var height: float = 1.0
    _static_box(center + Vector3(-width * 0.5 + 0.12, height, 0.0), Vector3(0.24, 0.24, depth), Vector3.ZERO, mat_dark_metal)
    _static_box(center + Vector3(width * 0.5 - 0.12, height, 0.0), Vector3(0.24, 0.24, depth), Vector3.ZERO, mat_dark_metal)
    if not only_sides:
        _static_box(center + Vector3(0.0, height, depth * 0.5 - 0.12), Vector3(width, 0.24, 0.24), Vector3.ZERO, mat_dark_metal)

func _static_box(pos: Vector3, size: Vector3, rot_deg: Vector3, material: Material) -> StaticBody3D:
    var body: StaticBody3D = StaticBody3D.new()
    body.position = pos
    body.rotation_degrees = rot_deg

    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    var physics_material: PhysicsMaterial = PhysicsMaterial.new()
    physics_material.friction = 1.15
    physics_material.bounce = 0.02
    body.physics_material_override = physics_material
    add_child(body)
    return body

func _anim_box(pos: Vector3, size: Vector3, material: Material) -> AnimatableBody3D:
    var body: AnimatableBody3D = AnimatableBody3D.new()
    body.position = pos

    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    return body

func _checkpoint_gate(pos: Vector3, index: int) -> void:
    _static_box(pos + Vector3(-2.6, 1.6, 0.0), Vector3(0.35, 3.2, 0.35), Vector3.ZERO, mat_checkpoint)
    _static_box(pos + Vector3(2.6, 1.6, 0.0), Vector3(0.35, 3.2, 0.35), Vector3.ZERO, mat_checkpoint)
    _static_box(pos + Vector3(0.0, 3.0, 0.0), Vector3(5.55, 0.35, 0.35), Vector3.ZERO, mat_checkpoint)

    var area: Area3D = Area3D.new()
    area.position = pos + Vector3(0.0, 1.2, 0.0)
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(5.0, 2.8, 1.6)
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_checkpoint_entered.bind(index))
    add_child(area)

func _goal_gate(pos: Vector3) -> void:
    _static_box(pos + Vector3(-3.0, 1.7, 0.0), Vector3(0.45, 3.4, 0.45), Vector3.ZERO, mat_goal)
    _static_box(pos + Vector3(3.0, 1.7, 0.0), Vector3(0.45, 3.4, 0.45), Vector3.ZERO, mat_goal)
    _static_box(pos + Vector3(0.0, 3.2, 0.0), Vector3(6.4, 0.45, 0.45), Vector3.ZERO, mat_goal)

    var area: Area3D = Area3D.new()
    area.position = pos + Vector3(0.0, 1.2, 0.0)
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(5.6, 3.0, 2.0)
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_goal_entered)
    add_child(area)

func _add_orb(pos: Vector3) -> void:
    total_orbs += 1
    var area: Area3D = Area3D.new()
    area.position = pos

    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.27
    sphere.height = 0.54
    sphere.radial_segments = 16
    sphere.rings = 8
    sphere.material = mat_orb
    mesh_instance.mesh = sphere
    area.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: SphereShape3D = SphereShape3D.new()
    shape.radius = 0.45
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_orb_collected.bind(area))
    add_child(area)

func _create_ball() -> void:
    ball = RigidBody3D.new()
    ball.position = Vector3(0.0, 2.2, 4.0)
    ball.mass = 1.25
    ball.linear_damp = 0.22
    ball.angular_damp = 0.16
    ball.continuous_cd = true
    ball.max_contacts_reported = 12
    ball.contact_monitor = true

    var physics_material: PhysicsMaterial = PhysicsMaterial.new()
    physics_material.friction = 1.4
    physics_material.bounce = 0.055
    ball.physics_material_override = physics_material

    ball_mesh = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = BALL_RADIUS
    sphere.height = BALL_RADIUS * 2.0
    sphere.radial_segments = 40
    sphere.rings = 24
    sphere.material = mat_ball_balanced
    ball_mesh.mesh = sphere
    ball.add_child(ball_mesh)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: SphereShape3D = SphereShape3D.new()
    shape.radius = BALL_RADIUS
    collision.shape = shape
    ball.add_child(collision)
    add_child(ball)

func _create_camera() -> void:
    follow_camera = Camera3D.new()
    follow_camera.fov = 66.0
    follow_camera.near = 0.12
    follow_camera.far = 190.0
    follow_camera.current = true
    camera_yaw = 0.0
    follow_camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
    add_child(follow_camera)

func _create_ui() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    add_child(canvas)

    ui_root = Control.new()
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.add_child(ui_root)

    hud_panel = Panel.new()
    hud_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.05, 0.065, 0.76), 18.0))
    hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(hud_panel)

    hud_title = Label.new()
    hud_title.text = "ROLLING BALANCE 16 • V2.1"
    hud_panel.add_child(hud_title)

    hud_checkpoint = Label.new()
    hud_panel.add_child(hud_checkpoint)
    hud_speed = Label.new()
    hud_panel.add_child(hud_speed)
    hud_time = Label.new()
    hud_panel.add_child(hud_time)
    hud_orbs = Label.new()
    hud_panel.add_child(hud_orbs)

    hud_message = Label.new()
    hud_message.text = "Reach the golden gate"
    hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hud_message.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.03, 0.04, 0.60), 16.0))
    ui_root.add_child(hud_message)

    stick_base = Panel.new()
    stick_base.add_theme_stylebox_override("panel", _circle_style(Color(0.08, 0.12, 0.15, 0.46), Color(0.78, 0.9, 0.96, 0.42), 3.0))
    stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(stick_base)

    stick_knob = Panel.new()
    stick_knob.add_theme_stylebox_override("panel", _circle_style(Color(0.78, 0.9, 0.96, 0.62), Color(1.0, 1.0, 1.0, 0.74), 2.0))
    stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(stick_knob)

    respawn_button = Button.new()
    respawn_button.text = "RESPAWN"
    respawn_button.pressed.connect(_respawn)
    ui_root.add_child(respawn_button)

    mode_buttons = HBoxContainer.new()
    mode_buttons.add_theme_constant_override("separation", 6)
    ui_root.add_child(mode_buttons)

    var modes: Array[String] = ["LIGHT", "BALANCED", "HEAVY"]
    for mode in modes:
        var button: Button = Button.new()
        button.text = mode
        button.pressed.connect(_set_ball_mode.bind(mode))
        mode_buttons.add_child(button)

    look_hint = Label.new()
    look_hint.text = "Swipe right side to rotate camera"
    look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    look_hint.modulate = Color(1.0, 1.0, 1.0, 0.72)
    ui_root.add_child(look_hint)

func _panel_style(color: Color, radius: float) -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = color
    var r: int = int(radius)
    box.corner_radius_top_left = r
    box.corner_radius_top_right = r
    box.corner_radius_bottom_left = r
    box.corner_radius_bottom_right = r
    box.content_margin_left = 16.0
    box.content_margin_right = 16.0
    box.content_margin_top = 12.0
    box.content_margin_bottom = 12.0
    return box

func _circle_style(color: Color, border: Color, border_width: float) -> StyleBoxFlat:
    var box: StyleBoxFlat = StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = border
    box.set_border_width_all(int(border_width))
    box.corner_radius_top_left = 999
    box.corner_radius_top_right = 999
    box.corner_radius_bottom_left = 999
    box.corner_radius_bottom_right = 999
    return box

func _layout_ui() -> void:
    if not is_instance_valid(ui_root):
        return

    var size: Vector2 = get_viewport().get_visible_rect().size
    var portrait: bool = size.y > size.x
    var short_side: float = minf(size.x, size.y)
    var ui_scale: float = clampf(short_side / 720.0, 0.72, 1.35)
    var margin: float = 18.0 * ui_scale

    if portrait:
        hud_panel.position = Vector2(margin, margin)
        hud_panel.size = Vector2(size.x - margin * 2.0, 150.0 * ui_scale)
        hud_message.position = Vector2(margin, hud_panel.position.y + hud_panel.size.y + 10.0 * ui_scale)
        hud_message.size = Vector2(size.x - margin * 2.0, 52.0 * ui_scale)
        mode_buttons.position = Vector2(margin, hud_message.position.y + hud_message.size.y + 8.0 * ui_scale)
        look_hint.position = Vector2(size.x * 0.35, size.y - 118.0 * ui_scale)
        look_hint.size = Vector2(size.x * 0.60, 34.0 * ui_scale)
    else:
        hud_panel.position = Vector2(margin, margin)
        hud_panel.size = Vector2(330.0 * ui_scale, 150.0 * ui_scale)
        hud_message.position = Vector2(size.x * 0.5 - 250.0 * ui_scale, margin)
        hud_message.size = Vector2(500.0 * ui_scale, 52.0 * ui_scale)
        mode_buttons.position = Vector2(size.x - 440.0 * ui_scale, margin + 64.0 * ui_scale)
        look_hint.position = Vector2(size.x * 0.50, size.y - 58.0 * ui_scale)
        look_hint.size = Vector2(size.x * 0.45, 34.0 * ui_scale)

    hud_title.position = Vector2(14.0 * ui_scale, 10.0 * ui_scale)
    hud_title.add_theme_font_size_override("font_size", int(21.0 * ui_scale))

    var labels: Array[Label] = [hud_checkpoint, hud_speed, hud_time, hud_orbs]
    for i in range(labels.size()):
        var label: Label = labels[i]
        label.position = Vector2(14.0 * ui_scale, (46.0 + float(i) * 23.0) * ui_scale)
        label.add_theme_font_size_override("font_size", int(16.0 * ui_scale))

    hud_message.add_theme_font_size_override("font_size", int(19.0 * ui_scale))
    look_hint.add_theme_font_size_override("font_size", int(14.0 * ui_scale))

    var stick_size: float = 174.0 * ui_scale
    stick_base.size = Vector2(stick_size, stick_size)
    stick_base.position = Vector2(30.0 * ui_scale, size.y - stick_size - 30.0 * ui_scale)

    var knob_size: float = 68.0 * ui_scale
    stick_knob.size = Vector2(knob_size, knob_size)
    _reset_stick_visual()

    respawn_button.size = Vector2(158.0 * ui_scale, 58.0 * ui_scale)
    respawn_button.position = Vector2(size.x - respawn_button.size.x - 28.0 * ui_scale, size.y - respawn_button.size.y - 26.0 * ui_scale)
    respawn_button.add_theme_font_size_override("font_size", int(16.0 * ui_scale))

    for child in mode_buttons.get_children():
        if child is Button:
            var button: Button = child as Button
            button.custom_minimum_size = Vector2(116.0 * ui_scale, 48.0 * ui_scale)
            button.add_theme_font_size_override("font_size", int(14.0 * ui_scale))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and not key.echo:
            if key.keycode == KEY_R:
                _respawn()
            elif key.keycode == KEY_Q:
                camera_yaw -= 0.22
            elif key.keycode == KEY_E:
                camera_yaw += 0.22
        return

    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        var viewport_size: Vector2 = get_viewport().get_visible_rect().size
        if touch.pressed:
            if touch.position.x < viewport_size.x * 0.48 and move_touch_id == -1:
                move_touch_id = touch.index
                touch_origin = touch.position
                touch_current = touch.position
                _place_floating_stick(touch_origin)
                _update_mobile_stick()
            elif look_touch_id == -1:
                look_touch_id = touch.index
                last_look_time = level_time
        else:
            if touch.index == move_touch_id:
                move_touch_id = -1
                mobile_input = Vector2.ZERO
                _layout_ui()
            elif touch.index == look_touch_id:
                look_touch_id = -1
        return

    if event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event as InputEventScreenDrag
        if drag.index == move_touch_id:
            touch_current = drag.position
            _update_mobile_stick()
        elif drag.index == look_touch_id:
            camera_yaw -= drag.relative.x * 0.006
            last_look_time = level_time

func _place_floating_stick(at: Vector2) -> void:
    var stick_size: Vector2 = stick_base.size
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var min_x: float = stick_size.x * 0.55
    var max_x: float = viewport_size.x * 0.48 - stick_size.x * 0.15
    var min_y: float = stick_size.y * 0.55
    var max_y: float = viewport_size.y - stick_size.y * 0.55
    var center: Vector2 = Vector2(clampf(at.x, min_x, max_x), clampf(at.y, min_y, max_y))
    stick_base.position = center - stick_size * 0.5
    _reset_stick_visual()

func _update_mobile_stick() -> void:
    var radius: float = maxf(stick_base.size.x * 0.56, 1.0)
    var delta: Vector2 = touch_current - touch_origin
    if delta.length() > radius:
        delta = delta.normalized() * radius
    mobile_input = Vector2(delta.x / radius, -delta.y / radius)
    if mobile_input.length() < 0.08:
        mobile_input = Vector2.ZERO
    var center: Vector2 = stick_base.position + stick_base.size * 0.5 - stick_knob.size * 0.5
    stick_knob.position = center + delta * 0.52

func _reset_stick_visual() -> void:
    if is_instance_valid(stick_base) and is_instance_valid(stick_knob):
        stick_knob.position = stick_base.position + stick_base.size * 0.5 - stick_knob.size * 0.5

func _physics_process(delta: float) -> void:
    if not is_instance_valid(ball):
        return

    if not finished and not respawning:
        var move: Vector2 = _get_move_input()
        var flat_velocity: Vector3 = Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
        if move.length() > 0.04:
            var cam_forward: Vector3 = -follow_camera.global_transform.basis.z
            cam_forward.y = 0.0
            cam_forward = cam_forward.normalized()
            var cam_right: Vector3 = follow_camera.global_transform.basis.x
            cam_right.y = 0.0
            cam_right = cam_right.normalized()
            var direction: Vector3 = (cam_right * move.x + cam_forward * move.y).normalized()
            var speed_factor: float = clampf(1.0 - flat_velocity.length() / MAX_SPEED, 0.10, 1.0)
            var force_value: float = 30.0 * move_force_multiplier * ball.mass * (0.45 + speed_factor * 0.55)
            ball.apply_central_force(direction * force_value)
            var roll_axis: Vector3 = direction.cross(Vector3.UP).normalized()
            ball.apply_torque(roll_axis * 15.5 * torque_multiplier * ball.mass)
        else:
            var brake: float = clampf(delta * 1.15, 0.0, 0.08)
            ball.linear_velocity.x = lerpf(ball.linear_velocity.x, 0.0, brake)
            ball.linear_velocity.z = lerpf(ball.linear_velocity.z, 0.0, brake)

    level_time += delta
    if not finished:
        elapsed_time += delta

    if is_instance_valid(moving_platform):
        var moving_pos: Vector3 = moving_platform_origin
        moving_pos.x += sin(level_time * 1.10) * 3.0
        moving_platform.position = moving_pos

    if is_instance_valid(lift_platform):
        var lift_pos: Vector3 = lift_origin
        lift_pos.y += (sin(level_time * 0.85) + 1.0) * 1.15
        lift_platform.position = lift_pos

    if is_instance_valid(sweeper):
        sweeper.rotation.y += delta * 1.25
    if is_instance_valid(sweeper_two):
        sweeper_two.rotation.y -= delta * 1.65

    if ball.position.y < -13.0 and not respawning:
        _respawn()

    _update_camera(delta)
    _update_hud()

func _get_move_input() -> Vector2:
    var x: float = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
    var y: float = (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
    var keyboard: Vector2 = Vector2(x, y)
    if keyboard.length() > 0.05:
        return keyboard.normalized()
    return mobile_input

func _update_camera(delta: float) -> void:
    var flat_velocity: Vector3 = Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
    if flat_velocity.length() > 4.0 and level_time - last_look_time > 2.8:
        var desired_yaw: float = atan2(-flat_velocity.x, -flat_velocity.z)
        camera_yaw = lerp_angle(camera_yaw, desired_yaw, clampf(delta * 0.35, 0.0, 1.0))

    var offset: Vector3 = Vector3(sin(camera_yaw) * CAMERA_DISTANCE, CAMERA_HEIGHT, cos(camera_yaw) * CAMERA_DISTANCE)
    var desired: Vector3 = ball.global_position + offset
    follow_camera.global_position = follow_camera.global_position.lerp(desired, clampf(delta * 5.2, 0.0, 1.0))
    follow_camera.look_at(ball.global_position + Vector3(0.0, 0.35, 0.0), Vector3.UP)

func _update_hud() -> void:
    if not is_instance_valid(hud_checkpoint):
        return
    var speed: float = Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z).length()
    hud_checkpoint.text = "Checkpoint  %d / 4" % current_checkpoint
    hud_speed.text = "Speed  %.1f m/s   •   %s" % [speed, ball_mode]
    hud_time.text = "Time  %02d:%05.2f" % [int(elapsed_time / 60.0), fmod(elapsed_time, 60.0)]
    hud_orbs.text = "Energy  %d / %d" % [collected_orbs, total_orbs]

func _on_orb_collected(body: Node3D, orb: Area3D) -> void:
    if body != ball or not is_instance_valid(orb):
        return
    collected_orbs += 1
    orb.queue_free()
    _flash_message("ENERGY +1")

func _on_checkpoint_entered(body: Node3D, index: int) -> void:
    if body != ball or finished:
        return
    if index > current_checkpoint:
        _set_checkpoint(index, true)

func _set_checkpoint(index: int, show_message: bool) -> void:
    if checkpoint_positions.is_empty():
        current_checkpoint = 0
        return
    current_checkpoint = clampi(index, 0, checkpoint_positions.size() - 1)
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
    hud_message.text = "FINISH!  %.2f s   •   Energy %d/%d" % [elapsed_time, collected_orbs, total_orbs]

func _on_kill_body_entered(body: Node3D) -> void:
    if body == ball and not respawning:
        _respawn()

func _respawn() -> void:
    if respawning or not is_instance_valid(ball) or checkpoint_positions.is_empty():
        return
    respawning = true
    _flash_message("RESPAWN")
    await get_tree().create_timer(RESPAWN_DELAY).timeout
    if not is_instance_valid(ball):
        respawning = false
        return
    ball.freeze = true
    ball.global_position = checkpoint_positions[current_checkpoint]
    ball.linear_velocity = Vector3.ZERO
    ball.angular_velocity = Vector3.ZERO
    ball.rotation = Vector3.ZERO
    ball.freeze = false
    respawning = false

func _set_ball_mode(mode: String) -> void:
    if not is_instance_valid(ball) or not is_instance_valid(ball_mesh):
        return
    ball_mode = mode
    match mode:
        "LIGHT":
            ball.mass = 0.68
            move_force_multiplier = 1.12
            torque_multiplier = 1.18
            ball.linear_damp = 0.18
            ball_mesh.material_override = mat_ball_light
        "HEAVY":
            ball.mass = 2.65
            move_force_multiplier = 0.82
            torque_multiplier = 0.82
            ball.linear_damp = 0.30
            ball_mesh.material_override = mat_ball_heavy
        _:
            ball.mass = 1.25
            move_force_multiplier = 1.0
            torque_multiplier = 1.0
            ball.linear_damp = 0.22
            ball_mesh.material_override = mat_ball_balanced
    _flash_message("Mode: %s" % mode)

func _flash_message(text: String) -> void:
    if not is_instance_valid(hud_message):
        return
    hud_message.text = text
    var token: int = Time.get_ticks_msec()
    hud_message.set_meta("message_token", token)
    _clear_message_later(token)

func _clear_message_later(token: int) -> void:
    await get_tree().create_timer(1.35).timeout
    if is_instance_valid(hud_message) and int(hud_message.get_meta("message_token", -1)) == token and not finished:
        hud_message.text = "Reach the golden gate"
