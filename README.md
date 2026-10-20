# Green Haven

Ein gemütliches veganes Farming-Spiel für Smartphones (zuerst Android, iOS vorbereitet).
Gebaut mit Godot 4.4, GDScript und 2D-Rendering – keine Web-App, kein Backend, vollständig offline spielbar.
Das Spiel läuft im **Querformat**.

Du startest mit einer kleinen Farm, baust Gemüse, Obst und Getreide an, stellst vegane Produkte in Bäckerei,
Küche, Pflanzenmilch-Manufaktur, Tofu-Werkstatt, Saftbar und Gartencafé her, erfüllst Kundenaufträge und gibst
geretteten Tieren ein Zuhause. Die Tiere produzieren nichts – sie werden einfach nur umsorgt.

## Umfang

- 19 Pflanzen mit mehreren Wachstumsstufen, stufenbasierter Progression und Freischaltsystem
- Weitere Pflanzen: Kürbis, Rote Bete, Salat, Gurke, Erbsen, mehrjährige Heidelbeeren, Reis, Quinoa und mehrjähriger Kaffee (für das Café)
- 6 Produktionsgebäude (inkl. Gartencafé), 26 Rezepte, Warteschlangen, Ausbaustufen und Abholfunktion
- Kundenaufträge, Münzen, Erfahrungspunkte, Quests, Shop, Dekoration und Landerweiterung
- Tierrefugium mit 5 Tierarten, eigenen Charakterzügen, optionalen artspezifischen Aktivitäten, wählbaren kosmetischen Belohnungen und Rettungsangeboten ohne Druck
- Refugium-Tagebuch für Rettungen und gemeinsame Momente, Freundschaftsstufen mit animierten Reaktionen und Profilgeschichten
- Optionale mehrteilige Nachbarschafts-Lieferungsgeschichten mit gespeichertem Fortschritt und Abschlussbelohnungen
- 13 einlösbare Erfolge für Aufträge, Ernten, Herstellung, Tierpflege, Freundschaft, Geschichten, Café und Farmerweiterung
- Belegungs- und Wohlbefinden-Übersicht pro Gehege; Tierprofile, Tagebuch und Geschichtenfortschritt sind Teil der versionierten Spielstände
- Wetter: Sonnig, Bewölkt, Regen und Nebel wechseln alle 120 Sekunden. Bewölkt verlangsamt das Wachstum um 10 %, Regen beschleunigt es um 25 %. Die Wachstumszeiten berücksichtigen den Wetterverlauf, auch während der Offline-Zeit
- Tag-Nacht-Zyklus mit Uhrzeitanzeige: ein Spieltag dauert 8 Minuten echter Zeit, mit Dämmerung und Farbstimmung
- Touch-Steuerung: Tippen, Wischen zum Säen/Ernten, Kamera verschieben mit Trägheit, Pinch-Zoom, Platzieren per Ziehen
- Lokales, versioniertes Speichersystem (geprüftes Laden, rotierendes Backup, Spielstände neuerer Versionen werden nie überschrieben); Wachstum und Produktion laufen offline weiter
- Spielstände als JSON exportieren und importieren (Import wird vor dem Ersetzen geprüft; bisheriger Stand wird als Backup gesichert)
- Soundeffekte (zur Laufzeit erzeugt), Vibrations-Feedback und optionale Hintergrundmusik; Ton, Musik und Vibration lassen sich in den Einstellungen abschalten

## Schnellstart

```bash
godot --headless --path . -s res://tests/run_tests.gd        # Logiktests
godot --headless --path . -s res://tests/achievements_ui.gd  # UI-Tests (Menüs, Tagebuch, Erfolge)
godot --headless --path . -s res://tests/save_transfer_ui.gd # UI-Test Spielstand-Export/Import
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
                 suites/ (Testgruppen), fixtures/ (Test-Spielstände)
docs/            BUILD.md
```
