extends Node3D

# Berserk-inspired fan prototype v5.0. Everything is generated procedurally at runtime.
const VERSION := "5.0"
const BASE_SPEED := 7.5
const SPRINT_SPEED := 12.0
const GRAVITY := 24.0
const CAMERA_DISTANCE := 7.6
const CAMERA_HEIGHT := 3.7
const ATTACK_RANGE := 3.4
const ATTACK_COOLDOWN := 0.42
const MAX_HP := 100.0
const JUNK_COUNT := 228
const ENEMY_COUNT := 24

var player: CharacterBody3D
var player_visual: Node3D
var sword_pivot: Node3D
var camera_pivot: Node3D
var follow_camera: Camera3D

var hp: float = MAX_HP
var speed_boost_time: float = 0.0
var rage_time: float = 0.0
var transform_time: float = 0.0
var invulnerable_time: float = 0.0
var attack_cooldown: float = 0.0
var dash_cooldown: float = 0.0
var attack_anim: float = 0.0
var elapsed: float = 0.0
var kills: int = 0
var pickups_taken: int = 0
var form_name: String = "BLACK SWORDSMAN"

var camera_yaw: float = 0.0
var camera_pitch: float = -0.22
var move_touch_id: int = -1
var look_touch_id: int = -1
var move_origin := Vector2.ZERO
var move_current := Vector2.ZERO
var mobile_move := Vector2.ZERO
var use_sensor_move: bool = true

var enemies: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var anomalies: Array[Node3D] = []
var floating_junk: Array[Dictionary] = []

var ui_root: Control
var hp_label: Label
var status_label: Label
var objective_label: Label
var message_label: Label
var stick_base: Panel
var stick_knob: Panel
var attack_button: Button
var dash_button: Button
var form_button: Button
var sensor_button: Button

var mat_black: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_leather: StandardMaterial3D
var mat_ground: StandardMaterial3D
var mat_ruin: StandardMaterial3D
var mat_red: StandardMaterial3D
var mat_blue: StandardMaterial3D
var mat_green: StandardMaterial3D
var mat_yellow: StandardMaterial3D
var mat_purple: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_medkit: StandardMaterial3D
var mat_glow: StandardMaterial3D
var toy_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
    _make_materials()
    _setup_environment()
    _build_world()
    _create_player()
    _create_camera()
    _spawn_junk_dimension()
    _spawn_pickups()
    _spawn_enemies()
    _create_ui()
    var viewport := get_viewport()
    if not viewport.size_changed.is_connected(_layout_ui):
        viewport.size_changed.connect(_layout_ui)
    _layout_ui()
    print("BERSERK_V5_READY")

func _physics_process(delta: float) -> void:
    elapsed += delta
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    speed_boost_time = maxf(0.0, speed_boost_time - delta)
    rage_time = maxf(0.0, rage_time - delta)
    transform_time = maxf(0.0, transform_time - delta)
    invulnerable_time = maxf(0.0, invulnerable_time - delta)
    attack_anim = maxf(0.0, attack_anim - delta)
    if transform_time <= 0.0 and form_name != "BLACK SWORDSMAN":
        _set_form("BLACK SWORDSMAN")
    _update_player(delta)
    _update_camera(delta)
    _update_enemies(delta)
    _update_pickups(delta)
    _update_anomalies(delta)
    _update_attack_visual(delta)
    _update_ui()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        var size := get_viewport().get_visible_rect().size
        if touch.pressed:
            if touch.position.x < size.x * 0.52 and touch.position.y > size.y * 0.35 and move_touch_id == -1:
                move_touch_id = touch.index
                move_origin = touch.position
                move_current = touch.position
                _update_stick_visual()
            elif touch.position.x >= size.x * 0.48 and look_touch_id == -1:
                look_touch_id = touch.index
        else:
            if touch.index == move_touch_id:
                move_touch_id = -1
                mobile_move = Vector2.ZERO
                _update_stick_visual()
            if touch.index == look_touch_id:
                look_touch_id = -1
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == move_touch_id:
            move_current = drag.position
            var delta_pos := move_current - move_origin
            mobile_move = delta_pos / 92.0
            if mobile_move.length() > 1.0:
                mobile_move = mobile_move.normalized()
            _update_stick_visual()
        elif drag.index == look_touch_id:
            camera_yaw -= drag.relative.x * 0.006
            camera_pitch = clampf(camera_pitch - drag.relative.y * 0.0045, -0.68, 0.18)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var motion := event as InputEventMouseMotion
        camera_yaw -= motion.relative.x * 0.005
        camera_pitch = clampf(camera_pitch - motion.relative.y * 0.004, -0.68, 0.18)

