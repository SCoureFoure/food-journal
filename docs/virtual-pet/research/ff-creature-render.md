# fitness_friends: creature rendering and creator tool

All paths are repo-relative with the `fitness_friends/` prefix. Facts cite `path:line`. Inferences are marked `Inference:`.

## 1. Rendering tech

Fact: creatures are drawn with the Flame game engine. A Flutter `StatelessWidget` wraps a Flame `GameWidget`, and every body shape is hand-drawn with `dart:ui` `Canvas` calls (ovals, circles, paths) inside Flame `PositionComponent.render()` overrides.
- `fitness_friends/flutter_app/lib/widgets/creature_flame_widget.dart:1-3` imports `flame/components.dart`, `flame/game.dart`, `flutter/material.dart`.
- `fitness_friends/flutter_app/lib/widgets/creature_flame_widget.dart:121` uses `GameWidget(game: CreatureGame(...))`. `CreatureGame extends FlameGame` (line 135).
- `fitness_friends/flutter_app/lib/widgets/creature_body_components.dart:237,337,473,616,779` are the five components, each extending `PositionComponent` and overriding `render(Canvas)`.
- Patterns are drawn with `canvas.drawRect/drawCircle/drawPath` in a `PatternRenderer` mixin (`creature_body_components.dart:6-136`).

Not used: SVG, image/sprite loading, Rive, Lottie. No `Sprite`, `Image`, `SvgPicture` or `CustomPainter` appears in the creature widget files. A `CustomPainter` appears only in the part-designer drawing canvas (`fitness_friends/flutter_app/lib/screens/creator/widgets/drawing_canvas.dart:84`) and the anchor selector (`part_designer_screen.dart:529`).

Packages (`fitness_friends/flutter_app/pubspec.yaml`):

| Package | Constraint | Line | Resolved (pubspec.lock) |
|---|---|---|---|
| Dart SDK | `^3.9.2` | 22 | n/a |
| flutter | sdk | 31-32 | n/a |
| cupertino_icons | `^1.0.8` | 36 | n/a |
| http | `^1.2.1` | 39 | n/a |
| flutter_secure_storage | `^9.2.2` | 42 | n/a |
| provider | `^6.1.2` | 45 | n/a |
| flame | `^1.22.0` | 48 | 1.33.0 (`fitness_friends/flutter_app/pubspec.lock:68-75`) |
| flutter_lints (dev) | `^5.0.0` | 59 | n/a |
| flutter_test (dev) | sdk | 51-52 | n/a |

Only `flame` is rendering-related. No flame sub-packages (flame_audio, flame_forge2d, etc.).

## 2. Body model

Fact: a creature's look comes entirely from three string fields inside the `creature.genetics` map. A body is NOT assembled from separate swappable parts. Each body type is one component class that draws the whole creature in a single `render()` call.

Which field drives which property (`fitness_friends/flutter_app/lib/widgets/creature_flame_widget.dart`):

| Visual property | Source field | Fallback | Lines |
|---|---|---|---|
| Body type (shape + proportions) | `genetics['bodyTypePhenotype']` (String) | `'quadruped_athletic'`; `'egg'` if `creature.isEgg` | 23-40 |
| Pattern | `genetics['patternPhenotype']` (String) | `'solid'`; `'solid'` for eggs | 43-59 |
| Primary color | `genetics['colorPhenotype']` (String enum name) | grey `0xFF808080`; grey for eggs | 64-102 |
| Secondary color | derived: primary HSL lightness x 0.7 | n/a | 105-110 |

- `creature.isEgg` is `state == 'EGG'` (`fitness_friends/flutter_app/lib/models/creature.dart:186`).
- Fact: the widget explicitly IGNORES `creature.primaryColor`, `creature.secondaryColor` and `creature.pattern` (comment at `creature_flame_widget.dart:62-63`).
- Color palette (hard-coded switch, `creature_flame_widget.dart:82-100`): fire `FF4500`, water `1E90FF`, earth `8B4513`, sky `87CEEB`, shadow `4B0082`, nature `228B22`, crystal `E0FFFF`, volcanic `DC143C`. Anything else is grey.

Body types (10 plus egg), mapped in `CreatureGame._createBodyComponent` (`creature_flame_widget.dart:163-259`). Four component families, parameterised by a `BodyProportions` preset (`creature_body_components.dart:139-234`):

