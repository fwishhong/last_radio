class_name I18n
extends RefCounted
# Lightweight in-process localization.
# Two surfaces:
#   1. t(key, args) — chrome strings (buttons, status labels, prompts). Reads
#      from data/i18n/{locale}.json, falls back to "zh", then to the key itself.
#   2. t_field(dict, field) — data-driven strings (night titles, day-card
#      names, resource names). Returns dict[field + "_" + locale] if present,
#      else dict[field].
# Format strings use printf-style %s / %d placeholders.
# Locale is a string ("zh", "en"). Default is "zh".
# Locales are loaded eagerly via load_locale() on game start.
# The current locale and chrome dicts are stored in static state; this is a
# single-language-at-a-time game (no per-frame locale swaps beyond a settings
# change, which is rare).

const DATA_DIR := "res://data/i18n"
const SUPPORTED_LOCALES := ["zh", "en"]
const DEFAULT_LOCALE := "zh"

static var locale: String = DEFAULT_LOCALE
static var dicts: Dictionary = {}  # {locale: {key: string, ...}}


# Load one locale from disk. Idempotent — calling twice replaces the dict.
static func load_locale(lang: String) -> bool:
	if not SUPPORTED_LOCALES.has(lang):
		push_warning("I18n: unsupported locale '%s'" % lang)
		return false
	var path := "%s/%s.json" % [DATA_DIR, lang]
	if not FileAccess.file_exists(path):
		push_warning("I18n: missing locale file %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("I18n: cannot open %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		push_warning("I18n: %s is not a JSON object" % path)
		return false
	dicts[lang] = parsed
	return true


# Load every supported locale. Safe to call multiple times.
static func load_all() -> void:
	for l in SUPPORTED_LOCALES:
		load_locale(l)


# Switch the active locale. Caller is responsible for re-rendering any UI
# that captured the old strings.
static func set_locale(lang: String) -> bool:
	if not dicts.has(lang):
		load_locale(lang)
	if not dicts.has(lang):
		return false
	locale = lang
	return true


# Convenience: list of locales that successfully loaded.
static func available_locales() -> Array:
	var out: Array = []
	for l in SUPPORTED_LOCALES:
		if dicts.has(l):
			out.append(l)
	return out


# Localize a chrome string key.
#   t("cover.start") -> "开始第一章"
#   t("assault", ["正门"]) -> "正门 遭到冲击。"  (printf-style %s)
# Falls back to "zh" then to the key itself.
static func t(key: String, args: Array = []) -> String:
	var raw: String = key
	if dicts.has(locale) and (dicts[locale] as Dictionary).has(key):
		raw = str((dicts[locale] as Dictionary)[key])
	elif dicts.has(DEFAULT_LOCALE) and (dicts[DEFAULT_LOCALE] as Dictionary).has(key):
		raw = str((dicts[DEFAULT_LOCALE] as Dictionary)[key])
	if not args.is_empty():
		return raw % args
	return raw


# Localize a data field.
# Looks up `field + "_" + locale` first (e.g. "title_en"), then the bare
# `field`. Returns empty string if neither is present.
static func t_field(d: Dictionary, field: String) -> String:
	if d == null or d.is_empty():
		return ""
	var localized_key: String = "%s_%s" % [field, locale]
	if d.has(localized_key) and str(d[localized_key]) != "":
		return str(d[localized_key])
	if d.has(field):
		return str(d[field])
	return ""


# Convenience: localize an optional "name" field.
static func t_name(d: Dictionary) -> String:
	return t_field(d, "name")