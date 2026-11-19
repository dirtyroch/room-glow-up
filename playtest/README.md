# Headless playtest

Roblox Studio does not run on Linux, so this folder plays the game without it.

`World.luau` is a small fake Roblox: a clock, a task scheduler, an Instance tree,
and the services the server touches (Players, RunService, DataStoreService,
MarketplaceService, PolicyService, AnalyticsService). It loads the real
`src/server` and `src/shared` files in the same tree `default.project.json`
builds, then starts `Main.server.luau`. The fake DataStore yields like the real
one and spaces writes to one key about 6 seconds apart, the way Roblox does.

`Bots.luau` plays kids who only read replicated attributes and only call the one
Action remote: a first-timer doing the Mini Room, a returning kid, a leaver, a kid
who places nothing, a duo, a shop spammer tapping items with id 0, a kid who never
votes, and a late joiner.

```
lune run playtest/run.luau          # 56 rounds: 1, 2, 5, and 10 players, every twist
lune run playtest/run.luau --quick  # about 18 rounds, for a fast check
```

It writes `playtest/out/report.md` and `report.json` (ignored by git) and exits 1
when it finds a crash, a stuck phase, a skipped phase, a purchase window for an
id 0 item, a name on the tour, or a save that does not round-trip.

Bot stars follow each room's Theme Match plus noise, so the fairness numbers say
how the scoring math treats rooms, not how real kids vote.

## Rough players

`stress.luau` runs six short servers with harder kids: two griefers who place
one piece, press DONE, and mash Report, one-star votes, and reactions; a kid
who drops and rejoins every 25 to 70 seconds; a +60 s buyer (in the lobby,
before the rush, in the last half second of Build, and just after the tour
starts, through a test-only product id); a Speed Round with late joiners; a
duo where one partner leaves; and a 10-kid server of phones (slower taps) and
low-end clients (every call lands 0.4 to 1.4 s late).

```
lune run playtest/stress.luau [--seed N] [--only NAME] [--rounds N]
```

`--only mixed10 --rounds 24` runs just the phone server for 24 rounds, which
is the fairness check (it writes `stress-mixed10.md`). The report has, per kid
type, coins, XP, Eye coins, stars, pieces and the share of rooms they voted
on; the phone vs PC coin gap; votes and stars for tour stops 1 to 6 against
stops 7 and later; the tour length with 8 or more rooms; and votes that
crossed a stop in flight, landed on the wrong room, or were refused as late.

It writes `playtest/out/stress.md` and `stress.json` and exits 1 on a server
error, two plots for one kid, a kid twice on the tour, an honest room taken
down by reports, or a purchase window for an id 0 item.

The main playtest report also has the bank XP per round, the median minutes
to level 2, 5 (Pibble Rug) and 8 (Unc Armchair), and the projected hours to
each level up to 50.