| `bodyTypePhenotype` | Component | Preset (bodyW, bodyH, legThick, legLen, head) |
|---|---|---|
| `quadruped_stocky` | `QuadrupedBase` | 1.6, 0.8, 1.3, 0.7, 1.2 |
| `quadruped_athletic` (and default) | `QuadrupedBase` | 1.2, 1.0, 1.0, 1.0, 1.0 |
| `quadruped_lithe` | `QuadrupedBase` | 0.9, 1.2, 0.8, 1.3, 0.8 |
| `biped_compact` | `BipedBase` | 1.4, 1.4, 1.4, 0.6, 1.3 |
| `biped_balanced` | `BipedBase` | 1.0, 1.3, 1.0, 1.0, 1.0 |
| `biped_tall` | `BipedBase` | 0.8, 1.4, 0.7, 1.5, 0.8 |
| `aquatic_streamlined` | `AquaticBase` | 1.5, 0.65, 0.8, 0.8, 0.9 |
| `aquatic_bulky` | `AquaticBase` | 1.3, 0.9, 1.0, 1.0, 1.0 |
| `avian_raptor` | `AvianBase` | 0.8, 1.0, 0.9, 0.9, 0.9 |
| `avian_songbird` | `AvianBase` | 1.0, 1.0, 0.6, 0.7, 1.1 |
| `egg` | `EggComponent` | none |

Shape composition per family (all coordinates scale by `size / 150`):
- Quadruped (`creature_body_components.dart:337-470`): 4 leg circles (only two distinct x positions are drawn, each pair drawn twice at the same spot, so the "4 legs" collapse to 2 visible circles; Inference: a bug or placeholder, since `legY` is the same for all), body oval, pattern overlay, head circle, 2 eyes with pupils.
- Biped (`473-613`): 2 leg circles, body oval, pattern, 2 arm ovals, head circle, eyes.
- Aquatic (`616-776`): semicircle tail, 2 flippers, body oval, pattern, triangular-ish head path, 2 eyes.
- Avian (`779-961`): 2 triangle wings, body oval, pattern, head circle, beak triangle, eyes, tail oval, 2 line legs.
- Egg (`237-334`): gradient oval, 8 seeded spots, outline, white highlight.

Patterns (`PatternRenderer.drawPattern`, `creature_body_components.dart:11-46`): `stripes`, `spots`, `gradient`, `patches`, `swirls`, `marble`, `solid` (no-op). Each is clipped to the body oval, painted with secondary color at alpha 0.4. Spots and marble use `Random(42)`, so they are deterministic. The pattern is applied to the body oval only, not to head, limbs or wings. The egg ignores `pattern` and always draws its own spots.

Other fields: `Creature.stats` (health, speed, etc.), `level`, `age`, `accessories`, `mood` are NOT read by the render path. `rareAlleleCount` (from `genetics['rareAlleles']`, `creature.dart:195-202`) only feeds the star badge (section 6).

## 3. Assets

Fact: everything is procedural. There are no image, sprite, SVG or font assets.
- `fitness_friends/flutter_app/pubspec.yaml:72-75` has the `assets:` section commented out (template text only). Only `uses-material-design: true` (line 70) is active.
- Glob for `fitness_friends/flutter_app/{assets,images,lib/assets}/**` returned no files.
- No `Flame.images.load`, `Sprite.load` or `SpriteComponent` in the rendering files read.

Doc vs code: see the Doc vs code section.

## 4. Animation

Fact: each component keeps a phase accumulator advanced in `update(double dt)`, which Flame calls every frame from `FlameGame`'s game loop. `render()` applies `sin(phase)` offsets. There is no sprite sheet, no animation controller, no tweens.

| Component | What moves | Rate | Amplitude | Lines |
|---|---|---|---|---|
| `EggComponent` | vertical bob | phase += dt*1.5 | 3 px | `creature_body_components.dart:258-271` |
| `QuadrupedBase` | "breathing": body oval scales | dt*1.5 | +/-5% (width and height) | `366-376` |
| `BipedBase` | horizontal sway of everything | dt*1.2 | 2 px | `502-512` |
| `AquaticBase` | vertical swim bob | dt*1.0 | 3 px | `645-657` |
| `AvianBase` | vertical bob | dt*2.0 | 2 px | `808-820` |

- Triggers: none. Animation starts on `onLoad`/mount and runs continuously. There is no input handling, tap, state-change trigger or one-shot animation in the creature files.
- Blink: NOT FOUND in code. Eyes are static circles. The design doc lists "blink" (see Doc vs code).
- Mood/emotion: NOT shown visually. `mood` is a `String` on the model (`creature.dart:63`) and `CreatureFlameWidget` never reads it. The detail screen shows it as text only: `'Generation ${_creature.generation} • ${_creature.mood}'` (`fitness_friends/flutter_app/lib/screens/creatures/creature_detail_screen.dart:323`). The creator tool's mock creature sets `mood: 'HAPPY'` (`fitness_friends/flutter_app/lib/screens/creator/creator_screen.dart:221`) with no visual effect.
- Only the head, eyes and legs never move on their own (except via whole-body offsets).
- Inference: because `CreatureGame` is constructed inside `build()` (`creature_flame_widget.dart:122`), a parent rebuild creates a new `CreatureGame` instance each time. Flame's `GameWidget` may restart the game and reset phases. Not verified.

