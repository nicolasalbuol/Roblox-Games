# Implementation log

## 2026-11-09 — Session 1 (from empty repo to v1.0 candidate)

1. **Environment**: no Roblox tooling preinstalled. Built Rojo 7.7.1, Lune 0.11.1, Selene, StyLua
   from crates.io. GitHub release downloads blocked; Selene's Roblox std fetch blocked (TLS via proxy)
   → wrote minimal `chroma.yml` std.
2. **Phase A — research**: web search on 2026 Roblox trends/monetization; 6 concepts scored → Chroma Turf.
3. **Phase B/C — GDD + architecture**: docs/GDD.md, docs/ARCHITECTURE.md; Rojo layout shared/server/client.
4. **Phase D — core**: `Grid` (4-connected walk, flood-fill capture), `GridCodec` (buffers), MatchService
   tick loop with anti-speed painting guard, cut/self-cut/enclose/overrun rules, respawn.
5. **Phase E — world**: WorldBuilder hub (spawn, podium, signage, wins board, how-to board) and 3
   themed arenas with obstacles, decor and lighting.
6. **Phase F — progression/economy**: Progression (levels, rewards, achievements, daily quests, daily
   gift), EconomyService, QuestService, 34 cosmetics.
7. **Phase G — multiplayer/social**: no-collision group, nametags/titles, bots that fill rounds,
   invites, podium, kill feed, global wins board.
8. **Phase H — monetization**: 3 passes, 4 coin products, idempotent receipts, store funnel telemetry.
9. **Phase I — UI**: Kit toolkit (responsive scale, modals), HUD, Shop, Quests, Results, Settings,
   splash/main menu, tutorial coach, toasts; top-down camera; tile pop wave; particle bursts.
10. **Phase J — persistence/security/perf**: session-locked ProfileStore, migrations, BindToClose,
    rate-limited RequestRouter, client-only tiles/bots.
11. **Phase K — tests**: 50 Lune tests incl. headless round simulation and reflection-validated UI/world.
    Bugs found and fixed by tests/lint: loader recursion; xp test expectation; `Kit.label` passing a
    non-property key; Lune-missing BindableEvent (removed unused event); operator precedence in
    reduced-FX handler; double intermission in round loop; duplicated pop branch.
12. **Phase L — commercial prep**: store copy EN/PT-BR, keywords, icon + 2 thumbnails rendered from a
    simulated round, shorts ideas, update text, publishing/monetization/analytics/external-setup guides.
