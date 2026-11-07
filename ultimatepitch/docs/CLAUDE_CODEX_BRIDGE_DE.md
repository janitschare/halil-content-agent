# /BOOST – Claude Code ↔ Codex: echte KI-zu-KI-Review-Übergabe

Stand 2026-11-07 · Active gameplay: `janitschare/halil-content-agent` / `claude/intelligent-einstein-d3v7qz` / `ultimatepitch/` · baseline `6a31195790fb81a8fe7892b75ab3bc046906e058`.

## Welche Verbindung ist technisch möglich?

**Nicht möglich:** Claude Code kann diesen konkreten offenen ChatGPT-Chat nicht ohne explizite Schnittstelle beliebig anschreiben oder Antworten darin automatisch auslösen.

**Sofort verwendbar:** Claude Code kann über den lokalen Befehlsaufruf `codex exec` eine **separate OpenAI-Codex-Agentensitzung** als unabhängigen Reviewer ausführen, das Ergebnis als Datei zurückerhalten und selbst die Fehler beheben. Somit muss der Nutzer keine Codeblöcke mehr zwischen zwei Chatfenstern übertragen.

**Option ohne lokalen zweiten CLI-Lauf:** Für GitHub-Pull-Requests lässt sich Codex Code Review als PR-Reviewer aktivieren und mit `@codex review` ansprechen, soweit die Integration für das jeweilige Konto/Repository aktiviert ist. Claude liest die PR-Kommentare über `gh` und reagiert darauf. Dies muss der Eigentümer der GitHub-App einmalig autorisieren. Es erzeugt keine automatische Nachricht in diesem Chat.

## Lokale Einrichtung, nur einmal

Auf **Windows PowerShell in der lokalen UltimatePitch-Projektkopie**:

1. Prüfen: `codex --version`. Falls noch nicht vorhanden: Node.js/npm prüfen (`node --version`, `npm --version`), bei vorhandener Node-Installation `npm install -g @openai/codex@latest` verwenden. Sonst zuerst eine offiziell unterstützte Node.js-Version installieren.
2. `codex login` ausführen. Anmeldung mit ChatGPT-Konto, wenn angeboten, **keine API-Schlüssel in Dateien** und keine ungeplanten kostenpflichtigen API-Vorgänge. Test: `codex login status`.
3. Feature-Branch mit dieser Bridge auschecken / mergen **nach** Prüfung von Git-Diff und laufendem Claude-Code-Workspace. **Nicht** ungesicherte Änderungen überschreiben.
4. Nach einem fertig committed Meilenstein: `powershell -NoProfile -File .\tools\peer-review.ps1 -Base HEAD~1`.
5. Claude Code liest `.peer-review/LATEST_REVIEW.md`, prüft exakte Fundstellen, behebt P0/P1, dokumentiert Prüfungen; **keine automatische Code-Übernahme aus einem Review**.

Die Review-Sitzung ist **schreibgeschützt** (`--sandbox read-only`). Der Generator legt lediglich die Berichtsdatei in einem ignorierten lokalen Ausgabeordner an; keine Roblox- oder GitHub-Schreibzugriffe, keine Veröffentlichung.

## Claude ↔ Codex: Ablauf

```text
Claude Code (Hauptentwickler)
  |  1) bearbeitet src/ via Rojo, führt Studio-Gates aus
  |  2) committet zusammenhängenden Stand
  v
PowerShell .\tools\peer-review.ps1 -Base HEAD~1
  |  3) startet codex exec --sandbox read-only
  v
Codex (unabhängiger Code-Reviewer)
  |  4) liest committed Diff, sucht echte P0/P1/P2
  |  5) schreibt LATEST_REVIEW.md
  v
Claude Code (gleicher lokaler Workspace)
  |  6) liest Review, fixt, testet gezielt, committet
  v
GitHub (gemeinsamer öffentlicher/privater Übergabepunkt)
  |  7) ausgewählter Status-/Review-Kommentar – OHNE Secrets
  v
ChatGPT (dieser Chat – bei Nutzeraufruf / aktivem Rechercheauftrag)
     8) unabhängiger Meilensteinreview, nicht dieselbe Codex-Sitzung
```

## Sicherheits-/Kostenregeln
- Die Codex-CLI-Sitzung zählt gegen verfügbare Codex-Nutzungsgrenzen; Kosten und Tarifbedingungen sind accountabhängig. **Kein API-Key für diesen ChatGPT-Login-Ansatz als Voraussetzung.**
- Höchstens ein Codex-Review pro Meilenstein, maximal eine gezielte Wiederholung nach P1-Korrektur. Keine Hooks, die automatisch jeden Stopp auslösen (würden auf dem schwachen PC Review-Schleifen verursachen).
- Kein Autopush, Autopublish, Asset-Upload, Robux-Kauf, Secrets in Reviewberichten oder Repo.
- Client-Cosmetics sind keine serverseitige Spiellogik: Fail nur bei belegtem Server-Sicherheits-Bypass. Separate Ergebnisse für Runtime-Risiko, Recht/Lizenzen und bloße Optik.
- Tests bleiben zweistufig: Codex kann Quellcode unabhängig prüfen, aber ohne Studio-MCP keine Roblox-Laufzeit verifizieren. Claude Code führt die Tests aus.

## Reproduzierbarkeit und Abnahme

**Offline bestanden** erst, wenn `codex --version`, ChatGPT-Login, 1 erfolgreicher `codex exec`-Lauf und eine nichtleere `.peer-review/LATEST_REVIEW.md` belegt sind. Bis dahin ist die Bridge **NUR VORBEREITET**.

Offizielle Quellen:
- https://developers.openai.com/blog/codex-as-a-platform
- https://developers.openai.com/cookbook/examples/codex/build_iterative_repair_loops_with_codex
- https://developers.openai.com/blog/custom-code-review-rules-for-codex
- https://code.claude.com/docs/en/settings
