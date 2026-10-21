# Big Head — Game Plan

Exported from the plan doc on 2026-10-20. This file is a snapshot; the living plan is the shared plan doc.

## Overview

Big Head is a Godot 4.6+ gag game: it turns the player into a bobblehead under a banner reading "\<name> is a Big Head" and awards the Steam achievement "Big Head". It ships in three iterations, each building on the same architecture so nothing is rewritten.

- **Company name:** the splash reads "Scapegoat A. L. LLC". The "A. L." is intentional. Store it as one constant with a do-not-correct comment, and use the same wording on the store page and Steamworks partner fields.
- **Iteration 1 (prototype):** splash, Steam identity, Head Builder, reveal with the pop, bobble physics, the "Big Head" achievement.
- **Iteration 2 (Steam release):** 2A on test app 480 (bundled GodotSteam, drag, fireworks, customization), then 2B after the App ID (Steamworks setup, Rich Presence, Steam Cloud, store page).
- **Iteration 3 (social):** friends shelf, lobbies, bobblehead interaction, leaderboard, full achievement set, room builder idea.
- **Out of scope:** AI-generated dialogue. Not planned at this point.

## Architecture

The game uses ports and adapters: scenes and core logic never call Steam directly, so iteration 3 adds friends and networking without touching the reveal.

```
Only the adapter layer talks to Steam

Scenes    Splash -> Head Builder -> Reveal -> Playground (iteration 3)
            |
Core      PlayerProfile    BobbleState     AchievementRules     (no Steam calls)
            |
Ports     IdentityPort     AchievementPort     StatsPort     NetworkPort (iteration 3)
            |
Adapters  SteamIdentity    SavedBuild    SteamAchievements    SteamStats / LocalStats    Steam lobbies (iteration 3)
```

Scenes depend on the core, the core on ports, and only adapters call GodotSteam. Steam players skip the builder after their first launch.

- **PlayerProfile** holds a name plus two optional avatars, built and Steam. The reveal reads which are set and picks its choreography.
- **IdentityPort** answers "who is playing" now and "who are my friends" in iteration 3; `get_friends()` exists from the start and returns an empty list until then.
- **Saved build** is the Head Builder's output, stored as separate layers so the Steam face can replace only the face layer.

## Iteration 1: prototype

Iteration 1 delivers the whole gag end to end on Steam test App ID 480 (Spacewar): splash, identity, builder, reveal, bobble, achievement.

### Splash

- Shows "Scapegoat A. L. LLC".
- Initializes GodotSteam during the splash, using `steam_appid.txt` (480 in development).
- Routes the player: first launch or Steam failure goes to the Head Builder; otherwise straight to the reveal.

### Steam identity

- Name from `Steam.getPersonaName()`, available immediately.
- Avatar from `Steam.getPlayerAvatar(Steam.AVATAR_LARGE)`. It arrives asynchronously through the `avatar_loaded` signal, then becomes a texture.
- The large avatar is 184 px. Design the head so a low-resolution face still looks right.

### Head Builder

- **When:** first launch for every player, then optional from a menu ("Edit my head"). Mandatory when Steam fails to start.
- **Name entry:** capped at 16 to 20 characters so the banner fits. Names stay local, so no moderation.
- **Selections:**

| Category | Options | Notes |
| --- | --- | --- |
| Face shape | 4 | round, oval, square, egg; also the mask for the Steam avatar |
| Skin tone | 6 | palette swap of one sprite |
| Hair | 5 | includes bald |
| Eyes | 4 |  |
| Mouth | 4 |  |
| Accessory | 5 | none, glasses, party hat, crown, goat horns |

- About 22 drawn assets give 9,600 combinations. Add a **Randomize** button.
- The build is saved to `user://` as separate layers, not one flattened image.
- Art rule: hair and accessories are drawn around one standard head outline so they fit every face shape.

### Reveal and the pop

The reveal picks its choreography from which avatars exist:

| Built avatar | Steam avatar | Reveal |
| --- | --- | --- |
| yes | yes | Built head bobbles, the face layer pops, the Steam face appears |
| no | yes | Steam face pops in from blank |
| yes | no | Built head only (non-Steam fallback) |

- **The pop:** squash-and-stretch on the built face, a confetti burst (`GPUParticles2D`), then the Steam face springs out with a large spring impulse.
- **After the pop:** the Steam avatar replaces only the face layer, masked to the chosen face shape. Background, hair and accessory stay.
- The pop hides the avatar's load time: the built head is on screen while the Steam avatar arrives behind it.
- Banner: "\<name> is a Big Head".

### Bobble physics

