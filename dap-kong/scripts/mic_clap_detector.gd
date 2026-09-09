extends Node
class_name MicClapDetector
## Protótipo de captura de microfone para jogo de ritmo.
## Detecta o "dap" (palma) do jogador, filtra ruído ambiente
## e gera uma nota (0.0 a 1.0) baseada na intensidade do som,
## além de uma pontuação de "perfeição" comparando com um alvo esperado.
##
## USO BÁSICO:
##   1. Adicione este script como um Node na sua cena (ou Autoload).
##   2. Conecte os sinais:
##        mic_ready.connect(_on_mic_ready)
##        clap_detected.connect(_on_clap_detected)
##   3. Quando a nota esperada do ritmo mudar, chame:
##        set_target_note(0.0 a 1.0)
##   4. Ao receber "clap_detected", use evaluate_perfection() se quiser
##      comparar com a nota alvo manualmente (ou já vem calculado no sinal).

# --- Sinais -----------------------------------------------------------

## Emitido assim que a calibração de ruído termina e o mic está pronto pra jogar.
signal mic_ready(noise_floor_db: float)

## Emitido a cada dap detectado.
## note_value: 0.0 (fraco) a 1.0 (mais forte) -> "altura" da nota
## peak_db: valor bruto em decibéis captado
## perfection: 0.0 a 1.0, o quão perto ficou da nota alvo (se houver uma definida)
## rank: string com classificação textual
signal clap_detected(note_value: float, peak_db: float, perfection: float, rank: String)

## Emitido continuamente durante a calibração inicial (útil pra mostrar uma barrinha de progresso).
signal calibration_progress(percent: float)


# --- Configuráveis no Inspector ----------------------------------------

@export_group("Áudio")
@export var bus_name: String = "Mic"          ## Nome do Audio Bus dedicado ao microfone
@export var mic_device: String = ""            ## Deixe vazio para usar o dispositivo padrão

@export_group("Calibração de ruído")
@export var calibration_time: float = 2.0      ## Segundos "ouvindo" o ambiente antes de começar
@export var noise_margin_db: float = 3.0       ## Margem de segurança acima do pico medido no ambiente
@export var threshold_above_floor_db: float = 12.0 ## Quanto acima do ruído de fundo já conta como dap

@export_group("Faixa de volume esperada do dap")
@export var min_expected_db: float = -35.0     ## dB de um dap bem fraco (perto do limiar)
@export var max_expected_db: float = -15.0     ## dB de um dap bem forte

@export_group("Detecção")
@export var cooldown_time: float = 0.22        ## Tempo mínimo entre dois daps detectados
@export var capture_window: float = 0.12       ## Janela após o início do som pra capturar o pico real (evita detectar o mesmo dap várias vezes)

@export_group("Perfeição")
@export var perfect_tolerance: float = 0.08    ## Diferença máxima p/ ser "PERFEITO"
@export var great_tolerance: float = 0.18      ## Diferença máxima p/ ser "ÓTIMO"
@export var good_tolerance: float = 0.32       ## Diferença máxima p/ ser "BOM"


# --- Estado interno -----------------------------------------------------

enum _State { IDLE, CAPTURING, COOLDOWN }

var _bus_idx: int = -1
var _player: AudioStreamPlayer
var _noise_floor_db: float = -60.0
var _calibrating: bool = false
var _calibration_elapsed: float = 0.0
var _calibration_samples: PackedFloat32Array = []
var _cooldown_timer: float = 0.0
var _target_note: float = -1.0  # -1 = nenhuma nota alvo definida agora
var is_ready: bool = false

var _state: int = _State.IDLE
var _capture_peak_db: float = -1000.0
var _capture_timer: float = 0.0


func _ready() -> void:
	_setup_bus_and_filters()
	_setup_mic_player()
	start_calibration()


func _process(delta: float) -> void:
	if _bus_idx == -1:
		return

	var db := _get_peak_db()

	if _calibrating:
		_calibration_elapsed += delta
		_calibration_samples.append(db)
		calibration_progress.emit(clamp(_calibration_elapsed / calibration_time, 0.0, 1.0))
		if _calibration_elapsed >= calibration_time:
			_finish_calibration()
		return

	var gate := _noise_floor_db + threshold_above_floor_db

	match _state:
		_State.IDLE:
			if db > gate:
				# Início de um possível dap: começa a capturar o pico real
				# durante uma pequena janela, em vez de disparar na hora.
				# Isso evita registrar o mesmo dap várias vezes enquanto
				# o medidor de volume ainda está "decaindo" do pico.
				_state = _State.CAPTURING
				_capture_peak_db = db
				_capture_timer = capture_window

		_State.CAPTURING:
			_capture_peak_db = max(_capture_peak_db, db)
			_capture_timer -= delta
			if _capture_timer <= 0.0:
				_register_clap(_capture_peak_db)
				_state = _State.COOLDOWN
				_cooldown_timer = cooldown_time

		_State.COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				_state = _State.IDLE


