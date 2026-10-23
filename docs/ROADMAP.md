# Roadmap

Die Reihenfolge folgt einer Entscheidung: **Tiefe statt Breite**. Vorhandene Systeme
(Café, Refugium, Nachbarschaft, Sammlung) bekommen mehr Entscheidungen, statt dass
neue Systeme daneben treten. Alles bleibt offline, im bestehenden Godot-Projekt und
ohne neue Abhängigkeiten.

Jedes Paket ist für sich spielbar, testbar und auslieferbar. Die Reihenfolge ist so
gewählt, dass kein Paket auf ein späteres wartet.

## Paket 1 – Lesbarkeit

**Status: umgesetzt.**

Einstellbare Schriftgröße (Klein / Normal / Groß), größere Schaltflächen und ein
kontrastreiches Farbschema. Die drei Werte liegen in `GameState.settings` und
überleben Speichern, Laden und Export. `UiKit` formt Schrift, Mindesthöhen und
Palette zentral, deshalb genügt ein Schalter statt einer zweiten Oberfläche.

Warum zuerst: Jedes spätere Menü erbt die Einstellung, und auf einem Telefon in
der Sonne entscheidet Lesbarkeit darüber, ob ein Feature überhaupt ankommt.

## Paket 2 – Hoflexikon

**Status: umgesetzt.**

Ein Nachschlagewerk für alles, was der Hof hervorbringt: Pflanzen, Rezepte,
Tierarten und Fundstücke. Jeder Eintrag zeigt, wo er herkommt, was er wert ist –
und was noch fehlt. Lücken sind sichtbar, aber ohne Zeitdruck.

**Umfang**
- Neuer Bereich „Lexikon" als Sheet, geöffnet aus dem Erfolge-Menü (die Navigation
  bleibt bei sieben Einträgen).
- Reiter bzw. Abschnitte: Pflanzen, Gerichte, Tiere, Fundstücke.
- Ein Eintrag gilt als entdeckt, sobald er einmal geerntet, hergestellt, gerettet
  oder gesammelt wurde.
