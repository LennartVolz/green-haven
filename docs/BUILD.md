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

Die Export-Konfiguration liegt in `export_presets.cfg` (arm64-v8a, Querformat laut `display/window/handheld/orientation=0`; für Hochformat dort `1` und das Viewport-Format anpassen;
Vibration erlaubt, kein Internet-Zugriff).

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

Die gesamte Spiellogik (Anbau, Inventar, Produktion, Aufträge, Quests, Tiere, Land,
Speicherstand, Offline-Fortschritt, Migration, Balance) wird headless geprüft:

```
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . -s res://tests/achievements_ui.gd   # UI-Test (Menüs, Tagebuch, Erfolge)
godot --headless --path . -s res://tests/save_transfer_ui.gd # UI-Test (Spielstand-Export/Import)
```

Exit-Code 0 bedeutet: alle Prüfungen bestanden.

## Projektstruktur

```
scripts/core/    GameData (Balancing), GameState (Logik), SaveSystem, Sfx
scripts/world/   Welt, Kamera/Touch, Gelände, Felder, Objekte, Tiere, Painter
scripts/ui/      UiRoot (HUD, Aktionen), UiKit, Icons, sheets/ (Menüs)
scenes/          main, world, ui_root, entity, animal
tests/           run_tests.gd
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
  Produktion offline „weiter“: beim Start wird aus der verstrichenen Zeit der Zustand abgeleitet

## Steuerung

| Geste | Wirkung |
| --- | --- |
| Tippen auf Feld | Saat wählen, pflanzen oder ernten |
| Wischen über Felder (mit Saat-/Leerwerkzeug) | Mehrere Felder in einem Zug säen oder ernten |
| Wischen auf freier Fläche | Kamera verschieben (mit Trägheit) |
| Zwei Finger | Pinch-Zoom |
| Tippen auf Gebäude / Tier | Produktions- bzw. Tiermenü |
| Platzieren | Finger ziehen, Vorschau zeigt Grün/Rot, „Platzieren“ bestätigt |
