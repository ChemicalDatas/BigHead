# Big Head

Scapegoat A.L. LLC presents: become a bobblehead.

**Current state: iteration 2A** (everything before Big Head has its own Steam
App ID). The game runs as Valve's test app 480 (Spacewar) until then.

## What's in it

- **Splash → Head Builder → Reveal.** Steam players watch their built face pop
  into their Steam avatar (hair and accessory stay on) and unlock "Big Head".
  Without Steam, the built head is the reveal and nothing unlocks.
- **Builder tabs**
  - *Head*: face shape, skin, hair, eyes, mouth, accessory, and a head-size
    slider (80%–150%; maxing it unlocks Swelled Head).
  - *Body*: Suit, Hoodie, T-shirt, Robe or Goat, any color, or your own
    uploaded texture. "Save body template…" gives you a PNG to paint over.
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

The click and firework counters borrow Spacewar's `NumGames` and `NumWins`
stats.

## Testing switches

Put these after `--` on the command line, or in Project → Project Settings →
Editor → Run → Main Run Args.

| Flag | Effect |
| --- | --- |
| `--reset` | Forget the saved head, style and uploads (first-launch flow) |
| `--no-steam` | Ignore Steam even if it's available (fallback flow) |
| `--reset-achievement` | Re-lock the test achievements so unlocks fire again |
| `--fake-friends=N` | Pretend N friends have Big Head (try 4 and 19; `--fake-friends N` works too) |
| `--fast-faces` | Run the face swap cycle 10x faster for testing |

Example: `godot --path . -- --reset --fake-friends=19`

Saved data lives in `~/.local/share/godot/app_userdata/Big Head/` on Linux
and `%APPDATA%\Godot\app_userdata\Big Head\` on Windows. Esc quits.

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
  body_template.png
```

## Iteration 2B checklist (after the App ID)

- `game.gd`: set `DEV_APP_ID` to the real App ID and `DEV_MODE = false`.
- Steamworks: define the nine achievements with the ids above, plus the
  `clicks` and `fireworks` stats; Rich Presence ("Being a Big Head");
  Steam Cloud for `head_build.json` and `uploads/`.
- Store page, AI-content survey ("none"), build uploads.

Note: "Scapegoat A.L. LLC" is intentional. Do not change "A.L." to "A.I.".
