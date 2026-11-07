#Requires -Version 5.1
<#
UltimatePitch v0.5: run one independent Codex review after a Claude Code milestone.
No API key in the repository. No autonomous GitHub push, studio access, or code writes.
Run from a local shell: powershell -NoProfile -File .\tools\peer-review.ps1
#>
[CmdletBinding()]
param(
    [string]$Base = "HEAD~1",
    [ValidateRange(1, 10)][int]$MaxFiles = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $project
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git CLI fehlt."
    }
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw "Codex CLI fehlt. Einmalig installieren und anmelden: npm install -g @openai/codex@latest; codex login"
    }
    $current = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Git HEAD ist nicht lesbar." }
    $from = (& git rev-parse --verify "$Base^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $from) { throw "Unbekannter Basis-Commit: $Base" }
    $from = ($from | Select-Object -Last 1).Trim()

    # Only review committed milestone code; drafts stay with Claude Code.
    $dirty = @(& git status --porcelain -- src default.project.json build.ps1 build.py)
    if ($LASTEXITCODE -ne 0) { throw "git status fehlgeschlagen." }
    if ($dirty.Count -gt 0) {
        throw "Nicht gesicherte Änderungen in Gameplay/Build-Dateien: zuerst Commit oder Stash, nichts überschreiben."
    }

    $changed = @(& git diff --name-only $from $current -- src tests default.project.json build.ps1 build.py)
    if ($LASTEXITCODE -ne 0) { throw "Git diff fehlgeschlagen." }
    if ($changed.Count -eq 0) { throw "Zwischen $from und $current sind keine relevanten Dateien geändert." }
    if ($changed.Count -gt $MaxFiles) {
        throw "Der Diff betrifft $($changed.Count) Dateien (Limit $MaxFiles). Bitte Meilenstein aufteilen."
    }

    $reviewDir = Join-Path $project ".peer-review"
    New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null
    $shaShort = $current.Substring(0, 10)
    $report = Join-Path $reviewDir ("review_" + $shaShort + ".md")
    $latest = Join-Path $reviewDir "LATEST_REVIEW.md"
    $changedList = ($changed -join ", ")
    # Windows: Die read-only-Sandbox von Codex kann dort keine Shell-Prozesse starten
    # ("helper_unknown_error: setup refresh had errors"). Darum bekommt Codex den committeten Diff
    # mit 25 Kontextzeilen direkt über stdin (als <stdin>-Block) und braucht keinen Dateizugriff.
    $diff = (& git diff -U25 $from $current -- src tests default.project.json build.ps1 build.py) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Git diff (Inhalt) fehlgeschlagen." }
    if ($diff.Length -gt 400000) { throw "Diff zu groß ($($diff.Length) Zeichen). Bitte Meilenstein aufteilen." }
    $prompt = @"
You are an independent critical code reviewer for a Roblox Luau 5v5 football game.
This is a READ-ONLY security/correctness review. DO NOT modify or create project source files.
The complete committed diff (git diff -U25 $from $current -- src tests default.project.json build.ps1 build.py)
is attached below as the <stdin> block. Base your review on that diff; shell/file access may be unavailable.
Changed files: $changedList

Review server authority for Kick/Pass/Shot/Aurora, remote-event schema, rate limits, goal attribution, stamina and movement validation.
Check client-only visual effects (KickAnim, AuroraFX, HUD, graphic profiles, sound); flag only concrete client -> gameplay authority bypasses.
Check R15 animation overlap and cleanup, Focus/Touch/Reduced Motion, build.ps1 and Rojo default.project.json.
Identify Roblox-specific runtime/API compatibility risks. Compare review claims with code.
Find at most 8 MATERIAL findings, each with:
- P0/P1/P2/P3 priority, exact path:line, failure mechanism, minimal reproduction, minimal fix.
- Separate CONFIRMED FROM CODE, NEEDS ROBLOX STUDIO, and INFORMATION MISSING.
- Call out green tests documented in Git history that were NOT rerun by you.
- Give a one-line MERGE/HOLD decision and the smallest targeted tests to close blockers.
- If no material issue found, say NO MATERIAL ISSUE FOUND, not generic suggestions.
Do NOT request another full 10-client test by default. No asset purchases/uploads, no releases/monetization.
Write in German. Keep the review under 900 words.
"@
    Write-Host "Codex Read-only Review: $($current.Substring(0, 12)) vs $($from.Substring(0, 12))"
    $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $diff | & codex exec --sandbox read-only --output-last-message $report $prompt
    $exit = $LASTEXITCODE
    if ($exit -ne 0 -or -not (Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).Length -eq 0) {
        throw "Codex-Review schlug fehl (Exitcode: $exit). Kein PASS und kein Bericht vorgetäuscht."
    }
    Copy-Item -LiteralPath $report -Destination $latest -Force
    Write-Host ("REVIEW CREATED: " + $latest)
    Write-Host "Claude Code: LATEST_REVIEW.md lesen; nur begründete P0/P1-Fehler beheben; Änderungen separat verifizieren."
    Get-Content -LiteralPath $latest
} finally {
    Pop-Location
}
