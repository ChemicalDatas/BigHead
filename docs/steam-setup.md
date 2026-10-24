# Steam setup: everything for the App ID day

Everything Steamworks needs is ready in `steam/`. When the App ID arrives,
work down this list. Valve's references: [achievements](https://partner.steamgames.com/doc/features/achievements/ach_guide),
[Rich Presence](https://partner.steamgames.com/doc/features/enhancedrichpresence),
[Steam Cloud](https://partner.steamgames.com/doc/features/cloud),
[store assets](https://partner.steamgames.com/doc/store/assets).

## 1. The code change

In `scripts/autoload/game.gd`:

- `DEV_APP_ID` = the real App ID (rename it to `APP_ID` if you like)
- `DEV_MODE = false`
- empty `DEV_ACHIEVEMENT_MAP` and `DEV_STAT_MAP`

That's the whole code change: achievement and stat API names in Steamworks
are exactly the game's own names below.

Also bundle GodotSteam (the GDExtension) into the project before exporting,
so release builds have Steam. Without it the game runs in its no-Steam mode.

## 2. Achievements

`steam/achievements.csv` lists all ten: API name, display name, description,
spoiler flag, and the two icon files. Icons are in `steam/achievements/`,
256 × 256 PNG, named for Valve's bulk upload (`API_NAME_ACHIEVED.png`,
`API_NAME_UNACHIEVED.png`): zip the folder and use "Upload icons" on the
achievements page.

| API name | Display name | Description | Spoiler |
| --- | --- | --- | --- |
| BIG_HEAD | Big Head | Become a bobblehead. | no |
| WHIPLASH | Whiplash | Fling your bobblehead hard enough to see stars. | no |
| PERPETUAL_MOTION | Perpetual Motion | Keep your head bobbling for a full minute. | no |
| BOBBLE_BOOP | Bobble Boop | Boop your bobblehead 100 times. | no |
| OOH_AAH | Ooh, Aah | Launch 50 fireworks. | no |
| ITS_A_PARTY | It's a Party | Launch 5 rockets at once: you and 4 friends who play Big Head. | no |
| GRAND_FINALE | Grand Finale | Launch 20 rockets at once: you and 19 friends who play Big Head. | no |
| LEVEL_HEADED | Level-Headed | Leave your bobblehead perfectly still for 5 minutes. | no |
| SWELLED_HEAD | Swelled Head | Make your head as big as it goes. | no |
| POP_GOES_THE_HEAD | Pop Goes the Head | Pop your balloon head. | yes (the Balloon rig is a surprise) |

To redraw the icons after changing the art: `godot --path . --resolution 1280x960 tools/achievement_icons.tscn`, then `python3 tools/finish_icons.py`.

## 3. Stats

| API name | Type | Set by | Increment only | Default | Display name |
| --- | --- | --- | --- | --- | --- |
| clicks | INT | Client | yes | 0 | Head boops |
| fireworks | INT | Client | yes | 0 | Fireworks launched |

`fireworks` also gates the rigs (Balloon from 500, Marionette from 1,000).

## 4. Rich Presence

Upload `steam/rich_presence/english.vdf` on the Rich Presence localization
page. The game sets `steam_display` to:

| Token | Shown to friends | When |
| --- | --- | --- |
| `#Status_Playing` | Being a Big Head | the playground |
| `#Status_Customizing` | Building a bobblehead | Customize |
| `#Status_Buddy` | Bobbling on the desktop | desktop buddy |
| `#Status_Together` | In a room full of Big Heads | a shared room |

Test it at https://steamcommunity.com/dev/testrichpresence while the game runs.

## 5. Steam Cloud

The game saves to its own folder: `%APPDATA%\BigHead` on Windows and
`~/.local/share/BigHead` on Linux (Godot's `user://` with a custom folder
name). Files: `head_build.json` (head and scene style), `inventory.json`,
`stats.json`, `uploads/` (body and background images, at most 2048 px).

Steam Cloud Settings:

- Byte quota per user: 50 MB. Files per user: 50.
- Auto-Cloud root path: Root `WinAppDataRoaming`, Subdirectory `BigHead`,
  Pattern `*`, OS `[Cross-Platform]`, Recursive on.
- Root override: Original root `WinAppDataRoaming`, OS Linux, New root
  `LinuxXdgDataHome`, Add/Replace path `BigHead`, Replace path on.
- Leave out `logs/` and `shader_cache/` if you prefer: they're harmless but
  machine-specific (a second root path per folder lets you pick).
- Save, then Publish.

## 6. Store page

- Text and tags: `steam/store-page.md`.
- Screenshots: `steam/screenshots/` (6, 1920 × 1080, gameplay only, no
  spoilers). Redo them with `--store-screenshots` (instructions in
  `tools/store_screenshots.gd`).
- Capsules: `steam/capsules/`, placeholders at every required size:
  header 920 × 430, small 462 × 174, main 1232 × 706, vertical 748 × 896,
  library capsule 600 × 900, library header 920 × 430, library hero
  3840 × 1240 (art only), library logo 1280 × 720 (transparent). Redraw with
  `godot --path . tools/capsules.tscn`. See the artist brief below to replace
  them with commissioned art.
- AI-content survey: none. Content: no mature content.

## 7. Launch options and depots

Launch options (Installation → General):

| Name | Executable | Arguments | OS |
| --- | --- | --- | --- |
| Play | `BigHead.exe` | | Windows |
| Desktop buddy | `BigHead.exe` | `--buddy` | Windows |
| Play | `BigHead.x86_64` | | Linux |
| Desktop buddy | `BigHead.x86_64` | `--buddy` | Linux |

Depots: one for Windows, one for Linux. Builds go up with SteamPipe:
fill in `APP_ID`, `WINDOWS_DEPOT_ID` and `LINUX_DEPOT_ID` in
`steam/steampipe/*.vdf`, export both release builds into `build/`, then

    steamcmd +login <account> +run_app_build /full/path/to/steam/steampipe/app_build.vdf +quit

## 8. Multiplayer

- Install GodotSteam's MultiplayerPeer alongside GodotSteam so Steam invites
  use Steam's relay (no port forwarding). Without it, invites still work but
  fall back to a direct connection to the host's address.
- Nothing to configure in Steamworks for lobbies; they work with the App ID.

## 9. Before release

- Release builds ignore every test flag except `--buddy` (checked on the
  Linux export). Nothing to remove by hand.
- Choose which cheat codes ship: `release = true/false` in
  `scripts/core/cheat_codes.gd` (now: confetti, party and dizzy on;
  bighead, fastfaces and dropall development-only).
- Run the release checklist in Steamworks (every achievement needs an icon
  and a name).

## Capsule art: artist brief

**Game:** Big Head, a cozy gag toy: you build a bobblehead with a huge head
on a tiny body, then play with it (boop, fling, fireworks, collectables).

**Look:** flat cartoon, thick dark-brown outlines (#2a1d17), bright saturated
colors, a night sky full of fireworks. The bobblehead's head is enormous next
to its body; a spring neck; a little gold stand.

**Must have:** the title "BIG HEAD" (chunky, bouncy lettering; the
placeholders use Luckiest Guy), one big-headed bobblehead as the hero.
Optional: fireworks, a gift box, a unicorn-horn bobblehead as a nod to the
rares.

**Must not have:** any text besides the title on capsules; any real person's
face or Steam avatar; anything that reveals what happens after you press
Play (the bobblehead takes on your Steam avatar).

**Deliverables:** every size listed in section 6, plus a layered source file.
The library hero has no text and keeps its middle clear for the logo.
