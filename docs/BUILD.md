# Green Haven – Build und Installation

Green Haven ist ein natives Godot-4.4-Spiel (GDScript, 2D). Es gibt keine Web-App,
kein Backend und keine Plugins. Das Spiel läuft komplett offline.

## Voraussetzungen

| Was | Version |
| --- | --- |
| Godot Engine | 4.4.1 (Standard-Version, nicht .NET) |
| Godot-Export-Templates | 4.4.1 (Editor → *Projekt → Export → Export-Templates verwalten*) |
| JDK | 17 |
| Android SDK | Platform-Tools, Build-Tools 34.0.0, Platform android-34, Command-line Tools, CMake 3.10.2 |

## Android-APK bauen (Debug, direkt installierbar)

1. Android SDK installieren, am einfachsten über Android Studio (*SDK Manager*).
2. In Godot: *Editor → Editoreinstellungen → Export → Android*
   - **Android SDK Path**: Pfad zum SDK
   - **Debug Keystore**: wird von Godot beim ersten Export angeboten, oder per
     ```
     keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
       -keystore debug.keystore -storepass android \
       -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
     ```
     Benutzer `androiddebugkey`, Passwort `android`.
3. Projekt öffnen (`project.godot`), *Projekt → Exportieren → Android → Projekt exportieren*,
   oder auf der Kommandozeile:
   ```
   godot --headless --path . --import
   godot --headless --path . --export-debug "Android" build/GreenHaven.apk
   ```
4. APK aufs Smartphone bringen:
   ```
   adb install -r build/GreenHaven.apk
   ```
   Oder USB-Debugging aktivieren und in Godot oben rechts auf das Android-Symbol
   („Auf Gerät ausführen“) klicken.

Die Export-Konfiguration liegt in `export_presets.cfg` (arm64-v8a, Vibration erlaubt, kein Internet-Zugriff).
Das Spiel ist bewusst für **Querformat** ausgelegt: `project.godot` setzt `display/window/handheld/orientation=0`
und ein Viewport von 1920×1080. Das UI ist darauf abgestimmt; ein Wechsel auf Hochformat wäre eine größere Layout-Änderung
und kein reiner Schalter.

### Build per CI (GitHub Actions)

`.github/workflows/android.yml` führt zuerst die Logiktests aus und baut dann
einen Debug-APK als Download-Artefakt. Dafür das Projekt in ein GitHub-Repository
pushen. Der Workflow nutzt das Image `barichello/godot-ci:4.4.1`.

### Release-Build für den Play Store

1. Eigenen Release-Keystore erzeugen (`keytool -genkeypair …`) und **sicher aufbewahren**.
2. Im Export-Preset *Android* unter *Keystore → Release* Datei, Benutzer und Passwort eintragen.
3. *Gradle Build verwenden* aktivieren, Export-Format *AAB* wählen
   (`Projekt → Install Android Build Template` vorher ausführen).
4. `version/code` bei jedem Upload erhöhen.

## iOS (vorbereitet)

Das Projekt nutzt nur plattformneutrale Funktionen (GL Compatibility, `user://`,
Touch-Eingabe). Das Preset *iOS* in `export_presets.cfg` ist angelegt.
Notwendig sind ein Mac mit Xcode, ein Apple-Developer-Konto und die iOS-Export-Templates:

1. `application/app_store_team_id` im Preset eintragen.
2. *Projekt → Exportieren → iOS* erzeugt ein Xcode-Projekt in `build/ios/`.
3. In Xcode Signing wählen und auf das Gerät oder in TestFlight bringen.

## Tests

Die gesamte Spiellogik (Anbau, Wetter und Tag-Nacht-Zyklus, Inventar, Produktion, Aufträge, Quests, Tiere, Land,
Café, Nachbarschaftsgeschichten, Erfolge, Speicherstand, Offline-Fortschritt, Migration, Balance) wird headless geprüft:

```
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . -s res://tests/achievements_ui.gd   # UI-Test (Menüs, Tagebuch, Erfolge)
godot --headless --path . -s res://tests/save_transfer_ui.gd # UI-Test (Spielstand-Export/Import)
godot --headless --path . -s res://tests/production_overview_ui.gd # UI-Test (Produktions-Dashboard)
godot --headless --path . -s res://tests/boot_ui.gd           # UI-Test (Ladebildschirm und Start)
godot --headless --path . -s res://tests/i18n.gd              # Übersetzungen (Kataloge, Oberfläche, Sprachwahl)
```

Exit-Code 0 bedeutet: alle Prüfungen bestanden. Alle sechs Läufe sind auch in der CI eingebunden.
`tests/i18n.gd` prüft mit `I18N_LOCALES=en,fr` auch nur eine Auswahl; ohne die Variable laufen alle vier Sprachen.

`tests/screenshots.gd` ist kein Test, sondern ein Hilfsskript für die visuelle Prüfung: Es spielt eine Szenenfolge durch
und speichert Screenshots. Es braucht ein Display (z. B. `xvfb`) und läuft nicht in der CI:

```
godot --path . --rendering-driver opengl3 --resolution 960x540 -s res://tests/screenshots.gd -- /pfad/zum/ordner
```

Testgruppen liegen in `tests/suites/`, Test-Spielstände (z. B. `save_v8.json` für die Migration) in `tests/fixtures/`.

## Projektstruktur

```
assets/          Startbild (boot_splash.svg als Quelle, boot_splash.png für die Engine)
audio/           Hintergrundmusik (Sunlight_on_the_Path.mp3)
scripts/core/    GameData (Balancing), GameState (Logik), SaveSystem, Sfx, BackgroundMusic
scripts/world/   Welt, Kamera/Touch, Gelände, Felder, Objekte, Tiere, Painter
scripts/ui/      UiRoot (HUD, Aktionen), UiKit, Icons, BootScreen, sheets/ (Menüs)
scenes/          boot, main, world, ui_root, entity, animal
tests/           run_tests.gd, achievements_ui.gd, save_transfer_ui.gd, boot_ui.gd,
                 i18n.gd, screenshots.gd, suites/ (Testgruppen), fixtures/ (Test-Spielstände)
locale/          Übersetzungskataloge de/en/fr/es/it.json (deutsche Texte = Schlüssel)
tools/           make_boot_splash.gd (PNG aus der SVG-Quelle erzeugen),
                 dump_i18n.gd (fehlende Schlüssel sammeln), merge_tr.py (Kataloge ergänzen)
docs/            diese Anleitung
```

Trennung: `GameState` kennt keine Darstellung und wird von Welt (`world.gd`) und
Oberfläche (`ui_root.gd`) nur über Signale und Methodenaufrufe benutzt.

## Spielstand