func _update_player(delta: float) -> void:
    if player == null:
        return
    var move_input := mobile_move
    var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if keyboard.length() > 0.05:
        move_input = keyboard
    if use_sensor_move and OS.has_feature("mobile"):
        var accel := Input.get_accelerometer()
        var sensor := Vector2(accel.x / 5.2, -accel.y / 5.2)
        if sensor.length() > 0.12:
            sensor = sensor.limit_length(0.65)
            move_input = (move_input + sensor * 0.45).limit_length(1.0)
        var gyro := Input.get_gyroscope()
        if absf(gyro.y) > 0.08:
            camera_yaw -= gyro.y * delta * 0.55

    var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
    var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
    var wish := right * move_input.x + forward * -move_input.y
    if wish.length() > 1.0:
        wish = wish.normalized()
    var current_speed := BASE_SPEED
    if speed_boost_time > 0.0:
        current_speed = SPRINT_SPEED
    if form_name == "RAGE BEAST":
        current_speed *= 1.22
    elif form_name == "VOID WRAITH":
        current_speed *= 1.10
    var target := wish * current_speed
    player.velocity.x = move_toward(player.velocity.x, target.x, 25.0 * delta)
    player.velocity.z = move_toward(player.velocity.z, target.z, 25.0 * delta)
    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta
    else:
        player.velocity.y = -0.5
    player.move_and_slide()
    if wish.length() > 0.15:
        player_visual.rotation.y = lerp_angle(player_visual.rotation.y, atan2(-wish.x, -wish.z), 10.0 * delta)
    if player.global_position.y < -18.0:
        _respawn_player()

func _update_camera(delta: float) -> void:
    if follow_camera == null or player == null:
        return
    var yaw_basis := Basis(Vector3.UP, camera_yaw)
    var back := yaw_basis * Vector3(0.0, 0.0, CAMERA_DISTANCE)
    var target := player.global_position + Vector3(0.0, 1.8, 0.0)
    var desired := target + back + Vector3(0.0, CAMERA_HEIGHT + camera_pitch * 4.2, 0.0)
    follow_camera.global_position = follow_camera.global_position.lerp(desired, minf(1.0, delta * 8.0))
    follow_camera.look_at(target, Vector3.UP)

func _attack() -> void:
    if attack_cooldown > 0.0:
        return
    attack_cooldown = ATTACK_COOLDOWN
    attack_anim = 0.34
    var damage := 38.0
    if rage_time > 0.0:
        damage = 70.0
    if form_name == "RAGE BEAST":
        damage *= 1.45
    elif form_name == "VOID WRAITH":
        damage *= 1.18
    for enemy in enemies:
        if bool(enemy.get("dead", false)):
            continue
        var node := enemy.get("node") as Node3D
        if node == null:
            continue
        var dist := player.global_position.distance_to(node.global_position)
        if dist <= ATTACK_RANGE:
            var to_enemy := (node.global_position - player.global_position).normalized()
            var face := -player_visual.global_transform.basis.z.normalized()
            if face.dot(to_enemy) > -0.15:
                enemy["hp"] = float(enemy.get("hp", 0.0)) - damage
                node.global_position += to_enemy * 0.7
                if float(enemy["hp"]) <= 0.0:
                    _kill_enemy(enemy)
    _show_message("DRAGON SLAYER HIT")

func _dash() -> void:
    if dash_cooldown > 0.0:
        return
    dash_cooldown = 1.2
    invulnerable_time = 0.32
    var face := -player_visual.global_transform.basis.z.normalized()
    face.y = 0.0
    player.velocity += face * 14.0
    _show_message("DASH")

func _cycle_form() -> void:
    if transform_time <= 0.0:
        _show_message("FIND A MORPH RELIC")
        return
    if form_name == "BLACK SWORDSMAN":
        _set_form("RAGE BEAST")
    elif form_name == "RAGE BEAST":
        _set_form("VOID WRAITH")
    else:
        _set_form("BLACK SWORDSMAN")

func _set_form(next_form: String) -> void:
    form_name = next_form
    if player_visual == null:
        return
    if next_form == "RAGE BEAST":
        player_visual.scale = Vector3(1.12, 1.05, 1.12)
    elif next_form == "VOID WRAITH":
        player_visual.scale = Vector3(0.92, 1.08, 0.92)
    else:
        player_visual.scale = Vector3.ONE
    _show_message(next_form)

func _kill_enemy(enemy: Dictionary) -> void:
    enemy["dead"] = true
    kills += 1
    var node := enemy.get("node") as Node3D
    if node != null:
        node.visible = false
    if kills >= ENEMY_COUNT:
        _show_message("THE RIFT IS QUIET... FOR NOW")

func _damage_player(amount: float) -> void:
    if invulnerable_time > 0.0:
        return
    invulnerable_time = 0.65
    hp = maxf(0.0, hp - amount)
    _show_message("WOUNDED")
    if hp <= 0.0:
        _respawn_player()

func _respawn_player() -> void:
    hp = MAX_HP
    player.global_position = Vector3(0.0, 1.2, 9.0)
    player.velocity = Vector3.ZERO
    _show_message("STRUGGLE AGAIN")

