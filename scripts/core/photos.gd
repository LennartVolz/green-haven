class_name Photos
extends RefCounted
## Fotos vom Hof liegen als PNG neben dem Spielstand – bewusst nicht im
## Spielstand: Bilddaten würden ihn bei jedem Autosave wachsen lassen, und ein
## Foto ist kein Fortschritt. Es wird nichts freigeschaltet, nichts gezählt,
## nichts belohnt; wer nie fotografiert, verpasst nichts.

const DIR := "user://photos"
## So viele Aufnahmen bleiben liegen. Ältere räumt save() weg, damit der Ordner
## auf dem Telefon nicht unbegrenzt wächst.
const KEEP := 12
## Der Framebuffer eines Telefons ist größer als das Bild, das jemand braucht.
## Breitere Aufnahmen werden verkleinert, damit zwölf Fotos nicht den Speicher
## füllen; kleinere bleiben unangetastet.
const MAX_WIDTH := 1920
## Nur für Tests: eigener Ordner, damit ein Testlauf keine echten Fotos löscht.
static var path_override := ""


static func directory() -> String:
	return path_override if not path_override.is_empty() else DIR


## Der Ordner als Pfad, den das Betriebssystem versteht (“Ordner öffnen”).
static func folder() -> String:
	return ProjectSettings.globalize_path(directory())


static func ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(folder()):
		return true
	return DirAccess.make_dir_recursive_absolute(folder()) == OK


## Ortszeit statt UTC: Auf dem Foto steht die Uhrzeit, die auf der Uhr des
## Spielers stand. Godot rechnet Unix-Zeiten sonst in UTC um.
static func local_datetime(unix_time: float) -> Dictionary:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_dict_from_unix_time(int(unix_time) + bias * 60)


## Datum und Uhrzeit im Dateinamen: lesbar und sortierbar, ohne auf die
## Dateizeit angewiesen zu sein.
static func stamp(unix_time: float) -> String:
	var t := local_datetime(unix_time)
	return "%04d-%02d-%02d-%02d%02d%02d" % [int(t.year), int(t.month), int(t.day), int(t.hour), int(t.minute), int(t.second)]


## Die laufende Nummer hält Aufnahmen derselben Sekunde auseinander und sorgt
## dafür, dass der Name allein chronologisch sortiert bleibt.
static func file_name(unix_time: float, index: int = 1) -> String:
	return "hof-%s-%02d.png" % [stamp(unix_time), index]


## Speichert das Bild und gibt den Pfad zurück. "" heißt: nicht gespeichert –
## dann sagt die Oberfläche Bescheid, statt still nichts zu tun.
static func save(image: Image, unix_time: float = -1.0) -> String:
	if image == null or image.is_empty() or not ensure_dir():
		return ""
	var moment := Time.get_unix_time_from_system() if unix_time < 0.0 else unix_time
	var index := 1
	var path := directory().path_join(file_name(moment, index))
	while FileAccess.file_exists(path):
		index += 1
		path = directory().path_join(file_name(moment, index))
	var stored := image
	if image.get_width() > MAX_WIDTH:
		var height := maxi(1, roundi(float(image.get_height()) * float(MAX_WIDTH) / float(image.get_width())))
		stored = image.duplicate()
		stored.resize(MAX_WIDTH, height, Image.INTERPOLATE_LANCZOS)
	if stored.save_png(path) != OK:
		return ""
	prune()
	return path


## Neueste zuerst. Der Dateiname trägt Datum und Uhrzeit, deshalb genügt die
## Sortierung der Namen – keine Dateizeit, keine zusätzliche Liste.
static func photos() -> Array:
	var out: Array = []
	var dir := DirAccess.open(directory())
	if dir == null:
		return out
	for name in dir.get_files():
		if str(name).to_lower().ends_with(".png"):
			out.append(directory().path_join(str(name)))
	out.sort()
	out.reverse()
	return out


## Löscht alles über KEEP hinaus und gibt die Zahl der gelöschten Dateien zurück.
static func prune() -> int:
	var all := photos()
	var removed := 0
	for index in range(KEEP, all.size()):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(str(all[index]))) == OK:
			removed += 1
	return removed

