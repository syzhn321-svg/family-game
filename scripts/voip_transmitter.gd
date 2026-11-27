class_name VoipTransmitter
extends Node

## Industry-standard VOIP capture pipeline backed by native C++ TwoVoIP
## (libopus 1.5.2 + RNNoise neural denoiser + SpeexDSP resampler & AGC) and
## direct AudioServer hardware microphone pulling (`get_input_frames`).

signal control_packet_ready(packet: PackedByteArray)
signal audio_packet_ready(packet: PackedByteArray)
signal level_updated(db: float, rms: float, speech_prob: float, is_transmitting: bool)
signal capture_state_changed(active: bool, err: int)

enum VoiceMode { PUSH_TO_TALK, OPEN_MIC, ALWAYS_ON }

const OPUS_SAMPLE_RATE: int = 48000
const OPUS_FRAME_MS: int = 20
const OPUS_CHUNK_SAMPLES: int = 960  # 48000 * 20 / 1000
const OPUS_CHANNELS: int = 1
const OPUS_BITRATE: int = 24000
const OPUS_COMPLEXITY: int = 5
const OPUS_INBAND_FEC_PERC: int = 15

const LEAD_TIME_SEC: float = 0.12        # 120ms C++ lookback captures initial plosives
const HANG_TIME_SEC: float = 0.42        # 420ms Discord-style tail hold after speech stops
const INPUT_GAP_THRESHOLD_SEC: float = 0.12
const TIMESTAMP_HISTORY_SEC: float = 1.0

@export var preview_only: bool = false

var voice_mode: VoiceMode = VoiceMode.OPEN_MIC
var is_muted: bool = false
var ptt_held: bool = false
var mic_threshold_db: float = -36.0
var mic_sensitivity: float = 1.0

var _encoder: TwovoipOpusEncoder = null
var _chunk_prefix: PackedByteArray = PackedByteArray()
var _configured_input_rate: int = 0
var _capture_active: bool = false
var _capture_starting: bool = false
var _resume_flush_pending: bool = false

var _currently_talking: bool = false
var _opus_stream_count: int = 0
var _opus_frame_count: int = 0
var _frame0_usec: int = 0
var _talking_start_sec: float = 0.0
var _talking_sum_squares: float = 0.0

var _vad_hold_timer: float = 0.0
var _input_chunk_number: int = -1
var _input_chunk_times_usec: PackedInt64Array = PackedInt64Array()

var _last_db: float = -80.0
var _last_rms: float = 0.0
var _last_speech_prob: float = 0.0


func _ready() -> void:
	set_process(false)
	_chunk_prefix = TwoVoipPacket.make_sequence_chunk_prefix()


func _exit_tree() -> void:
	stop_capture()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Reset any in-flight episode after mobile background/suspend so clock doesn't jump.
		_resume_flush_pending = true
		if _capture_active:
			AudioServer.set_input_device_active(true)


## Starts OS hardware microphone capture and initializes native Opus/RNNoise DSP.
func start_capture() -> void:
	if _capture_active or _capture_starting:
		return
	if not ClassDB.class_exists("TwovoipOpusEncoder"):
		push_warning("VoipTransmitter: TwovoipOpusEncoder native extension unavailable.")
		capture_state_changed.emit(false, ERR_UNAVAILABLE)
		return

	_capture_starting = true
	if OS.get_name() == "Android":
		var granted: PackedStringArray = OS.get_granted_permissions()
		if not granted.has("android.permission.RECORD_AUDIO"):
			if not OS.request_permission("android.permission.RECORD_AUDIO"):
				var res: Array = await get_tree().on_request_permissions_result
				if res.size() < 2 or not bool(res[1]):
					push_warning("VoipTransmitter: Android RECORD_AUDIO permission denied.")
					_capture_starting = false
					capture_state_changed.emit(false, ERR_UNAUTHORIZED)
					return

	var err: Error = AudioServer.set_input_device_active(true)
	if err != OK:
		push_warning("VoipTransmitter: AudioServer.set_input_device_active(true) returned %s." % error_string(err))
		_capture_starting = false
		capture_state_changed.emit(false, err)
		return

	var ok: bool = _init_encoder()
	_capture_starting = false
	_capture_active = ok
	if ok:
		set_process(true)
		print("VoipTransmitter: Direct hardware pull started (%d Hz -> %d Hz Opus/RNNoise/AGC)." % [
			_configured_input_rate, OPUS_SAMPLE_RATE
		])
	capture_state_changed.emit(ok, OK if ok else ERR_CANT_CREATE)


