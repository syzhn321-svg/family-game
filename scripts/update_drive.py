with open('scripts/story_drive.gd', 'r', encoding='utf-8') as f:
    text = f.read()

old_cutscene = """\tif is_skipping:
\t\tskip_hold_time += delta
\t\tif skip_bar:
\t\t\tskip_bar.visible = true
\t\t\tskip_bar.value = (skip_hold_time / 0.75) * 100.0
\t\tif skip_hold_time >= 0.75:
\t\t\t_transition_to_driving()
\t\t\treturn
\telse:
\t\tskip_hold_time = maxf(0.0, skip_hold_time - delta * 2.0)
\t\tif skip_bar:
\t\t\tskip_bar.value = (skip_hold_time / 0.75) * 100.0
\t\t\tif skip_hold_time <= 0.05:
\t\t\t\tskip_bar.visible = false

\t# Cutscene Car Speeds (Realistic night convoy ~18-20 m/s)
\tfor i in range(cars.size()):
\t\tvar car: CharacterBody3D = cars[i]
\t\tif is_instance_valid(car):
\t\t\tvar cutscene_speed := 18.0 + sin(elapsed_time * 1.5 + i * 1.8) * 2.8
\t\t\tcar.set("current_speed", cutscene_speed)
\t\t\tcar.position.z -= cutscene_speed * delta

\t\t\tvar lane_target := 2.1 if (i % 2 == 0) else -2.1
\t\t\tvar road_cx := _get_road_center_x(car.position.z)
\t\t\tcar.position.x = lerpf(car.position.x, road_cx + lane_target + sin(elapsed_time * 2.0 + i) * 0.3, delta * 1.8)
\t\t\tcar.position.y = _get_road_elevation(car.position.z)

\t\t\tcar.call("_update_wheel_and_chassis_animations", delta)

\t# Cinematic Camera Shots
\tvar lead_z: float = cars[0].position.z if not cars.is_empty() else 0.0
\tvar net := get_node_or_null("/root/NetworkManager")
\tvar is_solo: bool = _is_solo_mode()

\t# Shot 1 (0.0s - 3.2s): Low-Angle Roadside Pass
\tif elapsed_time < 3.2:
\t\tvar cam_pos := Vector3(-3.8, 0.75, -45.0)
\t\tcamera.position = cam_pos
\t\tvar target_look := Vector3(0.0, 0.8, lead_z)
\t\tif camera.position.distance_to(target_look) > 0.5:
\t\t\tcamera.look_at(target_look, Vector3.UP)
\t\tif subtitle_label:
\t\t\tif is_solo:
\t\t\t\tsubtitle_label.text = "Laluan 189 • 11:42 PM. Driving alone through the coastal mist after a long journey..."
\t\t\telse:
\t\t\t\tsubtitle_label.text = "Laluan 189 • Pasir Puteh. The siblings convoy home together through the dark."

\t# Shot 2 (3.2s - 6.0s): High-Speed Chase Follow Cam
\telif elapsed_time < 6.0:
\t\tvar last_z: float = cars.back().position.z if not cars.is_empty() else lead_z
\t\tvar cam_pos := Vector3(2.4, 3.4, last_z + 14.0)
\t\tcamera.position = cam_pos
\t\tvar look_target := Vector3(0.0, 1.2, lead_z - 12.0)
\t\tif camera.position.distance_to(look_target) > 0.5:
\t\t\tcamera.look_at(look_target, Vector3.UP)
\t\tif subtitle_label:
\t\t\tif is_solo:
\t\t\t\tsubtitle_label.text = "The highway stretches into the dark. Only the low hum of the engine and the radio static."
\t\t\telse:
\t\t\t\tsubtitle_label.text = "Maya: 'Step on it! Last one back to the estate cleans the cellar!'"

\t# Shot 3 (6.0s - 8.5s): Dynamic Front Angle under Roadlamps
\telif elapsed_time < CUTSCENE_DURATION:
\t\tvar cam_pos := Vector3(-2.8, 1.3, lead_z - 12.0)
\t\tcamera.position = cam_pos
\t\tvar look_target := Vector3(0.0, 1.0, lead_z + 3.0)
\t\tif camera.position.distance_to(look_target) > 0.5:
\t\t\tcamera.look_at(look_target, Vector3.UP)
\t\tif subtitle_label:
\t\t\tif is_solo:
\t\t\t\tsubtitle_label.text = "Almost at Kuala Semerak. Time to take over the wheel."
\t\t\telse:
\t\t\t\tsubtitle_label.text = "Leo: 'In your dreams! Keep up if you can!'"

\telse:
\t\t_transition_to_driving()"""