func _update_enemies(delta: float) -> void:
    if player == null:
        return
    for enemy in enemies:
        if bool(enemy.get("dead", false)):
            continue
        var node := enemy.get("node") as Node3D
        if node == null:
            continue
        var to_player := player.global_position - node.global_position
        var dist := to_player.length()
        if dist < 22.0 and dist > 1.65:
            var dir := to_player.normalized()
            dir.y = 0.0
            var speed := float(enemy.get("speed", 2.2))
            node.global_position += dir * speed * delta
            node.rotation.y = lerp_angle(node.rotation.y, atan2(-dir.x, -dir.z), 7.0 * delta)
        elif dist <= 1.75:
            var timer := float(enemy.get("attack_time", 0.0)) - delta
            enemy["attack_time"] = timer
            if timer <= 0.0:
                enemy["attack_time"] = 1.0 + float(enemy.get("variant", 0)) * 0.08
                _damage_player(float(enemy.get("damage", 8.0)))
        var bob := float(enemy.get("bob", 0.0))
        node.position.y = float(enemy.get("base_y", node.position.y)) + sin(elapsed * 2.2 + bob) * 0.08

func _update_pickups(delta: float) -> void:
    if player == null:
        return
    for pickup in pickups:
        if bool(pickup.get("taken", false)):
            continue
        var node := pickup.get("node") as Node3D
        if node == null:
            continue
        node.rotation.y += delta * 1.4
        var base_y := float(pickup.get("base_y", node.position.y))
        node.position.y = base_y + sin(elapsed * 2.6 + float(pickup.get("phase", 0.0))) * 0.18
        if player.global_position.distance_to(node.global_position) < 1.5:
            pickup["taken"] = true
            node.visible = false
            pickups_taken += 1
            _apply_pickup(String(pickup.get("kind", "HEAL")))

func _apply_pickup(kind: String) -> void:
    match kind:
        "HEAL":
            hp = minf(MAX_HP, hp + 45.0)
            _show_message("MEDKIT +45")
        "SPEED":
            speed_boost_time = maxf(speed_boost_time, 12.0)
            _show_message("SPEED x1.6 / 12s")
        "RAGE":
            rage_time = maxf(rage_time, 13.0)
            _show_message("BERSERK POWER / 13s")
        "MORPH":
            transform_time = maxf(transform_time, 25.0)
            _set_form("RAGE BEAST")
        _:
            hp = minf(MAX_HP, hp + 15.0)

func _update_anomalies(delta: float) -> void:
    for i in range(anomalies.size()):
        var node := anomalies[i]
        if is_instance_valid(node):
            node.rotation.y += delta * (0.12 + float(i % 5) * 0.025)
            node.rotation.z = sin(elapsed * 0.7 + float(i)) * 0.12
    for item in floating_junk:
        var node := item.get("node") as Node3D
        if node == null:
            continue
        var base: Vector3 = item.get("base", Vector3.ZERO)
        var phase := float(item.get("phase", 0.0))
        node.position.y = base.y + sin(elapsed * 1.2 + phase) * float(item.get("amp", 0.22))
        node.rotation.y += delta * float(item.get("spin", 0.4))

func _update_attack_visual(delta: float) -> void:
    if sword_pivot == null:
        return
    if attack_anim > 0.0:
        var t := 1.0 - attack_anim / 0.34
        sword_pivot.rotation.x = deg_to_rad(-45.0 + sin(t * PI) * 118.0)
        sword_pivot.rotation.z = deg_to_rad(-28.0 + sin(t * PI) * 42.0)
    else:
        sword_pivot.rotation.x = lerp_angle(sword_pivot.rotation.x, deg_to_rad(-35.0), minf(1.0, delta * 12.0))
        sword_pivot.rotation.z = lerp_angle(sword_pivot.rotation.z, deg_to_rad(-24.0), minf(1.0, delta * 12.0))

func _make_materials() -> void:
    mat_black = _material(Color("#101116"), 0.55, 0.45)
    mat_steel = _material(Color("#59616b"), 0.27, 0.86)
    mat_skin = _material(Color("#c89a7a"), 0.74, 0.02)
    mat_leather = _material(Color("#3a2723"), 0.82, 0.08)
    mat_ground = _material(Color("#292524"), 0.98, 0.0)
    mat_ruin = _material(Color("#56524f"), 0.94, 0.02)
    mat_red = _material(Color("#c03542"), 0.48, 0.12)
    mat_blue = _material(Color("#2878c7"), 0.42, 0.10)
    mat_green = _material(Color("#47a45d"), 0.56, 0.06)
    mat_yellow = _material(Color("#d9b62e"), 0.45, 0.14)
    mat_purple = _material(Color("#8e4fc4"), 0.40, 0.16)
    mat_white = _material(Color("#d9d7d2"), 0.70, 0.03)
    mat_medkit = _material(Color("#dfddd4"), 0.56, 0.02)
    mat_glow = _material(Color("#80d8ff"), 0.18, 0.16, Color("#2ab5ff"), 2.8)
    toy_materials = [mat_red, mat_blue, mat_green, mat_yellow, mat_purple, mat_white, mat_black, mat_steel]

