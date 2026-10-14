extends Node
## Statische Spieldaten für Green Haven: Pflanzen, Rezepte, Gebäude, Dekoration,
## Tiere, Quests. Alle Werte sind hier zentral balanciert.
## Zeiten in Sekunden, Preise in Münzen.

const TILE := 128
const MAX_LEVEL := 30
const WORLD_COLS := 24
const WORLD_ROWS := 30
const START_LAND := Rect2i(8, 11, 8, 8)
const TILL_COST := 10
const START_COINS := 120

## Jede Erweiterung vergrößert das Land um 1 Zelle in alle Richtungen.
const LAND_EXPANSIONS := [
	{"cost": 300, "level": 3},
	{"cost": 800, "level": 6},
	{"cost": 2000, "level": 10},
	{"cost": 5000, "level": 15},
]

const CROPS := {
	"wheat": {"name": "Weizen", "grow": 30, "seed": 1, "yield": 2, "sell": 3, "xp": 2, "level": 1, "col": "#E0B93C", "perennial": false},
	"carrot": {"name": "Karotte", "grow": 60, "seed": 2, "yield": 2, "sell": 5, "xp": 3, "level": 1, "col": "#EE8A2E", "perennial": false},
	"oat": {"name": "Hafer", "grow": 90, "seed": 2, "yield": 3, "sell": 4, "xp": 3, "level": 2, "col": "#C9C58A", "perennial": false},
	"potato": {"name": "Kartoffel", "grow": 120, "seed": 3, "yield": 3, "sell": 6, "xp": 4, "level": 3, "col": "#B98B55", "perennial": false},
	"tomato": {"name": "Tomate", "grow": 180, "seed": 4, "yield": 3, "sell": 8, "xp": 5, "level": 4, "col": "#E04B3A", "perennial": false},
	"corn": {"name": "Mais", "grow": 240, "seed": 5, "yield": 4, "sell": 8, "xp": 6, "level": 5, "col": "#F2CF3E", "perennial": false},
	"soy": {"name": "Sojabohne", "grow": 300, "seed": 6, "yield": 4, "sell": 9, "xp": 7, "level": 5, "col": "#9DB35C", "perennial": false},
	"strawberry": {"name": "Erdbeere", "grow": 420, "seed": 8, "yield": 5, "sell": 12, "xp": 9, "level": 6, "col": "#D9344F", "perennial": false},
	"apple": {"name": "Apfel", "grow": 600, "seed": 10, "yield": 6, "sell": 14, "xp": 12, "level": 7, "col": "#C9362D", "perennial": true},
	"sunflower": {"name": "Sonnenblume", "grow": 360, "seed": 6, "yield": 4, "sell": 11, "xp": 8, "level": 8, "col": "#F6C21C", "perennial": false},
}

## Zutaten, die nicht angebaut, sondern im Shop gekauft werden.
const EXTRA_ITEMS := {
	"almond": {"name": "Mandeln", "sell": 6, "col": "#C9A070", "shop": 12, "level": 5},
}

const BUILDINGS := {
	"bakery": {"name": "Bäckerei", "kind": "production", "cost": 150, "level": 2, "size": [2, 2], "slots": 2, "max": 1, "col": "#D9A066", "roof": "#B5532F"},
	"kitchen": {"name": "Vegane Küche", "kind": "production", "cost": 400, "level": 3, "size": [2, 2], "slots": 2, "max": 1, "col": "#EBDDB5", "roof": "#6F9A63"},
	"milkery": {"name": "Pflanzenmilch-Manufaktur", "kind": "production", "cost": 700, "level": 4, "size": [2, 2], "slots": 2, "max": 1, "col": "#E8EEF0", "roof": "#6D9AB0"},
	"juicebar": {"name": "Saftbar", "kind": "production", "cost": 900, "level": 6, "size": [2, 2], "slots": 2, "max": 1, "col": "#F6E3B4", "roof": "#E0783A"},
	"tofu": {"name": "Tofu-Werkstatt", "kind": "production", "cost": 1100, "level": 6, "size": [2, 2], "slots": 2, "max": 1, "col": "#F1E6C8", "roof": "#D6A93A"},
	"paddock": {"name": "Gehege", "kind": "paddock", "cost": 250, "level": 3, "size": [4, 3], "capacity": 3, "max": 4, "col": "#9CC47A", "roof": "#8E6240"},
}

