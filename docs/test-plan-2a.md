# Big Head — Iteration 2A Test Plan

A checklist for verifying iteration 2A on Fedora. Tick items as they pass
(`[ ]` → `[x]`) and log anything odd in **Findings** at the end.

## Setup

### Running the game from a terminal

Open Terminal (or Konsole on KDE) and move into the project, then update it:

```
cd ~/BigHead
git pull
```

Pick the Godot command that matches how Godot is installed. Not sure? Run
`flatpak list | grep -i godot`; if it prints a line, use the Flatpak command.

| How Godot is installed | Command to start the game |
| --- | --- |
| Flatpak (Software Center / Flathub) | `flatpak run org.godotengine.Godot --path .` |
| Downloaded binary | `~/Downloads/Godot_v4.6-stable_linux.x86_64 --path .` (wherever you saved it) |
| On your PATH as `godot` | `godot --path .` |

`--path .` runs the project in the current folder, without the editor. Game
flags go after a lone `--`, and several can be combined:

```
flatpak run org.godotengine.Godot --path . -- --reset --fake-friends=19
```

The commands below are written as `godot --path . -- …`; swap in your own
Godot command. Press Esc in the game, or Ctrl+C in the terminal, to stop it.

**From the editor instead:** Project → Project Settings → turn on Advanced
Settings → Editor → Run → **Main Run Args**. Type the game flags without the
leading `--` (for example `--reset --fake-friends=19`), then press F5. Clear
the field afterwards, or every run will reset your saved head.

### Flags

Run every test from a terminal in the project folder so the log lines are
visible. Flags go after `--`.

| Flag | Effect |
| --- | --- |
| `--reset` | Forget the saved head, style and uploads (first-launch flow) |
| `--no-steam` | Ignore Steam even if it's available |
| `--reset-achievement` | Re-lock the test achievements |
| `--fake-friends=N` | Pretend N friends have Big Head (`--fake-friends N` works too) |
| `--fast-faces` | Run the face swap cycle 10x faster (1.5 s Steam face, 4.5 s your face) |

Terminal lines worth watching: `[game] Steam available: …`, `[friends] …`,
and `[achievements] UNLOCKED …`.

- [ ] Pulled the latest from GitHub (`git pull`)
- [ ] Running Godot 4.6 (Help → About)

## 1. First launch without Steam

Run `godot --path . -- --reset --no-steam`.

- [ ] Splash shows "Scapegoat A.L. LLC", then the builder
- [ ] Name box is visible; typing a ~20-character name updates the preview banner live
- [ ] Head tab: every picker cycles both directions and nudges the head
- [ ] Head size slider at 150%: the whole figure shrinks to fit and never hits the banner
- [ ] "Play": reveal shows the built head and typed name, with no pop
- [ ] No `UNLOCKED` lines in the terminal

## 2. Body tab

- [ ] All five bodies cycle (Suit, Hoodie, T-shirt, Robe, Goat), each with its own default color
- [ ] Goat outline is smooth and it stands on four hooved legs
- [ ] T-shirt has no star; Robe has no belt stripe
- [ ] Changing the body color recolors the trim (suit tie and lapels, hoodie pocket, goat tufts)
- [ ] "Save body template…" writes a PNG with the outlines on it
- [ ] A painted template uploads and covers the body inside its outline
- [ ] A huge photo (over 4000 px) uploads fine
- [ ] A non-image file shows a red error message and nothing crashes
- [ ] "Remove" returns the body to a solid color

## 3. Scene tab

- [ ] All five backgrounds cycle (Night, Sunset, Spotlight, Office, Party)
- [ ] A wide photo uploads and fills the screen, cropped, not stretched
- [ ] A tall photo uploads and fills the screen, cropped, not stretched
- [ ] Banner color and text color change live
- [ ] All six fonts work; the longest name still fits in Press Start 2P and Lobster

## 4. Persistence

Quit, then relaunch without `--reset`.

- [ ] The builder is skipped; the game lands in the reveal
- [ ] Body texture, background, banner style and head size are all intact