## 5. Creator tool

There are two creator UIs, plus the standalone `tool/` copy.

A. Proportion editor (in-app screen, `fitness_friends/flutter_app/lib/screens/creator/creator_screen.dart`, 442 lines):
- Preset dropdown of the 10 `BodyProportions` presets (`CreatorPresets.all`, `lib/screens/creator/models/editable_body_config.dart`), five sliders (0.5 to 2.0, 30 divisions, lines 283-337), a pattern dropdown (7 patterns), Reset, Export. The color picker is a stub: `'(Color picker coming in next version)'` (line 385).
- Live preview: builds a mock `Creature` (line 195) and renders `CreatureFlameWidget(... customProportions: _config.toProportions())` (234-239).
- Output: `EditableBodyConfig.generateDartCode()` returns a Dart snippet `static const <name> = BodyProportions(...)` with a timestamp comment (`tool/models/editable_body_config.dart:66-79`). The export dialog shows it and has a "Copy Code" button using `Clipboard.setData` (`creator_screen.dart:82`). The README tells the user to paste it by hand into `creature_body_components.dart` and edit the switch in `creature_flame_widget.dart` (`fitness_friends/flutter_app/tool/README.md:79-85`).
- Storage: NONE. Nothing is written to a file, database, asset or backend. Output is clipboard text only, so the app cannot read the output at runtime; it only "reads" it after a developer pastes it into source and rebuilds.

B. Part Designer (`fitness_friends/flutter_app/lib/screens/creator/part_designer_screen.dart`, 579 lines; opened from the pen icon in the app bar, `creator_screen.dart:103-110`):
- Freehand drawing canvas (`widgets/drawing_canvas.dart`, 223 lines), Douglas-Peucker simplification (`utils/path_simplifier.dart`, 129 lines, `_douglasPeucker` line 22), part type enum of 10 types: head, body, legFront, legBack, leg, arm, wing, tail, ear, fin (`models/creature_part.dart:4-14`), anchor point selection, bounds.
- Output: `CreaturePartDefinition` (`creature_part.dart:23`) with `toJson()`/`fromJson()` (lines 86, 105) but no code in the files read calls `toJson` for persistence (grep of `part_designer_screen.dart` found no `toJson`, `File(`, or `jsonEncode`). The export path is `generateComponentCode()` (line 133), which emits a Dart `PositionComponent` class with hard-coded `path.moveTo/lineTo` points, copied to the clipboard (`part_designer_screen.dart:138,197`).
- The app does not load or render these parts. Nothing in `lib/` references the generated classes.

C. Standalone entry `fitness_friends/flutter_app/tool/main_creator.dart` (23 lines) runs `CreatureCreatorApp` -> `tool/screens/creator_screen.dart` (429 lines) via `flutter run -d chrome tool/main_creator.dart` (`tool/README.md:15-20`). It imports `package:flutter_app/...` so it shares the app package. It is a near-copy of A without the Part Designer button.
- Fact: the `tool/` preview builds `CreatureFlameWidget(creature: mockCreature, width: 400, height: 400)` WITHOUT `customProportions` (`tool/screens/creator_screen.dart:222-226`). So in the `tool/` version the sliders change the config but not the preview. Only the `lib/screens/creator` version passes `customProportions`.
- Fact (both versions): the mock creature uses `bodyTypePhenotype: '${_config.bodyType}_custom'` (e.g. `quadruped_custom`, `lib/screens/creator/creator_screen.dart:228`). That string matches no case in the factory switch, so the default branch runs and ALWAYS builds `QuadrupedBase` (`creature_flame_widget.dart:251-257`). Preview of biped/aquatic/avian presets therefore draws a quadruped with those proportions. Colors are hard-coded `'fire'` (line 229), so `_config.primaryColor`/`secondaryColor` have no effect on the preview.
- Reachability: grep for `screens/creator`, `CreatorScreen` in `flutter_app/lib` and `flutter_app/test` found no import outside the creator folder itself. Inference: the in-app creator screen is not wired into the app's navigation; it is reachable only if someone pushes it by hand.

## 6. Widget API

Main widget: `CreatureFlameWidget` (`creature_flame_widget.dart:8-20`):