const RECIPES := {
	"bread": {"name": "Vollkornbrot", "building": "bakery", "inputs": {"wheat": 3}, "time": 60, "sell": 16, "xp": 6, "level": 2, "col": "#B07A3F"},
	"oat_cookies": {"name": "Haferkekse", "building": "bakery", "inputs": {"oat": 3}, "time": 90, "sell": 24, "xp": 8, "level": 3, "col": "#D2A765"},
	"carrot_muffin": {"name": "Karottenmuffins", "building": "bakery", "inputs": {"carrot": 2, "wheat": 2}, "time": 120, "sell": 30, "xp": 10, "level": 4, "col": "#E38B3C"},
	"carrot_soup": {"name": "Karottensuppe", "building": "kitchen", "inputs": {"carrot": 3, "potato": 1}, "time": 120, "sell": 34, "xp": 10, "level": 3, "col": "#EE8A2E"},
	"tomato_sauce": {"name": "Tomatensauce", "building": "kitchen", "inputs": {"tomato": 3}, "time": 150, "sell": 38, "xp": 12, "level": 4, "col": "#C9372B"},
	"veg_pan": {"name": "Gemüsepfanne", "building": "kitchen", "inputs": {"potato": 1, "carrot": 1, "tomato": 1}, "time": 150, "sell": 42, "xp": 13, "level": 5, "col": "#8DAA4A"},
	"oat_milk": {"name": "Hafermilch", "building": "milkery", "inputs": {"oat": 3}, "time": 90, "sell": 22, "xp": 8, "level": 4, "col": "#F1EAD3"},
	"almond_milk": {"name": "Mandelmilch", "building": "milkery", "inputs": {"almond": 3}, "time": 120, "sell": 34, "xp": 11, "level": 5, "col": "#EFE0C8"},
	"soy_milk": {"name": "Sojamilch", "building": "milkery", "inputs": {"soy": 3}, "time": 120, "sell": 32, "xp": 11, "level": 6, "col": "#F4EFD0"},
	"berry_smoothie": {"name": "Beerensmoothie", "building": "juicebar", "inputs": {"strawberry": 3}, "time": 100, "sell": 52, "xp": 15, "level": 6, "col": "#D95A7B"},
	"apple_juice": {"name": "Apfelsaft", "building": "juicebar", "inputs": {"apple": 3}, "time": 90, "sell": 50, "xp": 15, "level": 7, "col": "#D9A93A"},
	"tofu": {"name": "Naturtofu", "building": "tofu", "inputs": {"soy": 4}, "time": 150, "sell": 42, "xp": 14, "level": 6, "col": "#F3E7C4"},
	"smoked_tofu": {"name": "Räuchertofu", "building": "tofu", "inputs": {"tofu": 1, "corn": 1}, "time": 180, "sell": 64, "xp": 18, "level": 7, "col": "#B08A5A"},
	"marinated_tofu": {"name": "Marinierter Tofu", "building": "tofu", "inputs": {"tofu": 1, "tomato_sauce": 1}, "time": 180, "sell": 92, "xp": 22, "level": 8, "col": "#D87A4A"},
}

const DECOS := {
	"bush": {"name": "Beerenbusch", "cost": 30, "level": 1, "size": [1, 1]},
	"flowers": {"name": "Blumenbeet", "cost": 25, "level": 1, "size": [1, 1]},
	"haybale": {"name": "Strohballen", "cost": 40, "level": 2, "size": [1, 1]},
	"tree": {"name": "Laubbaum", "cost": 80, "level": 2, "size": [1, 1]},
	"bench": {"name": "Gartenbank", "cost": 120, "level": 3, "size": [2, 1]},
	"lantern": {"name": "Laterne", "cost": 90, "level": 4, "size": [1, 1]},
	"scarecrow": {"name": "Vogelscheuche", "cost": 150, "level": 5, "size": [1, 1]},
	"pond": {"name": "Seerosenteich", "cost": 300, "level": 6, "size": [2, 2]},
}