## Ends any open speech stream and shuts down hardware microphone capture.
func stop_capture() -> void:
	set_process(false)
	if _currently_talking:
		_end_talk_episode()
	if _capture_active:
		AudioServer.set_input_device_active(false)
	_capture_active = false
	_capture_starting = false
	capture_state_changed.emit(false, OK)


## Updates sensitivity gain inside the native C++ encoder and the dB noise gate.
func configure_mic_settings(p_threshold_db: float, p_sensitivity: float) -> void:
	mic_threshold_db = p_threshold_db
	mic_sensitivity = clampf(p_sensitivity, 0.25, 4.0)
	if _encoder:
		_encoder.set_gain(mic_sensitivity)


## Emits a fresh START control packet snapshot for peers who connect mid-sentence.
func get_midstream_control_packets() -> Array[PackedByteArray]:
	if not _currently_talking or not _encoder:
		return []
	var hdr: Array = TwoVoipPacket.make_header(
		TwoVoipPacket.TYPE_START,
		OPUS_CHUNK_SAMPLES,
		OPUS_SAMPLE_RATE,
		OPUS_CHANNELS,
		_chunk_prefix.size(),
		_opus_stream_count,
		_opus_frame_count,
		_get_next_frame_time_usec(),
		_encoder.get_bitrate(),
		false,
		0
	)
	return [TwoVoipPacket.encode_control_packet(hdr)]


func _init_encoder() -> bool:
	var input_rate: int = int(round(AudioServer.get_input_mix_rate()))
	if input_rate <= 0:
		input_rate = int(round(AudioServer.get_mix_rate()))
	if input_rate <= 0:
		input_rate = OPUS_SAMPLE_RATE

	_encoder = TwovoipOpusEncoder.new()
	var frame_secs: float = float(OPUS_FRAME_MS) / 1000.0
	_input_chunk_times_usec.resize(ceili(TIMESTAMP_HISTORY_SEC / frame_secs) + 2)
	_input_chunk_times_usec.fill(0)
	_input_chunk_number = -1
	_configured_input_rate = input_rate

	var err: Error = _encoder.initialize(
		input_rate,
		OPUS_SAMPLE_RATE,
		OPUS_CHANNELS,
		TwovoipOpusEncoder.DENOISER_RNNOISE,
		TwovoipOpusEncoder.AGC_APPLIED,
		OPUS_CHUNK_SAMPLES
	)
	if err != OK:
		push_error("VoipTransmitter: TwovoipOpusEncoder.initialize failed (%s)." % error_string(err))
		_encoder = null
		return false

	_encoder.target_agc_gain(5.0)
	_encoder.set_gain(mic_sensitivity)
	_encoder.set_bitrate(OPUS_BITRATE)
	_encoder.set_complexity(OPUS_COMPLEXITY)
	_encoder.set_signal_type(TwovoipOpusEncoder.SIGNAL_VOICE)
	_encoder.set_inband_perc(OPUS_INBAND_FEC_PERC)
	return true