```dart
const CreatureFlameWidget({
  super.key,
  required Creature creature,
  double width = 200,
  double height = 200,
  BodyProportions? customProportions,
})
```

- Inputs: a `Creature` model (needs only `isEgg`/`state` and `genetics` map), a size, and an optional proportions override that replaces the preset for all non-egg types.
- Inner game: `CreatureGame({required Color primaryColor, required Color secondaryColor, required String bodyType, required String pattern, BodyProportions? customProportions})` (`creature_flame_widget.dart:142-148`). Transparent background (line 151).
- Dependencies of the widget file: `package:flame` (components, game), `flutter/material.dart`, `package:flutter_app/models/creature.dart`, `package:flutter_app/widgets/creature_body_components.dart`. No providers, no services, no `Navigator`, no HTTP, no secure storage.
- `Creature` model (`fitness_friends/flutter_app/lib/models/creature.dart`): has no `import` lines (grep found none), so it is plain Dart. It contains `CurrentAdventure`, `CreatureStats`, and JSON parsing. `genetics` is a `Map<String, dynamic>?`.

Companion widget: `RareAlleleIndicator({required Creature creature, double size = 16.0, bool showCount = true})` and `RareAlleleIndicatorDetailed({required Creature creature, double size = 16.0})` (`fitness_friends/flutter_app/lib/widgets/rare_allele_indicator.dart:10-15, 63-67`). Draws a star icon plus `xN` count; colors by count: 1 = yellow shade 700, 2 = amber, 3 or more = purple (lines 47-55). Hidden when count is 0. The Detailed variant adds a Tooltip listing trait names taken from `allele.split('_')[0]` (lines 77-86). Depends only on `Creature` and Material. It is an overlay badge, not part of the drawn creature.

Use sites: `creature_detail_screen.dart:305-309` (150x150) with `RareAlleleIndicatorDetailed` at 331; `creature_list_screen.dart:273` uses `RareAlleleIndicator` only. The list screen uses a Material `Icon` via `_getCreatureIcon()` (line 243), NOT `CreatureFlameWidget`.

Drop into another Flutter app? Yes, with little. Copy these files:
1. `lib/widgets/creature_flame_widget.dart`
2. `lib/widgets/creature_body_components.dart`
3. `lib/models/creature.dart` (or replace the `Creature` parameter: the widget really needs only `isEgg` and the `genetics` map)
4. Add `flame` (resolved 1.33.0 here) to pubspec. Rewrite the `package:flutter_app/...` imports to the new package name.
It would NOT pull in provider, http, flutter_secure_storage or any service. Optionally add `rare_allele_indicator.dart`.
Caveat: `GameWidget` allocates a Flame game per creature, so a long list of them is heavier than a `CustomPaint`. Inference: since the drawing is plain Canvas code, the five components could be ported to `CustomPainter` with a `Ticker`, removing Flame; not tried.

## 7. Tests covering rendering

- `fitness_friends/flutter_app/test/widgets/creature_flame_widget_test.dart` (108 lines): 4 widget tests. They pump `CreatureFlameWidget` and check it exists, that width/height take custom and default values (300 and 200), and that creature fields pass through. They do NOT assert any pixels, body type selection, color mapping, pattern drawing, or animation.
- Grep in `flutter_app/test` for `CreatureFlameWidget|RareAllele|GameWidget` matched only that one file (12 hits).
- Related but not rendering: `test/models/creature_genetics_test.dart` (genetics model), `test/screens/creature_detail_screen_test.dart`, `test/screens/creature_list_screen_test.dart`, `test/screens/creature_adoption_screen_test.dart`. Whether the detail screen test pumps the Flame widget indirectly was not read in full. Inference: the detail screen test may mount `CreatureFlameWidget` transitively; the grep shows no direct reference.
- No tests for `creature_body_components.dart`, `PatternRenderer`, `rare_allele_indicator.dart`, or anything in `lib/screens/creator/` or `tool/`.

## 8. Rough size (lines)

| File | Lines |
|---|---|
| `fitness_friends/flutter_app/lib/widgets/creature_body_components.dart` | ~961 |
| `fitness_friends/flutter_app/lib/widgets/creature_flame_widget.dart` | ~260 |
| `fitness_friends/flutter_app/lib/widgets/rare_allele_indicator.dart` | ~92 |
| `fitness_friends/flutter_app/lib/screens/creator/part_designer_screen.dart` | ~579 |
| `fitness_friends/flutter_app/lib/screens/creator/creator_screen.dart` | ~442 |
| `fitness_friends/flutter_app/lib/screens/creator/models/creature_part.dart` | ~271 |
| `fitness_friends/flutter_app/lib/screens/creator/models/editable_body_config.dart` | ~242 |
| `fitness_friends/flutter_app/lib/screens/creator/widgets/drawing_canvas.dart` | ~223 |
| `fitness_friends/flutter_app/lib/screens/creator/utils/path_simplifier.dart` | ~129 |
| `fitness_friends/flutter_app/tool/screens/creator_screen.dart` | ~429 |
| `fitness_friends/flutter_app/tool/models/editable_body_config.dart` | ~242 |
| `fitness_friends/flutter_app/tool/main_creator.dart` | 23 |

