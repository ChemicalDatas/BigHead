# Big Head

Scapegoat A.L. LLC presents: become a bobblehead.

**Current state: iteration 2A plus "Before the App ID" steps 1 to 4**
(catalog and inventory, drops, item variants, the unicorn set, arms and legs, the Balloon and Marionette rigs). The game runs as Valve's test app 480 (Spacewar) until Big Head
has its own Steam App ID.

## What's in it

- **Splash → Head Builder → Reveal.** Steam players watch their built face pop
  into their Steam avatar (hair and accessory stay on) and unlock "Big Head".
  Without Steam, the built head is the reveal and nothing unlocks.
- **Collection.** New players own two options each of face shape, hair,
  eyes, mouth and body, and no accessories. Everything else shows in the
  builder as "(locked)" until it's unlocked.
- **Desktop buddy.** The playground's "Desktop buddy" button (or launching
  with `--buddy`) shrinks the game to a small see-through bobblehead in the
  corner of your desktop, always on top. Clicks pass through to your other
  apps except on the figure. Drag the stand to move it; "Full game" brings the
  window back. While it runs, a drop falls every 60 to 90 minutes (no
  super-rares; unopened boxes pile up beside it).
- **Friends' shelves.** Friends who have Big Head stand on shelves on the
  wall as little bobbleheads with their Steam avatar as the face. Click one
  to make it wobble; hover for the name. Up to 72 (two wall shelves, then a
  bookcase on each side). `--fake-friends=N` fills them for testing.
- **Drops.** Each right-click in the playground has a 1 in 20 chance of a
  drop. A new item falls as a gift box; click it to unlock the item. An item
  you already own bursts into confetti instead. Unclicked boxes are lost when
  you quit.