new_cutscene = """\tif is_skipping:
\t\tskip_hold_time += delta
\t\tif skip_bar:
\t\t\tskip_bar.visible = true
\t\t\tskip_bar.value = (skip_hold_time / 0.75) * 100.0
\t\tif skip_hold_time >= 0.75:
\t\t\tif multiplayer.has_multiplayer_peer() and not _is_solo_mode():
\t\t\t\trpc_sync_transition_to_driving.rpc()
\t\t\telse:
\t\t\t\t_transition_to_driving()
\t\t\treturn
\telse:
\t\tskip_hold_time = maxf(0.0, skip_hold_time - delta * 2.0)
\t\tif skip_bar:
\t\t\tskip_bar.value = (skip_hold_time / 0.75) * 100.0
\t\t\tif skip_hold_time <= 0.05:
\t\t\t\tskip_bar.visible = false

\t# Cutscene Car Speeds (Realistic night convoy ~18-20 m/s)
\tfor i in range(cars.size()):
\t\tvar car: CharacterBody3D = cars[i]
\t\tif is_instance_valid(car):
\t\t\tvar cutscene_speed := 18.0 + sin(elapsed_time * 1.5 + i * 1.8) * 2.8
\t\t\tcar.set("current_speed", cutscene_speed)
\t\t\tcar.position.z -= cutscene_speed * delta

\t\t\t# Malaysian Left-Hand Traffic: Convoy travels in the left lane (-2.1m)
\t\t\tvar lane_target := -2.1 + (0.12 if (i % 2 == 1) else -0.12)
\t\t\tvar road_cx := _get_road_center_x(car.position.z)
\t\t\tcar.position.x = lerpf(car.position.x, road_cx + lane_target + sin(elapsed_time * 2.0 + i) * 0.25, delta * 1.8)
\t\t\tcar.position.y = _get_road_elevation(car.position.z)

\t\t\tcar.call("_update_wheel_and_chassis_animations", delta)

\t# Cinematic Camera Shots
\tvar lead_z: float = cars[0].position.z if not cars.is_empty() else 0.0
\tvar net := get_node_or_null("/root/NetworkManager")
\tvar is_solo: bool = _is_solo_mode()

\t# Shot 1 (0.0s - 3.2s): Low-Angle Roadside Pass on Left Verge
\tif elapsed_time < 3.2:
\t\tvar cam_pos := Vector3(-4.6, 0.85, -45.0)
\t\tcamera.position = cam_pos
\t\tvar target_look := Vector3(-2.1, 0.85, lead_z)
\t\tif camera.position.distance_to(target_look) > 0.5:
\t\t\tcamera.look_at(target_look, Vector3.UP)
\t\tif subtitle_label:
\t\t\tif is_solo:
\t\t\t\tsubtitle_label.text = "Laluan 189 • 11:42 PM. Driving alone through the coastal mist after a long journey..."
\t\t\telse:
\t\t\t\tsubtitle_label.text = "Laluan 189 • Pasir Puteh. The siblings convoy home together through the dark."

\t# Shot 2 (3.2s - 6.0s): High-Speed Chase Follow Cam (Left Lane Convoy)
\telif elapsed_time < 6.0:
\t\tvar last_z: float = cars.back().position.z if not cars.is_empty() else lead_z
\t\tvar cam_pos := Vector3(-1.8, 3.2, last_z + 13.5)
\t\tcamera.position = cam_pos
\t\tvar look_target := Vector3(-2.1, 1.15, lead_z - 12.0)
\t\tif camera.position.distance_to(look_target) > 0.5:
\t\t\tcamera.look_at(look_target, Vector3.UP)
\t\tif subtitle_label:
\t\t\tif is_solo:
\t\t\t\tsubtitle_label.text = "The highway stretches into the dark. Only the low hum of the engine and the radio static."
\t\t\telse:
\t\t\t\tsubtitle_label.text = "Maya: 'Step on it! Last one back to the estate cleans the cellar!'"

\t# Shot 3 (6.0s - 8.5s): Dynamic Front Angle under Roadlamps (Framing Driver at Right)
\telif elapsed_time < CUTSCENE_DURATION:
\t\tvar cam_pos := Vector3(-2.1, 1.35, lead_z - 12.0)
\t\tcamera.position = cam_pos
\t\tvar look_target := Vector3(-2.1, 0.95, lead_z + 2.5)
\t\tif camera.position.distance_to(look_target) > 0.5:
\t\t\tcamera.look_at(look_target, Vector3.UP)
\t\tif subtitle_label:
\t\t\tif is_solo:
\t\t\t\tsubtitle_label.text = "Almost at Kuala Semerak. Time to take over the wheel."
\t\t\telse:
\t\t\t\tsubtitle_label.text = "Leo: 'In your dreams! Keep up if you can!'"

\telse:
\t\tif multiplayer.has_multiplayer_peer() and not _is_solo_mode():
\t\t\tif multiplayer.is_server():
\t\t\t\trpc_sync_transition_to_driving.rpc()
\t\telse:
\t\t\t_transition_to_driving()


@rpc("any_peer", "call_local", "reliable")
func rpc_sync_transition_to_driving() -> void:
\t_transition_to_driving()"""

