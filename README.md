# Room Glow Up

Players decorate a tiny room to a theme against the clock. The server then tours every submitted room. Between rounds, each player will grow a Dream Home (later milestones). This launch is **Room Glow Up: Holiday Season**. After December 31 the theme pool switches to winter.

Auntie Roch, the NPC critic, adds one vote, so a solo round still has a judge. A server holds up to 10 players.

This milestone adds the shop, codes, and Family Night private servers. The place file is built locally and is not published.

## Round

| Phase | Length | What happens |
| --- | --- | --- |
| Lobby | 20s | Waits until at least 1 player is here. The timer starts when someone arrives and resets if the lobby empties. |
| Theme | 5s | The theme is shown. |
| Build | 240s | Ends early when every active player has pressed DONE. When 60% of the builders who placed are done, or all but one of them, the server cuts the rest to 30 seconds and shows "30 seconds left!". Idle and empty builders are not in that count. When the timer ends, every active room that has props is submitted too. |
| Tour | about 10s of voting per room | The camera, spotlight, sting, and crowd emoji follow the server tour index, plot, and label. The tour order is shuffled on the server. The visual lock is the last second, and votes are still accepted for that second. Once everyone who can vote has voted, the server moves on. Rooms from players who left are skipped. A round with nothing to show still passes through Tour. |
| Results | 30s | The podium and Auntie Roch first. At 10 seconds the rewards card and Spot the Theme show, with the podium still first. Then back to Lobby. |

Someone who joins during Build with at least 60 seconds left gets a room and plays the shortened build. Anyone else who joins after Lobby can vote on the tour and, while they wait, do the Mini Room or a free-decorate sandbox. A countdown shows when the next round starts. Names stay off the tour. Phase, time left, theme, and season are replicated with attributes on `ReplicatedStorage.RoundState`. The only client remote is `Remotes.Action`. Requests are type-checked and rate-limited. The client is not trusted.

`RoundService.setHostTheme` is the Family Night hook. Only the private-server owner can set it, and only to a theme on the server allowlist.

## Themes

`Config.Season` is `auto`, `holiday`, or `winter`. Auto is Holiday Season in November and December, then winter after December 31 (Central time). Holiday rounds rotate room, gingerbread, then tree. The picker skips themes used in the last 10 rounds when it still has another choice.

Holiday rooms: Cocoa Hearth, Stocking Mantel, Nutcracker Nook, Snow Globe Parlor, Ribbon Window Seat, Carol Piano Corner, Sleigh Bell Entry, Starlight Reading Nook.

Holiday gingerbread: Gumdrop Gable, Icing Shingle Cottage, Candy Cane Porch, Sprinkle Chimney, Licorice Lane House, Frosting Drip Roof, Peppermint Doorway, Ginger Wall Bake.

Holiday trees: Tinsel Topper, Popcorn Garland, Paper Star Tree, Bauble Burst, Ribbon Spiral, Bell Branch, Snowflake Ladder, Cranberry Strand.

Winter rooms: Frosted Window, Knit Blanket Fort, Lantern Mudroom, Snowfall Sunroom, Pinecone Shelf, Ice Crystal Hall, Flannel Reading Corner, Thermos Table, Quilted Window, Birch Log Den.

Winter trees: Frosted Fir, Ice Lantern Spruce, Silver Cone, Quiet Snow Pine, Blue Glass Branches, Wool Pom Pine, Cedar Candle Tree, Birch White Tree.

## Plots

Ten plots stand in two rows. A player gets one on join and gives it back on leave. The lowest free number is reused. Each round type shows its own shell: a small room (floor grid and back wall), a gingerbread house (wall and roof pads), or a tree with 12 ornament hooks.

## Placement

During Build, an active player taps a prop in the bottom tray, then taps or drags it onto the grid. Rotate, a palette recolor, delete, and undo sit on that same tray. Mouse, keyboard, and gamepad drive the same cursor. Spectators cannot place, spend, or change the meter.

Gingerbread uses the candy and icing pieces only. There is no freehand draw. Tree ornaments snap to hooks. The server checks the cell, the turn, the item cap (16), and the coin budget (128). Place has its own rate bucket, wider than the other actions.

Props pop in with a short scale tween, a sound, and a few sparkles.

## Props

134 original chunky props (four of them, a coffee bar, sink counter, retro fridge, and retro stove, make up the Kitchen category), built a little larger than life (1.2x) so they read on a phone. Eight of them are cheap 2-cell rugs and accents so a room can look full. Two of them are free jokes: a pit-bull rug and a recliner with a remote and reading glasses. Each one has a category, a coin cost, and tags for a round type and the theme ids. The tray shows a picture of the real prop, a price, and a star when it fits the theme. Category chips are at least 44px, and item names are at least 16px on a 420px-wide phone. Low-end devices get a colored silhouette instead of the live preview. The tray, the Theme Match meter, and the coin budget sit in their own bands so they do not cover the top board, the theme reveal, or the DONE button, including on screens under 520px tall.