- **Builder tabs**
  - *Head*: face shape, skin color, hair, hair color, eyes, mouth, accessory
    (Glasses, Party hat, Crown, Goat horns, Wizard hat) and its Style, and a
    head-size slider (80%–150%; maxing it unlocks Swelled Head).
  - *Body*: Suit, Hoodie, T-shirt, Robe, Goat or Unicorn and its Style, or
    your own uploaded texture. People have arms; the goat and unicorn stand
    on four legs.
  - Animal faces: four unicorn and four goat faces, one matching each body
    style, with their own muzzle and mouth.
  - The super-rare unicorn set (faces, Rainbow mane, body, horn) comes from a
    separate 1-in-500 roll. Unicorn horns #2-#4 are multiplayer-only.
  - *Rig*: Bobble (the spring neck), Balloon or Marionette. The rigs join
    the super-rare roll after 500 (Balloon) and 1,000 (Marionette)
    fireworks in total. The Balloon head floats on a string from the hand
    and pops on a whiplash fling, the floor or a rocket hit, then
    reinflates. The Marionette hangs from a control bar you drag: strings to
    the hands (or an animal's four legs) lift and swing it, and the head
    flops along.
  - Every accessory and body comes in four numbered styles (#1-#4): same
    shape, different colors and patterns. Each style is its own item to
    collect. "Save template…" gives you a guide PNG to paint over;
    "Save blank template…" gives plain outlines.
- **Customize** from the playground has Save and Cancel; Esc cancels. Cancel
  throws away every change, uploads included. Either way you go straight back
  to the playground without replaying the reveal.
  - *Scene*: five drawn backgrounds or your own uploaded image; banner color,
    text color and font.
- **Playground** after the reveal
  - Left-click nudges the head; click and **drag** to pull it, release to
    fling it.
  - Steam players see their Steam face for 15 s, then their built face for
    45 s, repeating; Customize → Head → Face can lock either one.
  - The eyes follow the cursor; closed eyes and the Steam face tilt the head instead.
  - **Right-click** launches fireworks: one rocket of yours plus one for every
    Steam friend who has the Big Head achievement.

Uploads are copied into the game's own storage and downscaled to 2048 px.
They stay on your machine and are never shown to other players.

## Run it on Fedora

1. Install Godot 4.6 (Flatpak `org.godotengine.Godot` or the binary from
   godotengine.org).
2. Open `project.godot` and press F5, or run `godot --path .` in this folder.

## Steam: bundle GodotSteam (one-time, please commit it)

GodotSteam isn't in the repo yet. Its downloads now live on Codeberg, which
the build session couldn't reach, so this one step happens on your machine:

1. In the Godot editor, open **AssetLib**, search **GodotSteam GDExtension
   4.4+** (version 4.14 or newer), and install it into `addons/godotsteam`.
   Restart the editor.
2. Commit it so every clone and export carries Steam with no install step:

   ```
   git add addons/godotsteam
   git commit -m "Bundle GodotSteam"
   git push
   ```

The folder includes both `libsteam_api.so` (Linux) and `steam_api64.dll`
(Windows); exports pick up the right one automatically.

With Steam running, the terminal prints `[game] Steam available: true`.

## Achievements while on app 480

Spacewar only defines four test achievements, so four of ours borrow them and
show Spacewar's popup. The rest print to the terminal when they unlock:

| Ours | Trigger | On app 480 |
| --- | --- | --- |
| BIG_HEAD | Finish the reveal | Spacewar `ACH_WIN_ONE_GAME` |
| ITS_A_PARTY | 5 rockets in one right-click | Spacewar `ACH_WIN_100_GAMES` |
| WHIPLASH | Release a drag at 2,200+ px/s | Spacewar `ACH_TRAVEL_FAR_SINGLE` |
| BOBBLE_BOOP | Click the head 100 times | Spacewar `ACH_TRAVEL_FAR_ACCUM` |
| GRAND_FINALE | 20 rockets in one right-click | terminal |
| OOH_AAH | 50 fireworks in total | terminal |
| PERPETUAL_MOTION | Keep it moving for 60 s | terminal |
| LEVEL_HEADED | Leave it still for 5 min | terminal |
| SWELLED_HEAD | Max the head-size slider | terminal |
| POP_GOES_THE_HEAD | Pop the balloon head | terminal |

The click and firework counters borrow Spacewar's `NumGames` and `NumWins`
stats.

## Testing switches

Put these after `--` on the command line, or in Project → Project Settings →
Editor → Run → Main Run Args.

They only work in the editor and debug builds: a release export ignores all
of them except `--buddy`. In the playground you can also type cheat codes:
`confetti`, `party` and `dizzy` (all builds), and `bighead`, `fastfaces` and
`dropall` (debug only). They never count toward achievements.

| Flag | Effect |
| --- | --- |
| `--reset` | Forget the saved head, style and uploads (first-launch flow) |
| `--no-steam` | Ignore Steam even if it's available (fallback flow) |
| `--reset-achievement` | Re-lock the test achievements so unlocks fire again |
| `--fake-friends=N` | Pretend N friends have Big Head (try 4 and 19; `--fake-friends N` works too) |
| `--fast-faces` | Run the face swap cycle 10x faster for testing |
| `--unlock-all` | Treat every item as owned for this run (nothing is saved) |
| `--reset-inventory` | Forget unlocked items; back to the starting set |
| `--drop-rate=N` | Drop chance per right-click, 0 to 1 (`--drop-rate=1` drops every click) |
| `--buddy` | Start as the desktop buddy (stays in the shipped game as a launch option) |
| `--store-screenshots` | Stage and save the Steam store screenshots |
| `--fast-timed-drops` | Desktop buddy timed drops every 5 to 10 seconds |
| `--fireworks-launched=N` | Set your lifetime fireworks count (the Balloon rig can drop from 500, the Marionette from 1,000) |

Example: `godot --path . -- --reset --fake-friends=19`

Saved data lives in `~/.local/share/godot/app_userdata/Big Head/` on Linux
and `%APPDATA%\Godot\app_userdata\Big Head\` on Windows. Esc quits from the
playground and cancels in Customize.

## Exporting Linux and Windows builds

1. Editor → Manage Export Templates → Download and Install (Godot 4.6).
2. Project → Export → Linux or Windows → Export Project. Builds land in
   `build/` (git-ignored). Or from a terminal:

   ```
   godot --headless --path . --export-release "Linux" build/linux/BigHead.x86_64
   godot --headless --path . --export-release "Windows" build/windows/BigHead.exe
   ```

To try the Windows build on Fedora, run it under Proton (or Wine). Once Big
Head is on Steam, Steam can force the Windows build through Proton for you.

## Layout

```
scripts/
  core/       PlayerProfile, HeadBuild, SceneStyle, BobbleState (springs + drag),
              AchievementRules (events in, unlocks out) — no Steam
  ports/      IdentityPort, AchievementPort, StatsPort — what scenes ask for
  adapters/   SteamIdentity (incl. friend lookup), SteamAchievements, SteamStats,
              LocalStats, NullAchievements, SavedBuild, UploadStore — the only Steam/disk code
  view/       HeadView, BodyShapes, BackgroundView, Banner, Fireworks, Confetti
  scenes/     splash, head_builder, reveal
  autoload/   game.gd — wiring, routing, dev mappings, COMPANY_NAME
assets/
  fonts/      Bangers, Luckiest Guy, Lobster, Pacifico, Press Start 2P (+ licenses)
  body_template.png, body_template_blank.png
tools/        dump_body_shapes.gd + make_body_templates.py: regenerate both
              templates from BodyShapes after changing a body outline;
              achievement_icons.tscn + finish_icons.py, capsules.tscn and
              store_screenshots.gd: the Steam art (see docs/steam-setup.md)
steam/        everything for Steamworks: achievement icons and CSV, Rich
              Presence file, screenshots, capsules, store text, SteamPipe
```

## Iteration 2B checklist (after the App ID)

- `game.gd`: set `DEV_APP_ID` to the real App ID and `DEV_MODE = false`.
- Steamworks: define the nine achievements with the ids above, plus the
  `clicks` and `fireworks` stats; Rich Presence ("Being a Big Head");
  Steam Cloud for `head_build.json` and `uploads/`.
- Store page, AI-content survey ("none"), build uploads.

Note: "Scapegoat A.L. LLC" is intentional. Do not change "A.L." to "A.I.".
