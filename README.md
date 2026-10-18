# Big Head — iteration 1

Scapegoat A. L. LLC presents: become a bobblehead.

Splash → Head Builder (first launch) → Reveal. Steam players watch their built
face pop into their Steam avatar (hair and accessory stay on) and unlock
"Big Head". Without Steam, the built head is the reveal and nothing unlocks.

## Run it on Fedora (no Steam needed)

1. Get Godot 4.6: `flatpak install flathub org.godotengine.Godot`, or the
   Linux binary from godotengine.org.
2. Unzip this folder and open `project.godot` in Godot (Import), then press F5.
   Or from a terminal, inside the folder:

   ```
   godot --path .
   ```

Without GodotSteam installed, the game runs the non-Steam fallback: you type a
name, build a head, and get "<name> is a Big Head."

## Add Steam (the real gag)

1. In the Godot editor, open AssetLib, search **GodotSteam GDExtension**, and
   install it (it lands in `addons/godotsteam`). Use version **4.14 or newer**;
   older versions use a different `steamInitEx` signature. Restart the editor.
2. Start the Steam client and log in.
3. Run the game. It initializes as Valve's test app **480 (Spacewar)**, so no
   App ID of our own is needed yet. The terminal prints
   `[game] Steam available: true`.
4. You'll see your Steam name in the builder, then the pop into your Steam
   avatar. The "Big Head" achievement is mapped to Spacewar's
   `ACH_WIN_ONE_GAME` for testing, so the Steam popup will say Spacewar's
   achievement name, not ours.

If Steam doesn't initialize, the terminal prints the reason from
`steamInitEx`. A common cause on Linux is the Flatpak Steam client: its
sandbox can keep a game launched outside Steam from connecting. The RPM Fusion
`steam` package avoids that.

## Testing switches

Put these after `--` on the command line, or in Project → Project Settings →
Editor → Run → Main Run Args.

| Flag | Effect |
| --- | --- |
| `--reset` | Forget the saved head (first-launch flow again) |
| `--no-steam` | Ignore Steam even if it's available (fallback flow) |
| `--reset-achievement` | Re-lock the test achievement so the unlock can fire again |

Example: `godot --path . -- --reset --no-steam`

The saved head lives in `~/.local/share/godot/app_userdata/Big Head/head_build.json`.
Esc quits.

## Layout

```
scripts/
  core/       PlayerProfile, HeadBuild, BobbleState (springs), AchievementRules — no Steam
  ports/      IdentityPort, AchievementPort — what scenes ask for
  adapters/   SteamIdentity, SteamAchievements, NullAchievements, SavedBuild — the only Steam code
  view/       HeadView (draws the bobblehead in code), Confetti
  scenes/     splash, head_builder, reveal
  autoload/   game.gd — wiring, routing, COMPANY_NAME
```

## Iteration 2 checklist

- Replace `DEV_APP_ID` (480) with the real App ID; empty `DEV_ACHIEVEMENT_MAP`.
- Define `BIG_HEAD` in Steamworks.
- Drag, fireworks, Rich Presence.

Note: "Scapegoat A. L. LLC" is intentional. Do not change "A. L." to "A. I.".
