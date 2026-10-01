# Cat/Fish — How the Game Works

*Last updated Sep 30, 2026. Godot 4.7.2, Meta Quest (OpenXR) with a desktop fallback.*

## The big picture

The whole game lives in one scene, `game.tscn`. Almost everything you see is **built by code when the scene starts**: the pond, bridge, grass, rocks, fish and poster all come from the numbers in the Inspector. That's why the Scene panel looks nearly empty, and why changing a number reshapes the world.

**One round, start to finish:**

1. **Launch.** `main.gd` tries to start the Quest (OpenXR). If there's no headset, it switches to desktop mode (mouse and keyboard camera).
2. **Build.** The **Pond** builds the water, floor, bridge and scenery, then spawns 30 fish. Each fish builds its own body from a species file.
3. **Pick a target.** The **GameManager** picks a WANTED species, makes sure at least 2 of them are in the pond, and puts that species on the **Wanted poster**.
4. **Search.** You walk around the ring bridge and look into the murky water. The fish wander on their own.
5. **Pounce.** You pull the trigger (VR) or click (desktop). An invisible ray shoots out up to 5 m. If it hits a fish's hitbox, that fish says "I got hit".
6. **Score.** The message passes up to the GameManager. Right species: +10, the fish is replaced and a new round starts. Wrong species: −5, and the fish darts away. Every pounce, including misses, is written to the CSV log.

The game follows one design rule: **mechanics live in the GameManager, the fish and the pounce. Looks live in the Pond, the shaders and the scenery.** Changing one side rarely touches the other.

## The node tree

This is `game.tscn` while the game runs. Nodes marked *(code)* don't exist in the Scene panel; scripts create them at start-up. To see them live, run the game, then in Godot click **Remote** at the top of the Scene panel.

```
Game                      main.gd: start VR, or fall back to desktop
├─ XROrigin3D             the player (moves as you walk)
│  ├─ XRCamera3D          your head in VR
│  ├─ XRControllerLeft / Right
│  │  └─ Pounce           pounce.gd: aim line, trigger, ray, haptic buzz
│  ├─ XRMovement, XRHands, XRVisuals, grab areas   (VR template, unchanged)
│  └─ DesktopCamera       (code) only in desktop mode
├─ WorldEnvironment        sky, ambient light, distance haze
├─ SunLight                the sun + shadows
├─ Passthrough             template: toggle Quest passthrough
├─ Pond                    pond.gd (instance of pond.tscn)
│  ├─ Fishes               container: every fish lives here
│  │  └─ Fish × 30         fish.gd (instance of fish.tscn)
│  │     ├─ look          (code) FishBuilder body, fins, pattern
│  │     └─ Hitbox        (code) Area3D on layer 2: what pounces hit
│  ├─ Water, PondFloor, PondWall, Bank, BankEdge          (code)
│  ├─ BridgeFrame, BridgePlanks, BridgeSide…, Curb…, BridgePost…  (code)
│  ├─ Scenery              (code) grass, reeds, cattails, rocks, distant hills
│  ├─ Ambience             (code) water sounds
│  └─ WantedPoster         (code, added by GameManager) board + post
├─ BridgeWalk              bridge_walk.gd: keeps you on the ring
├─ GameManager             game_manager.gd: rounds, score, poster, log
│  └─ DataLogger           (code) writes the CSV
└─ DesktopFallback         (code) only when there's no headset
```

**What you'd click on in the Inspector:** **Pond** for water, size, clarity and scenery. **GameManager** for points and targets. **Fish** is set in `fish.tscn`, where speed and wander apply to every fish. **WorldEnvironment** and **SunLight** control lighting and sky.

## System design

Godot has one golden rule, and this game follows it: **signals go up, calls go down.** A child never reaches up and changes its parent. It just announces something (a signal), and whoever is listening decides what to do. Parents change their children directly by calling their functions.