## Gerettete Tiere. Sie produzieren nichts – sie werden gepflegt und geliebt.
const ANIMALS := {
	"rabbit": {"name": "Kaninchen", "cost": 100, "level": 3, "food": "carrot", "traits": ["curious", "gentle", "playful"], "names": ["Krümel", "Möhre", "Flocke", "Pünktchen"],
		"stories": ["wurde als Findelkind in einer Gartenlaube entdeckt.", "lebte zu eng in einem winzigen Käfig und genießt jetzt die Wiese.", "ist aus einer Hinterhofhaltung gerettet worden."]},
	"chicken": {"name": "Huhn", "cost": 120, "level": 3, "food": "wheat", "traits": ["curious", "social", "brave"], "names": ["Berta", "Frieda", "Paula", "Gundula"],
		"stories": ["kam aus einer Massentierhaltung und lernt gerade, Gras zu entdecken.", "ist von einem Transporter gefallen und wurde aufgenommen.", "liebt Sonnenbäder im Staub."]},
	"sheep": {"name": "Schaf", "cost": 250, "level": 5, "food": "oat", "traits": ["gentle", "cozy", "patient"], "names": ["Wölkchen", "Watte", "Mohn", "Linus"],
		"stories": ["wurde als Lamm ausgesetzt und mit der Flasche aufgezogen.", "braucht keinen Scherer – das Fell darf einfach flauschig bleiben.", "folgt dir überall hin, sobald du Hafer dabeihast."]},
	"pig": {"name": "Schwein", "cost": 300, "level": 6, "food": "potato", "traits": ["playful", "curious", "cozy"], "names": ["Rosa", "Trüffel", "Emil", "Schnuffi"],
		"stories": ["suhlt sich nach jedem Regen mit Begeisterung im Matsch.", "entkam einem Schlachttransport und fand hier ein Zuhause.", "ist ein echter Kuschelfan und grunzt vor Glück."]},
	"cow": {"name": "Kuh", "cost": 450, "level": 8, "food": "wheat", "traits": ["gentle", "patient", "social"], "names": ["Mathilda", "Klara", "Bruno", "Elsa"],
		"stories": ["durfte ihr Kalb behalten und muss nie wieder gemolken werden.", "liebt Streicheleinheiten hinter den Ohren.", "döst am liebsten im Schatten des Apfelbaums."]},
}

## Kosmetische Belohnungen für die Zuneigung (Herzen) eines Tieres.
const COSMETICS := [
	{"hearts": 15, "id": "flower", "name": "Blumenkranz"},
	{"hearts": 40, "id": "bow", "name": "Schleife"},
	{"hearts": 90, "id": "crown", "name": "Blütenkrone"},
]

## Quest-Typen: stat (Zähler in GameState.stats), level, building, animals, decos.
const QUESTS := [
	{"id": "q_plant5", "text": "Pflanze 5 Felder an", "type": "stat", "key": "planted", "target": 5, "coins": 30, "xp": 10},
	{"id": "q_harvest10", "text": "Ernte 10 Felder", "type": "stat", "key": "harvested", "target": 10, "coins": 40, "xp": 15},
	{"id": "q_order1", "text": "Erfülle deinen ersten Auftrag", "type": "stat", "key": "orders", "target": 1, "coins": 50, "xp": 15},
	{"id": "q_level3", "text": "Erreiche Stufe 3", "type": "level", "target": 3, "coins": 80, "xp": 0},
	{"id": "q_bakery", "text": "Baue eine Bäckerei", "type": "building", "building": "bakery", "target": 1, "coins": 60, "xp": 20},
	{"id": "q_craft5", "text": "Stelle 5 Produkte her", "type": "stat", "key": "crafted", "target": 5, "coins": 80, "xp": 25},
	{"id": "q_deco3", "text": "Platziere 3 Dekorationen", "type": "decos", "target": 3, "coins": 60, "xp": 20},
	{"id": "q_order5", "text": "Erfülle 5 Aufträge", "type": "stat", "key": "orders", "target": 5, "coins": 120, "xp": 40},
	{"id": "q_paddock", "text": "Baue ein Gehege", "type": "building", "building": "paddock", "target": 1, "coins": 100, "xp": 30},
	{"id": "q_animal1", "text": "Rette dein erstes Tier", "type": "animals", "target": 1, "coins": 150, "xp": 50},
	{"id": "q_pet10", "text": "Streichle Tiere 10 Mal", "type": "stat", "key": "pets", "target": 10, "coins": 90, "xp": 30},
	{"id": "q_feed5", "text": "Füttere Tiere 5 Mal", "type": "stat", "key": "fed", "target": 5, "coins": 90, "xp": 30},
	{"id": "q_level8", "text": "Erreiche Stufe 8", "type": "level", "target": 8, "coins": 400, "xp": 0},
	{"id": "q_harvest100", "text": "Ernte 100 Felder", "type": "stat", "key": "harvested", "target": 100, "coins": 250, "xp": 80},
	{"id": "q_order15", "text": "Erfülle 15 Aufträge", "type": "stat", "key": "orders", "target": 15, "coins": 400, "xp": 120},
	{"id": "q_animals3", "text": "Rette 3 Tiere", "type": "animals", "target": 3, "coins": 300, "xp": 100},
]

