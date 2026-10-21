extends Node
## Statische Spieldaten für Green Haven: Pflanzen, Rezepte, Gebäude, Dekoration,
## Tiere, Quests. Alle Werte sind hier zentral balanciert.
## Zeiten in Sekunden, Preise in Münzen.
## Jede Stufe schaltet höchstens eine Pflanze und ein Gebäude frei; Rezepte und
## Geschichten erscheinen nie vor ihren Zutaten. Der Test „Freischalt-Takt“ prüft das.

const TILE := 128
const MAX_LEVEL := 30
## Die sichtbare Einzelkarte passt die begehbare Wiese an die volle Farmgröße an.
const WORLD_COLS := 24
const WORLD_ROWS := 30
const WORLD_MARGIN_CELLS := 2
## Prozedural erzeugter Wildnisgürtel um die Karte. Er wird in Chunks
## gezeichnet, damit beim Schwenken und Zoomen kein leerer Rand entsteht.
const SCENERY_MARGIN_CELLS := 24
## Sammelstellen wachsen in einem Ring um die Farm: zwei Zellen Abstand zum Zaun,
## höchstens so weit draußen, dass man sie noch gut erreichen kann.
const FORAGE_BAND_CELLS := 7
const FORAGE_EDGE_CELLS := 1
const FORAGE_CHANCE := 0.09
const WORLD_ORIGIN := Vector2i(0, 0)
const START_LAND := Rect2i(8, 11, 8, 8)
const TILL_COST := 10
const START_COINS := 120

## Ein Spieltag dauert 8 Minuten echter Zeit (passend zum Tag-Nacht-Zyklus).
const REAL_DAY_SECONDS := 8.0 * 60.0

## Gemeinsamer Wetterzyklus für Anzeige und Erntezeit: Sonne, Wolken, Regen, Nebel.
const WEATHER_DURATION_SECONDS := 120.0
const WEATHER_TYPES := ["Sonnig", "Bewölkt", "Regen", "Nebel"]
const WEATHER_GROWTH_RATES := {"Sonnig": 1.0, "Bewölkt": 0.9, "Regen": 1.25, "Nebel": 1.0}

## Jahreszeiten: Ein Jahr hat vier Jahreszeiten zu je sechs Spieltagen (24 Tage).
## Die Saison wird aus dem Spieltag abgeleitet und braucht deshalb keinen eigenen
## Eintrag im Spielstand. Pflanzen ihrer Saison wachsen wie gewohnt, bringen aber
## eine Extra-Einheit Ertrag und einen zusätzlichen Erfahrungspunkt. Nicht jede
## Sorte ist Saisonpflanze (Zuckerrohr etwa nicht) – alles bleibt ganzjährig
## pflanzbar, die Jahreszeit ist ein Bonus und keine Sperre.
const SEASON_DAYS := 6
const SEASONS := [
	{"id": "spring", "name": "Frühling", "col": "#8FBF6A", "crops": ["strawberry", "rhubarb", "lettuce", "pea", "carrot"],
		"note": "Alles sprießt. Erdbeeren, Rhabarber und zartes Blattgemüse geben eine Extra-Ernte."},
	{"id": "summer", "name": "Sommer", "col": "#F2C64C", "crops": ["tomato", "corn", "cucumber", "zucchini", "sunflower"],
		"note": "Sonne satt. Tomaten, Mais, Gurken und Sonnenblumen geben eine Extra-Ernte."},
	{"id": "autumn", "name": "Herbst", "col": "#E08A3C", "crops": ["pumpkin", "beet", "apple", "blueberry", "wheat"],
		"note": "Erntezeit. Kürbis, Rote Bete und Äpfel geben eine Extra-Ernte."},
	{"id": "winter", "name": "Winter", "col": "#8FB8D0", "crops": ["potato", "rice", "quinoa", "coffee", "almond"],
		"note": "Draußen ist es still. Kartoffeln, Reis und Quinoa geben eine Extra-Ernte."},
]

## Jede Erweiterung vergrößert das Land um 1 Zelle in alle Richtungen.
## Acht Ausbauschritte wachsen von 8x8 bis 24x24 Felder und bleiben in der Karte.
const LAND_EXPANSIONS := [
	{"cost": 300, "level": 3},
	{"cost": 800, "level": 6},
	{"cost": 2000, "level": 10},
	{"cost": 5000, "level": 15},
	{"cost": 7000, "level": 18},
	{"cost": 11000, "level": 21},
	{"cost": 18000, "level": 25},
	{"cost": 28000, "level": 30},
]

const CROPS := {
	"wheat": {"name": "Weizen", "grow": 30, "seed": 1, "yield": 2, "sell": 3, "xp": 2, "level": 1, "col": "#E0B93C"},
	"carrot": {"name": "Karotte", "grow": 60, "seed": 2, "yield": 2, "sell": 5, "xp": 3, "level": 2, "col": "#EE8A2E"},
	"oat": {"name": "Hafer", "grow": 90, "seed": 2, "yield": 3, "sell": 4, "xp": 3, "level": 3, "col": "#C9C58A"},
	"potato": {"name": "Kartoffel", "grow": 120, "seed": 3, "yield": 3, "sell": 6, "xp": 4, "level": 4, "col": "#B98B55"},
	"tomato": {"name": "Tomate", "grow": 180, "seed": 4, "yield": 3, "sell": 8, "xp": 5, "level": 5, "col": "#E04B3A"},
	"corn": {"name": "Mais", "grow": 240, "seed": 5, "yield": 4, "sell": 8, "xp": 6, "level": 6, "col": "#F2CF3E"},
	"soy": {"name": "Sojabohne", "grow": 300, "seed": 6, "yield": 4, "sell": 9, "xp": 7, "level": 7, "col": "#9DB35C"},
	"almond": {"name": "Mandeln", "grow": 420, "seed": 6, "yield": 3, "sell": 8, "xp": 8, "level": 8, "col": "#D8B98A"},
	"strawberry": {"name": "Erdbeere", "grow": 420, "seed": 8, "yield": 5, "sell": 12, "xp": 9, "level": 9, "col": "#D9344F"},
	"apple": {"name": "Apfel", "grow": 600, "seed": 10, "yield": 6, "sell": 14, "xp": 12, "level": 10, "col": "#C9362D"},
	"sunflower": {"name": "Sonnenblume", "grow": 360, "seed": 6, "yield": 4, "sell": 11, "xp": 8, "level": 11, "col": "#F6C21C"},
	"coffee": {"name": "Kaffeekirsche", "grow": 720, "seed": 10, "yield": 3, "sell": 14, "xp": 10, "level": 12, "col": "#A9463D"},
	"pumpkin": {"name": "Kürbis", "grow": 480, "seed": 8, "yield": 4, "sell": 13, "xp": 9, "level": 13, "col": "#E8792F"},
	"sugarcane": {"name": "Zuckerrohr", "grow": 480, "seed": 9, "yield": 4, "sell": 8, "xp": 9, "level": 14, "col": "#9FC468"},
	"beet": {"name": "Rote Bete", "grow": 540, "seed": 9, "yield": 4, "sell": 15, "xp": 10, "level": 15, "col": "#A93659"},
	"rhubarb": {"name": "Rhabarber", "grow": 360, "seed": 7, "yield": 3, "sell": 11, "xp": 8, "level": 16, "col": "#C94F5A"},
	"lettuce": {"name": "Salat", "grow": 150, "seed": 4, "yield": 3, "sell": 7, "xp": 5, "level": 17, "col": "#79B85A"},
	"zucchini": {"name": "Zucchini", "grow": 300, "seed": 6, "yield": 3, "sell": 10, "xp": 7, "level": 18, "col": "#5E9E4A"},
	"cucumber": {"name": "Gurke", "grow": 210, "seed": 5, "yield": 4, "sell": 8, "xp": 6, "level": 19, "col": "#4F9A55"},
	"pea": {"name": "Erbse", "grow": 270, "seed": 6, "yield": 4, "sell": 10, "xp": 7, "level": 20, "col": "#79A94B"},
	"blueberry": {"name": "Blaubeere", "grow": 360, "seed": 7, "yield": 5, "sell": 12, "xp": 8, "level": 21, "col": "#5365A8"},
	"rice": {"name": "Reis", "grow": 540, "seed": 10, "yield": 5, "sell": 15, "xp": 10, "level": 22, "col": "#D5C98E"},
	"quinoa": {"name": "Quinoa", "grow": 720, "seed": 12, "yield": 5, "sell": 18, "xp": 13, "level": 23, "col": "#B66D70"},
}

