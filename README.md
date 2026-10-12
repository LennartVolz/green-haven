# Green Haven

Gemütliches veganes Farming-Spiel für Smartphones (Android zuerst, iOS vorbereitet).
Gebaut mit **Godot 4.4**, **GDScript** und 2D-Rendering – keine Web-App, kein Backend, komplett offline spielbar.

Du startest mit einer kleinen Farm, baust Gemüse, Obst und Getreide an, stellst vegane Produkte in
Bäckerei, Küche, Pflanzenmilch-Manufaktur, Tofu-Werkstatt und Saftbar her, erfüllst Kundenaufträge und
gibst geretteten Tieren ein Zuhause. Die Tiere produzieren nichts – sie werden einfach gepflegt.

## Umfang

- 10 Pflanzen mit mehreren Wachstumsphasen, Stufen- und Freischaltsystem
- 5 Produktionsgebäude, 14 Rezepte, Warteschlangen, Ausbau und Abholfunktion
- Kundenaufträge, Münzen, XP, Quests, Shop, Dekoration, Landerweiterung
- Tierrefugium mit 5 Tierarten, Bedürfnissen, Streicheln/Füttern und kosmetischen Belohnungen
- Touch-Steuerung: Tippen, Wischen zum Säen/Ernten, Kamera-Pan mit Trägheit, Pinch-Zoom, Platzieren per Ziehen
- Lokaler, versionierter Spielstand; Wachstum und Produktion laufen offline weiter

## Schnellstart

```
godot --headless --path . -s res://tests/run_tests.gd   # Logiktests (328 Prüfungen)
godot --path .                                          # Spiel am Desktop starten
```

Android-APK, iOS und Release-Builds: siehe [docs/BUILD.md](docs/BUILD.md).
Bei jedem Push baut GitHub Actions (`.github/workflows/android.yml`) die Tests und einen Debug-APK
(Artefakt `GreenHaven-debug-apk` unter *Actions*).

## Projektstruktur

```
scripts/core/    GameData (Balancing), GameState (Logik), SaveSystem, Sfx
scripts/world/   Welt, Kamera/Touch, Gelände, Felder, Objekte, Tiere, Painter
scripts/ui/      UiRoot (HUD, Aktionen), UiKit, Icons, sheets/ (Menüs)
scenes/          main, world, ui_root, entity, animal
tests/           run_tests.gd, screenshots.gd
docs/            BUILD.md
```
