# Green Haven

Ein gemütliches veganes Farming-Spiel für Smartphones (zuerst Android, iOS vorbereitet).
Gebaut mit Godot 4.4, GDScript und 2D-Rendering – keine Web-App, kein Backend, vollständig offline spielbar.
Das Spiel läuft im **Querformat**.

Du startest mit einer kleinen Farm, baust Gemüse, Obst und Getreide an, stellst vegane Produkte in Bäckerei,
Küche, Pflanzenmilch-Manufaktur, Tofu-Werkstatt, Saftbar und Gartencafé her, erfüllst Kundenaufträge und gibst
geretteten Tieren ein Zuhause. Die Tiere produzieren nichts – sie werden einfach nur umsorgt.

## Umfang

- 22 Pflanzen mit mehreren Wachstumsstufen, stufenbasierter Progression und Freischaltsystem. Alle Pflanzen sind einjährig: Nach der Ernte wird das Feld frei und muss neu bestellt werden
- Weitere Pflanzen: Kürbis, Rote Bete, Rhabarber, Salat, Zucchini, Gurke, Erbsen, Heidelbeeren, Reis, Quinoa und Kaffee (für das Café)
- Mandeln als Feldfrucht ab Stufe 5: pflanzbar, erntbar und Grundlage für Mandelmilch
- 12 Produktionsgebäude (inkl. Gartencafé), 46 Rezepte, Warteschlangen, Ausbaustufen und Abholfunktion
- Neue Produktionsketten: Blumenwerkstatt (8), Ölmühle (9), Konfitürenküche (9), Nudelwerkstatt (10), Eismanufaktur (11) und Müsli-Manufaktur (14); Zucker für Konfitüren gibt es im Land-Shop
- Produktions-Dashboard: alle Gebäude mit Warteschlange, Restzeiten und abholbaren Produkten auf einen Blick, Sammelabholung und Badge in der Navigation
- Kundenaufträge, Münzen, Erfahrungspunkte, Quests, Shop, Dekoration und Landerweiterung
- Tierrefugium mit 5 Tierarten, eigenen Charakterzügen, optionalen artspezifischen Aktivitäten, wählbaren kosmetischen Belohnungen und Rettungsangeboten ohne Druck
- Refugium-Tagebuch für Rettungen und gemeinsame Momente, Freundschaftsstufen mit animierten Reaktionen und Profilgeschichten
- Optionale mehrteilige Nachbarschafts-Lieferungsgeschichten mit gespeichertem Fortschritt und Abschlussbelohnungen
- 25 einlösbare Erfolge für Aufträge, Ernten, Herstellung, Tierpflege, Freundschaft, Geschichten, Café, neue Produktionsketten und Farmerweiterung
- Belegungs- und Wohlbefinden-Übersicht pro Gehege; Tierprofile, Tagebuch und Geschichtenfortschritt sind Teil der versionierten Spielstände
- Wetter: Sonnig, Bewölkt, Regen und Nebel wechseln alle 120 Sekunden. Bewölkt verlangsamt das Wachstum um 10 %, Regen beschleunigt es um 25 %. Die Wachstumszeiten berücksichtigen den Wetterverlauf, auch während der Offline-Zeit
- Tag-Nacht-Zyklus mit Uhrzeitanzeige: ein Spieltag dauert 8 Minuten echter Zeit, mit Dämmerung und Farbstimmung
- Tageszähler und Tagesrückblick: „Tag N“ steht im HUD. Beim Tageswechsel und nach einer längeren Pause zeigt ein kurzer Rückblick Ernten, erfüllte Aufträge, Tiermomente und hergestellte Produkte. Alte Spielstände starten ohne rückwirkende Tageshistorie und werden automatisch migriert (Save-Version 9)
- Kosmetisches Tier-Ambiente: Bei Regen gehen Tiere in den Gehege-Unterstand; nachts schlafen sie dort mit geschlossenen Augen, ruhiger Atmung und kleinen „Z“. Individuelle Schlafzeiten lassen nachts mindestens ein Tier wach; Streicheln weckt kurz auf. Nach Regen erscheint im Nebel für etwa 15 Sekunden ein ein-/ausblendender Regenbogen. Keine Auswirkung auf Werte oder Spielstände.
- Touch-Steuerung: Tippen, Wischen zum Säen/Ernten, Kamera verschieben mit Trägheit, Pinch-Zoom, Platzieren per Ziehen
- Lokales, versioniertes Speichersystem (geprüftes Laden, rotierendes Backup, Spielstände neuerer Versionen werden nie überschrieben); Wachstum und Produktion laufen offline weiter
- Spielstände als JSON exportieren und importieren (Import wird vor dem Ersetzen geprüft; bisheriger Stand wird als Backup gesichert)
- Soundeffekte (zur Laufzeit erzeugt), Vibrations-Feedback und optionale Hintergrundmusik; Ton, Musik und Vibration lassen sich in den Einstellungen abschalten

## Schnellstart

```bash
godot --headless --path . -s res://tests/run_tests.gd        # Logiktests
godot --headless --path . -s res://tests/achievements_ui.gd  # UI-Tests (Menüs, Tagebuch, Erfolge)
godot --headless --path . -s res://tests/save_transfer_ui.gd # UI-Test Spielstand-Export/Import
godot --headless --path . -s res://tests/production_overview_ui.gd # UI-Test Produktions-Dashboard
godot --path .                                               # Spiel auf dem Desktop starten
```

Android-APK, iOS und Release-Builds: siehe [docs/BUILD.md](docs/BUILD.md).
Jeder Push startet GitHub Actions (`.github/workflows/android.yml`), die die Tests ausführen und einen Debug-APK bauen
(Artefakt `GreenHaven-build` unter Actions).

## Projektstruktur

```text
audio/           Hintergrundmusik (Sunlight_on_the_Path.mp3)
scripts/core/    GameData (Balancing), GameState (Logik), SaveSystem, Sfx, BackgroundMusic
scripts/world/   Welt, Kamera/Touch, Gelände, Felder, Objekte, Tiere, Painter
scripts/ui/      UiRoot (HUD, Aktionen), UiKit, Icons, sheets/ (Menüs)
scenes/          main, world, ui_root, entity, animal
tests/           run_tests.gd, achievements_ui.gd, save_transfer_ui.gd, screenshots.gd,
                 suites/ (inkl. Tier-Wetter-Ambiente), fixtures/ (Test-Spielstände)
docs/            BUILD.md
```