- Fortschrittszeile je Abschnitt („18 von 23 Pflanzen") und eine Gesamtzeile.
- Rezeptseite zeigt Zutaten und Verarbeitungsgebäude aus `GameData`.

**Bewusst nicht:** keine Boni, keine Münzen, kein Zwang zu sammeln. Das Lexikon
erklärt, es belohnt nicht.

**Daten & Spielstand:** Die Entdeckung wird vollständig abgeleitet – aus den
vorhandenen Lebenszeit-Zählern (`harvested:<sorte>`, `crafted_<rezept>`), dem
Vorrat und den Tieren im Refugium. Für Fundstücke kommt ein Zähler
`foraged:<stelle>` dazu, der beim Sammeln mitläuft. Es gibt keinen eigenen
Lexikon-Eintrag im Spielstand, deshalb brauchen ältere Stände keine Migration:
Sie zeigen sofort, was ihre Zähler und ihr Vorrat hergeben.

**Tests:** Jeder Eintrag hat einen deutschen Namen und einen Katalogeintrag in
allen fünf Sprachen (der i18n-Test deckt das ab). Ein Logiktest prüft, dass
Entdeckungen aus Zählern ableitbar sind und ein alter Spielstand ohne
`discovered` lädt. Layout-Test: kein Text wird gequetscht, Sheet bleibt im Bild.

**Aufwand:** mittel (2–3 Abende). **Risiko:** gering, reine Leseansicht.

## Paket 3 – Café-Gäste

**Status: umgesetzt.**

Das Gartencafé ist ein Ort statt einer Produktionsstätte: Zu Öffnungszeiten
setzen sich Gäste an die Tische, bestellen ein Gericht aus der Karte und zahlen
nach dem Essen. Der Tagesumsatz steht im Café-Sheet, die Erweiterung stellt
Tische auf und zieht mehr Laufkundschaft an.

**Umfang**
- Tische als Ausbaustufe des Cafés (1 bis 4), jeder Tisch ein Sitzplatz.
- Zu Öffnungszeiten (Spielzeit 10–18 Uhr) kommen Gäste, setzen sich, bestellen
  ein Gericht aus der vorhandenen Karte und zahlen nach dem Verzehr.
- Wer nichts auf Lager hat, lässt den Gast gehen – höflich, ohne Strafe.
- Tagesumsatz und „heute zufriedene Gäste" im Café-Sheet.
- Ein Café-Ausbau erhöht gleichzeitig Plätze und Nachfrage.

**Bewusst nicht:** kein Zeitdruck, keine Bewertungen, kein Personalmanagement.

**Daten & Spielstand:** Tischanzahl ist Teil der Café-Ausbaustufe (vorhanden),
Gäste sind flüchtig und leben nur im laufenden Spiel; gezählt werden Gäste und
Umsatz in `stats`. Kein neuer Spielstand-Zwang, keine Version nötig.

**Tests:** Logiktest für Sitzplatzvergabe, Bedienung, Tagesreset und Offline-Zeit
(Gäste erscheinen nicht rückwirkend). UI-Test für das Café-Sheet. Layout-Test für
die Gästezeilen in allen Sprachen.

**Aufwand:** groß (4–6 Abende). **Risiko:** mittel – braucht eine kleine
Zustandsmaschine und darf die Produktionswarteschlange nicht stören.

## Paket 4 – Tierroutinen und Ausflüge

**Status: umgesetzt.**

Die Tiere bekommen einen Tagesablauf und ab und zu ein gemeinsames Ereignis.

**Umfang**
- Feste Tageszeiten je Tier: morgens im Gehege, mittags Schatten, abends
  Unterstand, nachts Schlaf (die vorhandene Ambiente-Logik wird zur Grundlage).
- Ein bis zwei Ausflüge pro Spieltag: zwei Tiere gehen gemeinsam zu einem Ziel
  (Waldrand, Wiese, Bach) und kommen nach einer Weile zurück.
- Der Spieler kann einen Ausflug begleiten: kurze Szene mit zwei Sätzen, einem
  Foto fürs Refugium-Tagebuch und einem Freundschaftsherz.
- Ein Ausflug ist optional und verfällt ohne Nachteil.

**Bewusst nicht:** keine Zucht, keine Produktion, keine Zufriedenheitswerte, die
sinken können.

**Daten & Spielstand:** Ausflugsziele und Texte in `GameData`; im Spielstand nur
die laufende Ausflugs-ID und die Freundschaftsherzen (vorhanden). Alte Stände
starten ohne laufenden Ausflug.

**Tests:** Logiktest für Auswahl, Dauer, Rückkehr und Offline-Verhalten;
UI-Test für die Ausflugsszene; Layout-Test für die Tagebuchzeile.

**Aufwand:** mittel bis groß (3–4 Abende). **Risiko:** gering, das Ambiente-System
trägt den Großteil.

## Paket 5 – Briefe und Besuche

**Status: umgesetzt.**

Sechs Nachbarn schreiben kurze Briefe, ab und zu mit einer kleinen Bitte; ab dem
zweiten Brief öffnet sich ihr Hof als gemalte Szene mit zwei antippbaren Stellen.
Freundschaft wächst durch Lesen, Liefern und Besuche – und schenkt ab Stufe 2 ein
Namensschild für den eigenen Hof. Der Briefkasten sitzt als Knopf in der Kopfzeile
des Auftragsbuchs, damit die vier Aufträge darunter sichtbar bleiben.

**Umfang**
- Sechs feste Nachbarn mit eigenem Ton, die in unregelmäßigen Abständen kurze
  Briefe schreiben: eine Bitte, ein Dank, eine Beobachtung.
- Ein Brief kann eine kleine Lieferung anbieten (wie die vorhandenen Geschichten)
  oder nur erzählen. Nichts läuft ab.
- Ab dem zweiten Besuch darfst du einen Hof besuchen: eine statische, gemalte
  Szene mit zwei bis drei antippbaren Stellen, die einen Satz erzählen.
- Freundschaftsstufe je Nachbar, rein erzählerisch; ab Stufe 2 gibt es eine
  Namensdeko für den eigenen Hof.

**Bewusst nicht:** kein Chat, kein Online-Besuch, keine Gegenseitigkeit, die
Zeit kostet.

**Daten & Spielstand:** Nachbarn, Briefe und Szenen in `GameData`; im Spielstand
gelesene Briefe, Freundschaftsstufen und die laufende Szene. Ältere Stände starten
leer.

**Tests:** Logiktest für Briefauswahl (keine Wiederholung), Lesen, Besuch und
Deko-Freischaltung; UI-Test für Briefliste und Szene; Layout-Test in allen
Sprachen, weil Brieftexte lang sind.

**Aufwand:** groß (4–5 Abende). **Risiko:** mittel – viel Text, der in fünf
Sprachen gepflegt werden muss.

## Paket 6 – Hofränge

**Status: umgesetzt.**

Sechs Ränge oberhalb der Auszeichnungen: „Aufgehender Hof" bis „Weiter Hof". Jeder
Rang verlangt zwei bis vier Bereiche gleichzeitig – Lexikon, Erntesorten,
Jahreszeiten, Saisonziele, Rezepte, Café-Gäste, Café-Geschichten, Briefe,
Hofbesuche, Freundschaften, Hofbuch-Einträge oder Erfolge – und nichts davon gibt
Münzen, XP oder Stärke. Einmal erreicht, bleibt ein Rang; er schenkt ein sichtbares
Zeichen am Hof (Wimpel, Tor, Bank unter dem Baum, Glocke, Meilenstein, Hoftafel)
und einen kurzen Absatz. Die Ränge stehen oben im Hofbuch, damit die Navigation
unverändert bleibt.

Das Endgame nach Stufe 23 und nach allen Erfolgen.

**Umfang**
- Sechs Hofränge (z. B. „Aufgehender Hof", „Alter Hof"), die dauerhaft bleiben.
- Jeder Rang verlangt Breite statt Zahlen: eine Mischung aus Lexikon-Fortschritt,
  Café-Gästen, Ausflügen, Briefen und Jahreszielen.
- Ein Rang schaltet nichts Stärkeres frei, sondern eine sichtbare Veränderung am
  Hof: Wimpel, Tor, Bank unter dem Baum, Namensschild – und einen kurzen Absatz.
- Anzeige im Hofbuch, damit die Navigation bei sieben Einträgen bleibt.

**Bewusst nicht:** kein Prestige, kein Neuanfang, kein Macht-Zuwachs. Wer alle
Ränge hat, hat einen schönen Hof – keinen schnelleren.

**Daten & Spielstand:** Ränge in `GameData`, Fortschritt aus vorhandenen Zählern.
Kein neuer Spielstand-Zwang.

**Tests:** Logiktest für Rangbedingungen und Freischaltung; Hofbuch-Test;
Layout-Test für die Rangzeilen.

**Aufwand:** mittel (2 Abende), weil es auf den Zählern der Pakete 2–5 aufsetzt.
**Risiko:** gering, aber es lohnt erst, wenn Paket 2–5 stehen.

## Querschnitt

- **Sprachen:** Jeder neue Text kommt in alle fünf Kataloge; der i18n-Test bricht
  den Build, wenn ein Literal fehlt oder ein Platzhalter verloren geht.
- **Layout:** Jedes neue Sheet läuft durch `tests/layout_ui.gd` – gequetschter
  Text, Überlauf, Sheet-Höhe und die drei Lesbarkeitsstufen.
- **Spielstand:** Neue Felder sind optional und werden beim Laden mit
  Standardwerten ergänzt. Eine Versionserhöhung gibt es nur, wenn Daten
  umgeschrieben werden müssen.
- **Offline:** Kein Paket braucht einen Server, ein Konto oder eine
  Netzwerkberechtigung.
