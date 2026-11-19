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
