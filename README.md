# Green Haven

A cozy vegan farming game for smartphones (Android first, iOS prepared).
Built with Godot 4.4, GDScript, and 2D rendering — no web app, no backend, fully playable offline.

You begin with a small farm, grow vegetables, fruits, and grains, craft vegan products in a bakery,
kitchen, plant milk factory, tofu workshop, and juice bar, complete customer orders, and give rescued
animals a home. The animals produce nothing — they are simply cared for.

## Scope

- 10 crops with multiple growth stages, tier-based progression, and unlock system
- 5 production buildings, 14 recipes, queues, upgrades, and pickup functionality
- Customer orders, coins, XP, quests, shop, decoration, and land expansion
- Animal sanctuary with 5 animal types, needs, petting/feeding, and cosmetic rewards
- Touch controls: tap, swipe to sow/harvest, camera pan with inertia, pinch-to-zoom, placement by drag
- Local, versioned save system; crop growth and production continue offline

## Quick Start

```bash
godot --headless --path . -s res://tests/run_tests.gd   # Logic tests (328 checks)
godot --path .                                          # Start the game on desktop
```

Android APK, iOS, and release builds: see [docs/BUILD.md](docs/BUILD.md).
Every push triggers GitHub Actions (`.github/workflows/android.yml`) to run the tests and build a debug APK
(artifact `GreenHaven-debug-apk` under Actions).

## Project Structure

```text
scripts/core/    GameData (balancing), GameState (logic), SaveSystem, Sfx
scripts/world/   World, camera/touch, terrain, fields, objects, animals, Painter
scripts/ui/      UiRoot (HUD, actions), UiKit, icons, sheets/ (menus)
scenes/          main, world, ui_root, entity, animal
tests/           run_tests.gd, screenshots.gd
docs/            BUILD.md
```
