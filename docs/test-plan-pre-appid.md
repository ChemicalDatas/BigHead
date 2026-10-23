# Big Head — Before-the-App-ID Test Plan

Tests for the features on the "Before the App ID" roadmap in `docs/plan.md`.
Each section matches a roadmap step and is marked with its status. Test a
section once its status says **Built**; until then it describes what the
finished feature must do.

Tick items as they pass (`[ ]` → `[x]`) and log anything odd in **Findings**
at the end. The older features (splash, builder, reveal, fireworks, face swaps,
eyes, dizzy stars) are covered in `docs/test-plan-2a.md`.

## Setup

From the project folder, after every `git pull`:

```
git pull
godot --path . --headless --import
```

Use your own Godot command (for example
`flatpak run org.godotengine.Godot`). The second line refreshes Godot's class
cache; skipping it after new scripts arrive causes `SCRIPT ERROR: Parse Error`
lines when the builder opens.

Then run the game with flags after a lone `--`:

```
godot --path . -- --reset --unlock-all
```

| Flag | Effect |
| --- | --- |
| `--reset` | Forget the saved head, style and uploads (first-launch flow) |
| `--no-steam` | Ignore Steam even if it's available |
| `--fake-friends=N` | Pretend N friends have Big Head |
| `--fast-faces` | Run the face swap cycle 10x faster |
| `--unlock-all` | Treat every catalog item as owned (step 1) |
| `--reset-inventory` | Forget unlocked items and go back to the starting set (step 1) |
| `--drop-rate=N` | Chance of a drop per right-click, 0 to 1, e.g. `--drop-rate=1` drops every click (step 2) |
| `--fast-timed-drops` | Desktop buddy timed drops every few seconds instead of 60 to 90 minutes (step 5) |

`--reset-inventory` and `--drop-rate` are proposed names; this file is updated
if they change when the steps are built.

## 1. Catalog and inventory

