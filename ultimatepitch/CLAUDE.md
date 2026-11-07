# Claude Code – UltimatePitch v0.5 development and independent Codex review

**Mission:** Build the ORIGINAL Roblox 5v5 football game with responsive ball gameplay, Spectra Dome stadium, high-quality R15 motion and Aurora Break. Use official Roblox Studio MCP only for scenes/playtests/images, Rojo 7.7.1 live sync for ordinary code. No purchased assets, third-party IP copying, live release or Robux monetization without user approval.

## Independent reviewer now available (separate ChatGPT/Codex instance)
After finishing a cohesive milestone **and committing source changes**, run this from the local **ultimatepitch** folder:

```powershell
powershell -NoProfile -File .\tools\peer-review.ps1 -Base HEAD~1
```

If Codex is not installed/signed in, first follow `docs/CLAUDE_CODEX_BRIDGE_DE.md`. The tool performs one **read-only** `codex exec` review on the committed diff, writes `.peer-review/LATEST_REVIEW.md`, and makes no code edits or GitHub changes.

Read the generated report yourself, fix verified P0/P1 defects in a new commit, run targeted regression, then proceed. Do not run an endless recursive multi-agent review loop; at most one re-review for a corrected milestone unless truly necessary. Never interpret a missing report as a PASS.

**Important:** This contacts a **separate OpenAI Codex session**, not this exact ChatGPT conversation. To give the ChatGPT coordinator access to the result, push the review report in a deliberately selected documentation PR or GitHub comment (after checking it contains no secrets); ChatGPT can then read it from the connected GitHub repository upon the next query. No automatic inbound message to this chat exists.

## Quality gates
- Dedicated 2-client regression when gameplay events change. Solo Studio proof is not multiplayer proof.
- Real Player/Mobile/FPS measurements separate from studio with verified focus and device; old 26.9 FPS baseline does not meet 60 FPS.
- Keep original gameplay code on its active branch; never overlay v0.2/v0.3 stand-alone demos.
- Protect existing Places: `build.ps1` also generates an **overwrite-capable** Studio installer. Do not execute its installer on an existing Place without backup and consent.