- An underdamped spring on the head's **angle** around the neck pivot (damping ratio about 0.1 to 0.3), plus a small **offset** spring for drags.
- Integrated by hand in `_physics_process` with semi-implicit Euler.
- A click adds a velocity impulse toward the cursor; the spring does the rest.

### Achievement

- Steam players: `setAchievement("BIG_HEAD")` then `storeStats()` when the reveal finishes.
- Non-Steam players: no achievement and no toast.

## Iteration 2A: before the App ID

Iteration 2A builds everything on test app 480; the App ID only changes configuration afterwards. Status: built, tested, and pushed to GitHub on 2026-10-18, except bundling GodotSteam, which happens on David's machine (below).

### Steam plumbing

- **Bundle GodotSteam:** commit `addons/godotsteam` with both Steam libraries (`libsteam_api.so`, `steam_api64.dll`), pinned to one release that matches the Godot version. Clones and exports run with Steam with no install step. Nothing installs at runtime, since GDExtensions load only at engine startup. GodotSteam's downloads moved to Codeberg, which the build session can't reach, so David installs it from AssetLib once and commits the folder.
- **Stats port:** a `StatsPort` beside `AchievementPort` for persistent counters (clicks, fireworks launched).
- **Dev mappings:** up to four achievements map onto Spacewar's test achievements; the rest log to the console.
- **Export presets:** Linux and Windows. The Windows build is exported from Fedora and tested under Proton.

### Interaction

- **Drag:** a hold that moves past about 8 px becomes a drag; a quick press stays a click nudge. The head is pulled through the offset spring (stretched, not teleported), and mouse velocity on release goes into both springs. Iteration 1 testing confirmed click-and-hold currently acts as one click.
- **Fireworks:** right-click launches rockets at the cursor (CPU particles, which look the same on every renderer and GPU). Each click launches one rocket of your own plus one per Steam friend who has the Big Head achievement.
- **Friend lookup:** at startup the game requests each friend's stats once and caches who has Big Head, never per click. On 480 this would count a Spacewar achievement, so a `--fake-friends N` flag stands in until 2B.

### Customization

- **Head size slider:** about 80% to 150%, saved with the build, clamped so a maxed head with a party hat clears the banner. Maxing it unlocks Swelled Head.
- **Background:** pick a preset or upload an image.
- **Body:** shapes (suit, hoodie, t-shirt, robe, goat body) and a color picker.
- **Body texture upload:** maps onto the drawn body the way the Steam face maps onto the face shape. Ships with a body template PNG showing the layout, for designing in Krita or GIMP.
- **Banner:** text color, banner color, and font from a bundled set of open-licensed fonts.
- **Upload handling:** files are copied into `user://` and downscaled to about 2048 px. The native file picker goes through the desktop portal on Fedora, so it works with Flatpak Godot too.
- **Uploads stay local:** in iteration 3, friends see your preset body and background, not uploaded images, unless moderation or Steam Workshop is added later.

## Iteration 2B: after the App ID

Iteration 2B is configuration and store work; the only code change is removing the dev mappings.

- Pay the Steam Direct fee; replace 480 with the App ID and empty the dev mappings.
- Define every achievement, stat and icon in Steamworks, including It's a Party.
- Friend lookups become meaningful: friends who own Big Head and earned the achievement.
- **Rich Presence:** a localization file with "Being a Big Head"; friends only see it under your own App ID.
- **Steam Cloud:** sync the saved head and uploaded images across machines.
- Store page, capsule art, screenshots, AI-content survey (none), and build uploads.

### Store page assets