const ANIMAL_TRAITS := {
	"curious": {"name": "Neugierig", "description": "erkundet gern jeden Winkel."},
	"gentle": {"name": "Sanftmütig", "description": "mag ruhige Momente und vorsichtige Nähe."},
	"playful": {"name": "Verspielt", "description": "freut sich besonders über kleine Spiele."},
	"social": {"name": "Gesellig", "description": "fühlt sich in Gesellschaft wohl."},
	"brave": {"name": "Mutig", "description": "probiert gern Neues aus."},
	"cozy": {"name": "Gemütlich", "description": "liebt sonnige Ruhepausen."},
	"patient": {"name": "Geduldig", "description": "lässt sich Zeit und beobachtet aufmerksam."},
}

const ANIMAL_ACTIVITIES := {
	"rabbit": {"name": "Schnüffelspiel", "description": "Ein paar versteckte Kräuter zum Erkunden."},
	"chicken": {"name": "Pickspiel", "description": "Ein kleines Suchspiel im weichen Stroh."},
	"sheep": {"name": "Wollpflege", "description": "Eine sanfte Bürstenrunde, ganz ohne Scheren."},
	"pig": {"name": "Matschbad", "description": "Ein fröhliches Planschen und Wühlen."},
	"cow": {"name": "Kraulzeit", "description": "Eine ruhige Massage hinter den Ohren."},
}

const CUSTOMERS := ["Lena", "Jonas", "Mira", "Oskar", "Fatima", "Ben", "Sofia", "Karim", "Hanna", "Leo", "Yuki", "Pia", "Tarek", "Ida"]

## Alle handelbaren Gegenstände (Feldfrüchte, Zutaten, Produkte).
var items := {}


func _init() -> void:
	for id in CROPS:
		var c: Dictionary = CROPS[id]
		items[id] = {"id": id, "name": c.name, "sell": c.sell, "col": c.col, "kind": "crop", "level": c.level}
	for id in EXTRA_ITEMS:
		var e: Dictionary = EXTRA_ITEMS[id]
		items[id] = {"id": id, "name": e.name, "sell": e.sell, "col": e.col, "kind": "extra", "level": e.level}
	for id in RECIPES:
		var r: Dictionary = RECIPES[id]
		items[id] = {"id": id, "name": r.name, "sell": r.sell, "col": r.col, "kind": "product", "level": r.level}


static func xp_needed(lvl: int) -> int:
	return 25 + 15 * lvl


func item_name(id: String) -> String:
	if items.has(id):
		return items[id].name
	return id


func object_def(type: String) -> Dictionary:
	if BUILDINGS.has(type):
		return BUILDINGS[type]
	if DECOS.has(type):
		var d: Dictionary = DECOS[type].duplicate()
		d["kind"] = "deco"
		return d
	return {}


func object_size(type: String) -> Vector2i:
	var d := object_def(type)
	if d.is_empty():
		return Vector2i.ONE
	return Vector2i(int(d["size"][0]), int(d["size"][1]))


func recipes_for(building: String) -> Array:
	var out: Array = []
	for id in RECIPES:
		if RECIPES[id].building == building:
			out.append(id)
	return out


func format_time(sec: float) -> String:
	var s := maxi(0, int(ceil(sec)))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


## Namen alles, was auf einer Stufe freigeschaltet wird.
func unlocks_at(lvl: int) -> Array:
	var out: Array = []
	for id in CROPS:
		if CROPS[id].level == lvl:
			out.append(CROPS[id].name)
	for id in RECIPES:
		if RECIPES[id].level == lvl:
			out.append(RECIPES[id].name)
	for id in BUILDINGS:
		if BUILDINGS[id].level == lvl:
			out.append(BUILDINGS[id].name)
	for id in DECOS:
		if DECOS[id].level == lvl:
			out.append(DECOS[id].name)
	for id in ANIMALS:
		if ANIMALS[id].level == lvl:
			out.append(ANIMALS[id].name)
	return out
