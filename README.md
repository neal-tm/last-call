# Last Call — Godot starter project

A working skeleton of the bartender loop: customers arrive, order, wait, drink,
pay, and leave a dirty glass behind. Drinks take time to make, ice runs out,
and three walkouts end the shift.

## Install

Copy `scripts/`, `scenes/`, and this README into your Godot project folder
(the one with `project.godot` in it).

Then, in Godot:

1. **Project → Project Settings → Globals → Autoload.** Add `res://scripts/game_config.gd`
   with the node name **Config**. Every script reads its numbers from this, so
   nothing works until the autoload is in place.
2. **Project → Project Settings → Application → Run.** Set Main Scene to
   `res://scenes/main.tscn`.
3. **Display → Window.** Viewport width 720, height 1280, orientation
   Portrait, Stretch Mode `canvas_items`, Aspect `expand`.
4. Press F5 to play.

## Where to change things

- `scripts/game_config.gd` — every tunable number, with comments pointing at the
  matching question in the questions doc. Start here once your son's answers come in.
- `scripts/customer.gd` — the states a customer moves through.
- `scripts/main.gd` — the shift: arrivals, taps, the tip math, end of shift.
- `scripts/seat.gd` — how one stool draws itself.
- `scenes/main.tscn`, `scenes/seat.tscn` — layout. Safe to rearrange visually.

Everything is plain boxes and text on purpose. Art, sound, and animation come
after the loop feels right.

## Good next steps

- Replace the cocktail's flat prep time with a multi-tap build (ice, pour, shake).
- Give regulars "the usual" so tapping once orders their drink.
- Add a barback who clears glasses for you.
- Swap Panel nodes for sprites once you have art.