# --- Setup ---------------------------------------------------------------

func _setup_bus_and_filters() -> void:
	_bus_idx = AudioServer.get_bus_index(bus_name)
	if _bus_idx == -1:
		# Cria o bus dinamicamente se ele não existir no Audio Bus Layout do projeto.
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, bus_name)
		# OBS: não deixamos o bus mudo aqui de propósito — em algumas versões do Godot
		# o mute zera o sinal antes do medidor de pico calcular, travando a leitura em 0dB.
		# Recomendação: use fone de ouvido durante os testes pra evitar microfonia,
		# já que o som do mic vai sair pelas caixas normalmente.

	# Corta ruído grave de ambiente (ventilador, ar-condicionado, trânsito, vozes graves).
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 400.0
	AudioServer.add_bus_effect(_bus_idx, hp)

	# Corta chiado/agudo excessivo que não é o som de palma.
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 8000.0
	AudioServer.add_bus_effect(_bus_idx, lp)

	# Normaliza a dinâmica: ambiente barulhento tem picos irregulares,
	# o compressor deixa a resposta mais consistente pra detecção.
	var comp := AudioEffectCompressor.new()
	comp.threshold = -24.0
	comp.ratio = 4.0
	comp.attack_us = 5.0
	comp.release_ms = 60.0
	AudioServer.add_bus_effect(_bus_idx, comp)


func _setup_mic_player() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.bus = bus_name
	_player.stream = AudioStreamMicrophone.new()
	_player.play()


func start_calibration() -> void:
	_calibrating = true
	_calibration_elapsed = 0.0
	_calibration_samples.clear()
	_state = _State.IDLE
	_cooldown_timer = 0.0
	_capture_timer = 0.0
	is_ready = false


func _finish_calibration() -> void:
	_calibrating = false

	if _calibration_samples.is_empty():
		_noise_floor_db = -60.0
	else:
		var soma := 0.0
		var maximo := -120.0
		for v in _calibration_samples:
			soma += v
			maximo = max(maximo, v)
		var media := soma / _calibration_samples.size()
		# Usa o maior entre "média do ambiente" e "pico do ambiente - margem"
		# pra não deixar um pico isolado (ex: uma cadeira arrastando) bagunçar tudo.
		_noise_floor_db = max(media, maximo - noise_margin_db)

	is_ready = true
	mic_ready.emit(_noise_floor_db)


# --- Detecção e pontuação -------------------------------------------------

func _get_peak_db() -> float:
	# O segundo parâmetro é o índice do grupo de canais do bus (quase sempre 0),
	# NÃO é "esquerda/direita". Pra pegar os dois lados, usa-se left_db e right_db.
	var l := AudioServer.get_bus_peak_volume_left_db(_bus_idx, 0)
	var r := AudioServer.get_bus_peak_volume_right_db(_bus_idx, 0)
	return max(l, r)


func _register_clap(peak_db: float) -> void:
	var note_value: float = clamp(
		inverse_lerp(min_expected_db, max_expected_db, peak_db), 0.0, 1.0
	)

	var perfection := 1.0
	var rank := "SEM ALVO"
	if _target_note >= 0.0:
		perfection = evaluate_perfection(note_value, _target_note)
		rank = _perfection_to_rank(perfection)

	clap_detected.emit(note_value, peak_db, perfection, rank)


## Chame isso a cada evento de ritmo pra dizer qual nota o jogo espera
## naquele momento (ex: um dap fraco = 0.2, um dap forte = 0.9).
## Passe -1.0 pra "nenhum alvo" (a nota só é reportada, sem avaliação).
func set_target_note(target: float) -> void:
	_target_note = target


## Retorna 0.0 (errou feio) a 1.0 (perfeito) comparando o valor captado com o alvo.
func evaluate_perfection(note_value: float, target: float) -> float:
	var diff: float = abs(note_value - target)
	return clamp(1.0 - diff, 0.0, 1.0)


func _perfection_to_rank(perfection: float) -> String:
	var diff := 1.0 - perfection
	if diff <= perfect_tolerance:
		return "PERFEITO"
	elif diff <= great_tolerance:
		return "ÓTIMO"
	elif diff <= good_tolerance:
		return "BOM"
	else:
		return "ERROU"
