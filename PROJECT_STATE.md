# Project state — Chroma Turf

**Version:** 1.0.0 candidate · **Updated:** 2026-11-09 · **Branch:** `ccr-a1e0dedd-9nsle4`

## Resume here

1. `./scripts/ci.sh` must pass (syntax, lint, format, 50 tests, build, place verify).
2. Read KNOWN_ISSUES.md (top item: never run inside Roblox Studio yet).
3. Next human step: open `release/ChromaTurf.rbxlx` in Studio and run the QA list in docs/PUBLISHING.md.

## Status by acceptance criterion

| Criterion | IMPLEMENTED | TESTED (outside Studio) | Notes |
|---|---|---|---|
| Core mechanic works | yes | yes — headless round sim + rule tests | in-Studio feel untested |
| Progression integrated | yes | yes | levels, quests, gift, achievements |
| Initial content | yes | yes (builds) | 3 arenas, 3 power-ups, 34 cosmetics |
| Usable interface | yes | yes — reflection-validated, driven by fake server messages | visual layout unreviewed |
| Functional economy | yes | yes | |
| Persistence | yes | yes — with in-memory DataStore double | real DataStore: BLOCKED (Studio/API access) |
| Multiplayer | yes | partial — 2-player rules in sim | real multi-client: BLOCKED (Studio) |
| Purchases wired to configurable IDs | yes | yes — receipt logic | IDs: BLOCKED (Creator Hub, owner) |
| Major known bugs fixed | yes | — | see KNOWN_ISSUES.md |
| Opens in Roblox Studio | .rbxlx built and re-parsed | partial | opening in Studio itself: BLOCKED |
| Complete first-time experience | yes | yes (tutorial steps in sim) | |
| Publishing docs | yes | — | docs/PUBLISHING.md, docs/EXTERNAL_SETUP.md |

**Verdict:** feature-complete v1.0 candidate. **Not yet "ready to launch"**: requires the Studio QA
pass, product IDs, and original audio (all human/account actions).

## Map of the repo

- `src/` game code (see docs/ARCHITECTURE.md) · `tests/` Lune tests · `scripts/` build/CI/art
- `docs/` research, GDD, architecture, install, publishing, monetization, analytics, external setup, performance
- `assets/marketing/` icon + thumbnails · `release/ChromaTurf.rbxlx` ready-to-open place (regenerate with scripts/build.sh)
