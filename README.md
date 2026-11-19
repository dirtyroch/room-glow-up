# Room Glow Up

Players decorate a tiny room to a theme against the clock. The server then tours every submitted room. Between rounds, each player will grow a Dream Home (later milestones). This launch is **Room Glow Up: Holiday Season**. After December 31 the theme pool switches to winter.

Auntie Roch, the NPC critic, adds one vote, so a solo round still has a judge. A server holds up to 10 players.

This milestone adds the plots and phone-first placement. Voting and the shop come later. The place file is built locally and is not published.

## Round

| Phase | Length | What happens |
| --- | --- | --- |
| Lobby | 20s | Waits until at least 1 player is here. The timer starts when someone arrives and resets if the lobby empties. |
| Theme | 5s | The theme is shown. |
| Build | 240s | Ends early when every active player has pressed DONE. When the timer ends, every active room that has props is submitted too. |
| Tour | 8s per submitted room | The camera moves from the server tour index and label. Rooms from players who left are skipped. A round with nothing to show still passes through Tour. |
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

## Plots

Ten plots stand in two rows. A player gets one on join and gives it back on leave. The lowest free number is reused. Each round type shows its own shell: a small room (floor grid and back wall), a gingerbread house (wall and roof pads), or a tree with 12 ornament hooks.

## Placement

During Build, an active player taps a prop in the bottom tray, then taps or drags it onto the grid. Rotate, a palette recolor, delete, and undo sit on that same tray. Mouse, keyboard, and gamepad drive the same cursor. Spectators cannot place, spend, or change the meter.

Gingerbread uses the candy and icing pieces only. There is no freehand draw. Tree ornaments snap to hooks. The server checks the cell, the turn, the item cap (16), and the coin budget (96). Place has its own rate bucket, wider than the other actions.

Props pop in with a short scale tween, a sound, and a few sparkles.

## Props

120 original chunky props, built a little larger than life (1.2x) so they read on a phone. Each one has a category, a coin cost, and tags for a round type and the theme ids. The tray, the Theme Match meter, and the coin budget sit in their own bands so they do not cover the top board, the theme reveal, or the DONE button, including on screens under 520px tall.

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
src/shared/     Config, Themes, Items, Bases, UIKit, Logic
src/server/     Main.server, Boot, Props, ActionService, PlotService, RoomService, RoundService
src/client/     Main.client, Net, UI, Hud, Tray, Place, TourCam, Juice
tests/run.luau  Lune tests for rounds, plots, and placement
```