func _material(color: Color, roughness: float, metallic: float, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.metallic = metallic
    if emission_energy > 0.0:
        mat.emission_enabled = true
        mat.emission = emission
        mat.emission_energy_multiplier = emission_energy
    return mat

func _setup_environment() -> void:
    var env := Environment.new()
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#080812")
    sky_mat.sky_horizon_color = Color("#4a213b")
    sky_mat.ground_bottom_color = Color("#050509")
    sky_mat.ground_horizon_color = Color("#2d2732")
    sky.sky_material = sky_mat
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.62
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color("#3f3046")
    env.fog_density = 0.008
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
    moon.light_color = Color("#9db7ff")
    moon.light_energy = 1.55
    moon.shadow_enabled = true
    moon.directional_shadow_max_distance = 125.0
    add_child(moon)

    var hell_light := OmniLight3D.new()
    hell_light.position = Vector3(0.0, 9.0, -52.0)
    hell_light.light_color = Color("#df3f64")
    hell_light.light_energy = 7.0
    hell_light.omni_range = 34.0
    add_child(hell_light)

func _build_world() -> void:
    _static_box(Vector3(0.0, -1.0, -45.0), Vector3(90.0, 2.0, 130.0), mat_ground)
    _static_box(Vector3(0.0, 0.2, 12.0), Vector3(18.0, 0.8, 17.0), mat_ruin)
    _static_box(Vector3(0.0, 0.3, -20.0), Vector3(12.0, 1.0, 35.0), mat_ruin)
    _static_box(Vector3(0.0, 0.6, -68.0), Vector3(42.0, 1.2, 55.0), mat_ground)
    for i in range(14):
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * (7.0 + float((i * 3) % 6))
        var z := 2.0 - float(i) * 7.5
        _ruin_tower(Vector3(x, 2.0, z), 1.4 + float(i % 3) * 0.35, 4.0 + float(i % 5) * 1.2)
    for i in range(11):
        var z := -30.0 - float(i) * 7.0
        var x := -18.0 + float((i * 7) % 36)
        _broken_arch(Vector3(x, 1.2, z), float(i) * 17.0)
    _build_ufo(Vector3(18.0, 15.0, -62.0), 1.4)
    _build_ufo(Vector3(-26.0, 20.0, -83.0), 0.9)
    _build_rift(Vector3(0.0, 5.5, -103.0))

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "BlackSwordsman"
    player.position = Vector3(0.0, 1.2, 9.0)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.48
    capsule.height = 1.55
    collision.shape = capsule
    collision.position.y = 0.88
    player.add_child(collision)
    add_child(player)

    player_visual = Node3D.new()
    player_visual.name = "ProceduralSwordsman"
    player.add_child(player_visual)
    _mesh_box(player_visual, Vector3(0.0, 1.25, 0.0), Vector3(0.80, 1.45, 0.46), mat_black)
    _mesh_sphere(player_visual, Vector3(0.0, 2.12, 0.0), 0.42, mat_skin)
    _mesh_box(player_visual, Vector3(0.0, 2.25, -0.18), Vector3(0.86, 0.28, 0.54), mat_black)
    _mesh_box(player_visual, Vector3(-0.56, 1.30, 0.0), Vector3(0.26, 1.18, 0.30), mat_steel, Vector3(0.0, 0.0, -8.0))
    _mesh_box(player_visual, Vector3(0.56, 1.30, 0.0), Vector3(0.26, 1.18, 0.30), mat_leather, Vector3(0.0, 0.0, 8.0))
    _mesh_box(player_visual, Vector3(-0.25, 0.42, 0.0), Vector3(0.30, 0.88, 0.34), mat_black)
    _mesh_box(player_visual, Vector3(0.25, 0.42, 0.0), Vector3(0.30, 0.88, 0.34), mat_black)

    sword_pivot = Node3D.new()
    sword_pivot.position = Vector3(0.55, 1.65, 0.12)
    sword_pivot.rotation_degrees = Vector3(-35.0, 0.0, -24.0)
    player_visual.add_child(sword_pivot)
    _mesh_box(sword_pivot, Vector3(0.0, 0.0, -1.75), Vector3(0.28, 0.12, 3.7), mat_steel)
    _mesh_box(sword_pivot, Vector3(0.0, 0.0, 0.18), Vector3(0.72, 0.18, 0.16), mat_black)
    _mesh_box(sword_pivot, Vector3(0.0, 0.0, 0.48), Vector3(0.18, 0.18, 0.62), mat_leather)

func _create_camera() -> void:
    camera_pivot = Node3D.new()
    add_child(camera_pivot)
    follow_camera = Camera3D.new()
    follow_camera.current = true
    follow_camera.fov = 72.0
    add_child(follow_camera)
    follow_camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)