```
 SIGNALS GO UP  ─────────────────────────────────────────────────────►

 [Pounce / click] ──► [Fish] ──────────────► [Pond] ────────► [GameManager]
  ray hits a hitbox    swatted.emit(self)     fish_swatted     right +10, wrong −5
                                                                     │
 CALLS GO DOWN                                                       ▼
        ┌──────────────────┬──────────────────────┬──────────────────┐
        ▼                  ▼                      ▼                  ▼
 [WantedPoster]       [DataLogger]           [Pond]              [Fish]
  show_target,         log_row                replace_fish,       startle()
  set_score            (CSV, one per pounce)  ensure_species      (wrong fish darts off)
```

A miss (the ray hits nothing) skips the fish and the Pond. `Pounce` emits `pounced` with no fish, desktop mode emits `swatted`, and the GameManager logs it as a miss with 0 points.

**What each piece is responsible for, and nothing else:**

- **Fish** knows how to swim and how to look. It doesn't know about points or targets.
- **Pond** knows the world's shape and owns the fish: it spawns, replaces and counts them. It doesn't know the rules.
- **GameManager** knows the rules: the target, the score and the rounds. It doesn't draw anything itself; it tells the poster and the logger.
- **WantedPoster** just shows whatever species it's handed, rendered by the same `FishBuilder` as the pond fish, so it always matches.

**How the water murk works.** The murk is applied to what's underwater, not to the water surface. Each fish, the pond floor, the walls and the posts use a shader that measures how far your line of sight travels under water to reach that point, then fades it toward `murk_color` by `1 − exp(−distance × murk_per_metre)`. Clarity 0.2 turns into a `murk_per_metre` value, and the Pond pushes the same value to every underwater material with `apply_water()`. Fish and background fade identically, so nothing stands out just because it ignores the murk. The distance fog in the sky is separate, and fish ignore it on purpose.

## How fish are built

Every fish comes from a **species file** (`species/*.tres`), which is just a list of numbers. `FishBuilder.build(species)` turns those numbers into a 3D fish. The pond fish and the wanted poster both use the same builder, so they always match.

**The parts** (`fish_builder.gd`):

1. **Body:** a rounded mesh built along the fish: pointed at the nose, widest about 35% back, thin where it joins the tail. It takes up the front 80% of the length.
2. **Fins:** a tail, a dorsal fin on top, and two side fins that angle back and slightly down.
3. **Eyes:** two dark eyes near the front.
4. **Pattern:** painted on by `fish_pattern.gdshader`, not built as shapes. Along the body the pattern goes from 0 at the nose to 1 at the tail, and around it from the top of the back to the belly. The shader draws spots, bands, stripes or speckles from those positions, so a pattern's spatial frequency is exact.

