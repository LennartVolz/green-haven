extends RefCounted
## Der Hof-Bereich: alles, was der Hof gesammelt und erlebt hat, an einem Ort.
## Hofbuch, Lexikon, Briefe und Tagebuch sind Reiter unter dem Titel – keine
## versteckten Knöpfe in anderen Menüs. Die Reiter bleiben beim Scrollen stehen.

const HofbuchSheet := preload("res://scripts/ui/sheets/hofbuch_sheet.gd")
const LexiconSheet := preload("res://scripts/ui/sheets/lexicon_sheet.gd")
const LettersSheet := preload("res://scripts/ui/sheets/letters_sheet.gd")
const DiarySheet := preload("res://scripts/ui/sheets/diary_sheet.gd")

## Reihenfolge = Reihenfolge der Reiter. Die Kennung landet im Zustand der
## Oberfläche, damit ein Wechsel die Scrollposition nicht verliert.
const TABS := [
	["hofbuch", "Hofbuch"],
	["lexicon", "Hoflexikon"],
	["letters", "Briefe"],
	["diary", "Tagebuch"],
]


static func build(ui, args: Dictionary) -> void:
	var tab := str(args.get("tab", ui.state.get("hof_tab", "hofbuch")))
	if not _known(tab):
		tab = "hofbuch"
	ui.state["hof_tab"] = tab
	ui.set_tabs(TABS, tab)
	match tab:
		"lexicon":
			LexiconSheet.build(ui, {})
		"letters":
			LettersSheet.build(ui, {})
		"diary":
			DiarySheet.build(ui, {})
		_:
			HofbuchSheet.build(ui, {})


static func _known(tab: String) -> bool:
	for entry in TABS:
		if str(entry[0]) == tab:
			return true
	return false
