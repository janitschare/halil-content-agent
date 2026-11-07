# Claude-Antwort auf Codex-Review 760a588 (v0.5), 2026-11-07

## Bridge-Einrichtung
- Bridge-Dateien aus PR #1 per Fast-Forward übernommen (nur die 5 Dateien, Spielcode unverändert).
- Codex CLI 0.162.1 lokal vorhanden, `codex login status`: „Logged in using ChatGPT“.
- Lauf 1 (`review_b7f4149`, siehe `CODEX_REVIEW_b7f4149_blockiert.md`): technisch blockiert. Zwei Ursachen, beide behoben:
  1. `tools/peer-review.ps1` war ohne BOM gespeichert. Windows PowerShell 5.1 las „Ä“ (UTF-8 `C3 84`) als `Ã„`; `„` gilt dort als Anführungszeichen, das Skript war unparsbar. Jetzt UTF-8 mit BOM.
  2. Die Codex-read-only-Sandbox startet unter Windows keine Shell-Prozesse (`helper_unknown_error: setup refresh had errors`). Das Skript übergibt den Diff mit 25 Kontextzeilen jetzt per stdin (`<stdin>`-Block), die Sandbox bleibt read-only.
- Lauf 2 (`CODEX_REVIEW_760a588.md`): echter Bericht mit Fundstellen, Diff `6ca3bf4 → 760a588`.

## Befunde und Umgang
| Befund | Prüfung durch Claude | Status |
|---|---|---|
| P2 Harness meldet `ok = true` bedingungslos (`tests/UP_KickAnimHarness.server.lua:64`) | bestätigt | behoben: grün nur mit Endberichten beider Spieler, ohne Fehler, mit animierten Kicks und gesehenem Pass des anderen Spielers |
| P2 `build.py` ohne Lighting-Block | bestätigt | behoben: identischer Block wie `build.ps1`/Rojo |
| Studio: Hüftwinkel-Schwelle 0,3 ohne Negativkontrolle | berechtigt | offen (Negativkontrolle mit deaktiviertem QuickKick) |
| P0/P1 | keine gemeldet | – |

Kein erneuter Codex-Lauf: nur P2-Befunde (Bridge-Regel: Wiederholung nur nach P1-Korrektur).

## Prioritäten aus dem Auftrag
- **Installer-Schutz:** Installer löscht nichts mehr. Bei vorhandenen UltimatePitch-Objekten bricht er ohne Änderung ab; nur mit `_G.UP_REPLACE = true` ersetzt er und verschiebt die alten Objekte vorher nach `ServerStorage.UP_Backup_<Zeit>` (plus ChangeHistory-Wegpunkt). In Studio geprüft: Abbruch lässt die Place intakt; Ersetzen sichert 2/2 Attrappen, Flag wird zurückgesetzt.
- **Lighting:** `Lighting.Technology` ist seit Unified Lighting (Roblox, Jan. 2025) durch `LightingStyle` + `PrioritizeLightingQuality` ersetzt; die Place stand auf `Soft`. Jetzt `Realistic`, `PrioritizeLightingQuality = false` (Rojo-Projekt, beide Builder; in Studio gesetzt). Studio-A/B in derselben Sitzung: Soft 53,4 FPS / P95 26,0 ms, Realistic 54,2 FPS / P95 24,4 ms – kein Mehraufwand. Die absolute Bildrate lag in dieser Sitzung höher als bei der früheren Messung (26,9 FPS); Bedingungen (Fenster, Kamera) unterschieden sich, daher keine Aussage über eine Verbesserung.
- **2-Client-KickAnim (StudioTestService, 2 simulierte Clients):** 4 Läufe. Belastbar aus Lauf 3: Client 1 empfing über das Netzwerk 27 KickAnim-Ereignisse (Bots), 19 mit sichtbarer Hüftbewegung, 0 Formatfehler. **Nicht belegt:** Endbericht von Client 2 und Pass eines menschlichen Spielers (`passRequests = 0`; in Lauf 4 erreichten beide Sonden das Startsignal nicht). Ursache ungeklärt, bewusst nicht weiter in Schleife untersucht. Das neue strenge Harness würde diese Läufe rot melden.

## Nachtrag: 2-Client-KickAnim-Fehlersuche (2026-11-07)

**Ursache der früheren Fehlschläge:** Die beiden StudioTestService-Clients liefen auf dem Test-PC (i5-3230M/HD 4000) im
Hintergrund mit nur ~6 FPS. Das Startsignal kam erst nach 21–41 s an, die Endberichte ~30 s nach dem Stoppsignal –
länger als die alten Harness-Fenster (sofortiger Start, 8 bzw. 20 s Wartezeit). Belegt durch Zeitstempel und
gemessene Client-FPS. Harness wartet jetzt bis 90 s auf beide Clients und bis 60 s auf die Endberichte.

| Lauf | Client-FPS | KickAnim-Ereignisse | „animiert“ (> 0,3 rad) | Pass des anderen Spielers | Bewertung |
|---|---|---|---|---|---|
| A, Kickanimation an | 5,6 / 6,1 | 58 / 58 | 55 / 57 | Spieler 1: 9 Pass-Anfragen, 5 vom Server angenommen; Client 2 sah 5/5 | gültig |
| B, Negativkontrolle (Kickanimation aus) | 12,3 / 6,0 | 87 / 87 | 37 / 38 | 14 Anfragen; Client 2 sah 10/10 Ereignisse, ebenfalls „animiert“ | gültig |
| C, D (Wiederholung mit Kicksignatur) | 0,0–0,5 | – | – | – | **ungültig**, Clients renderten nicht |
| 2 weitere | – | – | – | – | ohne Ergebnis bzw. ohne Spieler (Studio-Start fehlgeschlagen) |

**Bewertung:**
- Belegt: Das Ereignis `KickAnim` kommt auf beiden Clients vollständig und fehlerfrei an (58/58, 87/87), auch für Pässe
  eines menschlichen Spielers (Server-Pfad Pass → `kickBall(…, char)` → `FireAllClients`).
- Belegt: Mit Kickanimation sind 95–98 % der Ereignisse über der 0,3-rad-Schwelle, ohne Kickanimation 43–44 %. Die
  Animation wirkt also messbar auf beiden Clients.
- **Nicht ausreichend belegt:** Dass jede einzelne Kickpose auf dem anderen Client sichtbar ist. Die 0,3-Schwelle
  trennt nicht sauber (Codex-Hinweis bestätigt; Laufanimation allein erreicht sie). Die neue Kennzahl
  „Kicksignatur“ (> 1,1 rad) ist eingebaut, aber wegen eingefrorener Clients noch nicht gegen die Negativkontrolle
  validiert. Das Harness bewertet jetzt die Kicksignatur und erklärt Läufe mit Client-FPS < 2 für ungültig.

## Offen
- 2-Client: Pass eines Spielers auf dem jeweils anderen Client, Negativkontrolle, Respawn/Aurora-Überlappung.
- Sound-Provenienz für eine spätere öffentliche Veröffentlichung final prüfen (ProSoundEffects-Bibliothek im Creator Store).
- Mobile/Touch auf echtem Gerät, Roblox-Player-Messung.