**Three levels of detail** (the groups in the species file's Inspector):

| Level | Settings | Options used in the 21 species |
| --- | --- | --- |
| Coarse: shape | `body_length`, `body_height`, `body_width` | **Darter** (default: 0.35 m, height 0.30 × length) · **Roundfish** (taller: height 0.45 × length) · **Longfish** (0.49 m, height 0.21 × length) |
| Medium: fins | `tail_type` | **Forked** (default) · **Fan** |
| Fine: pattern | `pattern`, `pattern_frequency`, `pattern_size` | None · **Bands** (2 wide) · **Spots** (3 large) · **Pinstripe** (14 thin stripes) · **Speckles** (28 dots per body length) |

**Colour:** the body uses `body_color`, and the fins use `fin_color`, always a lighter tint of the body colour. There are four colour families: silver-grey (default), orange, blue and yellow. Every pattern uses the same dark charcoal `pattern_color`, so colour never gives a pattern away. The same shader also applies the murk fade.

**The species list:** species 01–09 each change one thing from the plain grey darter (a colour, a shape, the tail, or one pattern). Species 10–21 combine a colour with a pattern, and sometimes a shape (for example Orange Pinstripe Darter, or Silver Banded Roundfish). Those combinations create the look-alikes, where you often need both the colour and the fine pattern to find the target. When a fish spawns, the Pond picks a species at random from `species_mix`. The exception is the target species: the GameManager makes sure at least `min_targets_in_pond` of them are swimming.

## File map

**Scenes**

| File | What it is |
| --- | --- |
| `game.tscn` | The game. Open this one and press Cmd+R. |
| `pond.tscn` | The Pond with its species list; used inside game.tscn |
| `fish.tscn` | One fish; settings here apply to every fish |
| `fish_test.tscn` | A small test scene: pond and bridge, no game rules |
| `main.tscn` | The original VR template scene; still the project's launch scene |

**Mechanics scripts** (`scripts/`)

| File | Job |
| --- | --- |
| `game_manager.gd` | Rules: pick the target, score, new rounds, popups, beeps; creates the poster and the logger |
| `fish.gd` | Swimming (wander + steering + walls), the hitbox, `on_swat`, `startle` |
| `pounce.gd` | VR aim line, trigger, ray, haptics |
| `desktop_fallback.gd` | Desktop camera, WASD and mouse, click-to-pounce, controls card |
| `bridge_walk.gd` | Keeps the player on the ring |
| `data_logger.gd` | Writes `logs/session_<time>.csv` |
| `main.gd` | Starts OpenXR or switches to desktop mode |

**Look scripts**

| File | Job |
| --- | --- |
| `pond.gd` | Builds water, floor, walls, lawn, bridge, posts; spawns fish; applies murk |
| `pond_scenery.gd` | Grass, reeds, cattails, rocks, distant tree line and hills |
| `pond_ambience.gd` | Water lapping and drip sounds |
| `wanted_poster.gd` | The board: frame, post, fish renders, labels; turns to face you |
| `fish_builder.gd` | Builds a fish body from a species file |
| `fish_species.gd` | Defines what a species file contains |

**Shaders** (`assets/shaders/`)

| File | Draws |
| --- | --- |
| `fish_pattern.gdshader` | Fish colour + spots, bands, stripes and speckles, plus the murk fade |
| `underwater_surface.gdshader` | Pond floor, walls and posts, with the same murk fade as the fish |
| `water_surface.gdshader` | The water surface: tint, soft ripples, sky reflection |
| `grass_ground.gdshader` | The lawn |
| `grass_blades.gdshader` | Grass tufts and reed blades, with wind sway |

**Data:** `species/01…21_*.tres` hold the 21 species. **Tools** (`tools/`) are one-off generators you run from the command line: `make_species.gd` rebuilds the species files, `make_game_scene.gd` rebuilds game.tscn, and `render_species_sheet.gd` makes a picture of every species. Don't rerun `make_game_scene.gd` now: it would wipe the hand edits to game.tscn.

## Changing mechanics

There are two levels. **Inspector knobs** mean you click a node, change a number and save; no code. **Code changes** mean opening the script and editing the named function.

| I want to… | Inspector knob | Code (if the knob isn't enough) |
| --- | --- | --- |
| Change points for right or wrong | GameManager → `points_right`, `points_wrong` | `game_manager.gd` → `_on_fish_swatted` |
| Make the target rarer or commoner | GameManager → `min_targets_in_pond` | `pond.gd` → `ensure_species` |
| Change how targets are picked (a level ladder, no repeats…) | — | `game_manager.gd` → `_new_round` |
| Change what happens after a right or wrong pounce | — | `_on_fish_swatted` (right: `replace_fish` + `_new_round`; wrong: `startle`) |
| Make the search harder or easier | Pond → `water_clarity`, `fish_count`, `species_mix` | — |
| Change fish speed or wiggliness | open `fish.tscn` → Fish → `cruise_speed`, `speed_multiplier`, `wander_*` | `fish.gd` → `_physics_process` |
| Change how a wrong fish reacts | — | `fish.gd` → `startle` |
| Add or edit a species | open a `species/*.tres` file; to add one, duplicate a file, edit it, and add it to Pond → `species_mix` | `fish_builder.gd` for new body shapes; `fish_pattern.gdshader` for new pattern types |
| Change pounce reach or rate | Pounce (under each controller) → `reach`, `cooldown`; desktop: `swat_reach` in `desktop_fallback.gd` | `pounce.gd` → `_pounce`, `_cast` |
| Change where the player can walk | Pond → `bridge_radius`, `bridge_width` | `bridge_walk.gd` |
| Log a new column | — | add it in `data_logger.gd` (header) **and** in both `log_row` calls in `game_manager.gd` |
| Change the level between rounds (e.g. clarity) | — | in `_new_round`, set `pond.water_clarity = …` (it updates the murk right away) |

**Guardrail for the research:** a mechanic must never give the target away. No target-only glow, sound, speed or behaviour unless it's a deliberate experimental condition you can switch off.

## Changing the look

The V2 art rule: **pretty outside the search area, quiet inside it.** Anything in or on the water must not compete with fine fish markings.

| I want to change… | Inspector knob | Code |
| --- | --- | --- |
| Water colour | Pond → `water_color` (surface tint), `murk_color` (what fish fade into) | — |
| Ripples | Pond → `ripple_strength` (0 = calm), `ripple_scale` | `water_surface.gdshader` (speed, band look) |
| Water reflection | Pond → `reflection_strength` | `water_surface.gdshader` → `sky_color` |
| Bridge wood | Pond → `wood_color` | `pond.gd` → `_ring_planks` (plank width, gaps, bevel) |
| Poster paper, frame, ink | — | `wanted_poster.gd` exports at the top: `paper_color`, `frame_color`, `ink_color`, `frame_width` |
| Poster layout or size | GameManager → `poster_height` | `wanted_poster.gd` → `_ready` (layout top-down) |
| Sky, sun, shadows | click WorldEnvironment (Sky → colours, Fog) and SunLight (colour, energy, shadow blur) in game.tscn | — |
| Lawn colours | — | `grass_ground.gdshader` → `grass_light`, `grass_dark`, `dry_patch` |
| Grass, reeds, rocks amount | Pond → `grass_tufts`, `reeds`, `rocks`, `trees` | `pond_scenery.gd` (placement, colours) |
| Distant hills | Pond → `distant_scenery` on/off | `pond_scenery.gd` → the three `_far_band(...)` lines (radius, height, colours) |
| Water sounds | Pond → `play_ambience` | `pond_ambience.gd` (volumes, drip rate; `water_loop` for a real recording) |
| Desktop controls card | DesktopFallback → `hint_seconds` (in the script) | `desktop_fallback.gd` → `_build_hud` |
| Fish look | species files | `fish_builder.gd` (shape), `fish_pattern.gdshader` (patterns) |

**Before you commit any look change,** run the game and check that Pinstripe, Speckled and Spotted fish still read at depth. Three traps to avoid:

- Don't give fish a lit (`StandardMaterial3D`) look. Fish and underwater parts use unshaded shaders on purpose, so the lighting can change without changing the task.
- Don't turn on tonemapping or glow in WorldEnvironment. They change fish contrast too.
- Keep new underwater objects on `underwater_surface.gdshader`, as the bridge posts and poster post are, so they fade with the murk exactly like the fish.

## Workflow and gotchas

**Edit, test, save:**

1. Open the project folder in Godot. Keep it out of iCloud-synced folders (like Documents on a Mac), because iCloud breaks git.
2. Open `game.tscn` and press **Cmd+R** to run the scene you're viewing. F5 runs `main.tscn`, the old template.
3. For Inspector changes: click the node, edit, then **Cmd+S**. The Pond redraws right away in the editor, since it's a tool script. Fish only appear when the game runs.
4. Test in desktop mode first. Then test on the Quest, especially for fine patterns and poster text, because the headset has a lower effective resolution.
5. Commit in GitHub Desktop with small commits (one idea each), then **Push origin**.

**Gotchas:**

- **Pond size lives in two places.** If you change the Pond's `pond_radius`, `surface_y` or `bottom_y`, the fish get the new edges automatically when they spawn. The values in `fish.tscn` only matter in the test scene.
- **game.tscn holds hand edits** (murk colour, lighting). Don't regenerate it with `tools/make_game_scene.gd`.
- **Don't delete the `.uid` files** next to scripts. Godot uses them to find files.
- **Change water clarity during play with `pond.water_clarity = x`, not a shader edit.** The setter pushes the new murk to every fish and underwater part.
- **Logs are saved on the computer that runs the game:** in Godot, Project → Open User Data Folder → `logs/`. One CSV per session.
- **Pond parts are rebuilt from code,** so hand-editing them in the Scene panel won't stick. Change the numbers or the script instead.