## Voting

During Tour, everyone except the room's owner can give 1 to 5 stars. Spectators can vote. A vote can change until one second after the visual lock, and it goes through the same rate-limited Action remote as every other request. With 5 or more votes, the highest and lowest star are dropped before the average. A fixed set of emoji reactions is rate-limited and is not a vote. The Judge's Eye streak counts rooms in a row.

Auntie Roch adds one vote from Theme Match, item variety, and how full the room is, plus one friendly line from a preset list for that star band. A solo round still has her vote. Players whose stars land within 1 of the final average earn Judge's Eye coins. A player with no room earns a smaller purse, capped, so building pays more. At Results the server turns those coins into real coins. It never reads the EyeCoins attribute.

Report targets the room on stage, not a username. The room leaves the round after reports from at least 3 different players, or half of the people who can vote, whichever is higher. Votes for a room whose owner left are ignored. In a duo room the partner is not an eligible voter and cannot report that room.

Owner names stay off the plot signs, the tour HUD, and the photo card through Tour and Results. The podium is where the names and avatars come back. The polaroid card shows the theme, the stars, and Auntie Roch's line.

## Saves

Profiles are schema version 1, keyed by UserId, with the dream home in its own store (`RoomGlowDream_v1`) so a lobby wipe of the plots cannot erase it. One session holds the lock. Writes retry with backoff. The server saves on leave and on shutdown (`BindToClose`). It does not save during Tour. The profile is written after Results settles.

## Levels and rewards

Coins and XP are granted once per round id, from placement, star average, podium finish, and the Judge's Eye purse. Levels run from 1 to 50. A fresh player owns 40 items, enough to furnish a room. Later levels unlock the rest in a fixed order, and the tray shows locked pieces greyed out with the level they open.

## Dream home

From the lobby a player can visit their dream home. It reuses placement with no budget and only owned items. The shell grows from a studio to a loft at level 15 and a two-storey house at level 30. Up to 3 Lookbook snapshots keep their best contest rooms. A coin multiplier, extra home slots, and a server luck flag are filled in by the shop. Luck adds a flat coin bonus. Extra slots never raise the 36-piece cap.

## Duo

A lobby toggle pairs two opted-in players, such as siblings, into one wider room with a shared budget of 1.5x. Both can place. Neither can vote or report that room, and the partner does not count as an eligible voter.

## Collections, quests, and rank

A theme stamp is earned at 4 stars or better, with a bonus for finishing a season set. Three daily quests are fixed by the Central date and can be finished in about 3 to 4 rounds. Designer Rank is a monthly track. Points do not decay, and the month is not the holiday or winter theme season.

## Shop

One catalog in `Config.Shop`. Every pass and product id starts at 0, and an id of 0 never opens a purchase prompt. `scripts/create-shop.luau` is a dry run until you pass a universe id and `--apply`. It does not publish the place.

| Item | Kind | Price |
| --- | --- | --- |
| VIP | Pass | 399 |
| Designer Tools | Pass | 249 |
| 2x Coins | Pass | 199 |
| Hearth Style Pack | Product | 149 |
| Gingerbread Style Pack | Product | 199 |
| Winter Style Pack | Product | 249 |
| Glow Style Pack | Product | 299 |
| Carol Piano | Product | 79 |
| Nutcracker Portrait | Product | 49 |
| Lavender Settee | Product | 99 |
| Quilt Table | Product | 69 |
| +60 Seconds | Product | 49 |
| Decor Crate | Product | 99 |
| Decor Rain | Product | 129 |
| Theme Hint | Product | 29 |
| Design Pass | Product | 349 |
| Dream Nook | Product | 99 |
| Dream Wing | Product | 179 |

VIP draws a butter frame in the lobby only. It is hidden during Tour, and it does not put a name on the plot. Designer Tools recolor the floor, wall, roof, and hooks, and set a material. Style packs and single pieces are shown in full before the buy button. +60 seconds is for the whole server, twice per round. During a Speed Round that purchase is refused and pays coins instead, so it does not stretch the shorter clock. 2x Coins uses the coin multiplier and does not stack. The Design Pass is a 30-day track beside the level unlocks. Dream Nook adds one home. Dream Wing adds two. Both go through `extraDreamSlots` and leave the 36-piece cap alone.

