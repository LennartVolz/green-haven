# Green Haven

A cozy vegan farming game for smartphones (Android first, iOS prepared).
Built with Godot 4.4, GDScript, and 2D rendering — no web app, no backend, fully playable offline.

You begin with a small farm, grow vegetables, fruits, and grains, craft vegan products in a bakery,
kitchen, plant milk factory, tofu workshop, and juice bar, complete customer orders, and give rescued
animals a home. The animals produce nothing — they are simply cared for.

## Scope

- 19 crops with multiple growth stages, tier-based progression, and unlock system
- 6 production buildings (incl. the garden café), 26 recipes, queues, upgrades, and pickup functionality
- New crops: pumpkin, beetroot, lettuce, cucumber, peas, perennial blueberries, rice, and quinoa
- Customer orders, coins, XP, quests, shop, decoration, and land expansion
- Animal sanctuary with 5 animal types, personal traits, optional species-specific activities, selectable cosmetic rewards, and no-pressure rescue offers
- Refuge journal for rescues and shared moments, friendship milestones with animated reactions and profile stories
- Optional multi-part neighborhood delivery stories with persistent progress and completion rewards
- 13 claimable achievements for orders, harvests, crafting, animal care, friendship, stories, café, and farm expansion
- Per-paddock occupancy and wellbeing overview; animal profiles, journal and story progress are included in versioned saves
- Touch controls: tap, swipe to sow/harvest, camera pan with inertia, pinch-to-zoom, placement by drag
- Local, versioned save system (validated loading, rotating backup, newer-version saves are never overwritten); crop growth and production continue offline

## Quick Start

```bash
godot --headless --path . -s res://tests/run_tests.gd        # Logic tests
godot --headless --path . -s res://tests/achievements_ui.gd  # UI tests
godot --path .                                          # Start the game on desktop
```

Android APK, iOS, and release builds: see [docs/BUILD.md](docs/BUILD.md).
Every push triggers GitHub Actions (`.github/workflows/android.yml`) to run the tests and build a debug APK
(artifact `GreenHaven-build` under Actions).

## Project Structure

```text
scripts/core/    GameData (balancing), GameState (logic), SaveSystem, Sfx
scripts/world/   World, camera/touch, terrain, fields, objects, animals, Painter
scripts/ui/      UiRoot (HUD, actions), UiKit, icons, sheets/ (menus)
scenes/          main, world, ui_root, entity, animal
tests/           run_tests.gd, achievements_ui.gd, screenshots.gd
docs/            BUILD.md
```
