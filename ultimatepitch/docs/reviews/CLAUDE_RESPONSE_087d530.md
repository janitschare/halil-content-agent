# Claude-Antwort: M1a Open-World-Vorbereitung (087d530), 2026-11-10

## Inhalt
1. **Keine globalen Eingriffe:** Server deaktiviert keine fremden SpawnLocations mehr; er besitzt nur `workspace.UltimatePitch`,
   `ReplicatedStorage.UltimatePitch`, die Teams Lobby/Rot/Blau und die Lighting-Effekte `UP_*`.
2. **Teilnahme per Anmeldung:** Match erfasst nur Spieler mit `UP_InMatchQueue = true` (nur serverseitig gesetzt;
   `CFG.AutoQueue = true` meldet vorerst jeden an). Abmeldung im Match: Platz geht an einen Bot.
3. **Zonenlicht:** Server setzt nur das Grundlicht der Welt (später Nachmittag); das Nachtspiel-Licht blendet jeder
   Client lokal ein, solange seine Kamera im Stadion ist.

## Studio-Solo
| Prüfung | Ergebnis |
|---|---|
| Fremder Spawn + Part in `workspace` (temporär) | Spawn bleibt `Enabled`, Part unverändert; Testobjekte danach entfernt, nicht in der Datei |
| Zonenlicht | Lobby: Clock 16,6 / Brightness 2,2 / Bloom 0,4 → im Stadion nach ~1 s: 20,3 / 1,5 / 0,9 |
| Abmeldung im Match | Team Lobby, Position Lobby, Bot übernimmt (10 Bots), Match endet, danach kein neues Match |
| Anmeldung | Vorbereitung + Match starten, Team Rot, 9 Bots |
| Regression | Anstoß-Intro, Ballannahme, Tor (1:1) ok; keine Skriptfehler |

## Codex-Review 087d530 → MERGE, NO MATERIAL ISSUE FOUND
Offene Laufzeitprüfungen laut Codex (keine Fehler): Abmeldung während „Goal“/Aurora-Windup, Anmeldung im laufenden
Match mit 2 Clients, Respawn eines nicht angemeldeten Spielers an fremdem Spawn; `BaseSpeed = 16` wird weiter für
alle Figuren gesetzt (für spätere Stadt-Bewegung/Fahrzeuge beachten).

## Place
`experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` gespeichert (10.11.2026 17:04, 210 127 Bytes, SHA256 `CBCE3033D0EFE711…`),
5/5 Skripte aus der Datei identisch mit dem Branch.

## Noch offen in M1 (M1b)
Match-Logik als eigenständige Instanz pro Arena (eigener Ball, eigene Maße, eigener Ursprung) – Voraussetzung für
den Bolzplatz. Die Bewegungsprüfung und `BaseSpeed` gelten weiter global.
