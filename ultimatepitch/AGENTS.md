# Codex independent reviewer – UltimatePitch

This directory contains the live v0.5 Roblox football source. Review `src/Server.server.lua`, `src/Client.client.lua`, `src/Dome.lua`, `src/AuroraFX.lua`, `default.project.json` and `build.ps1`. Do not confuse the separate legacy prototypes with this active source.

**Role:** read-only security/architecture/quality auditor of Claude Code changes. Do not edit source or run Roblox Studio, publish Experiences, upload assets, initiate purchases, or merge branches. Report specific material findings with file:line and an objective reproduction. Do not claim Roblox Studio or device tests unless you actually executed them.

**Hard invariants:** Ball direction, speed, ownership, goals, cooldowns, rewards and anti-cheat stay server-authoritative; clients only send intentions. A client-side FX/HUD/graphics/sound manipulation is not automatically a gameplay exploit. Network ownership and movement replication need appropriate server plausibility checks. The Aurora shot causality token must not survive an unrelated ball action. Legacy Robux/Pack/DataStore code stays off.

**Current v0.5 status (as of 2026-11-07):** Rojo Live Sync and Studio SOLO tests documented; 2-client regression of new `KickAnim` NOT run; Mobile, Player benchmarks and dynamic Lighting compatibility NOT confirmed. High graphics on old i5-3230M/HD 4000 measured 26.9 FPS and P95 54.5 ms, so no claim of 60 FPS. The Creator Store sound IDs loaded in Studio; exact licensing and deployment rights still need final provenance verification before public release. `build.ps1` generates an installer which can destroy existing place objects; do not execute it in an occupied Studio Place without a backup and explicit user approval.

Before reviewing: identify actual HEAD and diff against the supplied base. Output P0-P3, exact file:line, test required, minimal fix, and HOLD/MERGE recommendation. Avoid stylistic rework and duplicate reviews of unchanged files.