func _process(delta: float) -> void:
	if not _capture_active or not _encoder:
		return

	# Reconfigure SpeexDSP resampler automatically if OS hardware input rate changes (e.g. BT HFP).
	var live_in_rate: int = int(round(AudioServer.get_input_mix_rate()))
	if live_in_rate > 0 and live_in_rate != _configured_input_rate:
		if _currently_talking:
			_end_talk_episode()
		if not _init_encoder():
			return

	if _resume_flush_pending:
		_resume_flush_pending = false
		if _currently_talking:
			_end_talk_episode()
		var stale: int = AudioServer.get_input_frames_available()
		if stale > 0:
			AudioServer.get_input_frames(stale)
		return

	var req_frames: int = _encoder.get_required_input_chunk_size()
	if req_frames <= 0:
		return

	var processed_any: bool = false
	var chunk_secs: float = float(OPUS_FRAME_MS) / 1000.0

	while true:
		var avail: int = AudioServer.get_input_frames_available()
		var first_frame_usec: int = Time.get_ticks_usec() - roundi(
			float(avail) * 1000000.0 / float(_configured_input_rate)
		)

		var gap_plan: Dictionary = _plan_input_gap(first_frame_usec)
		if not gap_plan.is_empty():
			var discard_frames: int = 0 if bool(gap_plan.end_episode) else int(gap_plan.discard_input_frames)
			if avail < discard_frames:
				break
			if discard_frames > 0:
				var discarded := AudioServer.get_input_frames(discard_frames)
				if discarded.size() != discard_frames:
					break
				first_frame_usec = int(gap_plan.next_frame_time_usec)
			_apply_input_gap(gap_plan)
			avail -= discard_frames

		if avail < req_frames:
			break

		var raw_chunk: PackedVector2Array = AudioServer.get_input_frames(req_frames)
		if raw_chunk.is_empty():
			break

		if _encoder.push_input_chunk(raw_chunk) < 0:
			break

		_input_chunk_number += 1
		_input_chunk_times_usec[_input_chunk_number % _input_chunk_times_usec.size()] = first_frame_usec

		# Run RNNoise + AGC on chunk 0 in C++
		_encoder.denoise_chunk(0)
		_last_rms = _encoder.get_rms()
		_last_db = _linear_to_db(_last_rms)
		_last_speech_prob = _encoder.get_speech_probability()
		processed_any = true

		var should_transmit: bool = _evaluate_vad(chunk_secs, _last_db, _last_speech_prob)
		if not preview_only:
			if should_transmit and not _currently_talking:
				_begin_talk_episode()
			elif should_transmit and _currently_talking:
				_emit_opus_chunk(0)
			elif not should_transmit and _currently_talking:
				_end_talk_episode()
		elif _currently_talking:
			_end_talk_episode()

	if not processed_any:
		# Advance hold countdown smoothly even while waiting for next OS hardware block.
		if not is_muted and voice_mode == VoiceMode.OPEN_MIC:
			_vad_hold_timer = maxf(0.0, _vad_hold_timer - delta)
			if _vad_hold_timer <= 0.0 and _currently_talking and not preview_only:
				_end_talk_episode()

	level_updated.emit(_last_db, _last_rms, _last_speech_prob, _currently_talking or _should_indicator_active())


func _should_indicator_active() -> bool:
	if is_muted:
		return false
	if voice_mode == VoiceMode.ALWAYS_ON:
		return true
	if voice_mode == VoiceMode.PUSH_TO_TALK:
		return ptt_held
	return _vad_hold_timer > 0.0


func _evaluate_vad(step_delta: float, current_db: float, speech_prob: float) -> bool:
	if is_muted:
		_vad_hold_timer = 0.0
		return false
	if voice_mode == VoiceMode.ALWAYS_ON:
		return true
	if voice_mode == VoiceMode.PUSH_TO_TALK:
		return ptt_held

	# Hybrid Discord dB gate + RNNoise neural voice probability
	var speech_triggered: bool = (current_db > mic_threshold_db and speech_prob >= 0.15) \
		or (current_db > (mic_threshold_db + 6.0))
	if speech_triggered:
		_vad_hold_timer = HANG_TIME_SEC
	elif _vad_hold_timer > 0.0 and current_db > (mic_threshold_db - 4.0):
		# Sustain smoothly down to -4 dB hysteresis band on tail consonants
		_vad_hold_timer = maxf(0.0, _vad_hold_timer - step_delta * 0.5)
	else:
		_vad_hold_timer = maxf(0.0, _vad_hold_timer - step_delta)
	return _vad_hold_timer > 0.0


func _begin_talk_episode() -> void:
	if _input_chunk_number < 0 or not _encoder:
		return
	var frame_secs: float = float(OPUS_FRAME_MS) / 1000.0
	var avail_back: int = mini(_input_chunk_number, _input_chunk_times_usec.size() - 1)
	var lead_chunks: int = mini(int(LEAD_TIME_SEC / frame_secs), avail_back)
	var start_usec: int = _get_history_time_usec(lead_chunks)
	_talking_start_sec = Time.get_ticks_msec() * 0.001 - float(lead_chunks) * frame_secs

	var hdr: Array = TwoVoipPacket.make_header(
		TwoVoipPacket.TYPE_START,
		OPUS_CHUNK_SAMPLES,
		OPUS_SAMPLE_RATE,
		OPUS_CHANNELS,
		_chunk_prefix.size(),
		_opus_stream_count,
		0,
		start_usec,
		_encoder.get_bitrate(),
		false,
		lead_chunks
	)
	control_packet_ready.emit(TwoVoipPacket.encode_control_packet(hdr))

	_encoder.reset_opus_encoder()
	_opus_frame_count = 0
	_frame0_usec = start_usec
	_talking_sum_squares = 0.0
	_currently_talking = true

	# Encode pre-rolled C++ chunks oldest -> newest (0 = current chunk)
	for i in range(lead_chunks + 1):
		_emit_opus_chunk(lead_chunks - i)


