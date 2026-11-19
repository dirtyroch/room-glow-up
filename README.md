# Room Glow Up

Decorate a tiny room to the theme, then watch the server tour every room. Auntie Roch is always in the audience, so a solo round still has a vote. Between rounds, each player will grow a Dream Home (that loop is a later change).

The launch season is **Room Glow Up: Holiday Season**. Rounds rotate through gingerbread houses, trees, and holiday rooms. After 31 Dec 2026 (UTC) the `auto` season switch moves the server onto the winter list.

This repository is the scaffold and the round engine. Rooms, placement, scoring, the Dream Home, and the shop come later. The place file is built locally. Nothing here publishes it.

## Round

Servers hold up to 10 people. The phase lengths live in `src/shared/Config.luau`.

| Phase | Length | What happens |
|---|---|---|
| Lobby | 20 s | Waits until at least 1 player is here. A solo round is valid. |
| Theme | 5 s | The server picks the theme and shows the name. |
| Build | 240 s | Ends early once every active player has pressed DONE. |
| Tour | 8 s per room | One stop per player who is still in the round. |
| Results | 15 s | Hold, then back to the lobby. |

Someone who joins after the lobby watches until the next lobby. Someone who leaves is skipped: their room is not toured. Pressing DONE locks that player in early. When the build clock runs out, everyone who is still active is toured, whether or not they pressed DONE.

The client only asks. One `Action` remote accepts `Done` and `Hello`. Both are type-checked and rate-limited with a per-player token bucket and a tighter per-action bucket. Phase, time left, and the theme name are attributes on `RoundState`, so the phone HUD can count down without a second remote.

A private-server host can offer a theme id through `Round.setHostTheme`. That hook is not connected to the remote yet. A client cannot pick the theme, a score, or the phase.

Stars, when scoring arrives, are a flat 1 to 5. Nothing paid will roll a random reward.

## Themes

58 starter themes: 42 for Holiday Season (14 rooms, 14 gingerbread houses, 14 trees) and 16 for winter (10 rooms, 6 trees). The picker will not repeat a theme from the last 10 rounds while another choice of the needed type exists. Holiday rounds rotate room, gingerbread, tree. Winter skips gingerbread because that list has none.

The canonical list is `src/shared/Themes.luau`.

### Holiday rooms

Hearthside Parlor, Stocking Nook, Candle Window, Wreath Hall, Cocoa Corner, Mitten Mantel, Bell Choir Room, Starlight Landing, Pinecone Den, Ribbon Gallery, Holly Hearth, Nutcracker Stage, Gift Wrap Station, Carol Bench.

### Holiday gingerbread houses

Gumdrop Cottage, Icing Roof House, Candy Cane Porch, Peppermint Gate, Frosting Lane, Licorice Shutters, Sprinkle Chimney, Wafer Wall House, Marshmallow Eaves, Ginger Door House, Sugar Window Cottage, Caramel Path House, Gumdrop Garden House, Royal Icing House.

### Holiday trees

Tinsel Tree, Popcorn Garland Tree, Glass Bauble Tree, Star Topper Tree, Ribbon Spiral Tree, Pinecone Tree, Bell Strand Tree, Candle Clip Tree, Snowflake Tree, Cranberry Strand Tree, Paper Chain Tree, Mitten Ornament Tree, Gold Lantern Tree, Robin Nest Tree.

### Winter rooms

Frost Pane Parlor, Snowfort Den, Aurora Window, Icicle Porch, Quilt Lantern Nook, Mitten Mudroom, Sled Rack Hall, Thermos Cocoa Nook, Flannel Reading Nook, Snowshoe Entry.

### Winter trees

Frost Needle Tree, Ice Lantern Tree, Silver Birch Tree, Quiet Pine Tree, Crystal Icicle Tree, Wool Star Tree.

## Project layout

```
src/shared/             Config, themes, replica attribute names
src/shared/Logic/       Round, theme picker, actions, rate limiter
src/server/             Main.server, round service, action service
src/client/             Phone HUD (phase, countdown, theme, DONE)
tests/run.luau          Lune tests
scripts/build.sh        Rojo build -> RoomGlowUp.rbxlx
```

## Setup, test, and build

Tools are pinned in `rokit.toml`: Rojo 7.7.1, selene 0.32.0, Lune 0.11.1, and luau-lsp 1.70.1.

```bash
rokit install
selene generate-roblox-std
selene src
lune run tests/run
./scripts/build.sh
```

`./scripts/build.sh` writes `RoomGlowUp.rbxlx`. Open that place in Studio and use the Rojo plugin with `rojo serve` while editing. Set the server size to 10 when the place is published. This repo does not publish it.

`Config.Season` chooses the active list: `auto` (the default), `holiday`, or `winter`.

## Checks

GitHub Actions runs selene, the Lune tests, luau-lsp, and the place build. The workflow is `.github/workflows/ci.yml`.

## House rules

Names in this project are original. Players do not type text that other people see, and the game does not accept uploaded images. The action remote never trusts the client. There is no web calling from the server. Paid items, when they exist, will not have a random outcome, and the copy will not invent a sale or a countdown that is not the round clock.
