class_name SaveManagerClass
extends Node

## SaveManager handles Solo Campaign saves, Checkpoints, and Co-op Chapter Progression.

signal campaign_saved()
signal campaign_loaded(save_data: Dictionary)
signal chapter_unlocked(chapter_id: int, chapter_title: String)

const SAVE_DIR: String = "user://saves/"
const CAMPAIGN_SAVE_PATH: String = "user://saves/campaign_save.json"
const COOP_HOST_SAVE_PATH: String = "user://saves/coop_host_save.json"
const PROFILE_PATH: String = "user://saves/player_profile.json"

# Chapter Definitions
const CHAPTERS: Array[Dictionary] = [
	{
		"id": 1,
		"title": "Chapter 1: The Midnight Return",
		"subtitle": "Laluan 189 • Jambatan Tok Bali to Kandiez Beach Resort",
		"scene": "res://scenes/story_drive.tscn"
	},
	{
		"id": 2,
		"title": "Chapter 2: The Beach Chalet",
		"subtitle": "Kandiez Sunrise Beach Resort • Gathering Clues",
		"scene": "res://scenes/main.tscn"
	}
]

var campaign_data: Dictionary = {}
var profile_data: Dictionary = {}


func _ready() -> void:
	_ensure_save_directory()
	_load_profile()
	_load_campaign_data_silent()


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# --- Solo Campaign Save Management ---

func has_campaign_save() -> bool:
	return FileAccess.file_exists(CAMPAIGN_SAVE_PATH)


func get_campaign_save_summary() -> Dictionary:
	if not has_campaign_save():
		return {}
	
	var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var json_str := file.get_as_text()
	var json := JSON.new()
	if json.parse(json_str) == OK and json.data is Dictionary:
		return json.data
	return {}


func load_campaign_save() -> Dictionary:
	var summary := get_campaign_save_summary()
	if not summary.is_empty():
		campaign_data = summary
		campaign_loaded.emit(campaign_data)
		print("SaveManager: Loaded campaign save - %s (%s)" % [
			campaign_data.get("chapter_title", "Chapter 1"),
			campaign_data.get("checkpoint_display", "Start")
		])
		return campaign_data
	return {}


func save_campaign_progress(chapter_id: int, chapter_title: String, checkpoint_id: String, checkpoint_display: String, story_flags: Dictionary = {}) -> bool:
	_ensure_save_directory()
	
	var net := get_node_or_null("/root/NetworkManager")
	var p_name: String = "Player"
	if net and not net.local_player_name.is_empty():
		p_name = net.local_player_name

	# Merge existing flags if available
	var merged_flags: Dictionary = campaign_data.get("story_flags", {}).duplicate()
	for k in story_flags:
		merged_flags[k] = story_flags[k]

	var save_obj := {
		"version": 1,
		"chapter_id": chapter_id,
		"chapter_title": chapter_title,
		"checkpoint_id": checkpoint_id,
		"checkpoint_display": checkpoint_display,
		"player_name": p_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"story_flags": merged_flags
	}

	var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for writing at %s" % CAMPAIGN_SAVE_PATH)
		return false

	var json_text := JSON.stringify(save_obj, "\t")
	file.store_string(json_text)
	file.close()

	campaign_data = save_obj
	campaign_saved.emit()
	print("SaveManager: Saved campaign progress -> %s : %s" % [chapter_title, checkpoint_display])

	# Also unlock in player profile
	unlock_chapter(chapter_id, chapter_title)
	return true


func delete_campaign_save() -> bool:
	if FileAccess.file_exists(CAMPAIGN_SAVE_PATH):
		var err := DirAccess.remove_absolute(CAMPAIGN_SAVE_PATH)
		campaign_data = {}
		print("SaveManager: Deleted campaign save.")
		return err == OK
	return false


# --- Player Profile & Chapter Progression ---

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		profile_data = {
			"version": 1,
			"unlocked_chapters": [1], # Chapter 1 unlocked by default
			"achievements": [],
			"player_name": ""
		}
		_save_profile()
		return

	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			profile_data = json.data
		file.close()

	if not profile_data.has("unlocked_chapters"):
		profile_data["unlocked_chapters"] = [1]

	var saved_name := str(profile_data.get("player_name", "")).strip_edges()
	if not saved_name.is_empty():
		var net := get_node_or_null("/root/NetworkManager")
		if net:
			net.local_player_name = saved_name


func get_player_name() -> String:
	return str(profile_data.get("player_name", "")).strip_edges()


func set_player_name(p_name: String) -> void:
	var clean := p_name.strip_edges()
	profile_data["player_name"] = clean
	_save_profile()
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.local_player_name = clean


func has_player_name() -> bool:
	var n: String = get_player_name()
	return not n.is_empty() and n.to_lower() != "player"


func _save_profile() -> void:
	_ensure_save_directory()
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile_data, "\t"))
		file.close()


func unlock_chapter(chapter_id: int, chapter_title: String) -> void:
	var unlocked: Array = profile_data.get("unlocked_chapters", [1])
	if not unlocked.has(chapter_id):
		unlocked.append(chapter_id)
		profile_data["unlocked_chapters"] = unlocked
		_save_profile()
		chapter_unlocked.emit(chapter_id, chapter_title)
		print("SaveManager: Unlocked %s!" % chapter_title)


func get_unlocked_chapters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var unlocked: Array = profile_data.get("unlocked_chapters", [1])
	for ch in CHAPTERS:
		if unlocked.has(ch["id"]):
			result.append(ch)
	return result


# --- Co-op Host Save Management ---

func save_coop_host_progress(chapter_id: int, chapter_title: String, checkpoint_id: String, checkpoint_display: String) -> bool:
	_ensure_save_directory()
	var save_obj := {
		"version": 1,
		"chapter_id": chapter_id,
		"chapter_title": chapter_title,
		"checkpoint_id": checkpoint_id,
		"checkpoint_display": checkpoint_display,
		"timestamp": Time.get_datetime_string_from_system()
	}
	var file := FileAccess.open(COOP_HOST_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_obj, "\t"))
		file.close()
		print("SaveManager: Saved Co-op host progress -> %s" % chapter_title)
		unlock_chapter(chapter_id, chapter_title)
		return true
	return false


func _load_campaign_data_silent() -> void:
	if has_campaign_save():
		var summary := get_campaign_save_summary()
		if not summary.is_empty():
			campaign_data = summary