Status: **Built** (2026-10-22). The starting set is Round and Oval faces, Buzz
and Spiky hair, Dots and Googly eyes, Smile and Grin mouths, Suit and T-shirt
bodies (each in a random style, #1-#4), and no accessories.

**Starting set** (run with `--reset --reset-inventory`)

- [ ] Hair style, face shape, eyes, mouth and body each offer exactly two unlocked options
- [ ] The two starting bodies come in a random style: run `--reset-inventory` a few times and the Suit and T-shirt styles change
- [ ] Every other option is visible, marked "(locked)" in grey, and shows on the preview
- [ ] While a locked option is chosen, Play/Save is greyed out and a note says which part is locked
- [ ] Accessories start with "None" only
- [ ] Randomize only picks from unlocked options

**Color pickers**

- [ ] Hair color picker changes every hair style, including on the preview head
- [ ] Skin color picker changes the face; the colors survive a relaunch
- [ ] Body has no free color picker; body color comes from the unlocked variant or an uploaded texture

**Unlock everything** (run with `--unlock-all`)

- [ ] Every catalog item is selectable
- [ ] Without the flag on the next run, items not really unlocked are locked again

**Saved data**

- [ ] A head built before this update still loads; any option that's now locked falls back to an unlocked one without errors
- [ ] Unlocked items survive a relaunch

**Customize Cancel**

- [ ] Opening Customize from the playground shows Save and Cancel
- [ ] Cancel discards every change, including a newly uploaded body or background image
- [ ] Esc in Customize cancels instead of quitting the game
- [ ] Esc in the playground still quits
- [ ] On first launch there's nothing to cancel back to: only "Play" shows

## 2. Drops

Status: **Built** (2026-10-22). Drop chance is 1 in 20 right-clicks; the
super-rare roll is 1 in 500 but has nothing in its pool until the unicorn set
arrives in step 3. Drops start once the reveal has finished.

Run with `--drop-rate=1` so every right-click drops something, then again
without the flag to check normal rarity.

- [ ] A right-click rolls once for a drop, however many rockets launch (`--fake-friends=19` doesn't drop 20 items)
- [ ] A new item falls as a gift box and lands beside the bobblehead's stand, not on it or on other boxes
- [ ] Clicking a box opens it, adds the item, and shows "New: <item>!" under the banner
- [ ] Clicking a box doesn't also nudge the head
- [ ] An item you already own bursts into confetti instead of a gift box
- [ ] An unclicked gift box stays on screen until you quit, and is gone on the next launch
- [ ] Unclicked boxes are still there after a trip to Customize and back
- [ ] Newly unlocked items appear as unlocked in Customize straight away
- [ ] As the collection fills up, new items come noticeably less often (more confetti, fewer boxes)
- [ ] Super-rare items never drop from the normal pool; they only come from their own separate roll
- [ ] Without `--drop-rate`, drops feel rare but not absent over a few minutes of fireworks
- [ ] Non-Steam players get drops too (drops are local, not achievements)

## 3. Content

Status: **Partly built** (2026-10-22): variants, the wizard hat and the Style
pickers are in. Still to come: the unicorn set, arms and legs, and the
updated templates.

Run with `--unlock-all` to see everything.

**Variants**

- [ ] Every accessory base has four variants, numbered #1-#4 in a Style picker under Accessory
- [ ] Every body base has four variants, in a Style picker under Body
- [ ] Locked styles read "#3 (locked)"; switching hat or body jumps to a style you own
- [ ] A dropped style is named with its number, e.g. "New: Wizard hat #3!"
- [ ] Variants of one item keep the same shape and differ only by colors and patterns
- [ ] Variants look right with every face shape and with head size at 80% and 150%

**Wizard hat**

- [ ] Wizard hat fits every face shape and head size
- [ ] Tall hair (mohawk, spiky) tucks under it like the other hats

**Unicorn set**

- [ ] Unicorn head, rainbow hair and unicorn body (with rainbow tail) are selectable with `--unlock-all`
- [ ] The unicorn horn is a hat, with four variants
- [ ] Only one horn variant can drop in single player; the other three never drop yet
- [ ] Without `--unlock-all`, unicorn pieces are locked until dropped

**Arms and legs**

- [ ] Suit, hoodie and robe have sleeves matching the body
- [ ] T-shirt has short sleeves with bare arms in the skin color
- [ ] Goat and unicorn have no arms and stand on four legs
- [ ] Arms stay still on the bobble rig
- [ ] An uploaded body texture covers the arms and legs too

**Templates**

- [ ] "Save body template…" includes the arm and leg areas
- [ ] A blank template (outlines only) can also be saved
- [ ] Painting on either template and uploading it lines up with the body, arms and legs

## 4. Rigs

Status: **Not built yet**

**Balloon**

- [ ] Balloon rig is locked until unlocked, then selectable in Customize
- [ ] The head floats on a string tied to the body and sways gently
- [ ] Dragging pulls the string taut; releasing lets it bob back up
- [ ] Right-clicking near it pops it, leaving a limp string, then it reinflates
- [ ] Popping it unlocks Pop Goes the Head (Steam players; terminal line on app 480)
- [ ] Face swaps, eyes and dizzy stars still work on the balloon

**Marionette**

- [ ] Marionette rig is locked until unlocked, then selectable
- [ ] A control bar hangs above with strings to the arms
- [ ] Dragging the bar moves the body, and the head ragdolls with the motion
- [ ] Animal bodies (no arms) work sensibly on the marionette
- [ ] Face swaps and eyes still work on the marionette

## 5. Desktop buddy

Status: **Not built yet**

- [ ] The buddy opens as a small transparent window on the desktop, with no frame
- [ ] Clicks pass through to other apps everywhere except the bobblehead
- [ ] The bobblehead can still be clicked, dragged and fire fireworks
- [ ] On Windows and X11: eyes follow the cursor anywhere on screen
- [ ] On Wayland (KDE/Kinoite): eyes follow the cursor near the buddy, and drift idly otherwise
- [ ] The buddy never reacts to clicks in other apps
- [ ] The buddy can be closed and the normal game reopened
- [ ] While the buddy runs, a drop happens at a random time every 60 to 90 minutes (a gift box for a new item, confetti for one you own)
- [ ] Timed drops never give super-rares
- [ ] With 12 gift boxes waiting, timed drops stop until some are collected
- [ ] A timed-drop gift box on the desktop can be clicked even though the rest of the window lets clicks through

## Parallel track: Steam-ready prep

Status: **Not started**. These are documents and assets rather than game
features; check them by reading.

- [ ] Achievements sheet lists every achievement with API name, display name, description and two icons, at the size Valve requires
- [ ] Stat definitions match the stats the game reports (`clicks`, `fireworks`)
- [ ] Rich Presence file contains "Being a Big Head"
- [ ] Steam Cloud list covers `head_build.json`, `stats.json`, the inventory file and `uploads/`
- [ ] Store description draft reads well and never spoils the pop before the reveal
- [ ] Screenshots: at least 5, 1920 × 1080, gameplay only, 4 or more suitable for all ages
- [ ] Windows build runs under Proton: builder, reveal, fireworks, drops

## Findings

| Section | What happened | Terminal output |
| --- | --- | --- |
|  |  |  |