## Wilde Lebensmittel außerhalb des Zauns. Sie wachsen nicht auf Feldern,
## sondern an festen, prozedural bestimmten Sammelstellen nach.
const FORAGE := {
	"wild_herbs": {"name": "Wilde Kräuter", "level": 2, "sell": 6, "amount": 2, "respawn": 300.0, "xp": 2, "col": "#7FB56A"},
	"mushroom": {"name": "Waldpilze", "level": 4, "sell": 9, "amount": 2, "respawn": 420.0, "xp": 3, "col": "#C08A62"},
	"wild_berries": {"name": "Wildbeeren", "level": 6, "sell": 8, "amount": 3, "respawn": 360.0, "xp": 3, "col": "#C43A4E"},
}

## Zutaten, die nicht angebaut, sondern im Shop gekauft werden.
## Derzeit keine: Zucker wird seit der Zuckermühle selbst aus Zuckerrohr gepresst.
## Die Liste bleibt für künftige Shop-Zutaten bestehen.
const EXTRA_ITEMS := {}

const BUILDINGS := {
	"bakery": {"name": "Bäckerei", "kind": "production", "cost": 150, "level": 2, "size": [2, 2], "slots": 2, "max": 1, "col": "#D9A066", "roof": "#B5532F"},
	"kitchen": {"name": "Vegane Küche", "kind": "production", "cost": 400, "level": 4, "size": [2, 2], "slots": 2, "max": 1, "col": "#EBDDB5", "roof": "#6F9A63"},
	"milkery": {"name": "Pflanzenmilch-Manufaktur", "kind": "production", "cost": 700, "level": 5, "size": [2, 2], "slots": 2, "max": 1, "col": "#E8EEF0", "roof": "#6D9AB0"},
	"juicebar": {"name": "Saftbar", "kind": "production", "cost": 900, "level": 7, "size": [2, 2], "slots": 2, "max": 1, "col": "#F6E3B4", "roof": "#E0783A"},
	"tofu": {"name": "Tofu-Werkstatt", "kind": "production", "cost": 1100, "level": 6, "size": [2, 2], "slots": 2, "max": 1, "col": "#F1E6C8", "roof": "#D6A93A"},
	"cafe": {"name": "Veganes Gartencafé", "kind": "production", "cost": 1800, "level": 11, "size": [2, 2], "slots": 2, "max": 1, "col": "#F2E4C9", "roof": "#6F9A63"},
	"florist": {"name": "Blumenwerkstatt", "kind": "production", "cost": 900, "level": 8, "size": [2, 2], "slots": 2, "max": 1, "col": "#E9D9B0", "roof": "#6F9A63"},
	"oilmill": {"name": "Ölmühle", "kind": "production", "cost": 1200, "level": 9, "size": [2, 2], "slots": 2, "max": 1, "col": "#D8C6A2", "roof": "#8E6240"},
	"preserves": {"name": "Konfitürenküche", "kind": "production", "cost": 1000, "level": 13, "size": [2, 2], "slots": 2, "max": 1, "col": "#F2D9C6", "roof": "#B5532F"},
	"sugarmill": {"name": "Zuckermühle", "kind": "production", "cost": 950, "level": 12, "size": [2, 2], "slots": 2, "max": 1, "col": "#EDE3C8", "roof": "#8E6240"},
	"pasta": {"name": "Nudelwerkstatt", "kind": "production", "cost": 1450, "level": 14, "size": [2, 2], "slots": 2, "max": 1, "col": "#F0D9A8", "roof": "#C97A3A"},
	"icecream": {"name": "Eismanufaktur", "kind": "production", "cost": 1700, "level": 10, "size": [2, 2], "slots": 2, "max": 1, "col": "#F7E6D0", "roof": "#D9647A"},
	"muesli": {"name": "Müsli-Manufaktur", "kind": "production", "cost": 2200, "level": 16, "size": [2, 2], "slots": 2, "max": 1, "col": "#E4D1B0", "roof": "#9A6A4A"},
	"paddock": {"name": "Gehege", "kind": "paddock", "cost": 250, "level": 3, "size": [4, 3], "capacity": 3, "max": 4, "col": "#9CC47A", "roof": "#8E6240"},
}