Decor Crate odds are on the card before purchase. The server rolls after the receipt. A duplicate becomes coins, once per receipt. `PolicyService:ArePaidRandomItemsRestricted` is checked per player. Restricted players get a fixed set, and a failed policy check does not open a prompt. Decor Rain is a server luck event. It changes crate odds and the coin bonus. The buyer's name is announced in the lobby only.

Theme Hint lists pieces that fit the theme. The theme name stays on the board without it.

`ProcessReceipt` records the purchase id and saves that profile before the grant is shown. The same id does not grant twice. A session whose save did not load cannot buy or be granted. Pass ownership is `UserOwnsGamePassAsync` on the server.

The shop has Boosts, Decor, and Passes. It is open in the lobby, including crate opens. It uses the UI kit and fits a 420px-tall phone. Nothing in the shop is a countdown or a sale label. Stars, votes, and a bigger contest room are not for sale.

## Codes

`WELCOME` grants coins. `GLOWUP` grants the sleigh bell. The server redeems each code once per player, saves it, and rate-limits attempts.

## Family Night

Private servers are free. The owner picks the next theme from `Config.Shop.HostThemes` and can turn Duo on for everyone in the lobby. A public server and anyone who is not the owner are refused. A theme that exists but is not on the list is refused.

## First minute

A first visit gets a 30-second Mini Room. One big button places a rug, and Skip is always there. By 25 seconds Auntie Roch shows a warm 4-star practice line. That line is not a ballot, a payout, or a stat. A player who already finished or skipped it goes straight into the lobby.

## Round modifiers

About one round in three, the server picks Speed Round, Tiny Budget, Mystery Item, or Mirror Duo and announces it at Theme Reveal. Speed Round shortens Build. Tiny Budget stays high enough for a new player to place a starter piece. Mystery Item is one free piece from a fixed list, not a paid roll. Mirror Duo pairs the room and keeps names off the tour.

## Spot the Theme

During the Results wait, after the podium is up, a skippable three-choice guess pays a few coins. It does not sell extra time, and it does not cover the podium names.

## Juice and low-end

Placing a prop, the star reveal, the podium, and a level-up each play a sound or a world particle. A mute button and a volume attribute scale them. Nothing in that set is parented to the HUD. Low-end can turn on from a quiet quality setting or from the toggle. It cuts particles and uses a lighter tour for a full server of 10 rooms. The 16-item contest cap and the 36-piece dream cap stay where they are.

## Easter eggs

The Pibble Rug and the Unc Armchair are original props. Place enough rugs or seats, or reach the unlock level, and they are yours. They are not crate-only. Each one has its own Auntie Roch line when it is in the room. Her stars do not change.

## Store page

`docs/store-assets.md` has the icon concept, three thumbnail concepts, Party & Casual description copy, and the image sizes the experience page asks for.

## Look

Shared tokens live in `src/shared/UIKit.luau` (palette, type sizes, button styles, motion). The HUD uses them: cream, coral, mint, butter, and lavender, with dark ink text, chunky rounded shapes, a large countdown, and a DONE button along the bottom inside the safe area. The board pops when the phase changes. Theme reveal shows a short butter banner. Phone text stays at 18px or larger. Star marks use one filled and one open glyph.

Props are multi-part models (cylinders, balls, wedges, and small trims) inside a 3 to 10 part budget. Ids, prices, and footprints stay the same. Each style pack has its own pastel and accent. Rooms add baseboards, crown trim, a glass window, and a soft light. Floors mix wood and fabric. `src/shared/Look.luau` holds a light preset for each theme family: warm hearth, gingerbread, glow, winter, and frost.

The lobby is a pastel plaza with the Auntie Roch booth, a three-place stage, the game sign, and two photo spots. Names are written on the stage plates only during Results. The tour adds a light cone, a rising star, and confetti in the theme colors. Bloom, color grade, atmosphere, and Future lighting run in the lobby and on tour. Low-end turns those off.

### Furniture meshes

36 floor items have a Blender mesh with PBR maps (color, normal, roughness, and metalness where needed): the round-1 set plus the pieces that sit next to them (window candle, stools, star pillow, poufs, four rugs, rocker, reading chair, birch side table, entry bench, berry pot, and a softer fern). Each one is 0.8k to 11k triangles with 1024 px textures and lives in `assets/meshes/<itemId>/` (FBX, maps, `meta.json`, plus `assets/meshes/manifest.json`). The color map's alpha is a tint mask, so the palette and recolor tint only fabric and paint while wood, metal, and glass keep their own colors.