Core creature drawing (flame widget + body components): about 1,220 lines. The creator folder counts above (other than the two big files read in full) come from a line-count grep, so treat them as approximate.

## Doc vs code

| Doc claim | Code reality |
|---|---|
| `fitness_friends/flutter_app/docs/BODY_TYPES_GUIDE.md:338-341` says each body type gets its own component class (e.g. `QuadrupedStockyComponent`). | Only 4 shared classes plus `EggComponent`, varied by `BodyProportions`. Not per-type. |
| BODY_TYPES_GUIDE gives per-type pixel layouts (e.g. stocky legs at 55/95, head at (75,45)). | Code uses fixed offsets scaled by proportion multipliers; the numbers differ (e.g. quadruped legs at x = -15/+15, head at cy-35). Guide is a loose sketch. |
| BODY_TYPES_GUIDE `Future Enhancements` (line 382) lists pattern overlays as future. | Patterns are implemented (`creature_body_components.dart:6-136`). |
| BODY_TYPES_GUIDE:356-361 calls for tail wag, head bobbing, wing flutter, fin movement. | Only whole-body sin offsets/scale exist. No tail wag, wing flutter, fin or head motion. |
| `fitness_friends/docs/design/09-flutter-flame-hybrid-approach.md:272,473` promises "idle, blink, breathe" and "genetics-based sprite composition". Lines 232 and 465 show `mood: creature.mood` passed to the creature widget. | No blink. Breathing exists only on quadrupeds. No sprites. `CreatureFlameWidget` has no `mood` parameter. |
| 09 doc (line 503) lists `flame: ^1.12.0`. | pubspec has `^1.22.0`, resolved 1.33.0. |
| 09 doc file structure (line 514-517) shows `game/creature_sprite.dart`. | No such file; code lives in `lib/widgets/`. |
| `MODULAR_CREATURE_SYSTEM.md:4-6` describes modular parts (mix-and-match, Part Library, `PartRenderer`) used by the game. | Grep for `PartRenderer|ModularCreature|PartLibrary` across `.dart` and `.ts` found nothing. Only the Part Designer tool exists, and it exports clipboard text. The modular system is not implemented in the files I read. |
| `CREATURE_CREATOR_TOOL.md:15-28` lists `tool/widgets/creator_canvas.dart`, `properties_panel.dart`, `preset_selector.dart`, `export_dialog.dart`. | Those files are absent; `tool/` has only `main_creator.dart`, `models/`, `screens/`. |
| `CREATURE_CREATOR_TOOL.md:155-157` says debounce sliders and keep the Flame instance alive, updating props. | No debounce. The preview rebuilds `CreatureFlameWidget` (new `CreatureGame`) on each `setState`. |
| `tool/README.md:8` says live preview with Flame, and "adjust proportions". | True only for `lib/screens/creator`. `tool/screens/creator_screen.dart` does not pass `customProportions`, so sliders do not change the preview. |
| `tool/README.md:101` lists color pickers as future. | Matches: stub text only. |

## Open questions

1. Does `creature_detail_screen_test.dart` mount `CreatureFlameWidget`? Not read in full; grep shows no direct reference.
2. Do parent rebuilds reset the Flame animation (new `CreatureGame` in `build()`)? Not verified at runtime.
3. Is the in-app `lib/screens/creator/creator_screen.dart` reachable from any route? No importer found in `lib/` or `test/`; routes in `main.dart` were not read.
4. Why does the quadruped draw front and back legs at the same coordinates (`creature_body_components.dart:412-436`)? Intent not stated anywhere I read.
5. Whether the backend actually emits `bodyTypePhenotype`/`colorPhenotype`/`patternPhenotype` with the exact strings the Flutter switch expects was not checked (outside this slice).
6. `MODULAR_CREATURE_SYSTEM.md` was only skimmed by headings and the first lines; Phase status (done or planned) is inferred from the absence of code, not from a status line.
7. Exact line counts for `drawing_canvas.dart`, `path_simplifier.dart`, and `part_designer_screen.dart` came from a grep count, not a full read.