func _spawn_junk_dimension() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 0xB35E5A5
    for i in range(JUNK_COUNT):
        var x := rng.randf_range(-36.0, 36.0)
        var z := rng.randf_range(-94.0, -34.0)
        var y := rng.randf_range(0.25, 1.15)
        var type := i % 12
        var root := Node3D.new()
        root.position = Vector3(x, y, z)
        root.rotation_degrees.y = rng.randf_range(0.0, 360.0)
        add_child(root)
        match type:
            0:
                _toy_ball(root, rng.randf_range(0.18, 0.42), i)
            1:
                _toy_ring(root, rng.randf_range(0.22, 0.46), i)
            2:
                _toy_block(root, rng.randf_range(0.25, 0.50), i)
            3:
                _toy_domino(root, rng.randf_range(0.32, 0.58), i)
            4:
                _toy_brick(root, rng.randf_range(0.18, 0.34), i)
            5:
                _toy_robot(root, rng.randf_range(0.22, 0.34), i)
            6:
                _toy_car(root, rng.randf_range(0.22, 0.36), i)
            7:
                _toy_duck(root, rng.randf_range(0.20, 0.38), i)
            8:
                _junk_tv(root, rng.randf_range(0.28, 0.46), i)
            9:
                _junk_bottle(root, rng.randf_range(0.20, 0.40), i)
            10:
                _junk_clock(root, rng.randf_range(0.24, 0.42), i)
            _:
                _junk_mask(root, rng.randf_range(0.24, 0.40), i)
        if i % 7 == 0:
            var base := root.position
            base.y += rng.randf_range(0.4, 2.2)
            root.position = base
            floating_junk.append({"node": root, "base": base, "phase": rng.randf_range(0.0, TAU), "amp": rng.randf_range(0.12, 0.55), "spin": rng.randf_range(-0.9, 0.9)})
    for i in range(18):
        _strange_anomaly(Vector3(rng.randf_range(-32.0, 32.0), rng.randf_range(2.2, 8.0), rng.randf_range(-98.0, -38.0)), i)

func _spawn_pickups() -> void:
    var kinds := ["HEAL", "SPEED", "RAGE", "MORPH"]
    for i in range(24):
        var angle := float(i) * 1.7
        var radius := 8.0 + float((i * 11) % 27)
        var pos := Vector3(cos(angle) * radius, 1.25, -42.0 - sin(angle * 0.65) * 42.0)
        var kind := String(kinds[i % kinds.size()])
        var root := Node3D.new()
        root.position = pos
        add_child(root)
        _pickup_visual(root, kind)
        pickups.append({"node": root, "kind": kind, "taken": false, "base_y": pos.y, "phase": float(i) * 0.7})

func _spawn_enemies() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 19791014
    for i in range(ENEMY_COUNT):
        var node := Node3D.new()
        var x := rng.randf_range(-26.0, 26.0)
        var z := rng.randf_range(-98.0, -18.0)
        node.position = Vector3(x, 0.85, z)
        add_child(node)
        _creature_visual(node, i)
        enemies.append({
            "node": node,
            "hp": 65.0 + float(i % 4) * 18.0,
            "speed": 1.7 + float(i % 5) * 0.17,
            "damage": 7.0 + float(i % 4) * 2.0,
            "dead": false,
            "attack_time": 0.3 + float(i % 3) * 0.2,
            "variant": i % 5,
            "base_y": node.position.y,
            "bob": float(i) * 0.8
        })

func _create_ui() -> void:
    ui_root = Control.new()
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(ui_root)

    var title := Label.new()
    title.text = "BLACK SWORDSMAN — RIFT v5.0"
    title.add_theme_font_size_override("font_size", 24)
    title.position = Vector2(18.0, 14.0)
    ui_root.add_child(title)

    hp_label = Label.new()
    hp_label.add_theme_font_size_override("font_size", 22)
    ui_root.add_child(hp_label)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 18)
    ui_root.add_child(status_label)
    objective_label = Label.new()
    objective_label.add_theme_font_size_override("font_size", 17)
    ui_root.add_child(objective_label)
    message_label = Label.new()
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 24)
    ui_root.add_child(message_label)

    stick_base = Panel.new()
    stick_base.modulate = Color(1.0, 1.0, 1.0, 0.19)
    stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(stick_base)
    stick_knob = Panel.new()
    stick_knob.modulate = Color(1.0, 1.0, 1.0, 0.45)
    stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(stick_knob)

    attack_button = _button("SLASH", _attack)
    dash_button = _button("DASH", _dash)
    form_button = _button("MORPH", _cycle_form)
    sensor_button = _button("GYRO ON", _toggle_sensor)
    _update_ui()

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.add_theme_font_size_override("font_size", 18)
    button.button_down.connect(callback)
    ui_root.add_child(button)
    return button

func _toggle_sensor() -> void:
    use_sensor_move = not use_sensor_move
    sensor_button.text = "GYRO ON" if use_sensor_move else "GYRO OFF"
    _show_message(sensor_button.text)

func _layout_ui() -> void:
    if ui_root == null:
        return
    var size := get_viewport().get_visible_rect().size
    hp_label.position = Vector2(18.0, 52.0)
    status_label.position = Vector2(18.0, 80.0)
    objective_label.position = Vector2(18.0, 108.0)
    message_label.position = Vector2(size.x * 0.18, 145.0)
    message_label.size = Vector2(size.x * 0.64, 42.0)
    var stick_size := clampf(minf(size.x, size.y) * 0.20, 112.0, 178.0)
    stick_base.position = Vector2(24.0, size.y - stick_size - 28.0)
    stick_base.size = Vector2(stick_size, stick_size)
    stick_knob.size = Vector2(stick_size * 0.42, stick_size * 0.42)
    attack_button.size = Vector2(132.0, 70.0)
    attack_button.position = Vector2(size.x - 150.0, size.y - 98.0)
    dash_button.size = Vector2(112.0, 58.0)
    dash_button.position = Vector2(size.x - 274.0, size.y - 165.0)
    form_button.size = Vector2(112.0, 58.0)
    form_button.position = Vector2(size.x - 150.0, size.y - 172.0)
    sensor_button.size = Vector2(108.0, 44.0)
    sensor_button.position = Vector2(size.x - 126.0, 18.0)
    _update_stick_visual()