`src/shared/Meshes.luau` lists each mesh's size, center, and asset ids. `src/server/MeshProps.luau` swaps in a MeshPart with a SurfaceAppearance only when an item's model and color ids are non-zero, or when a template exists at `ServerStorage.MeshTemplates.<itemId>`. If the ids are 0 or a load fails, the item uses the part builder. Hitboxes, footprints, and the placement grid do not change.

Finish (Designer Tools) also changes meshes. `MeshFit.Finishes` gives each finish a tint shift and a roughness/metalness map: Fabric keeps the baked look, Wood is satin and warmer, Metal is low-roughness with metalness on the tinted parts, Glass is a pale high gloss, and Slate is matte and grey. The maps are 256 px files next to each mesh (`rough_satin`, `rough_metal` + `metal_metal`, `rough_gloss`, `rough_matte`). In Studio you can also save them as `Finish_<Name>` SurfaceAppearances under each template.

### Room shell

`src/server/ShellDress.luau` dresses every room: wainscot boards with raised panels and a chair rail, a window with a curtain rod and pleated curtains (`assets/shell/curtains`, part fallback otherwise), and floor and wall surfaces chosen per theme family by `Look.ShellStyles` (hearth: planks and stripe; ginger: planks and plaster; winter: carpet; glow: carpet and sprig; frost: tile and sprig). Theme pack tint and Designer Tools paint still set the colors; the textures are light and neutral so they take the tint.

Each surface (`assets/surfaces/<key>/`: color, normal, roughness, tileable 1024 px) is used in this order:
1. a MaterialVariant in MaterialService named `RGU Planks`, `RGU Tile`, `RGU Carpet`, `RGU Plaster`, `RGU Stripe`, or `RGU Sprig` (base materials WoodPlanks, CeramicTiles, Carpet, Plaster). Import the maps once in Studio with the stud size from `assets/surfaces/surfaces.json`.
2. a Texture overlay if the surface's image ids are set in `Meshes.luau`.
3. the built-in material (WoodPlanks, CeramicTiles, Carpet, Plaster) plus stripe parts.

To rebuild: `bash tools/meshes/run_all.sh` (Blender 4.2, `BLENDER=/path/to/blender`). It also runs `finishes.py`, `surfaces.py`, and `manifest.py`.

To upload: `lune run scripts/upload-meshes` is a dry run that lists the files (meshes, finish maps, the curtain mesh, and the surface textures). `lune run scripts/upload-meshes --apply --user <id>` (or `--group <id>`) needs `ROBLOX_OPEN_CLOUD_KEY` with asset write scope. It uploads the FBX as a Model and the maps as Images, then writes the ids into `Meshes.luau`. Building SurfaceAppearances from ids needs `AssetService:CreateSurfaceAppearanceAsync`. The surest path is to import the FBX and maps in Studio once and save them as `ServerStorage.MeshTemplates`.

Renders: `docs/renders/mesh-heroes-sheet.png`, `mesh-hearth-compare.png`, `mesh-kitchen-compare.png`, `mesh-showroom-close.png`, and round 2: `r2-kitchen-compare.jpg`, `r2-hearth-compare.jpg`, `r2-showroom-close-compare.jpg`, `r2-shell-nook-frost.jpg`, `r2-finish-sheet.jpg`, `r2-heroes-sheet.jpg`.

## Renders

```bash
python3 scripts/render_scenes.py
```

That writes approximate PNGs under `docs/renders/` plus a 512×512 icon and a 1920×1080 thumbnail. It does not upload anything.

## Setup

Tools are pinned in `rokit.toml` to the same versions as the other place project: Rojo 7.7.1, selene 0.32.0, Lune 0.11.1, luau-lsp 1.70.1.

```bash
rokit install
rojo serve
```

Connect the Rojo plugin in Studio to sync `src/` into the place. `default.project.json` sets the player cap to 10.

## Test

```bash
lune run tests/run.luau
selene generate-roblox-std
selene src
```

## Build

```bash
./scripts/build.sh
```

That writes `RoomGlowUp.rbxlx` next to the project file. It does not upload the place.

## Layout

```
src/shared/     Config, Themes, Items, Bases, UIKit, Look, Logic, Meshes, MeshFit
src/server/     Main.server, Boot, Props, MeshProps, ShellDress, Plaza, ActionService, PlotService, RoomService, VoteService, ProgressService, SaveService, RoundService, ShopService, FunnelService
src/client/     Main.client, Net, UI, Hud, Tray, Place, TourCam, Show, Vote, Home, Shop, Juice, Settings, Tutorial, SpotGame, Listen, Stage, Podium
scripts/        build.sh, create-shop.luau, render_scenes.py
docs/           store-assets.md, renders/
tests/run.luau  Lune tests for rounds, plots, placement, voting, saves, progression, the shop, and the polish pass
```
