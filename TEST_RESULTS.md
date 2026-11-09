# Test results

Last run: 2026-11-09, `./scripts/ci.sh` — **ALL CHECKS PASSED**. Tools: Lune 0.11.1, Rojo 7.7.1,
Selene 0.31.0, StyLua 2.6.0. All tests run real project source under Lune (not inside Roblox).

## Executed and passing

| Check | Result |
|---|---|
| Syntax compile of every `.luau` file (`scripts/check.luau`) | 0 errors |
| Selene lint (`selene src`, custom std) | 0 errors, 0 warnings |
| StyLua format check | clean |
| Unit + integration tests (`lune run tests/run.luau`) | **50 passed, 0 failed** |
| Rojo build → `release/ChromaTurf.rbxlx` | built |
| Place verification (`scripts/verify-place.luau`: reopen .rbxlx, tree, 40 scripts compile, Lighting/Workspace/Players props) | PLACE OK |

### Tests by area

| Spec | Count | Covers |
|---|---|---|
| `grid.spec` | 11 | index math, 4-connected walk, capture/flood-fill, enclosed-trail victims, blocked cells, border loops, clear, spawn search, binary codec roundtrip, dirty tracking |
| `match.spec` | 5 | **headless 180 s round with 6 bots** (grid invariants every 10 s), player loop capture → tutorial steps → rewards, teleport/speed exploit doesn't paint, cut/shield/self-cut/respawn, bomb + dash power-ups |
| `data.spec` | 16 | defaults + session lock, lock contention, release/handoff, stale-lock takeover + lost-lock write refusal (anti-dupe), transient failures retried, total failure surfaces error w/o writes, newer-version data untouched, migrations + reconciliation, NaN/limit sanitizing, receipts exactly-once, ack-after-save, no profile, unknown product, history trim, rate limiter |
| `economy.spec` | 11 | XP curve/cap, round rewards + multipliers, daily quests distinct & deterministic, daily gift no-reset, unlock rules, buy/equip/double-buy, pass-locked items, daily claim once, achievements once, quest cap/claim once, level-up coins |
| `telemetry.spec` | 1 | analytics failures never throw into gameplay |
| `ui.spec` | 3 | runs real `Main.client.luau`; HUD, grid renderer (1,600 tiles), bot renderer, shop (5 tabs), quests, settings, results driven by simulated server messages; all properties/enums validated by Lune reflection DB |
| `world.spec` | 3 | hub, 3 arenas, podium, wins board, nametags, all 8 cosmetic FX built with validated instances |

Measured in the simulation (Lune, NOT Roblox performance): ~0.08 ms/tick match logic, ~75 B/s grid
deltas, ~610 B/s bot packets, 1,133 tiles owned at round end, 8 eliminations.

## Not executed (needs Roblox Studio / devices / account) — see KNOWN_ISSUES.md

- Play Solo / multi-client server test in Studio.
- Real DataStore, MarketplaceService purchases (test purchases), AnalyticsService ingestion.
- Physics/network ownership of eliminated (anchored) characters.
- FPS / memory on PC and mobile; MicroProfiler server tick with 12 players.
- Visual review of UI layout on phone/tablet/console; gamepad navigation.
- Audio playback of built-in sound paths.