assert old_cutscene in text, 'old_cutscene not found'
text = text.replace(old_cutscene, new_cutscene)

# Also update _setup_cars
old_cars = """\t\tvar start_lane: float = 2.1
\t\tvar start_z: float = 25.0
\t\tvar road_cx := _get_road_center_x(start_z)
\t\tcar.position = Vector3(road_cx + start_lane, _get_road_elevation(start_z), start_z)

\t\tcar_container.add_child(car)
\t\tcars.append(car)
\t\tplayer_car = car
\t\tprint("StoryDrive: Solo Campaign mode active - 1 lone car spawned (no AI).")
\telse:
\t\t# --- CO-OP STORY: Strictly Human Cars (No AI replacement) ---
\t\tvar palette: Array[Color] = [
\t\t\tColor(0.14, 0.12, 0.15), # Car 1 (Host): Charcoal
\t\t\tColor(0.08, 0.16, 0.28), # Car 2: Navy
\t\t\tColor(0.28, 0.14, 0.06), # Car 3: Amber Bronze
\t\t\tColor(0.07, 0.22, 0.12)  # Car 4: Emerald
\t\t]

\t\tvar p_ids: Array = net.players.keys()
\t\tvar my_id := multiplayer.get_unique_id()

\t\tfor i in range(min(p_ids.size(), 4)):
\t\t\tvar pid: int = p_ids[i]
\t\t\tvar p_info: Dictionary = net.players.get(pid, {})
\t\t\tvar p_name: String = str(p_info.get("name", "Player %d" % pid))

\t\t\tvar car = STORY_CAR_SCRIPT.new()
\t\t\tcar.name = "StoryCar_%d" % pid
\t\t\tcar.sibling_id = pid
\t\t\tcar.sibling_name = p_name
\t\t\tcar.is_host = (pid == 1)
\t\t\tcar.paint_color = palette[i % palette.size()]
\t\t\tcar.is_ai = false # Strictly human player, no bots!

\t\t\tvar start_lane: float = 2.1 if (i % 2 == 0) else -2.1
\t\t\tvar start_z: float = 25.0 + (i * 12.0)
\t\t\tvar road_cx := _get_road_center_x(start_z)
\t\t\tcar.position = Vector3(road_cx + start_lane, _get_road_elevation(start_z), start_z)

\t\t\tcar_container.add_child(car)
\t\tcars.append(car)

\t\t\tif pid == my_id or (i == 0 and player_car == null):
\t\t\t\tplayer_car = car"""