## 5. Playground

Run `godot --path . -- --fake-friends=19`.

- [ ] Clicking the head bobbles it toward the click; clicking elsewhere still nudges it
- [ ] Pressing on the head and moving pulls it away on the spring neck
- [ ] Releasing a drag flings the head and it snaps back
- [ ] A quick press without moving counts as a click, not a drag
- [ ] A hard fling (Whiplash speed) sends a ring of stars around the head for about 3 seconds
- [ ] Another hard fling within 30 seconds doesn't bring the stars back; one after 30 seconds does
- [ ] A gentle release never shows stars
- [ ] Right-click launches 20 rockets with an "x20" marker
- [ ] Spamming right-click keeps a steady frame rate (capped at 80 rockets on screen)
- [ ] With `--fake-friends=4`: 5 rockets and "x5"
- [ ] With no flag: 1 rocket and no marker
- [ ] The hint text at the bottom matches the rocket count each time

## 5b. Face swaps and eyes

Steam path (GodotSteam installed, Steam running). Run `godot --path . -- --fast-faces`
so a full cycle takes 6 seconds instead of a minute.

- [ ] After the reveal pop, the Steam face shows, then your built face, then Steam again, repeating
- [ ] Swaps squash and spring the face only; the head itself doesn't jump
- [ ] A swap that comes due while you're dragging the head waits until you let go
- [ ] Confetti comes back on the swap after 10 full cycles (about 60 s with `--fast-faces`, 10 min normally), not on every swap
- [ ] Customize → Head → Face = "Keep Steam face": the Steam face stays after the reveal
- [ ] Face = "Keep my face": the Steam face pops at the reveal, then your face returns and stays
- [ ] The Face setting only appears for Steam players
- [ ] Googly eyes: pupils follow the cursor and never leave the whites
- [ ] Dots and Angry eyes: the dots shift a little toward the cursor; Angry brows stay put
- [ ] Happy (closed) eyes and the Steam face: the head tilts slightly toward the cursor instead
- [ ] Eyes ease toward the cursor rather than snapping, and stop at a limit when the cursor is far away
- [ ] Leaving the head alone with faces swapping still earns Level-Headed after 5 minutes

## 6. Achievements (Steam path)

Needs GodotSteam installed and Steam running. Run
`godot --path . -- --reset --reset-achievement --fake-friends=19` and watch for
`UNLOCKED` lines. Four achievements show a Spacewar popup; the rest only print
to the terminal until the App ID.

- [ ] Terminal shows `[game] Steam available: true`
- [ ] Finish the reveal: BIG_HEAD, with a Spacewar popup
- [ ] Max the head slider in the builder: SWELLED_HEAD
- [ ] Right-click once: ITS_A_PARTY (popup) and GRAND_FINALE
- [ ] Fling the head hard: WHIPLASH (popup)
- [ ] Click the head 100 times: BOBBLE_BOOP (popup)
- [ ] Keep it moving for 60 seconds: PERPETUAL_MOTION
- [ ] Leave it untouched for 5 minutes: LEVEL_HEADED
- [ ] Launch 50 rockets in total: OOH_AAH (a lifetime count, so it may unlock early on repeat runs)
- [ ] Each achievement unlocks once per session, with no repeats in the log
- [ ] Without the fake flag, the log shows `[friends] checking N friends` (expect 0 on app 480)

## 7. Exported builds

Install export templates first (Editor → Manage Export Templates).

- [ ] Linux export succeeds and `build/linux/BigHead.x86_64` runs
- [ ] Sections 4 and 5 pass briefly in the Linux build
- [ ] Windows export succeeds
- [ ] The Windows `.exe` runs under Proton or Wine (optional)

## Known issues

Already tracked, so they don't count as failures:

- The customize screen has no Cancel, and Esc quits the game
- Returning from Customize replays the full reveal
- Script errors on Kinoite, pending the error text and Godot version

## Findings

| Section | What happened | Terminal output |
| --- | --- | --- |
|  |  |  |
