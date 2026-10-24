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
| `--fast-timed-drops` | Desktop buddy timed drops every few seconds instead of 60 to 90 minutes (step 6) |

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
super-rare roll is 1 in 500 and holds the unicorn set (added in step 3). Drops start once the reveal has finished.

Run with `--drop-rate=1` so every right-click drops something, then again
without the flag to check normal rarity.

- [ ] A right-click rolls once for a drop, however many rockets launch (`--fake-friends=19` doesn't drop 20 items)
- [ ] A new item falls as a gift box and lands beside the bobblehead's stand, not on it or on other boxes
- [ ] Clicking a box opens it, adds the item, and shows "New: <item>!" under the banner
- [ ] Clicking a box doesn't also nudge the head
- [ ] An item you already own bursts into confetti instead of a gift box
- [ ] An unclicked gift box stays on screen until you quit, and is gone on the next launch
- [ ] Many boxes pile up: a front row, rows behind it (a little higher, smaller and darker), then stacked on top; no limit
- [ ] Clicking a pile opens the box in front, not one behind it; only the front one glows on hover
- [ ] Unclicked boxes are still there after a trip to Customize and back
- [ ] Newly unlocked items appear as unlocked in Customize straight away
- [ ] As the collection fills up, new items come noticeably less often (more confetti, fewer boxes)
- [ ] Super-rare items never drop from the normal pool; they only come from their own separate roll
- [ ] Without `--drop-rate`, drops feel rare but not absent over a few minutes of fireworks
- [ ] Non-Steam players get drops too (drops are local, not achievements)

## 3. Content

Status: **Built** (2026-10-23): variants, the wizard hat, the Style pickers,
the unicorn set, arms and legs, slimmer people bodies, and both templates.

Run with `--unlock-all` to see everything.

**Variants**

- [ ] Every accessory base has four variants, numbered #1-#4 in a Style picker under Accessory
- [ ] Every body base has four variants, in a Style picker under Body
- [ ] Locked items and styles never show by name: each picker steps through what you own, then one "?" entry reading "N still locked"
- [ ] On "?", the preview shows a question mark where that part goes (grey face or body for those); Play/Save still work and keep your real choice
- [ ] With `--unlock-all` there's no "?" entry
- [ ] Switching hat or body jumps to a style you own
- [ ] A dropped style is named with its number, e.g. "New: Wizard hat #3!"
- [ ] Variants of one item keep the same shape and differ only by colors and patterns
- [ ] Variants look right with every face shape and with head size at 80% and 150%
- [ ] Every hair style fits every face shape, animal faces included: caps sit flush, spikes grow from the head, the mop follows the face (fixed 2026-10-24; hair now follows each face's outline)

**Wizard hat**

- [ ] Wizard hat fits every face shape and head size
- [ ] Tall hair (mohawk, spiky) tucks under it like the other hats

**Unicorn set**

- [ ] Unicorn face (ears, muzzle), Rainbow mane and Unicorn body (rainbow tail, four styles) are selectable with `--unlock-all`
- [ ] The unicorn ears stay on when the Steam face pops
- [ ] The unicorn horn is a hat, with four variants; tall hair tucks under it
- [ ] Only horn #1 can drop in single player; #2-#4 read "(multiplayer)" when locked and never drop yet
- [ ] With Rainbow mane chosen, the Hair color picker is greyed out
- [ ] Without `--unlock-all`, unicorn pieces are locked until dropped
- [ ] A super-rare drop comes in a rainbow-wrapped gift box (try `--drop-rate=1` for a while; it's 1 in 500)

**Arms and legs**

- [ ] Suit, hoodie and robe have sleeves matching the body
- [ ] T-shirt has short sleeves with bare arms in the skin color
- [ ] Goat and unicorn have no arms and stand on four legs
- [ ] Arms stay still on the bobble rig
- [ ] People bodies are slim enough that the head is clearly the focal point; the goat and unicorn keep full width
- [ ] An uploaded body texture covers the arms and legs too

**Templates**

- [ ] "Save template…" includes the arm and leg areas
- [ ] "Save blank template…" saves plain outlines only
- [ ] Painting on either template and uploading it lines up with the body, arms and legs

**Animal faces** (added 2026-10-24)

- [ ] Face shape lists four unicorn faces (Pearl, Lavender, Pink, Midnight) and four goat faces (Cream, Brown, Black, Spotted), each its own item
- [ ] Each one matches its body style's colors and pattern, ears included
- [ ] Animal faces have their own muzzle and mouth; the Mouth row reads "The face's own"
- [ ] The goat face has floppy ears and a little beard; goat horns sit right on it
- [ ] On the dark coats (Midnight unicorn, Black goat) dot, happy and angry eyes turn light so they stay visible
- [ ] Unicorn faces drop only from the super-rare roll; goat faces from the regular pool
- [ ] A unicorn face unlocked before this change is still owned (it's the Pearl unicorn)
- [ ] The Steam face pops into an animal face with its ears still on

**Eyes and confetti** (added 2026-10-24)

- [ ] Dots, googly and angry eyes visibly follow the cursor, even when it's only a little way from the head
- [ ] Happy eyes (and the Steam face) tilt the head a bit more toward the cursor
- [ ] Confetti is paper: strips, dots, stars, hearts and curly spirals that flip over (lighter backs) and flutter down slowly
- [ ] Confetti stays visible in front of a big fireworks barrage (`--fake-friends=19`)

## 4. Rigs

Status: **Built** (2026-10-23): Balloon and Marionette.

Run with `--unlock-all` to pick the Balloon in Customize (Body tab, Rig).
`--fireworks-launched=N` sets your lifetime fireworks count for the unlock
checks. Each pop prints `[rig] Balloon popped (<cause>)` in the terminal.

**Unlock**

- [ ] Without `--unlock-all`, Rig shows "Balloon (locked)" and Play/Save stay disabled while it's chosen
- [ ] With `--fireworks-launched=499 --drop-rate=1`, the balloon never drops (it isn't in the pool yet)
- [ ] With `--fireworks-launched=500`, it can drop from the super-rare roll (1 in 500 right-clicks, rainbow gift box)

**Balloon**

- [ ] The head floats on a string tied to the right hand (the goat and unicorn: their back) and sways gently
- [ ] Dragging pulls the string taut; releasing lets it float back up
- [ ] A whiplash-speed fling pops it
- [ ] Dragging it down to the floor pops it
- [ ] Right-clicking on the head pops it when the rocket flies into it; rockets aimed elsewhere don't
- [ ] The pop: a tear opens where it was hit, the skin snaps back across the head, and a small scrap is left on the string
- [ ] The scrap drops limp onto the stand, then reinflates after about 3 seconds and floats back up
- [ ] It doesn't re-pop straight away when it reinflates on the floor
- [ ] The head can't be grabbed while it's popped
- [ ] Popping it unlocks Pop Goes the Head (Steam players; terminal line on app 480)
- [ ] Face swaps, eyes and dizzy stars still work on the balloon
- [ ] The figure fits under the banner with the tallest hat on

**Marionette**

- [ ] Without `--unlock-all`, Rig shows "Marionette (locked)"; with `--fireworks-launched=999` it never drops, from 1000 it can
- [ ] A wooden control bar sits above the tallest hat, with strings to both hands
- [ ] The head hangs from the middle of the bar on its own string, with a rope from the middle of the head to the back of the body (no spring neck)
- [ ] Goat and unicorn: four strings, one to the top of each leg
- [ ] At rest the strings are slightly slack: arms hang, the body sits on the stand
- [ ] Dragging the bar up lifts the body off the stand; the arms rise along the strings; animal legs hang straight down
- [ ] Dragging side to side swings the body, and the head flops on its spring with the motion
- [ ] Letting go: the bar springs back and the body drops back onto the stand
- [ ] The head can still be clicked and dragged (and Whiplash still works)
- [ ] The hint reads "Drag the bar or the head"
- [ ] Face swaps, eyes and dizzy stars still work on the marionette
- [ ] Level-Headed only counts once the puppet and head are both still

## 5. Friends' shelves

Status: **Built** (2026-10-24). Use `--fake-friends=N` for made-up friends.

- [ ] No friends (no flag, or no Steam friends with Big Head): the two wall shelves show, empty, waiting for friends
- [ ] The shelves fade in with the banner, not before the pop; back from Customize they're already there
- [ ] `--fake-friends=4`: four friends on the left wall shelf
- [ ] `--fake-friends=12`: both wall shelves full
- [ ] `--fake-friends=20`: a bookcase appears under the right wall shelf and fills from the top
- [ ] `--fake-friends=50`: the right bookcase is full and a second appears on the left
- [ ] `--fake-friends=80`: 72 on the shelves, the rest left off (fireworks still count all 80)
- [ ] Each friend keeps the same look between launches; avatars are their own (generated for fake friends)
- [ ] Clicking a friend's head makes it wobble, and doesn't nudge your bobblehead or launch anything
- [ ] Hovering a friend shows their name above them
- [ ] The shelves stay clear of the banner, your bobblehead, the gift boxes and the buttons
- [ ] They show over every background, and over an uploaded one

## 6. Desktop buddy

Status: **Built** (2026-10-24). This is the part most worth testing on your
own machines: see-through windows and click-through behave differently on
X11, Wayland (KDE/Kinoite) and Windows, and couldn't be checked here.
`--fast-timed-drops` makes timed drops come every 5 to 10 seconds.

- [ ] The playground has a "Desktop buddy" button; launching with `--buddy` goes straight to the buddy (or to Customize if no head is built yet)
- [ ] The buddy opens as a small transparent window on the desktop, with no frame, in the bottom-right corner, above other windows
- [ ] Dragging the stand moves the buddy around the desktop
- [ ] "Full game" brings back the normal window as it was (size, position, fullscreen); "Close" quits
- [ ] The two buttons are faint until the cursor is over the buddy
- [ ] Clicks pass through to other apps everywhere except the bobblehead
- [ ] The bobblehead can still be clicked, dragged and fire fireworks
- [ ] On Windows and X11: eyes follow the cursor anywhere on screen
- [ ] On Wayland (KDE/Kinoite): eyes follow the cursor near the buddy, and drift idly otherwise
- [ ] The buddy never reacts to clicks in other apps
- [ ] The buddy can be closed and the normal game reopened
- [ ] While the buddy runs, a drop happens at a random time every 60 to 90 minutes (a gift box for a new item, confetti for one you own)
- [ ] Timed drops never give super-rares
- [ ] Timed drops keep coming however many boxes are waiting
- [ ] A timed-drop gift box on the desktop can be clicked even though the rest of the window lets clicks through

## 7. Play together

Status: **Built** (2026-10-24). Tested here with two copies of the game on
one machine over a direct connection: joining, walking, boops, fireworks
and leaving all worked. The Steam invite needs two Steam accounts on two
machines (GodotSteam installed on both); on app 480 an invite only works
while the friend's game is already running, since Steam would otherwise
launch Spacewar.

Two copies on one computer: run one with `--host-room` and the other with
`--join-room=127.0.0.1`. Across two computers, the host's firewall has to let
in UDP port 7777 (Fedora: `sudo firewall-cmd --add-port=7777/udp`).

**Direct connection**

- [ ] Playground → "Play together" → "Host a room": you're in a room showing "Hosting. Friends join at <address>"
- [ ] On the other computer: "Play together", type that address, "Join": both see both bobbleheads with names
- [ ] A / D or the arrow keys walk your bobblehead; it lurches when starting and stopping; the other screen follows smoothly
- [ ] Clicking someone else's head boops it on both screens; dragging across it and letting go flings it
- [ ] Right-click fireworks show on both screens (one rocket per player)
- [ ] The room widens (the view zooms out) as a third and fourth player join; at 8 the room is full
- [ ] Everyone sees the host's background
- [ ] "Leave room" goes back to your playground; the others see "<name> left"
- [ ] If the host leaves, everyone else goes back to their playground with "The host left the room."
- [ ] A wrong address gives "Couldn't reach the host." and you stay in your playground

**Steam invite**

- [ ] "Play together" → "Invite a Steam friend" opens a room and the Steam invite overlay
- [ ] The friend accepts (game running): they join the room, with your Steam avatars on your heads
- [ ] "Join game" from the Steam friends list works too
- [ ] With GodotSteam's MultiplayerPeer installed, it works across different homes with no port forwarding
- [ ] Friends see "In a room full of Big Heads" as your status (after the App ID)

## Parallel track: Steam-ready prep

Status: **Built** (2026-10-24). Mostly documents and assets in `steam/`;
the step-by-step for the App ID day is `docs/steam-setup.md`.

- [ ] Release build (`build/linux` or the Windows zip): `--unlock-all`, `--fake-friends`, `--drop-rate` etc. do nothing; `--buddy` still works
- [ ] Saves are in `~/.local/share/BigHead` (Windows: `%APPDATA%\BigHead`); your old saves came along on first launch
- [ ] Typing `confetti`, `party` or `dizzy` in the playground works (and `bighead`, `fastfaces`, `dropall` in debug runs); a "Cheat: ..." toast shows; none count toward achievements

- [ ] Achievements sheet (`steam/achievements.csv`) lists every achievement with API name, display name, description and two icons (256 × 256 PNG)
- [ ] Stat definitions match the stats the game reports (`clicks`, `fireworks`)
- [ ] Rich Presence file contains "Being a Big Head" (plus Customize and desktop buddy states)
- [ ] Steam Cloud setup in `docs/steam-setup.md` covers `head_build.json`, `stats.json`, `inventory.json` and `uploads/`
- [ ] Store description draft reads well and never spoils the pop before the reveal
- [ ] Screenshots: at least 5, 1920 × 1080, gameplay only, 4 or more suitable for all ages
- [ ] Windows build runs under Proton: builder, reveal, fireworks, drops

## Findings

| Section | What happened | Terminal output |
| --- | --- | --- |
|  |  |  |
