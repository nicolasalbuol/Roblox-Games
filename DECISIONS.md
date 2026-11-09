# Decisions log

| Date | Decision | Why | Alternatives rejected |
|---|---|---|---|
| 2026-11-09 | Concept: **Chroma Turf** territory-loop arena | Best weighted score (7.70); fully procedural art fits a code-only pipeline; instantly readable for thumbnails/shorts. See docs/MARKET_RESEARCH.md | Night-survival coop (saturated after recent hits), cloud fishing (needs large art catalogue), party minigames (content-heavy) |
| 2026-11-09 | Rojo project + `.rbxlx` build, no external Luau packages | Versionable source, reproducible build, no network-dependent Wally packages | Hand-made place file; ProfileService/ProfileStore packages (couldn't fetch; own tested ~100-line equivalent) |
| 2026-11-09 | Server samples positions at 10 Hz and walks a 4-connected path | Authoritative, cheap, and 4-connectivity guarantees crossing paths share a cell (cuts can't be skipped diagonally) | Touched events (unreliable, exploitable), client-reported tiles |
| 2026-11-09 | Tiles rendered only on clients, replicated as binary buffers | 1,600 parts never replicate; deltas are 4 B/cell | Server-side tile parts (heavy replication) |
| 2026-11-09 | Bots simulated on server, rendered on clients, labelled "Bot" | New experiences have low CCU; rounds must always be lively; honesty to players | Empty servers; disguised bots (deceptive) |
| 2026-11-09 | Elimination wipes territory (classic .io rule) but never persistent progress | Drama + comeback potential; no frustration beyond 3 s | Partial territory loss |
| 2026-11-09 | No player-player collision | Prevents body-blocking/griefing | Default collisions |
| 2026-11-09 | StreamingEnabled off | Small arena; tiles are local anyway; avoids streaming edge cases with teleports | Streaming on |
| 2026-11-09 | Monetization: cosmetics + coin boosts only, no loot boxes, no auto-prompts, prices always visible | Platform rules, minors' safety, long-term trust | Paid random boxes, power-ups for Robux, timed offers |
| 2026-11-09 | Receipt ack only after successful save | Prevents lost purchases; idempotency by PurchaseId prevents dupes | Ack-then-save |
| 2026-11-09 | Daily gift never resets on missed days | Return motivation without pressure | Classic streak reset |
| 2026-11-09 | Kick instead of blank profile when save can't load | Never overwrite a real save with defaults | Play with temporary data (only allowed in Studio) |
| 2026-11-09 | Top-down follow camera while playing, normal camera in hub; "Classic" option | Territory readability on small screens | Default third-person only |