const RECIPES := {
	"bread": {"name": "Vollkornbrot", "building": "bakery", "inputs": {"wheat": 3}, "time": 60, "sell": 16, "xp": 6, "level": 2, "col": "#B07A3F"},
	"oat_cookies": {"name": "Haferkekse", "building": "bakery", "inputs": {"oat": 3}, "time": 90, "sell": 24, "xp": 8, "level": 3, "col": "#D2A765"},
	"carrot_muffin": {"name": "Karottenmuffins", "building": "bakery", "inputs": {"carrot": 2, "wheat": 2}, "time": 120, "sell": 30, "xp": 10, "level": 4, "col": "#E38B3C"},
	"carrot_soup": {"name": "Karottensuppe", "building": "kitchen", "inputs": {"carrot": 3, "potato": 1}, "time": 120, "sell": 34, "xp": 10, "level": 4, "col": "#EE8A2E"},
	"tomato_sauce": {"name": "Tomatensauce", "building": "kitchen", "inputs": {"tomato": 3}, "time": 150, "sell": 38, "xp": 12, "level": 5, "col": "#C9372B"},
	"veg_pan": {"name": "Gemüsepfanne", "building": "kitchen", "inputs": {"potato": 1, "carrot": 1, "tomato": 1}, "time": 150, "sell": 42, "xp": 13, "level": 5, "col": "#8DAA4A"},
	"oat_milk": {"name": "Hafermilch", "building": "milkery", "inputs": {"oat": 3}, "time": 90, "sell": 22, "xp": 8, "level": 5, "col": "#F1EAD3"},
	"almond_milk": {"name": "Mandelmilch", "building": "milkery", "inputs": {"almond": 3}, "time": 120, "sell": 34, "xp": 11, "level": 8, "col": "#EFE0C8"},
	"soy_milk": {"name": "Sojamilch", "building": "milkery", "inputs": {"soy": 3}, "time": 120, "sell": 32, "xp": 11, "level": 7, "col": "#F4EFD0"},
	"berry_smoothie": {"name": "Beerensmoothie", "building": "juicebar", "inputs": {"strawberry": 3}, "time": 100, "sell": 52, "xp": 15, "level": 9, "col": "#D95A7B"},
	"apple_juice": {"name": "Apfelsaft", "building": "juicebar", "inputs": {"apple": 3}, "time": 90, "sell": 50, "xp": 15, "level": 10, "col": "#D9A93A"},
	"tofu": {"name": "Naturtofu", "building": "tofu", "inputs": {"soy": 4}, "time": 150, "sell": 42, "xp": 14, "level": 7, "col": "#F3E7C4"},
	"smoked_tofu": {"name": "Räuchertofu", "building": "tofu", "inputs": {"tofu": 1, "corn": 1}, "time": 180, "sell": 64, "xp": 18, "level": 8, "col": "#B08A5A"},
	"marinated_tofu": {"name": "Marinierter Tofu", "building": "tofu", "inputs": {"tofu": 1, "tomato_sauce": 1}, "time": 180, "sell": 92, "xp": 22, "level": 8, "col": "#D87A4A"},
	"herb_potatoes": {"name": "Kräuterkartoffeln", "building": "kitchen", "inputs": {"potato": 2, "wild_herbs": 1}, "time": 90, "sell": 34, "xp": 10, "level": 10, "col": "#8FAE58"},
	"mushroom_soup": {"name": "Pilzrahm-Suppe", "building": "kitchen", "inputs": {"mushroom": 2, "oat_milk": 1}, "time": 150, "sell": 78, "xp": 18, "level": 7, "col": "#C08A62"},
	"wild_berry_compote": {"name": "Wildbeerenkompott", "building": "kitchen", "inputs": {"wild_berries": 2, "sugar": 1}, "time": 120, "sell": 64, "xp": 16, "level": 14, "col": "#C43A4E"},
	"pumpkin_soup": {"name": "Kürbissuppe", "building": "kitchen", "inputs": {"pumpkin": 3}, "time": 180, "sell": 56, "xp": 17, "level": 13, "col": "#E8792F"},
	"beet_spread": {"name": "Rote-Bete-Aufstrich", "building": "kitchen", "inputs": {"beet": 3}, "time": 180, "sell": 62, "xp": 18, "level": 15, "col": "#A93659"},
	"garden_salad": {"name": "Gartensalat", "building": "kitchen", "inputs": {"lettuce": 2, "cucumber": 1, "pea": 1}, "time": 150, "sell": 48, "xp": 15, "level": 20, "col": "#76A94D"},
	"blueberry_smoothie": {"name": "Blaubeer-Smoothie", "building": "juicebar", "inputs": {"blueberry": 3}, "time": 120, "sell": 54, "xp": 16, "level": 21, "col": "#6572BB"},
	"rice_milk": {"name": "Reismilch", "building": "milkery", "inputs": {"rice": 3}, "time": 150, "sell": 58, "xp": 17, "level": 22, "col": "#F1EAD3"},
	"quinoa_bowl": {"name": "Quinoa-Bowl", "building": "kitchen", "inputs": {"quinoa": 3, "pea": 1}, "time": 210, "sell": 82, "xp": 23, "level": 23, "col": "#B66D70"},
	"roasted_coffee": {"name": "Gerösteter Kaffee", "building": "cafe", "inputs": {"coffee": 3}, "time": 180, "sell": 52, "xp": 12, "level": 12, "col": "#805437"},
	"filter_coffee": {"name": "Filterkaffee", "building": "cafe", "inputs": {"roasted_coffee": 1}, "time": 90, "sell": 55, "xp": 16, "level": 13, "col": "#9B6540"},
	"oat_latte": {"name": "Hafer-Latte", "building": "cafe", "inputs": {"roasted_coffee": 1, "oat_milk": 1}, "time": 120, "sell": 90, "xp": 21, "level": 13, "col": "#C69B6D"},
	"coffee_cookie_plate": {"name": "Kaffee & Haferkekse", "building": "cafe", "inputs": {"filter_coffee": 1, "oat_cookies": 1}, "time": 120, "sell": 82, "xp": 24, "level": 14, "col": "#B88050"},
	"pumpkin_spice_latte": {"name": "Kürbisgewürz-Latte", "building": "cafe", "inputs": {"roasted_coffee": 1, "oat_milk": 1, "pumpkin": 1}, "time": 150, "sell": 145, "xp": 27, "level": 15, "col": "#D98B4F"},
	"blueberry_coffee_cake": {"name": "Blaubeer-Kaffeekuchen", "building": "cafe", "inputs": {"oat_cookies": 1, "blueberry": 2}, "time": 210, "sell": 110, "xp": 30, "level": 21, "col": "#8474A6"},
	"sunflower_oil": {"name": "Sonnenblumenöl", "building": "oilmill", "inputs": {"sunflower": 4}, "time": 120, "sell": 64, "xp": 15, "level": 11, "col": "#E2BC52"},
	"almond_butter": {"name": "Mandelmus", "building": "oilmill", "inputs": {"almond": 4}, "time": 150, "sell": 70, "xp": 18, "level": 11, "col": "#C99C69"},
	"sugar": {"name": "Zucker", "building": "sugarmill", "inputs": {"sugarcane": 3}, "time": 120, "sell": 30, "xp": 8, "level": 14, "col": "#F4E6C8"},
	"cane_syrup": {"name": "Zuckerrohrsirup", "building": "sugarmill", "inputs": {"sugarcane": 4}, "time": 150, "sell": 42, "xp": 12, "level": 14, "col": "#C9A24A"},
	"caramel_syrup": {"name": "Karamellsirup", "building": "sugarmill", "inputs": {"sugar": 1, "oat_milk": 1}, "time": 180, "sell": 78, "xp": 18, "level": 15, "col": "#B67A3C"},
	"caramel_latte": {"name": "Karamell-Latte", "building": "cafe", "inputs": {"caramel_syrup": 1, "roasted_coffee": 1, "oat_milk": 1}, "time": 150, "sell": 178, "xp": 30, "level": 15, "col": "#C08A55"},
	"strawberry_jam": {"name": "Erdbeerkonfitüre", "building": "preserves", "inputs": {"strawberry": 4, "sugar": 1}, "time": 120, "sell": 96, "xp": 18, "level": 14, "col": "#D95A7B"},
	"apple_jam": {"name": "Apfelkonfitüre", "building": "preserves", "inputs": {"apple": 4, "sugar": 1}, "time": 120, "sell": 104, "xp": 19, "level": 14, "col": "#D9A93A"},
	"rhubarb_jam": {"name": "Rhabarberkonfitüre", "building": "preserves", "inputs": {"rhubarb": 4, "sugar": 1}, "time": 150, "sell": 78, "xp": 19, "level": 16, "col": "#C94F5A"},
	"blueberry_jam": {"name": "Blaubeerkonfitüre", "building": "preserves", "inputs": {"blueberry": 4, "sugar": 1}, "time": 150, "sell": 82, "xp": 20, "level": 21, "col": "#6572BB"},
	"pasta": {"name": "Weizennudeln", "building": "pasta", "inputs": {"wheat": 3}, "time": 90, "sell": 30, "xp": 10, "level": 14, "col": "#E8C77A"},
	"tomato_ravioli": {"name": "Tomaten-Ravioli", "building": "pasta", "inputs": {"pasta": 1, "tomato": 2}, "time": 150, "sell": 78, "xp": 19, "level": 14, "col": "#D9644A"},
	"zucchini_noodles": {"name": "Zucchini-Nudeln", "building": "pasta", "inputs": {"pasta": 1, "zucchini": 2}, "time": 150, "sell": 78, "xp": 19, "level": 18, "col": "#6FAF5A"},
	"pumpkin_ravioli": {"name": "Kürbis-Ravioli", "building": "pasta", "inputs": {"pasta": 1, "pumpkin": 2}, "time": 180, "sell": 92, "xp": 22, "level": 15, "col": "#E08A3C"},
	"strawberry_ice": {"name": "Erdbeer-Eis", "building": "icecream", "inputs": {"strawberry": 3, "oat_milk": 1}, "time": 150, "sell": 82, "xp": 20, "level": 11, "col": "#E86F8E"},
	"apple_cookie_ice": {"name": "Apfel-Keks-Eis", "building": "icecream", "inputs": {"apple": 3, "oat_milk": 1, "oat_cookies": 1}, "time": 180, "sell": 116, "xp": 25, "level": 12, "col": "#D9A93A"},
	"rhubarb_ice": {"name": "Rhabarber-Eis", "building": "icecream", "inputs": {"rhubarb": 3, "almond_milk": 1}, "time": 180, "sell": 96, "xp": 22, "level": 16, "col": "#D96A7A"},
	"blueberry_ice": {"name": "Blaubeer-Eis", "building": "icecream", "inputs": {"blueberry": 3, "soy_milk": 1}, "time": 180, "sell": 98, "xp": 23, "level": 21, "col": "#6C7BC0"},
	"sunflower_bouquet": {"name": "Sonnenblumenstrauß", "building": "florist", "inputs": {"sunflower": 3, "wheat": 1}, "time": 90, "sell": 60, "xp": 14, "level": 11, "col": "#E2BC52"},
	"dried_wreath": {"name": "Trockenblumenkranz", "building": "florist", "inputs": {"sunflower": 4, "oat": 2}, "time": 150, "sell": 84, "xp": 19, "level": 12, "col": "#B08A5A"},
	"autumn_wreath": {"name": "Herbstkranz", "building": "florist", "inputs": {"sunflower": 3, "pumpkin": 2}, "time": 180, "sell": 96, "xp": 21, "level": 13, "col": "#D98B4F"},
	"berry_muesli": {"name": "Beeren-Müsli", "building": "muesli", "inputs": {"oat": 2, "almond": 2, "blueberry": 2}, "time": 120, "sell": 78, "xp": 19, "level": 21, "col": "#C9A36A"},
	"apple_rice_pudding": {"name": "Apfel-Reisbrei", "building": "muesli", "inputs": {"rice": 3, "almond_milk": 1, "apple": 1}, "time": 180, "sell": 132, "xp": 26, "level": 22, "col": "#EAD9B0"},
	"quinoa_bar": {"name": "Quinoa-Riegel", "building": "muesli", "inputs": {"quinoa": 2, "almond": 1, "oat": 1}, "time": 150, "sell": 86, "xp": 21, "level": 23, "col": "#B66D70"},
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
## Jede Art hat acht Rufnamen und acht persönliche Vorgeschichten; einige enthalten
## einen kurzen, respektvollen Abschiedssatz früherer Bezugspersonen.
const ANIMALS := {
	"rabbit": {"name": "Kaninchen", "cost": 100, "level": 3, "food": "carrot", "traits": ["curious", "gentle", "playful"],
		"names": ["Krümel", "Möhre", "Flocke", "Pünktchen", "Mohnkringel", "Hoppel", "Haselnuss", "Fips"],
		"stories": [
			"wurde in einer Gartenlaube gefunden. Die Finderin flüsterte: „Du darfst hier erst einmal ganz in Ruhe ankommen.“",
			"lebte lange in einem viel zu kleinen Käfig. Sein früherer Halter sagte bei der Übergabe: „Ich wusste nicht, wie viel Platz ein Kaninchen braucht.“ Jetzt gehören Wiese und Verstecke ihm.",
			"kam aus einer Hinterhofhaltung und erschrickt noch bei schnellen Bewegungen. Die Pflegerin versprach: „Hier fragt dich niemand nach Mut – du bestimmst das Tempo.“",
			"wurde von einer älteren Dame abgegeben, die nicht mehr für es sorgen konnte. „Es liebt Petersilie und leise Musik“, schrieb sie auf einen Zettel.",
			"saß nach einem Sturm allein unter einer Hecke. Ein Nachbar brachte es vorsichtig in einer Decke herüber und sagte: „Es hat die ganze Zeit meine Hand angestupst.“",
			"wurde als Jungtier ohne Mutter gefunden. Eine Pflegestelle zog es groß; beim Abschied sagte sie: „Seine Neugier ist größer als seine Ohren.“",
			"musste nach einem Umzug sein Zuhause verlassen. Seine Familie schrieb: „Wir wünschen ihm einen Garten, den es nach eigenen Regeln erkunden darf.“",
			"kam aus einer überfüllten Notaufnahme und brauchte zuerst nur eine dunkle Höhle. Heute steckt es neugierig die Nase heraus, sobald es Schritte kennt.",
		]},
	"chicken": {"name": "Huhn", "cost": 120, "level": 3, "food": "wheat", "traits": ["curious", "social", "brave"],
		"names": ["Berta", "Frieda", "Paula", "Gundula", "Pip", "Rosalie", "Kiesel", "Klara Kikeriki"],
		"stories": [
			"kam aus einer großen Legehennenanlage und lernte erst im Refugium, Gras zu erkunden. Die Helferin sagte: „Jeder Sonnenfleck gehört jetzt dir.“",
			"wurde nach einem Sturm durchnässt in einer Scheune gefunden. Der Bauer, der sie entdeckte, erzählte: „Sie ist mir bis zum Traktor hinterhergelaufen.“",
			"wurde von einer Familie abgegeben, als deren kleiner Garten zu klein wurde. Ihr Kind sagte zum Abschied: „Bitte gib ihr Körner und erzähl ihr, dass wir sie vermissen.“",
			"hatte lange Angst vor Händen. Ihre frühere Pflegerin bat: „Lass sie zuerst zu dir kommen – dann schenkt sie dir ihr Vertrauen.“",
			"wurde aus schlechter Haltung übernommen und gackert gern, wenn jemand antwortet. Der frühere Halter meinte überrascht: „Ich wusste gar nicht, dass sie so gesprächig ist.“",
			"kam als winziges Küken in eine Pflegestelle. Dort hieß es: „Sie schläft am liebsten neben einem warmen Heusack.“ Das tut sie manchmal noch.",
			"musste nach dem Tod ihrer Besitzerin umziehen. Eine Nachbarin brachte sie her und sagte: „Sie hat mir jeden Morgen Gesellschaft geleistet.“",
			"wurde verletzt am Wegesrand gefunden. Die Finderin sagte erleichtert: „Als sie wieder selbst scharren konnte, wusste ich, dass sie es schafft.“",
		]},
	"sheep": {"name": "Schaf", "cost": 250, "level": 5, "food": "oat", "traits": ["gentle", "cozy", "patient"],
		"names": ["Wölkchen", "Watte", "Mohn", "Linus", "Flauschi", "Mandel", "Sternchen", "Lotti"],
		"stories": [
			"wurde als Lamm ohne Mutter gefunden und mit der Flasche aufgezogen. Die Pflegerin sagte: „Es hat gelernt, dass eine Hand auch sanft sein kann.“",
			"kam aus einer kleinen Hobbyherde, deren Besitzerin krank wurde. „Sie erkennt meine Stimme sofort“, erzählte sie beim Abschied.",
			"wurde aus einer Schafgruppe gerettet, in der es kaum Ruhe fand. Der Schäfer bat: „Gebt ihm einen stillen Platz – es beobachtet erst einmal.“",
			"brauchte nach einer Verletzung lange Erholung. Die Tierärztin erinnert sich: „Es blieb ganz ruhig, wenn man ihm etwas vorgesungen hat.“",
			"wurde von einem Hof übernommen, der keine Schafe mehr halten konnte. Der frühere Besitzer sagte: „Bitte lasst die Wolle einfach Wolle sein; es soll sich wohlfühlen.“",
			"kam als Findelkind zu einer Pflegestelle. Dort wurde es mit einem Tuch gewärmt; noch heute sucht es gern den weichsten Strohhaufen.",
			"musste wegen eines Umzugs seine Herde verlassen. Seine Familie schrieb: „Es mochte immer die Hügel hinter dem Haus – vielleicht findet es wieder einen Lieblingsplatz.“",
			"wurde aus einer Vernachlässigungssituation geholt und braucht Zeit, bis es Nähe zulässt. Die Helferin sagte: „Geduld ist bei ihm das schönste Geschenk.“",
		]},
	"pig": {"name": "Schwein", "cost": 300, "level": 6, "food": "potato", "traits": ["playful", "curious", "cozy"],
		"names": ["Rosa", "Trüffel", "Emil", "Schnuffi", "Mats", "Mohnkeks", "Rübe", "Pünktchen"],
		"stories": [
			"wurde aus einer engen Haltung befreit und planscht für sein Leben gern. Die Helferin lachte: „Ein Matschloch ist für ihn ein Wellnessbad.“",
			"entkam bei einem Transport und wurde von einer Anwohnerin versorgt. Sie sagte: „Es hat sich an meinen Stiefel gekuschelt, als wäre das völlig selbstverständlich.“",
			"kam aus einer privaten Haltung, deren Besitzerin alt geworden war. „Sie kann Türen öffnen“, warnte sie lächelnd – die Riegel sind nun sicher.",
			"wurde als kleines Ferkel krank gefunden. Sein Pfleger sagte: „Es hat sich zurück ins Leben geschnüffelt – und in jede Tasche nach Snacks.“",
			"musste nach einer Hofschließung umziehen. Der frühere Halter gab ihm sein Lieblingsspielzeug mit und bat: „Spielt weiter mit ihm, das macht ihn glücklich.“",
			"hatte lange nur Beton unter den Klauen. Beim ersten weichen Beet blieb es staunend stehen; die Retterin sagte: „Es entdeckt gerade die Welt neu.“",
			"wurde von einer Familie abgegeben, die seine Größe unterschätzt hatte. „Es ist klug und braucht Beschäftigung“, stand in ihrem sorgfältigen Pflegebrief.",
			"kam aus einer Notunterkunft und liebt ruhige Bauch-Kraul-Momente. Die Pflegerin verabschiedete sich mit: „Du hast es verdient, einfach Schwein zu sein.“",
		]},
	"cow": {"name": "Kuh", "cost": 450, "level": 8, "food": "wheat", "traits": ["gentle", "patient", "social"],
		"names": ["Mathilda", "Klara", "Bruno", "Elsa", "Liesel", "Margerite", "Bolle", "Sonnentau"],
		"stories": [
			"durfte mit ihrem Kalb zusammenbleiben und kam gemeinsam mit ihm in Sicherheit. Die frühere Halterin sagte: „Sie sollen sich nie wieder suchen müssen.“",
			"wurde aus einer Haltung übernommen, die schließen musste. Der Landwirt verabschiedete sie mit: „Sie mochte immer den Schattenplatz neben der alten Linde.“",
			"wurde als Kalb von Hand aufgezogen. Ihr Pfleger erzählte: „Sie kam jeden Morgen zuerst zum Zaun, um Hallo zu sagen.“",
			"brauchte nach einer langen Reise einen ruhigen Neuanfang. Die Tierärztin sagte: „Lasst sie selbst entscheiden, wann sie Nähe möchte.“",
			"kam aus einer kleinen Herde, deren Besitzerin sie aus gesundheitlichen Gründen abgeben musste. „Sie liebt Bürsten und Apfelblätter“, schrieb sie dazu.",
			"wurde aus schwierigen Verhältnissen gerettet und erschrak zunächst vor lauten Geräuschen. Heute döst sie im Gras; ihre Pflegerin sagt: „Sie kann endlich tief schlafen.“",
			"musste nach dem Tod ihres Halters umziehen. Die Nachbarin, die sie versorgte, erinnert sich: „Sie wartete immer, bis alle anderen fertig gefressen hatten.“",
			"wurde zusammen mit ihrer besten Freundin aufgenommen. Der frühere Besitzer bat: „Wenn eine losgeht, schaut die andere immer nach – lasst sie bitte zusammen.“",
		]},
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
	{"id": "q_cafe_build", "text": "Eröffne das Gartencafé", "type": "building", "building": "cafe", "target": 1, "coins": 220, "xp": 70},
	{"id": "q_cafe_orders", "text": "Bediene 5 Café-Gäste", "type": "stat", "key": "cafe_orders", "target": 5, "coins": 180, "xp": 60},
	{"id": "q_cafe_story", "text": "Teile eine Café-Geschichte", "type": "stat", "key": "cafe_stories_completed", "target": 1, "coins": 260, "xp": 90},
	{"id": "q_cafe_specials", "text": "Serviere 5 Tagesgerichte", "type": "stat", "key": "cafe_special_orders", "target": 5, "coins": 240, "xp": 80},
	{"id": "q_florist", "text": "Baue eine Blumenwerkstatt", "type": "building", "building": "florist", "target": 1, "coins": 100, "xp": 30},
	{"id": "q_noodles", "text": "Stelle 5 Portionen Nudeln her", "type": "stat", "key": "crafted_pasta", "target": 5, "coins": 160, "xp": 55},
	{"id": "q_icecream", "text": "Stelle 5 Erdbeer-Eis her", "type": "stat", "key": "crafted_strawberry_ice", "target": 5, "coins": 190, "xp": 65},
	{"id": "q_sugarmill", "text": "Baue eine Zuckermühle", "type": "building", "building": "sugarmill", "target": 1, "coins": 110, "xp": 35},
	{"id": "q_sugar", "text": "Stelle 5 Zucker her", "type": "stat", "key": "crafted_sugar", "target": 5, "coins": 150, "xp": 50},
	{"id": "q_forage5", "text": "Sammle 5 wilde Lebensmittel", "type": "stat", "key": "foraged", "target": 5, "coins": 80, "xp": 25},
]

## Dauerhafte Erfolge: Kriterium + einmalige Münz-/XP-Belohnung.
const ACHIEVEMENTS := [
	{"id": "orders_2", "text": "Zwei gute Nachbarn", "description": "Erfülle 2 Bestellungen.", "type": "stat", "key": "orders", "target": 2, "coins": 50, "xp": 8},
	{"id": "orders_10", "text": "Stammkundschaft", "description": "Erfülle 10 Bestellungen.", "type": "stat", "key": "orders", "target": 10, "coins": 180, "xp": 28},
	{"id": "orders_25", "text": "Das ganze Viertel kennt dich", "description": "Erfülle 25 Bestellungen.", "type": "stat", "key": "orders", "target": 25, "coins": 450, "xp": 72},
	{"id": "harvest_25", "text": "Erste reiche Ernte", "description": "Ernte 25 Felder.", "type": "stat", "key": "harvested", "target": 25, "coins": 100, "xp": 14},
	{"id": "harvest_100", "text": "Grüne Daumen", "description": "Ernte 100 Felder.", "type": "stat", "key": "harvested", "target": 100, "coins": 300, "xp": 44},
	{"id": "crafted_10", "text": "Kleine Manufaktur", "description": "Stelle 10 Produkte her.", "type": "stat", "key": "crafted", "target": 10, "coins": 150, "xp": 22},
	{"id": "animals_3", "text": "Ein Refugium voller Leben", "description": "Gib 3 Tieren ein sicheres Zuhause.", "type": "animals", "target": 3, "coins": 220, "xp": 34},
	{"id": "friendship_15", "text": "Vertrauen wächst", "description": "Erreiche 15 Freundschaftsherzen mit einem Tier.", "type": "friendship", "target": 15, "coins": 180, "xp": 26},
	{"id": "story_complete", "text": "Gute Geschichten teilen", "description": "Schließe eine Liefergeschichte ab.", "type": "stat", "key": "stories_completed", "target": 1, "coins": 200, "xp": 32},
	{"id": "land_expansion", "text": "Platz zum Wachsen", "description": "Erweitere deine Farm zum ersten Mal.", "type": "stat", "key": "expansions", "target": 1, "coins": 100, "xp": 14},
	{"id": "cafe_open", "text": "Ein Platz für alle", "description": "Eröffne dein veganes Gartencafé.", "type": "building", "key": "cafe", "target": 1, "coins": 180, "xp": 26},
	{"id": "cafe_orders_10", "text": "Stammgäste im Café", "description": "Bediene 10 Café-Gäste.", "type": "stat", "key": "cafe_orders", "target": 10, "coins": 300, "xp": 44},
	{"id": "cafe_stories_3", "text": "Geschichten am Kaffeetisch", "description": "Höre drei Geschichten von Café-Gästen.", "type": "stat", "key": "cafe_stories_shared", "target": 3, "coins": 260, "xp": 38},
	{"id": "build_florist", "text": "Blumen für alle", "description": "Baue eine Blumenwerkstatt.", "type": "building", "key": "florist", "target": 1, "coins": 100, "xp": 14},
	{"id": "build_oilmill", "text": "Öl aus eigener Ernte", "description": "Baue eine Ölmühle.", "type": "building", "key": "oilmill", "target": 1, "coins": 130, "xp": 18},
	{"id": "build_preserves", "text": "Ein Vorrat für später", "description": "Baue eine Konfitürenküche.", "type": "building", "key": "preserves", "target": 1, "coins": 120, "xp": 16},
	{"id": "build_pasta", "text": "Frische Nudeln", "description": "Baue eine Nudelwerkstatt.", "type": "building", "key": "pasta", "target": 1, "coins": 150, "xp": 20},
	{"id": "build_icecream", "text": "Eiszeit", "description": "Baue eine Eismanufaktur.", "type": "building", "key": "icecream", "target": 1, "coins": 170, "xp": 22},
	{"id": "build_muesli", "text": "Guter Start in den Tag", "description": "Baue eine Müsli-Manufaktur.", "type": "building", "key": "muesli", "target": 1, "coins": 220, "xp": 30},
	{"id": "bouquets_10", "text": "Blumengruß", "description": "Stelle 10 Sonnenblumensträuße her.", "type": "stat", "key": "crafted_sunflower_bouquet", "target": 10, "coins": 160, "xp": 22},
	{"id": "oil_10", "text": "Flüssiges Gold", "description": "Stelle 10 Sonnenblumenöl her.", "type": "stat", "key": "crafted_sunflower_oil", "target": 10, "coins": 180, "xp": 24},
	{"id": "jam_10", "text": "Eingemacht", "description": "Stelle 10 Erdbeerkonfitüren her.", "type": "stat", "key": "crafted_strawberry_jam", "target": 10, "coins": 170, "xp": 22},
	{"id": "pasta_10", "text": "Nudelmeister", "description": "Stelle 10 Portionen Weizennudeln her.", "type": "stat", "key": "crafted_pasta", "target": 10, "coins": 190, "xp": 26},
	{"id": "icecream_10", "text": "Eismacher", "description": "Stelle 10 Erdbeer-Eis her.", "type": "stat", "key": "crafted_strawberry_ice", "target": 10, "coins": 210, "xp": 28},
	{"id": "muesli_10", "text": "Frühstücksliebe", "description": "Stelle 10 Beeren-Müsli her.", "type": "stat", "key": "crafted_berry_muesli", "target": 10, "coins": 240, "xp": 32},
	{"id": "build_sugarmill", "text": "Süß aus eigener Ernte", "description": "Baue eine Zuckermühle.", "type": "building", "key": "sugarmill", "target": 1, "coins": 120, "xp": 18},
	{"id": "sugar_10", "text": "Zuckersüß", "description": "Stelle 10 Zucker her.", "type": "stat", "key": "crafted_sugar", "target": 10, "coins": 170, "xp": 26},
	{"id": "forage_15", "text": "Wildnis-Körbchen", "description": "Sammle 15 wilde Lebensmittel außerhalb der Farm.", "type": "stat", "key": "foraged", "target": 15, "coins": 140, "xp": 22},
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

const FRIENDSHIP_THRESHOLDS := [5, 15, 40, 90]
const FRIENDSHIP_STORIES := {
	"rabbit": ["kommt beim Füttern schon ein Stück näher.", "stupst deine Hand an und bleibt noch einen Moment.", "hüpft freiwillig neben dich und döst entspannt.", "begrüßt dich mit einem mutigen Hüpfer."],
	"chicken": ["pickt neugierig neben deinen Schuhen.", "antwortet auf deine Stimme mit leisem Gackern.", "läuft dir ein paar Schritte entgegen.", "begrüßt dich mit einem fröhlichen Flügelschütteln."],
	"sheep": ["bleibt in deiner Nähe, während du leise sprichst.", "lehnt sich bei der Pflege vertrauensvoll an.", "sucht sich neben dir einen gemütlichen Platz.", "kommt dir entgegen und wartet auf eure ruhige Zeit."],
	"pig": ["teilt sein Matschbad gern mit deiner Gesellschaft.", "bringt dir sein Lieblingsspielzeug.", "legt sich entspannt neben dich.", "grunzt schon fröhlich, wenn es dich kommen hört."],
	"cow": ["nimmt Leckerbissen vorsichtig aus deiner Hand.", "genießt die vertraute Kraulrunde.", "ruht gelassen neben dir im Gras.", "begrüßt dich mit einem sanften Stupser."],
}

## Eine Geschichte startet erst auf der Stufe, auf der alle ihre Lieferungen herstellbar sind
## (cafe_opening braucht die Café-Rezepte bis Stufe 14).
const DELIVERY_STORIES := {
	"lena_cafe": {"title": "Lenas Gartencafé", "customer": "Lena", "level": 11,
		"intro": "Lena richtet ein kleines Café für die Nachbarschaft her und möchte möglichst viel aus der Umgebung verwenden.",
		"stages": [
			{"text": "Für die ersten Gäste fehlen noch frische Karotten und Weizen. Lena schreibt: „Es soll nach Zuhause duften.“", "items": {"carrot": 4, "wheat": 4}, "coins": 52, "xp": 16},
			{"text": "Das Café öffnet den Garten. Lena braucht Erdbeeren und Äpfel für einen bunten Obstteller.", "items": {"strawberry": 3, "apple": 2}, "coins": 92, "xp": 28},
			{"text": "Beim Eröffnungsnachmittag sitzen alle unter den Bäumen. Lena bittet um Hafer und Sonnenblumen als kleine Tischdekoration.", "items": {"oat": 5, "sunflower": 3}, "coins": 125, "xp": 40},
		], "bonus_coins": 120, "bonus_xp": 45},
	"fatima_picnic": {"title": "Fatimas Picknick im Park", "customer": "Fatima", "level": 10,
		"intro": "Fatima organisiert ein offenes Picknick, bei dem jede Person etwas teilen kann – ohne Anmeldung und ohne Eintritt.",
		"stages": [
			{"text": "Fatima stellt die ersten Körbe zusammen und fragt nach Tomaten und Mais für herzhafte Häppchen.", "items": {"tomato": 5, "corn": 4}, "coins": 82, "xp": 25},
			{"text": "Mehr Nachbarinnen und Nachbarn kommen dazu. Erdbeeren und Sojabohnen ergänzen das gemeinsame Buffet.", "items": {"strawberry": 4, "soy": 4}, "coins": 112, "xp": 34},
			{"text": "Zum Abschluss bleibt ein Korb für die Straßenküche übrig. Fatima sammelt Äpfel und Kartoffeln.", "items": {"apple": 5, "potato": 5}, "coins": 148, "xp": 46},
		], "bonus_coins": 160, "bonus_xp": 55},
	"cafe_opening": {"title": "Geschichten aus dem Gartencafé", "customer": "Mira", "level": 14, "requires_building": "cafe", "feature": "cafe",
		"intro": "Das Gartencafé ist eröffnet. Die ersten Gäste bringen ihre Lieblingsgeschichten mit – und Lust auf etwas Warmes.",
		"stages": [
			{"text": "Mira erinnert sich an den ersten Kaffee, den sie mit ihrer Großmutter selbst gemahlen hat. Für den Auftakt wünscht sie sich frisch geröstete Bohnen.", "items": {"roasted_coffee": 2}, "coins": 72, "xp": 22},
			{"text": "Sam erzählt, wie Hafermilch aus dem Nachbarschaftsgarten sein Lieblingsgetränk wurde. Zwei Hafer-Lattes würden den Nachmittag abrunden.", "items": {"oat_latte": 2}, "coins": 118, "xp": 36},
			{"text": "Lena bringt ein altes Rezeptbuch mit: Kaffee und Haferkekse waren immer ihre liebste Gesprächspause. Sie möchte den Moment mit allen teilen.", "items": {"coffee_cookie_plate": 2}, "coins": 160, "xp": 50},
		], "bonus_coins": 220, "bonus_xp": 75},
	"jonas_autumn": {"title": "Jonas’ Herbsttafel", "customer": "Jonas", "level": 15,
		"intro": "Jonas plant ein kostenloses Herbstessen im Gemeinschaftshaus. Jede Lieferung bringt die Nachbarschaft ein Stück näher zusammen.",
		"stages": [
			{"text": "Für die Suppe braucht Jonas Kürbisse und Rote Bete. Er schreibt: „Auch krumme Ernten sind willkommen.“", "items": {"pumpkin": 4, "beet": 4}, "coins": 118, "xp": 36},
			{"text": "Die Tafel wird länger als gedacht. Kürbis und Mais helfen, alle satt zu bekommen.", "items": {"pumpkin": 4, "corn": 6}, "coins": 152, "xp": 46},
			{"text": "Zum Dank teilen die Gäste Samen für das nächste Jahr. Jonas sammelt Kartoffeln und Sonnenblumen.", "items": {"potato": 5, "sunflower": 5}, "coins": 188, "xp": 58},
		], "bonus_coins": 220, "bonus_xp": 70},
}

const NEIGHBORHOOD_EVENT_STAGES := [
	{"name": "Samen & Geschichten", "description": "Die Nachbarschaft tauscht Saatgut und erzählt von den ersten Ernten.", "crops": ["wheat", "carrot", "oat", "potato"], "bonus_coins": 20, "bonus_xp": 8},
	{"name": "Buntes Gartenbuffet", "description": "Alle bringen etwas mit – auf dem Gartentisch ist Platz für jede Ernte.", "crops": ["tomato", "corn", "soy", "strawberry", "pumpkin", "lettuce", "cucumber", "pea"], "bonus_coins": 35, "bonus_xp": 12},
	{"name": "Langer Café-Nachmittag", "description": "Das Gartencafé bleibt offen: Lieblingsrezepte und kleine Geschichten werden geteilt.", "cafe_recipes": ["filter_coffee", "oat_latte", "coffee_cookie_plate", "pumpkin_spice_latte", "blueberry_coffee_cake"], "crops": ["apple", "sunflower", "blueberry", "rice", "quinoa"], "bonus_coins": 55, "bonus_xp": 18},
]
const NEIGHBORHOOD_EVENT_STORIES := [
	"Ich habe die ersten Samen von meiner Nachbarin bekommen. Jetzt kann ich ihr endlich eigene zurückgeben.",
	"Wir haben alle etwas anderes mitgebracht – und am Ende hat jede Person von allem probiert.",
	"Zwischen Kaffeetassen und Gartenstühlen erzählen wir uns, was dieses Jahr gewachsen ist – nicht nur im Beet.",
]

const CAFE_MENU := ["filter_coffee", "oat_latte", "coffee_cookie_plate", "pumpkin_spice_latte", "blueberry_coffee_cake"]
const CAFE_VISITOR_STORIES := [
	"Der Duft erinnert mich an die Sonntage, an denen wir gemeinsam gebacken haben.",
	"Ich wollte schon lange einen ruhigen Ort, an dem man einfach sitzen und erzählen darf.",
	"Meine Freundin hat mir gezeigt, wie gut Hafermilch im Kaffee schmeckt.",
	"Ich sammle besondere Tassen. Diese hier war ein Geschenk von meinem Bruder.",
	"Nach dem Spaziergang durch den Garten ist eine warme Tasse genau richtig.",
	"Ich lerne gerade für eine Prüfung – kleine Kaffeepausen helfen mir dabei.",
	"Der Kürbisduft erinnert mich an einen goldenen Herbstnachmittag mit meiner Schwester.",
	"Blaubeeren und Kaffee? Das klingt nach genau der gemütlichen Pause, die ich heute brauche.",
	"Ich habe das Rezept meiner Nachbarin mitgebracht – sie sagt, ein guter Kuchen schmeckt gemeinsam am besten.",
	"Heute gönne ich mir etwas Besonderes. Der Garten ist mein liebster Ort für eine kleine Feier.",
]
const CUSTOMERS := ["Lena", "Jonas", "Mira", "Oskar", "Fatima", "Ben", "Sofia", "Karim", "Hanna", "Leo", "Yuki", "Pia", "Tarek", "Ida", "Sam"]

## Alle handelbaren Gegenstände (Feldfrüchte, Zutaten, Produkte).
var items := {}


func weather_index_at(seconds: float) -> int:
	var cycle_length := WEATHER_DURATION_SECONDS * float(WEATHER_TYPES.size())
	return int(floor(fposmod(seconds, cycle_length) / WEATHER_DURATION_SECONDS))


func weather_at(seconds: float) -> String:
	return WEATHER_TYPES[weather_index_at(seconds)]


func seconds_into_weather(seconds: float) -> float:
	return fposmod(seconds, WEATHER_DURATION_SECONDS)


func rainbow_strength_at(seconds: float, night: bool = false) -> float:
	if night or weather_at(seconds) != "Nebel":
		return 0.0
	var elapsed := seconds_into_weather(seconds)
	if elapsed >= 15.0:
		return 0.0
	return clampf(minf(elapsed / 2.0, (15.0 - elapsed) / 2.0), 0.0, 1.0)


func weather_growth_rate(weather: String) -> float:
	return float(WEATHER_GROWTH_RATES.get(weather, 1.0))


func weather_effect_text(weather: String) -> String:
	match weather:
		"Bewölkt":
			return "Wetter: Bewölkt · Wachstum −10%"
		"Regen":
			return "Wetter: Regen · Wachstum +25%"
		"Nebel":
			return "Wetter: Nebel · Wachstum normal"
	return "Wetter: Sonnig · Wachstum normal"


## Jahreszeit zu einem Spieltag (Tag 1 ist der erste Frühlingstag).
func season_index_at(day: int) -> int:
	return posmod(floori(float(maxi(1, day) - 1) / float(SEASON_DAYS)), SEASONS.size())


func season_at(day: int) -> Dictionary:
	return SEASONS[season_index_at(day)]


func season_name_at(day: int) -> String:
	return String(season_at(day)["name"])


## Tag innerhalb der laufenden Jahreszeit, beginnend bei 1.
func season_day_at(day: int) -> int:
	return posmod(maxi(1, day) - 1, SEASON_DAYS) + 1


## Saisonpflanzen einer Jahreszeit (IDs aus CROPS).
func season_crops_at(day: int) -> Array:
	return season_at(day)["crops"]


func crop_in_season(crop: String, day: int) -> bool:
	return season_crops_at(day).has(crop)


func season_crop_names_at(day: int) -> Array:
	var out: Array = []
	for id in season_crops_at(day):
		out.append(item_name(String(id)))
	return out


## HUD-Kurzform, z. B. "Herbst · Tag 2/6".
func season_label_at(day: int) -> String:
	return "%s · Tag %d/%d" % [season_name_at(day), season_day_at(day), SEASON_DAYS]


func season_effect_text_at(day: int) -> String:
	return "In der Saison: %s · je +1 Ertrag und +1 XP" % ", ".join(PackedStringArray(season_crop_names_at(day)))


func _crop_growth_seconds_in_partial_cycle(start_time: float, end_time: float) -> float:
	var growth := 0.0
	var cursor := start_time
	while cursor < end_time - 0.000001:
		var phase := floori(cursor / WEATHER_DURATION_SECONDS)
		var phase_end := (float(phase) + 1.0) * WEATHER_DURATION_SECONDS
		var segment_end := minf(end_time, phase_end)
		var weather_index := posmod(phase, WEATHER_TYPES.size())
		growth += (segment_end - cursor) * weather_growth_rate(WEATHER_TYPES[weather_index])
		cursor = segment_end
	return growth


## Effektive Wachstumszeit für einen Zeitraum, effizient auch bei langen Offline-Abwesenheiten.
func crop_growth_seconds_between(start_time: float, end_time: float) -> float:
	if end_time <= start_time:
		return 0.0
	var cycle_length := WEATHER_DURATION_SECONDS * float(WEATHER_TYPES.size())
	var cursor := start_time
	var growth := 0.0
	var first_cycle_end: float = (floor(cursor / cycle_length) + 1.0) * cycle_length
	var first_end := minf(end_time, first_cycle_end)
	growth += _crop_growth_seconds_in_partial_cycle(cursor, first_end)
	cursor = first_end
	if cursor >= end_time:
		return growth
	var average_growth_per_cycle := 0.0
	for weather in WEATHER_TYPES:
		average_growth_per_cycle += weather_growth_rate(weather) * WEATHER_DURATION_SECONDS
	var full_cycles := floori((end_time - cursor) / cycle_length)
	growth += float(full_cycles) * average_growth_per_cycle
	cursor += float(full_cycles) * cycle_length
	if cursor < end_time:
		growth += _crop_growth_seconds_in_partial_cycle(cursor, end_time)
	return growth


## Reale Wartezeit bis zur verbleibenden effektiven Wachstumszeit; maximal wenige Wetterphasen.
func real_seconds_for_crop_growth(start_time: float, growth_needed: float) -> float:
	var remaining := maxf(0.0, growth_needed)
	var cursor := start_time
	var elapsed := 0.0
	while remaining > 0.000001:
		var phase := floori(cursor / WEATHER_DURATION_SECONDS)
		var phase_end := (float(phase) + 1.0) * WEATHER_DURATION_SECONDS
		var rate := weather_growth_rate(WEATHER_TYPES[posmod(phase, WEATHER_TYPES.size())])
		var segment_duration := phase_end - cursor
		var growth_available := segment_duration * rate
		if remaining <= growth_available:
			return elapsed + remaining / rate
		remaining -= growth_available
		elapsed += segment_duration
		cursor = phase_end
	return elapsed


func _init() -> void:
	for id in CROPS:
		var c: Dictionary = CROPS[id]
		items[id] = {"id": id, "name": c.name, "sell": c.sell, "col": c.col, "kind": "crop", "level": c.level}
	for id in FORAGE:
		var f: Dictionary = FORAGE[id]
		items[id] = {"id": id, "name": f.name, "sell": f.sell, "col": f.col, "kind": "forage", "level": f.level}
	for id in EXTRA_ITEMS:
		var e: Dictionary = EXTRA_ITEMS[id]
		items[id] = {"id": id, "name": e.name, "sell": e.sell, "col": e.col, "kind": "extra", "level": e.level}
	for id in RECIPES:
		var r: Dictionary = RECIPES[id]
		items[id] = {"id": id, "name": r.name, "sell": r.sell, "col": r.col, "kind": "product", "level": r.level}


## Erfahrung für den Aufstieg von lvl auf lvl + 1. Früh moderat, später deutlich
## steiler: Erfolge und Quests beschleunigen den Start, tragen aber nicht mehr
## allein bis zur Maximalstufe.
static func xp_needed(lvl: int) -> int:
	return 30 + 12 * lvl + 2 * lvl * lvl


## Stabile, ortsgebundene Zufallszahl (0…1) für Gelände, Sammelstellen und Deko.
## Gleiche Zelle + gleicher Salt ergibt immer denselben Wert – auch nach Neustart.
static func cell_hash(x: int, y: int, salt: int = 0) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n) % 10000) / 10000.0