Steam requires these before the store page goes up ([Steamworks: store assets](https://partner.steamgames.com/doc/store/assets/standard), [library assets](https://partner.steamgames.com/doc/store/assets)):

| Asset | Size (px) | Notes |
| --- | --- | --- |
| Header capsule | 920 × 430 | Title only, no other text |
| Small capsule | 462 × 174 | Logo should nearly fill it |
| Main capsule | 1232 × 706 | Title only |
| Vertical capsule | 748 × 896 | Title only |
| Screenshots | 1920 × 1080 or larger, 16:9 | At least 5, gameplay only; mark at least 4 suitable for all ages |
| Library capsule | 600 × 900 | Logo and artwork |
| Library hero | 3840 × 1240 | Artwork only, PNG |
| Library logo | 1280 wide and/or 720 tall | PNG, shown over the hero |
| Library header | 920 × 430 |  |

Screenshots can be rendered straight from the game at 1920 × 1080 with the same scripted capture used for testing. Also needed: a short description, the About section, tags, and the AI-content survey (none).

## Iteration 3: social

Iteration 3 adds friends, in order of cost: local first, networked second.

1. **Friends shelf** (no networking): friends' Steam avatars as bobbleheads on a shelf, read locally through `get_friends()`.
2. **Lobby playground:** friends' heads share one screen over Steam lobbies and Steam Networking Sockets (relayed, no port forwarding).
3. **Interaction:** flick, drag and boop each other's heads; head-to-head collisions; firework duels.
4. **"Big Head Off":** longest bobble from one flick, posted to a Steam leaderboard.
5. **Cosmetics:** more builder hats, bodies and banners; Steam Workshop for player-made hats later.

**Room builder (idea):** the background becomes a room players furnish, with furniture they build or trade.

- Trading between players means Steam Inventory Service: item definitions, tradable flags, and possibly Steam Market listings. That needs the App ID and Valve setup, and tradable items with market value bring fraud and regulatory questions.
- A lighter first version: furniture unlocked through play and achievements, with trading added later.
- Open question: does the room replace the uploaded background, or sit on top of it?

Non-Steam players stay single-player: multiplayer requires Steam, so built-only heads never go online.

## Backlog: collection, rigs and desktop buddy

Decided on 2026-10-20 and not yet slotted into an iteration: almost everything is earned through play, nothing is traded, and the bobblehead gains new rigs and a desktop mode.

### Catalog and drops

- **Data catalog:** every item has an id, slot, base shape, variant, rarity and unlock source. A new `InventoryPort` with a `LocalInventory` adapter holds what the player owns; no trading means it stays local.
- **Starting set:** two options each of hair style, face shape, eyes, mouth and body variant. Everything else is unlocked through play.
- **Free color pickers:** hair color and skin color only. Bodies come from unlocked variants or the player's own uploaded texture.
- **Variants:** four per accessory base and per body base. New accessory: **wizard hat**.
- **Drop roll:** one roll per click (not per rocket), so the friend multiplier doesn't multiply drops.
- **Duplicates:** a drop picks from the whole regular pool. An item the player already owns bursts into confetti; a new item falls as a gift box the player clicks to pick up. Gift boxes stay on screen until the game shuts down; a box left unclicked at quit is lost, by design. New items get rarer as the collection grows (the coupon collector effect).
- **No pity timer.** Super-rares are on their own separate roll, out of the regular pool. Simulated: the regular collection finishes in about 280 drops for a typical player; with super-rares mixed in it would take about 1,300.
- **Other unlock sources:** achievements (Grand Finale awards a gold crown variant), stat milestones, and multiplayer moments.

### Unicorn set (super-rare)

- Unicorn head (a face shape with muzzle and ears), rainbow hair, and a unicorn body with a rainbow tail.
- **Unicorn horn** is a hat accessory with four variants: one can drop in single player; the other three only drop in multiplayer and are the rarest drops in the game.

### Rigs (unlockable)

- **Bobble:** today's spring neck.
- **Balloon:** the head floats on a string tied to the body, using a rope simulation and buoyancy; drag pulls the string taut, release lets it bob back up. A right-click near it pops it, then it reinflates.
- **Marionette:** a control bar above with strings to the arms; the player drags the bar and the head ragdolls with the motion.
- **Arms on every people body:** sleeves matching the body (suit, hoodie, robe), short sleeves with bare arms for the T-shirt. They stay still on the bobble rig and carry the strings on the marionette rig. Animal bodies have no arms: the goat and the unicorn both stand on four legs. Arms and legs are part of the body template, so uploaded textures cover them too, and a blank template (outlines only) is also downloadable to make painting arms easier.
- The head layers draw the same on every rig; only what moves them changes.

### Face and reveal

- **Reset face to default:** a button that puts the Steam avatar back as the face, replacing whatever face variant is set. Without Steam, it returns to the built face.
- **Reveal pop** plays on first launch, and again only when triggered: a "Replay reveal" button in the playground, and automatically after "Reset face" (trying this to see how it feels). Returning from Customize goes straight to the playground.

### Desktop buddy (single player)

- A small transparent window on the desktop; clicks pass through everywhere except the bobblehead, which can still be clicked, dragged and fire fireworks.
- Eyes follow the cursor anywhere on Windows and X11. On Wayland (including KDE on Kinoite) they follow it only near the buddy, because Wayland blocks reading the cursor elsewhere.
- No global click hooks: the buddy never watches input in other apps.

### Shared custom accessories (not planned)

Uploads stay local. If sharing is ever wanted: friends in a live session send the PNG plus slot JSON peer to peer, keyed by a content hash; sharing beyond friends goes through Steam Workshop, which brings hosting, reporting and takedowns. Either way: size limits, defensive image decoding, metadata stripped, off for non-friends by default, per-player mute. AI-generated accessories would also fall under Steam's AI-content disclosure rules.

### Trading (not planned)

Ruled out. It would move the inventory to Steam Inventory Service, conflict with duplicates becoming confetti, attach real-money value that invites scams and support load, and let players buy rarity instead of earning it.

## Achievements

Only "Big Head" ships in iteration 1; the rest are candidates for iterations 2 and 3.

| Achievement | Trigger | Iteration |
| --- | --- | --- |
| Big Head | Finish the reveal (first launch) | 1 |
| Whiplash | Drag the head past a speed threshold | 2A |
| Perpetual Motion | Keep it bobbling for 60 seconds | 2A |
| Bobble Boop | Click the head 100 times | 2A |
| Ooh, Aah | Launch 50 fireworks in total | 2A |
| It's a Party | 5 rockets in one right-click (you plus 4 friends with Big Head) | 2A |
| Grand Finale | 20 rockets in one right-click (you plus 19 friends with Big Head); awards a gold crown variant | 2A |
| Level-Headed | Leave it completely still for 5 minutes | 2A |
| Swelled Head | Max out the head-size slider | 2A |
| Pop Goes the Head | Pop the balloon head | Backlog (rigs) |
| Head Count | 5 friends on the shelf | 3 |
| Big Heads Think Alike | Join a lobby with a friend | 3 |
| Head-to-Head | Collide with a friend's bobblehead | 3 |

## Risks and decisions

### Gotchas

- **Low-resolution avatar:** 184 px at most. The face-shape mask, hair and accessories carry the visual quality.
- **Asynchronous avatar:** never assume it is loaded; the pop covers the wait.
- **Overlay in the editor:** the Steam overlay does not show when running from the editor with the Forward+ renderer. Test achievement popups in an exported build or with the Compatibility renderer.
- **Version coupling:** GodotSteam versions track Steamworks SDK versions. Pin one and upgrade deliberately.
- **Name "correction":** "A. L." looks like a typo to reviewers and tools. Keep the do-not-correct comment.

### Decisions log

| Decision | Choice |
| --- | --- |
| Splash name | "Scapegoat A. L. LLC", intentional |
| Identity source | GodotSteam in-client SDK, not the Steam Web API |
| Steam failure | Fallback to the Head Builder |
| Builder access | First launch, then optional from a menu |
| Steam players and the builder | They build a head; the Steam avatar pops out and replaces the face layer |
| What survives the pop | Background, hair, accessory; face shape becomes the avatar mask |
| Non-Steam achievement | None, no toast |
| Bobble model | Angle spring at the neck plus an offset spring for drags |
| AI dialogue | Not planned |
| Iteration 2 split | 2A before the App ID on test app 480; 2B after |
| GodotSteam | Bundled in the repo, never installed at runtime |
| Fireworks | Right-click; one extra rocket per friend with Big Head |
| Grand Finale | 19 friends (20 rockets) |
| It's a Party | 4 friends (5 rockets) |
| Swelled Head | In 2A, with a head-size slider |
| Body texture | Upload with a template, not in-game painting |
| Uploaded images | Local only; not shown to friends |
| Banner | Custom colors and bundled fonts |
| Platforms | Linux and Windows |
| Color pickers | Hair and skin only; body color comes from unlocked variants or an upload |
| Starting set | Two options each of hair, face shape, eyes, mouth, body variant |
| Variants | Four per accessory and body base; wizard hat added |
| Drops | One roll per click; duplicates burst into confetti, new items fall as a gift box |
| Pity timer | None |
| Super-rares | Separate roll, out of the regular pool |
| Unicorn horn | Hat accessory, four variants: one single-player, three multiplayer-only and rarest |
| Trading | Not planned |
| Shared custom accessories | Not planned; uploads stay local |
| Rigs | Bobble, Balloon, Marionette; unlockable |
| Arms | People bodies only, matching the clothes; animals (goat, unicorn) have four legs instead; part of the body template, plus a blank template |
| Reveal | Plays on first launch, then via a Replay reveal button and after Reset face |
| Reset face | Button restores the Steam avatar as the face |
| Desktop buddy | In; no global click hooks |

### Sources

- [GodotSteam: Avatars tutorial](https://godotsteam.com/tutorials/avatars/)
- [GodotSteamKit: Avatars](https://godotsteam.com/tutorials/godotsteamkit/avatars/)
- [GodotSteam on GitHub](https://github.com/Gramps/GodotSteam)