new_cars = """\t\t# Malaysian Left-Hand Traffic: Drive in left lane (-2.1m)
\t\tvar start_lane: float = -2.1
\t\tvar start_z: float = 25.0
\t\tvar road_cx := _get_road_center_x(start_z)
\t\tcar.position = Vector3(road_cx + start_lane, _get_road_elevation(start_z), start_z)

\t\tcar_container.add_child(car)
\t\tcars.append(car)
\t\tplayer_car = car
\t\tprint("StoryDrive: Solo Campaign mode active - 1 lone car spawned in left lane (no AI).")
\telse:
\t\t# --- CO-OP STORY: Strictly Human Cars with Network Authority ---
\t\tvar palette: Array[Color] = [
\t\t\tColor(0.14, 0.12, 0.15), # Car 1 (Host): Charcoal
\t\t\tColor(0.08, 0.16, 0.28), # Car 2: Navy
\t\t\tColor(0.28, 0.14, 0.06), # Car 3: Amber Bronze
\t\t\tColor(0.07, 0.22, 0.12)  # Car 4: Emerald
\t\t]

\t\tvar p_ids: Array = net.players.keys()
\t\t# Deterministic sorting: Host (pid=1) is ALWAYS car 0 on all peers
\t\tp_ids.sort_custom(func(a: int, b: int) -> bool:
\t\t\tif a == 1: return true
\t\t\tif b == 1: return false
\t\t\treturn a < b
\t\t)
\t\tvar my_id := multiplayer.get_unique_id()

\t\tfor i in range(min(p_ids.size(), 4)):
\t\t\tvar pid: int = p_ids[i]
\t\t\tvar p_info: Dictionary = net.players.get(pid, {})
\t\t\tvar p_name: String = str(p_info.get("name", "Player %d" % pid))

\t\t\tvar car = STORY_CAR_SCRIPT.new()
\t\t\tcar.name = "StoryCar_%d" % pid
\t\t\tcar.sibling_id = pid
\t\t\tcar.sibling_name = p_name
\t\t\tcar.is_host = (pid == 1)
\t\t\tcar.paint_color = palette[i % palette.size()]
\t\t\tcar.is_ai = false # Strictly human player, no bots!
\t\t\tcar.set_multiplayer_authority(pid)

\t\t\t# Malaysian Left-Hand Traffic: All cars travel in left lane (-2.1m) in single file convoy
\t\t\tvar start_lane: float = -2.1 + (0.10 if (i % 2 == 1) else -0.10)
\t\t\tvar start_z: float = 25.0 + (i * 12.0)
\t\t\tvar road_cx := _get_road_center_x(start_z)
\t\t\tcar.position = Vector3(road_cx + start_lane, _get_road_elevation(start_z), start_z)

\t\t\tcar_container.add_child(car)
\t\t\tcars.append(car)

\t\t\tif pid == my_id or (i == 0 and player_car == null):
\t\t\t\tplayer_car = car"""

assert old_cars in text, 'old_cars not found'
text = text.replace(old_cars, new_cars)

with open('scripts/story_drive.gd', 'w', encoding='utf-8', newline='\n') as f:
    f.write(text)
print('Successfully updated story_drive.gd!')