func _update_stick_visual() -> void:
    if stick_base == null or stick_knob == null:
        return
    var center := stick_base.position + stick_base.size * 0.5
    var radius := stick_base.size.x * 0.30
    var offset := mobile_move * radius
    stick_knob.position = center + offset - stick_knob.size * 0.5

func _update_ui() -> void:
    if hp_label == null:
        return
    hp_label.text = "HP %d / %d" % [int(hp), int(MAX_HP)]
    var buffs: Array[String] = []
    if speed_boost_time > 0.0:
        buffs.append("SPEED %.0fs" % speed_boost_time)
    if rage_time > 0.0:
        buffs.append("RAGE %.0fs" % rage_time)
    if transform_time > 0.0:
        buffs.append("MORPH %.0fs" % transform_time)
    status_label.text = "%s   %s" % [form_name, " | ".join(buffs)]
    objective_label.text = "Apostles %d/%d   Relics %d/%d" % [kills, ENEMY_COUNT, pickups_taken, pickups.size()]

func _show_message(text: String) -> void:
    if message_label == null:
        return
    message_label.text = text
    var timer := get_tree().create_timer(1.3)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(message_label) and message_label.text == text:
            message_label.text = ""
    )

func _static_box(pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    box.material = material
    mesh.mesh = box
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    return body

func _ruin_tower(pos: Vector3, radius: float, height: float) -> void:
    var root := Node3D.new()
    root.position = pos
    add_child(root)
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius * 0.86
    cylinder.bottom_radius = radius
    cylinder.height = height
    cylinder.radial_segments = 12
    cylinder.material = mat_ruin
    mesh.mesh = cylinder
    root.add_child(mesh)
    for i in range(5):
        _mesh_box(root, Vector3(sin(float(i) * 1.7) * radius * 0.8, height * 0.48, cos(float(i) * 1.7) * radius * 0.8), Vector3(radius * 0.45, 0.45, radius * 0.45), mat_ground, Vector3(float(i) * 7.0, float(i) * 33.0, float(i) * 11.0))

func _broken_arch(pos: Vector3, yaw: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation_degrees.y = yaw
    add_child(root)
    _mesh_box(root, Vector3(-1.6, 2.0, 0.0), Vector3(1.0, 4.0, 1.0), mat_ruin)
    _mesh_box(root, Vector3(1.6, 1.7, 0.0), Vector3(1.0, 3.4, 1.0), mat_ruin, Vector3(0.0, 0.0, 7.0))
    _mesh_box(root, Vector3(0.0, 3.7, 0.0), Vector3(3.8, 0.75, 1.0), mat_ruin, Vector3(0.0, 0.0, -5.0))

func _build_ufo(pos: Vector3, scale_factor: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.scale = Vector3.ONE * scale_factor
    add_child(root)
    var disc := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 3.4
    cyl.bottom_radius = 4.8
    cyl.height = 0.75
    cyl.radial_segments = 28
    cyl.material = mat_steel
    disc.mesh = cyl
    root.add_child(disc)
    _mesh_sphere(root, Vector3(0.0, 0.7, 0.0), 1.9, mat_glow, Vector3(1.0, 0.52, 1.0))
    for i in range(10):
        var a := float(i) / 10.0 * TAU
        _mesh_sphere(root, Vector3(cos(a) * 3.5, -0.25, sin(a) * 3.5), 0.22, mat_glow)
    anomalies.append(root)

func _build_rift(pos: Vector3) -> void:
    var root := Node3D.new()
    root.position = pos
    add_child(root)
    for i in range(17):
        var a := float(i) / 17.0 * TAU
        var r := 4.4 + sin(float(i) * 1.8) * 0.7
        _mesh_box(root, Vector3(cos(a) * r, sin(a) * 4.9, 0.0), Vector3(0.45, 1.7, 0.5), mat_black, Vector3(0.0, 0.0, -rad_to_deg(a)))
    _mesh_sphere(root, Vector3.ZERO, 2.9, mat_glow, Vector3(1.0, 1.65, 0.24))
    anomalies.append(root)

func _strange_anomaly(pos: Vector3, index: int) -> void:
    var root := Node3D.new()
    root.position = pos
    add_child(root)
    var mat := toy_materials[index % toy_materials.size()]
    _mesh_sphere(root, Vector3.ZERO, 0.45 + float(index % 4) * 0.12, mat_glow, Vector3(1.0, 1.0 + float(index % 3), 1.0))
    for j in range(3 + index % 5):
        var a := float(j) / float(3 + index % 5) * TAU
        _mesh_box(root, Vector3(cos(a) * 1.2, sin(a * 2.0) * 0.4, sin(a) * 1.2), Vector3(0.18, 0.18 + float(j) * 0.08, 0.8), mat, Vector3(float(j) * 25.0, rad_to_deg(a), float(j) * 13.0))
    anomalies.append(root)

func _pickup_visual(root: Node3D, kind: String) -> void:
    if kind == "HEAL":
        _mesh_box(root, Vector3.ZERO, Vector3(0.8, 0.55, 0.42), mat_medkit)
        _mesh_box(root, Vector3(0.0, 0.02, -0.24), Vector3(0.38, 0.12, 0.08), mat_red)
        _mesh_box(root, Vector3(0.0, 0.02, -0.25), Vector3(0.12, 0.36, 0.08), mat_red)
    elif kind == "SPEED":
        _mesh_sphere(root, Vector3.ZERO, 0.42, mat_blue)
        _mesh_box(root, Vector3(0.0, 0.0, -0.35), Vector3(0.12, 0.72, 0.18), mat_glow, Vector3(0.0, 0.0, -28.0))
    elif kind == "RAGE":
        _mesh_sphere(root, Vector3.ZERO, 0.48, mat_red)
        _mesh_box(root, Vector3.ZERO, Vector3(0.16, 1.05, 0.16), mat_yellow, Vector3(0.0, 0.0, 45.0))
    else:
        _mesh_sphere(root, Vector3.ZERO, 0.56, mat_purple)
        _mesh_sphere(root, Vector3.ZERO, 0.26, mat_glow)

func _creature_visual(root: Node3D, index: int) -> void:
    var variant := index % 5
    var body_mat := [mat_red, mat_purple, mat_green, mat_black, mat_steel][variant] as StandardMaterial3D
    _mesh_sphere(root, Vector3(0.0, 1.1, 0.0), 0.72, body_mat, Vector3(0.78, 1.28, 0.75))
    _mesh_sphere(root, Vector3(0.0, 1.95, -0.08), 0.42, body_mat, Vector3(0.88, 1.10, 0.86))
    _mesh_sphere(root, Vector3(-0.16, 2.03, -0.39), 0.075, mat_glow)
    _mesh_sphere(root, Vector3(0.16, 2.03, -0.39), 0.075, mat_glow)
    for i in range(2 + variant):
        var side := -1.0 if i % 2 == 0 else 1.0
        _mesh_box(root, Vector3(side * (0.55 + float(i) * 0.12), 1.05 + float(i % 2) * 0.28, 0.0), Vector3(0.16, 0.95, 0.18), body_mat, Vector3(0.0, 0.0, side * (18.0 + float(i) * 8.0)))
    if variant == 2:
        _mesh_box(root, Vector3(0.0, 2.5, 0.0), Vector3(0.13, 1.3, 0.13), mat_yellow, Vector3(0.0, 0.0, 12.0))
    elif variant == 4:
        _mesh_sphere(root, Vector3(0.0, 1.2, 0.55), 0.34, mat_glow)

func _toy_ball(root: Node3D, s: float, index: int) -> void:
    _mesh_sphere(root, Vector3.ZERO, s, toy_materials[index % toy_materials.size()])
    _mesh_box(root, Vector3(0.0, s * 0.15, -s * 0.88), Vector3(s * 0.18, s * 1.1, s * 0.08), toy_materials[(index + 3) % toy_materials.size()], Vector3(0.0, 0.0, 35.0))

func _toy_ring(root: Node3D, s: float, index: int) -> void:
    for i in range(10):
        var a := float(i) / 10.0 * TAU
        _mesh_sphere(root, Vector3(cos(a) * s, sin(a) * s, 0.0), s * 0.22, toy_materials[(index + i) % toy_materials.size()])

func _toy_block(root: Node3D, s: float, index: int) -> void:
    _mesh_box(root, Vector3.ZERO, Vector3.ONE * s, toy_materials[index % toy_materials.size()])
    _mesh_sphere(root, Vector3(-s * 0.22, s * 0.56, -s * 0.22), s * 0.09, toy_materials[(index + 2) % toy_materials.size()])
    _mesh_sphere(root, Vector3(s * 0.22, s * 0.56, s * 0.22), s * 0.09, toy_materials[(index + 2) % toy_materials.size()])

func _toy_domino(root: Node3D, s: float, index: int) -> void:
    _mesh_box(root, Vector3.ZERO, Vector3(s * 0.46, s, s * 0.18), toy_materials[index % toy_materials.size()])
    for i in range(3):
        _mesh_sphere(root, Vector3((float(i) - 1.0) * s * 0.11, s * 0.18, -s * 0.11), s * 0.045, mat_black)
        _mesh_sphere(root, Vector3((float(i) - 1.0) * s * 0.11, -s * 0.18, -s * 0.11), s * 0.045, mat_white)

func _toy_brick(root: Node3D, s: float, index: int) -> void:
    _mesh_box(root, Vector3.ZERO, Vector3(s * 1.5, s * 0.48, s), toy_materials[index % toy_materials.size()])
    for x in range(3):
        for z in range(2):
            _mesh_sphere(root, Vector3((float(x) - 1.0) * s * 0.45, s * 0.30, (float(z) - 0.5) * s * 0.45), s * 0.12, toy_materials[index % toy_materials.size()], Vector3(1.0, 0.45, 1.0))

func _toy_robot(root: Node3D, s: float, index: int) -> void:
    var m := toy_materials[index % toy_materials.size()]
    _mesh_box(root, Vector3(0.0, s * 0.4, 0.0), Vector3(s * 0.9, s, s * 0.52), m)
    _mesh_box(root, Vector3(0.0, s * 1.15, 0.0), Vector3(s * 0.7, s * 0.5, s * 0.48), mat_steel)
    _mesh_sphere(root, Vector3(-s * 0.18, s * 1.18, -s * 0.26), s * 0.08, mat_glow)
    _mesh_sphere(root, Vector3(s * 0.18, s * 1.18, -s * 0.26), s * 0.08, mat_glow)

func _toy_car(root: Node3D, s: float, index: int) -> void:
    var m := toy_materials[index % toy_materials.size()]
    _mesh_box(root, Vector3.ZERO, Vector3(s * 1.8, s * 0.55, s), m)
    _mesh_box(root, Vector3(0.0, s * 0.42, 0.0), Vector3(s * 0.9, s * 0.45, s * 0.8), mat_white)
    for x in [-0.58, 0.58]:
        for z in [-0.42, 0.42]:
            _mesh_sphere(root, Vector3(float(x) * s, -s * 0.36, float(z) * s), s * 0.20, mat_black, Vector3(1.0, 0.42, 1.0))

func _toy_duck(root: Node3D, s: float, index: int) -> void:
    _mesh_sphere(root, Vector3(0.0, 0.0, 0.0), s, mat_yellow, Vector3(1.2, 0.85, 1.0))
    _mesh_sphere(root, Vector3(0.0, s * 0.78, -s * 0.18), s * 0.56, mat_yellow)
    _mesh_box(root, Vector3(0.0, s * 0.76, -s * 0.72), Vector3(s * 0.34, s * 0.16, s * 0.42), mat_red)
    _mesh_sphere(root, Vector3(-s * 0.17, s * 0.92, -s * 0.47), s * 0.055, mat_black)
    _mesh_sphere(root, Vector3(s * 0.17, s * 0.92, -s * 0.47), s * 0.055, mat_black)

func _junk_tv(root: Node3D, s: float, index: int) -> void:
    _mesh_box(root, Vector3.ZERO, Vector3(s * 1.5, s, s * 0.72), mat_black)
    _mesh_box(root, Vector3(0.0, 0.0, -s * 0.39), Vector3(s * 1.15, s * 0.72, s * 0.05), mat_glow)
    _mesh_box(root, Vector3(-s * 0.28, s * 0.72, 0.0), Vector3(s * 0.06, s * 0.75, s * 0.06), mat_steel, Vector3(0.0, 0.0, -24.0))
    _mesh_box(root, Vector3(s * 0.28, s * 0.72, 0.0), Vector3(s * 0.06, s * 0.75, s * 0.06), mat_steel, Vector3(0.0, 0.0, 24.0))

func _junk_bottle(root: Node3D, s: float, index: int) -> void:
    _mesh_sphere(root, Vector3(0.0, s * 0.2, 0.0), s * 0.45, toy_materials[index % toy_materials.size()], Vector3(0.65, 1.5, 0.65))
    _mesh_box(root, Vector3(0.0, s * 0.92, 0.0), Vector3(s * 0.25, s * 0.62, s * 0.25), mat_white)
    _mesh_box(root, Vector3(0.0, s * 1.26, 0.0), Vector3(s * 0.34, s * 0.12, s * 0.34), mat_red)

func _junk_clock(root: Node3D, s: float, index: int) -> void:
    _mesh_sphere(root, Vector3.ZERO, s, mat_white, Vector3(1.0, 1.0, 0.28))
    _mesh_box(root, Vector3(0.0, 0.0, -s * 0.31), Vector3(s * 0.07, s * 0.58, s * 0.04), mat_black, Vector3(0.0, 0.0, float(index * 17 % 360)))
    _mesh_box(root, Vector3(0.0, 0.0, -s * 0.32), Vector3(s * 0.05, s * 0.42, s * 0.04), mat_red, Vector3(0.0, 0.0, float(index * 29 % 360)))

func _junk_mask(root: Node3D, s: float, index: int) -> void:
    _mesh_sphere(root, Vector3.ZERO, s, toy_materials[index % toy_materials.size()], Vector3(0.86, 1.12, 0.30))
    _mesh_sphere(root, Vector3(-s * 0.26, s * 0.14, -s * 0.32), s * 0.10, mat_black)
    _mesh_sphere(root, Vector3(s * 0.26, s * 0.14, -s * 0.32), s * 0.10, mat_black)
    _mesh_box(root, Vector3(0.0, -s * 0.25, -s * 0.33), Vector3(s * 0.46, s * 0.08, s * 0.05), mat_black, Vector3(0.0, 0.0, 8.0))

func _mesh_box(parent: Node, pos: Vector3, size: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.rotation_degrees = rot_deg
    parent.add_child(mesh_instance)
    return mesh_instance

func _mesh_sphere(parent: Node, pos: Vector3, radius: float, material: Material, scale_factor: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 7
    mesh.material = material
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.scale = scale_factor
    parent.add_child(mesh_instance)
    return mesh_instance
