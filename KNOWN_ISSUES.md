# Known issues and risks

Ordered by impact. "Unverified" = cannot be checked without Roblox Studio/devices in this environment.

| # | Issue | Status | Impact | Next step |
|---|---|---|---|---|
| 1 | Game never executed inside Roblox Studio. Engine behaviour (physics, network ownership, camera feel, real UI layout, ProcessReceipt) is unverified. | BLOCKED (needs Studio) | high | Run the QA checklist in docs/PUBLISHING.md |
| 2 | SFX use built-in `rbxasset://sounds/...` paths; some may not exist in current clients (worst case: silent, warning in Output). No music. | PENDING | medium | Upload original SFX/music, set `Config.Audio` |
| 3 | Eliminated players are frozen by anchoring the HumanoidRootPart for 3 s; on some clients this may show a small snap on respawn. | UNVERIFIED | low | Watch in a 2-player test; alternative: move to a spectator spot |
| 4 | Marketing images are original concept renders, not in-engine screenshots. | PENDING | medium | Capture real screenshots in Studio |
| 5 | Analytics enum names (`AnalyticsCustomFieldKeys`, `AnalyticsEconomyFlowType`) unverified; calls are fully pcall-protected and tested to never throw. | UNVERIFIED | low | Check Creator Analytics after first session |
| 6 | No Luau type checker run (luau-analyze/luau-lsp unavailable offline); Selene uses a minimal custom std (`chroma.yml`). Mitigation: every Instance class/property/enum created by the client UI, renderers, WorldBuilder, AvatarService, LeaderboardService and PowerupService is validated against the Roblox reflection DB in tests. Calls into engine services (DataStore, Marketplace, Players, Analytics) are not validated. | PARTIAL | low | Open in Studio with Script Analysis; optionally run luau-lsp |
| 7 | Grid 40x40 tuned for <= 12 players; larger servers will feel crowded. | BY DESIGN | low | Set Max Players = 12 |
| 8 | Bots use simple rectangle/hunt/flee heuristics; skilled players will notice patterns. | ACCEPTED v1 | low | Roadmap: bot difficulty tiers |
| 9 | Speed anomaly detection only blocks painting (no kick) to avoid false positives on lag. A client spoofing slow, valid movement is indistinguishable from a real player (inherent). | ACCEPTED | low | Monitor `[Match] speed anomaly` warnings |
| 10 | Wins leaderboard writes on player leave/round end (1 write/s throttle). Very large servers could hit DataStore budgets. | ACCEPTED | low | Batch further if warnings appear |