func item_name(id: String) -> String:
	if items.has(id):
		return items[id].name
	return id


## Sammelstelle für eine Zelle außerhalb der Farm. Deterministisch aus der
## Zellposition abgeleitet, damit Fundstellen nach einem Neustart gleich bleiben.
func forage_at(cell: Vector2i, land_rect: Rect2i) -> String:
	if FORAGE.is_empty() or land_rect.has_point(cell):
		return ""
	if land_rect.grow(FORAGE_EDGE_CELLS).has_point(cell):
		return ""
	if not land_rect.grow(FORAGE_BAND_CELLS).has_point(cell):
		return ""
	if cell_hash(cell.x, cell.y, 71) >= FORAGE_CHANCE:
		return ""
	# Nicht in einen Baum setzen: das Gelände zeichnet dort eine Krone.
	var world := Rect2i(WORLD_ORIGIN, Vector2i(WORLD_COLS, WORLD_ROWS))
	var tree_chance := 0.5 if not world.has_point(cell) else 0.1
	if cell_hash(cell.x, cell.y, 3) < tree_chance:
		return ""
	var ids: Array = FORAGE.keys()
	var roll := cell_hash(cell.x, cell.y, 72)
	return String(ids[mini(ids.size() - 1, int(roll * float(ids.size())))])


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
	for id in FORAGE:
		if FORAGE[id].level == lvl:
			out.append("Wildnis: " + String(FORAGE[id].name))
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
