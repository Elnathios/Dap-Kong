extends Control
## Cena de teste para calibrar o MicClapDetector no ambiente real.
##
## COMO USAR:
##   1. Coloque este arquivo e o "mic_clap_detector.gd" na mesma pasta do projeto
##      (ex: res://mic_clap_detector.gd e res://test_mic_scene.gd).
##      Se você colocar em outra pasta, ajuste o caminho do preload abaixo.
##   2. Crie uma nova Cena no Godot: Scene > New Scene > "User Interface" (raiz tipo Control).
##   3. Selecione o node raiz e anexe este script a ele (Attach Script > escolha este arquivo,
##      ou aponte o script existente).
##   4. Rode a cena (F6). Fique em silêncio nos primeiros segundos (calibração),
##      depois dê um dap para ver a barra, o dB e a nota reagindo.

const MicClapDetectorScript = preload("res://scripts/mic_clap_detector.gd")

var mic  # instância do MicClapDetector
var volume_bar: ProgressBar
var db_label: Label
var status_label: Label
var noise_label: Label
var clap_label: Label
var target_slider: HSlider
var target_label: Label
var recalibrate_button: Button

var _clap_display_timer: float = 0.0


func _ready() -> void:
	# Faz o Control raiz preencher toda a viewport/janela.
	# Sem isso, o root nasce com tamanho (0,0) e nada aparece na tela,
	# mesmo com os filhos configurados corretamente.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	mic = MicClapDetectorScript.new()
	add_child(mic)
	mic.mic_ready.connect(_on_mic_ready)
	mic.clap_detected.connect(_on_clap_detected)
	mic.calibration_progress.connect(_on_calibration_progress)

	status_label.text = "Calibrando... fique em silêncio por alguns segundos"


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	add_child(vbox)

	var title := Label.new()
	title.text = "Teste de Microfone - Detector de Dap"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	status_label = Label.new()
	vbox.add_child(status_label)

	var db_row := HBoxContainer.new()
	vbox.add_child(db_row)
	var db_caption := Label.new()
	db_caption.text = "Volume atual: "
	db_row.add_child(db_caption)
	db_label = Label.new()
	db_label.text = "-- dB"
	db_row.add_child(db_label)

	volume_bar = ProgressBar.new()
	volume_bar.min_value = -60
	volume_bar.max_value = 0
	volume_bar.value = -60
	volume_bar.show_percentage = false
	volume_bar.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(volume_bar)

	noise_label = Label.new()
	noise_label.text = "Piso de ruído: aguardando calibração..."
	vbox.add_child(noise_label)

	vbox.add_child(HSeparator.new())

	var target_row := HBoxContainer.new()
	vbox.add_child(target_row)
	var target_caption := Label.new()
	target_caption.text = "Nota alvo p/ testar perfeição: "
	target_row.add_child(target_caption)
	target_label = Label.new()
	target_label.text = "0.50"
	target_row.add_child(target_label)

	target_slider = HSlider.new()
	target_slider.min_value = 0.0
	target_slider.max_value = 1.0
	target_slider.step = 0.01
	target_slider.value = 0.5
	target_slider.custom_minimum_size = Vector2(0, 20)
	target_slider.value_changed.connect(_on_target_slider_changed)
	vbox.add_child(target_slider)

	vbox.add_child(HSeparator.new())

	clap_label = Label.new()
	clap_label.text = "Dê um dap para testar!"
	clap_label.add_theme_font_size_override("font_size", 18)
	clap_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(clap_label)

	recalibrate_button = Button.new()
	recalibrate_button.text = "Recalibrar ruído do ambiente"
	recalibrate_button.pressed.connect(_on_recalibrate_pressed)
	vbox.add_child(recalibrate_button)

	_on_target_slider_changed(target_slider.value)


func _process(delta: float) -> void:
	if mic == null or not is_instance_valid(mic):
		return

	# Leitura contínua só para visualização em tempo real (o detector já lê isso internamente).
	var bus_idx := AudioServer.get_bus_index(mic.bus_name)
	if bus_idx != -1:
		var db := AudioServer.get_bus_peak_volume_left_db(bus_idx, 0)
		db_label.text = "%.1f dB" % db
		volume_bar.value = clamp(db, volume_bar.min_value, volume_bar.max_value)

	if _clap_display_timer > 0.0:
		_clap_display_timer -= delta
		if _clap_display_timer <= 0.0:
			clap_label.text = "Dê um dap para testar!"
			clap_label.modulate = Color.WHITE


func _on_calibration_progress(percent: float) -> void:
	status_label.text = "Calibrando... %d%% (fique em silêncio)" % int(percent * 100.0)


func _on_mic_ready(noise_floor_db: float) -> void:
	status_label.text = "Pronto! Pode dar o dap."
	noise_label.text = "Piso de ruído medido: %.1f dB" % noise_floor_db


func _on_clap_detected(note_value: float, peak_db: float, perfection: float, rank: String) -> void:
	clap_label.text = "Nota: %.2f  |  dB: %.1f  |  Perfeição: %.0f%%  |  %s" % [
		note_value, peak_db, perfection * 100.0, rank
	]
	match rank:
		"PERFEITO":
			clap_label.modulate = Color.GOLD
		"ÓTIMO":
			clap_label.modulate = Color.LIGHT_GREEN
		"BOM":
			clap_label.modulate = Color.LIGHT_BLUE
		_:
			clap_label.modulate = Color.LIGHT_CORAL
	_clap_display_timer = 2.0


func _on_target_slider_changed(value: float) -> void:
	target_label.text = "%.2f" % value
	if mic:
		mic.set_target_note(value)


func _on_recalibrate_pressed() -> void:
	status_label.text = "Recalibrando..."
	noise_label.text = "Piso de ruído: aguardando calibração..."
	mic.start_calibration()
