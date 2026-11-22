extends Node
## Carga las traducciones base desde el CSV canónico y controla el locale.
##
## Se evita depender de los artefactos .translation generados por el importador:
## el CSV es la fuente de verdad y también funciona en exports.

const CSV_PATH := "res://localization/strings.csv"
const FALLBACK_LOCALE := "es_VE"
const LOCALES := [
	"es_VE",
	"es_ES",
	"en",
	"pt_PT",
	"pt_BR",
	"it",
	"fr",
	"de",
	"ru",
	"zh_CN",
	"ja",
]

var _translations: Dictionary = {}
var _current_locale := FALLBACK_LOCALE
var _applying_locale := false


func _ready() -> void:
	_load_translations()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.diagnostics_context_requested.connect(_on_diagnostics_context_requested)
	var saved_locale := str(SettingsManager.get_value("gameplay", "language", FALLBACK_LOCALE))
	set_locale(saved_locale, false)


func get_available_locales() -> PackedStringArray:
	var result := PackedStringArray()
	for locale in LOCALES:
		if _translations.has(locale):
			result.append(locale)
	return result


func get_locale() -> String:
	return _current_locale


func has_key(key: String) -> bool:
	var translation: Translation = _translations.get(_current_locale)
	if translation == null:
		return false
	return translation.get_message(StringName(key)) != ""


func translate_key(key: String, fallback: String = "") -> String:
	var translated := tr(key)
	if translated == key and fallback != "":
		return fallback
	return translated


func set_locale(locale: String, persist: bool = true) -> bool:
	if not _translations.has(locale):
		push_warning("LocalizationManager: locale no disponible %s" % locale)
		return false
	_applying_locale = true
	_current_locale = locale
	TranslationServer.set_locale(locale)
	if persist:
		SettingsManager.set_value("gameplay", "language", locale)
	_applying_locale = false
	EventBus.locale_changed.emit(locale)
	return true


func get_diagnostics_context() -> Dictionary:
	return {
		"locale": _current_locale,
		"available_locales": Array(get_available_locales()),
		"keys_loaded": _count_keys(),
	}


func _load_translations() -> void:
	if _load_imported_translations():
		return
	if not FileAccess.file_exists(CSV_PATH):
		push_error("LocalizationManager: no hay CSV ni traducciones importadas")
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("LocalizationManager: no se pudo abrir %s" % CSV_PATH)
		return
	var header := file.get_csv_line()
	if header.is_empty():
		push_error("LocalizationManager: CSV vacío")
		return
	header[0] = header[0].lstrip("\ufeff")
	var locale_columns: Dictionary = {}
	for index in range(1, header.size()):
		var locale := header[index].strip_edges()
		if not LOCALES.has(locale):
			continue
		var translation := Translation.new()
		translation.locale = locale
		_translations[locale] = translation
		locale_columns[locale] = index
	if locale_columns.is_empty():
		push_error("LocalizationManager: el CSV no contiene locales válidos")
		return
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		var key := row[0].strip_edges()
		if key.is_empty() or key == "key":
			continue
		for locale in locale_columns.keys():
			var column: int = locale_columns[locale]
			if column >= row.size():
				continue
			var value := row[column]
			if value.is_empty():
				continue
			var translation: Translation = _translations[locale]
			translation.add_message(StringName(key), StringName(value))
	for locale in _translations.keys():
		TranslationServer.add_translation(_translations[locale])
	for locale in LOCALES:
		if not _translations.has(locale):
			push_warning("LocalizationManager: falta el locale %s en el CSV" % locale)
	print(
		"[LOCALIZATION] %d locales, %d claves por locale"
		% [_translations.size(), _count_keys()]
	)


func _count_keys() -> int:
	var fallback: Translation = _translations.get(FALLBACK_LOCALE)
	if fallback == null:
		return 0
	if fallback is OptimizedTranslation:
		return 0
	var messages := fallback.get_message_list()
	return messages.size()


func _load_imported_translations() -> bool:
	var loaded: Dictionary = {}
	for locale in LOCALES:
		var translation := TranslationServer.get_translation_object(locale)
		if translation == null:
			continue
		if translation.get_message(StringName("APP_TITLE")).is_empty():
			continue
		loaded[locale] = translation
	if loaded.size() != LOCALES.size():
		return false
	_translations = loaded
	var fallback: Translation = _translations.get(FALLBACK_LOCALE)
	if fallback is OptimizedTranslation:
		print("[LOCALIZATION] %d locales desde recursos importados" % _translations.size())
	else:
		print(
			"[LOCALIZATION] %d locales, %d claves por locale"
			% [_translations.size(), _count_keys()]
		)
	return true


func _on_settings_changed(section: String, key: String, value: Variant) -> void:
	if _applying_locale:
		return
	if section == "gameplay" and key == "language":
		set_locale(str(value), false)


func _on_diagnostics_context_requested() -> void:
	EventBus.diagnostics_context_updated.emit("localization", get_diagnostics_context())
