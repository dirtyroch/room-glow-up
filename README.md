# Room Glow Up

Players decorate a tiny room to a theme against the clock. The server then tours every submitted room. Between rounds, each player will grow a Dream Home (later milestones). This launch is **Room Glow Up: Holiday Season**. After December 31 the theme pool switches to winter.

Auntie Roch, the NPC critic, adds one vote, so a solo round still has a judge. A server holds up to 10 players.

This milestone is the project scaffold and the round engine. Rooms, placement, voting, and the shop come later. The place file is built locally and is not published.

## Round

| Phase | Length | What happens |
| --- | --- | --- |
| Lobby | 20s | Waits until at least 1 player is here. The timer starts when someone arrives and resets if the lobby empties. |
| Theme | 5s | The theme is shown. |
| Build | 240s | Ends early when every active player has pressed DONE. |
| Tour | 8s per submitted room | Rooms from players who left are skipped. A round with no DONE still passes through Tour. |
| Results | 15s | Then back to Lobby. |

Someone who joins after Lobby spectates until the next Lobby. Phase, time left, theme, and season are replicated with attributes on `ReplicatedStorage.RoundState`. The only client remote is `Remotes.Action`. Requests are type-checked and rate-limited. The client is not trusted.

`RoundService.setHostTheme` is the hook for a private-server host to choose the next theme. It is not wired to a remote yet.

## Themes

`Config.Season` is `auto`, `holiday`, or `winter`. Auto is Holiday Season in November and December, then winter after December 31 (Central time). Holiday rounds rotate room, gingerbread, then tree. The picker skips themes used in the last 10 rounds when it still has another choice.

Holiday rooms: Cocoa Hearth, Stocking Mantel, Nutcracker Nook, Snow Globe Parlor, Ribbon Window Seat, Carol Piano Corner, Sleigh Bell Entry, Starlight Reading Nook.

Holiday gingerbread: Gumdrop Gable, Icing Shingle Cottage, Candy Cane Porch, Sprinkle Chimney, Licorice Lane House, Frosting Drip Roof, Peppermint Doorway, Ginger Wall Bake.

Holiday trees: Tinsel Topper, Popcorn Garland, Paper Star Tree, Bauble Burst, Ribbon Spiral, Bell Branch, Snowflake Ladder, Cranberry Strand.

Winter rooms: Frosted Window, Knit Blanket Fort, Lantern Mudroom, Snowfall Sunroom, Pinecone Shelf, Ice Crystal Hall, Flannel Reading Corner, Thermos Table, Quilted Window, Birch Log Den.

Winter trees: Frosted Fir, Ice Lantern Spruce, Silver Cone, Quiet Snow Pine, Blue Glass Branches, Wool Pom Pine, Cedar Candle Tree, Birch White Tree.

## Look

Shared tokens live in `src/shared/UIKit.luau` (palette, type sizes, button styles, motion). The HUD uses them: cream, coral, mint, butter, and lavender, with dark ink text, chunky rounded shapes, a large countdown, and a DONE button along the bottom inside the safe area. The board pops when the phase changes. Theme reveal shows a short butter banner.

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
src/shared/     Config, Themes, UIKit, Logic (season, themes, rounds, actions)
src/server/     Main.server, Boot, ActionService, RoundService
src/client/     Main.client, Net, UI, Hud
tests/run.luau  Lune tests for the round loop
```