func _emit_opus_chunk(chunks_back: int) -> void:
	if not _currently_talking or not _encoder:
		return
	TwoVoipPacket.set_sequence_chunk_prefix(_chunk_prefix, _opus_frame_count, _opus_stream_count)
	var raw_opus: PackedByteArray = _encoder.encode_chunk(_chunk_prefix, chunks_back)
	audio_packet_ready.emit(TwoVoipPacket.encode_audio_packet(raw_opus, false))
	_opus_frame_count += 1
	_talking_sum_squares += _encoder.get_chunk_sum_squares(chunks_back)


func _end_talk_episode() -> void:
	if not _currently_talking:
		return
	_currently_talking = false
	var end_sec: float = Time.get_ticks_msec() * 0.001
	var duration_sec: float = maxf(0.0, end_sec - _talking_start_sec)
	var sent_rms: float = sqrt(_talking_sum_squares / float(_opus_frame_count * OPUS_CHUNK_SAMPLES)) \
		if _opus_frame_count > 0 else 0.0
	var footer: Array = TwoVoipPacket.make_footer(
		_opus_stream_count,
		_opus_frame_count,
		duration_sec,
		end_sec,
		sent_rms
	)
	control_packet_ready.emit(TwoVoipPacket.encode_control_packet(footer))
	_opus_stream_count += 1


func _get_next_frame_time_usec() -> int:
	return _frame0_usec + _opus_frame_count * OPUS_FRAME_MS * 1000


func _get_history_time_usec(chunks_back: int) -> int:
	if chunks_back < 0 or chunks_back > mini(_input_chunk_number, _input_chunk_times_usec.size() - 1):
		return 0
	return _input_chunk_times_usec[(_input_chunk_number - chunks_back) % _input_chunk_times_usec.size()]


func _plan_input_gap(frame_usec: int) -> Dictionary:
	if not _currently_talking or frame_usec == 0 or _frame0_usec == 0:
		return {}
	var frame_dur_usec: int = OPUS_FRAME_MS * 1000
	var predicted_usec: int = _frame0_usec + _opus_frame_count * frame_dur_usec
	var gap_usec: int = frame_usec - predicted_usec
	if gap_usec >= roundi(INPUT_GAP_THRESHOLD_SEC * 1000000.0):
		var missing_frames: int = ceili(float(gap_usec) / float(frame_dur_usec))
		if missing_frames <= 0:
			return {}
		var next_usec: int = predicted_usec + missing_frames * frame_dur_usec
		var discard_frames: int = ceili(maxi(0, next_usec - frame_usec) * float(_configured_input_rate) / 1000000.0)
		return {
			"missing_frame_count": missing_frames,
			"next_frame_time_usec": next_usec,
			"discard_input_frames": discard_frames,
			"end_episode": float(gap_usec) > HANG_TIME_SEC * 1000000.0,
		}
	return {}


func _apply_input_gap(gap_plan: Dictionary) -> void:
	if gap_plan.is_empty():
		return
	if bool(gap_plan.end_episode):
		_end_talk_episode()
		return
	var missing_frames: int = int(gap_plan.missing_frame_count)
	var next_usec: int = int(gap_plan.next_frame_time_usec)
	var stored: int = _encoder.push_silent_input_chunks(missing_frames)
	for c in range(maxi(0, stored)):
		_input_chunk_number += 1
		_input_chunk_times_usec[_input_chunk_number % _input_chunk_times_usec.size()] = \
			next_usec - (stored - c) * OPUS_FRAME_MS * 1000
	_opus_frame_count += missing_frames
	var mid: Array = TwoVoipPacket.make_mid(_opus_stream_count, _opus_frame_count, next_usec, _encoder.get_bitrate())
	control_packet_ready.emit(TwoVoipPacket.encode_control_packet(mid))


static func _linear_to_db(lin: float) -> float:
	if lin <= 0.00001:
		return -80.0
	return 20.0 * (log(lin) / log(10.0))