- Datei: `user://savegame.json` (Android: app-privater Speicher), Backup: `.bak`
- In den Einstellungen lassen sich JSON-Spielstände exportieren und importieren; vor einem Import werden JSON, Version und Spielzustand auf einer isolierten Kopie geprüft. Erst danach wird der bisherige Stand als Backup gesichert und der Import übernommen.
- Desktop nutzt `DisplayServer.file_dialog_show`. Godot 4.4 dokumentiert `FEATURE_NATIVE_DIALOG_FILE` für Android, jedoch nicht `FEATURE_NATIVE_DIALOG_FILE_EXTRA`; ein nativer Dialog sagt nichts über tatsächlichen Datei-Zugriff aus. Ein Godot-Fehlerbericht reproduziert in 4.4.1, dass eine ausgewählte Android-Datei nicht über `FileAccess.open()` lesbar war (https://github.com/godotengine/godot/issues/105328). Deshalb nutzt Android den app-internen Ordner `user://save_transfer/savegame.json`; Dateien müssen dort über Android-Dateiverwaltung hinein- bzw. herauskopiert werden. Geräteprüfung steht noch aus.
- Format versioniert (`version`), ältere Stände werden in `SaveSystem.migrate()` angehoben
- Gespeichert wird alle 15 s, beim Pausieren, bei Fokusverlust und beim Beenden
- Zeitbasierte Systeme speichern nur Zeitstempel, deshalb laufen Wachstum und
  Produktion offline „weiter“: beim Start wird aus der verstrichenen Zeit der Zustand abgeleitet.
  Das Pflanzenwachstum berücksichtigt dabei den Wetterverlauf der verstrichenen Zeit

## Mehrsprachigkeit

Deutsch ist die Quelle: der deutsche Text im Code ist zugleich der Schlüssel. `I18n.t("Vorrat")` und
`UiKit.label("Vorrat")` liefern den Eintrag aus `locale/<sprache>.json` – fehlt er, erscheint der deutsche
Text. Angebotene Sprachen und ihre Reihenfolge stehen in `I18n.LOCALES` (de, en, fr, es, it).

- Beim Start gilt die Gerätesprache; nicht angebotene Sprachen fallen auf Englisch zurück. In den
  Einstellungen lässt sich eine Sprache fest wählen, sie liegt im Spielstand und überlebt ein neues Spiel.
- Datennamen, Story-Texte, Meldungen und Tagebucheinträge nutzen dieselben Schlüssel. Tagebucheinträge
  speichern Schlüssel und Parameter statt des fertigen Satzes; ältere Stände werden in
  `SaveSystem.migrate()` übernommen.
- Neuer Text: deutschen Text einbauen, dann je Sprache `python3 tools/merge_tr.py en` mit Zeilen der Form
  `Deutsch|English` ergänzen. `tests/i18n.gd` meldet fehlende Schlüssel, abweichende Platzhalter und
  Literale, die in keinem Katalog stehen; der Test läuft in der CI mit.
- Was der Test sieht: Literale in `I18n.t`, `UiKit.label/button/…`, `show_toast`, `last_error = …`,
  `lines.append(…)` und `_show_modal`, die Tutorial-Texte (`TUTORIAL`), die Saison-Geschichten sowie
  Katalogschlüssel mit Leerzeichen am Rand, die kein Code verwendet. Was er nicht sieht: ein Text, den man
  direkt mit `label.text = "…"` setzt. Solche Texte immer in `I18n.t(…)` fassen.
- Das Tutorial (`TUTORIAL` in `ui_root.gd`) hat Aktionsschritte (warten auf Pflanzen, Ernten, Auftrag) und
  danach Hinweisschritte mit „Weiter“ (ab `TUTORIAL_INFO_FROM`). Die Aktionsschritte zählen nur, was seit dem
  Start des Tutorials passiert ist (`GameState.tutorial_base`), damit „Tutorial wiederholen“ wirklich bei
  Schritt 1 beginnt.
- `tools/dump_i18n.gd` öffnet alle Bereiche in allen Sprachen und schreibt fehlende Schlüssel nach
  `locale/_missing.json` – der Startpunkt für eine weitere Sprache.

## Wetter, Tageszeit und Tier-Ambiente

- Wetter (`GameData`): Sonnig, Bewölkt, Regen und Nebel wechseln in dieser Reihenfolge alle 120 Sekunden
  (`WEATHER_DURATION_SECONDS`). Wachstumsfaktoren: Sonnig 1,0, Bewölkt 0,9, Regen 1,25, Nebel 1,0
  (`WEATHER_GROWTH_RATES`). Das Wetter hängt von der Spielzeit ab, nicht vom Spielstand-Inhalt.
- Nach Regen erscheint im ersten Nebelabschnitt für etwa 15 Sekunden ein ein- und ausblendender Regenbogen;
  nachts bleibt er unsichtbar.
- Tag-Nacht-Zyklus (`world.gd`): Ein Spieltag dauert 8 Minuten echter Zeit (`REAL_DAY_LENGTH_SECONDS`).
  Nachts gehen Tiere in den Gehege-Unterstand und schlafen mit geschlossenen Augen; versetzte Schlafpläne
  lassen mindestens ein Tier wach. Streicheln weckt ein schlafendes Tier kurz. Bei Regen suchen die Tiere
  denselben Unterstand auf, bis es wieder trocken ist. Alle diese Reaktionen sind kosmetisch und werden
  weder gespeichert noch auf Hunger, Wohlbefinden oder Freundschaft angerechnet; `SAVE_VERSION` bleibt 8.
- Screenshots `animals_rain_shelter`, `animals_sleeping` und `after_rain_rainbow` in
  `tests/screenshots.gd` sind für manuelle Sichtprüfung vorgesehen und laufen nicht in der CI.

## Start und Ladebildschirm

- `scenes/boot.tscn` ist die Startszene. Sie zeigt zuerst den handgezeichneten Ladebildschirm,
  lädt dann Spielstand und Welt dahinter und blendet weich ins Spiel über. `scenes/main.tscn`
  bleibt die eigentliche Spielszene und wird unverändert von den UI-Tests geladen.
- Der Engine-Startbildschirm davor ist `assets/boot_splash.png`. Godot akzeptiert dafür **nur PNG**.
  Die bearbeitbare Quelle ist `assets/boot_splash.svg`; nach Änderungen das PNG neu erzeugen:
  ```
  godot --headless --path . -s res://tools/make_boot_splash.gd
  godot --headless --path . --import
  ```
  `project.godot` verweist unter `application/boot_splash/image` auf das PNG, `fullsize=true`
  füllt den Bildschirm. Ohne diese Einstellung zeigt Godot wieder sein eigenes Logo.
- Der Ladebildschirm läuft auch ohne Display (headless): `tests/boot_ui.gd` prüft Fortschritt,
  Spielstand-Laden, Begrüßung, Layout und das Überspringen per Tipp. Die gezeichnete Grafik selbst
  braucht für eine Sichtprüfung ein Display.

## Audio

- Soundeffekte werden zur Laufzeit synthetisiert (`Sfx`), dafür sind keine Audiodateien nötig.
- Hintergrundmusik (`BackgroundMusic`) spielt `res://audio/Sunlight_on_the_Path.mp3` leise als Schleife. Der Schalter
  „Hintergrundmusik“ erscheint in den Einstellungen nur, wenn die Datei vorhanden ist; fehlt sie, startet das Spiel
  ohne Musik und gibt nur eine Warnung aus.

## Offene Punkte vor einer Veröffentlichung

- **Musik:** Quelle und Lizenz von `Sunlight_on_the_Path.mp3` sind hier nicht dokumentiert. Vor einem Play-Store-Release
  klären und an dieser Stelle festhalten (oder den Track entfernen; das Spiel läuft auch ohne).
- **Android-Dateiimport:** Der Pfad über `user://save_transfer/` ist noch nicht auf einem echten Gerät geprüft.
- **Release-Build:** Es gibt keinen automatischen Release-/AAB-Workflow, nur die Anleitung oben. Launcher-Icons sind im
  Preset leer (Fallback auf `icon.svg`). Version ist `0.1.0`, `version/code` ist `1`.

## Steuerung

| Geste | Wirkung |
| --- | --- |
| Tippen auf Feld | Saat wählen, ein Feld säen, anlegen oder ernten |
| Ziehen auf der Karte | Kamera verschieben (mit Trägheit), auch über Feldern und mit aktivem Werkzeug |
| Zwei Finger | Pinch-Zoom |
| Tippen auf Gebäude / Tier | Produktions- bzw. Tiermenü |
| Platzieren | Finger ziehen, Vorschau zeigt Grün/Rot, „Platzieren“ bestätigt |
