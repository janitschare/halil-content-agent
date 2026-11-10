# Claude-Antwort: M1b Match als Arena-Instanz (2662b7f, Korrektur 504fde0), 2026-11-10

## Inhalt
`createArena(A)` kapselt je Arena Aufbau, Zustand, KI, Ballführung, Torerkennung, Spielschleife und Watchdog.
Das Stadion ist die erste Instanz (`id = "Stadium"`, fester Ursprung, unveränderte Pfade `workspace.UltimatePitch.*` und
`ReplicatedStorage.UltimatePitch.State`). Weitere Arenen entstehen serverseitig über
`ServerScriptService.UltimatePitchServer.CreateArena` (BindableFunction, Konfiguration wird geprüft) und liegen unter
`workspace.UltimatePitch.Arenas.<id>` bzw. `ReplicatedStorage.UltimatePitch.Arenas.<id>.State`.
Teilnahme: Player-Attribut `UP_Arena` = Arena-Id (ersetzt `UP_InMatchQueue`). Ausdauer, Sprint und Bewegungsprüfung
laufen einmal serverweit.

## Studio-Solo
| Prüfung | Ergebnis |
|---|---|
| Stadion-Regression | Match, 9 Bots, Ballannahme; 25 s: 7 Ballannahmen, 5 Schüsse, 0 Bot-Proben außerhalb, Torwart ≤ 10 Studs vor dem Tor; AURORA per Taste; Tor 0:0 → 1:0 |
| Konfigurationsprüfung | ungültige Id und doppelte Id abgelehnt |
| Test-Arena 3v3 bei z = 500 (30 × 18, Tor 6) parallel | wartet ohne Bots, während das Stadion spielt |
| Spieler wechselt in die Test-Arena | Stadion: Bot übernimmt, Match endet; Test-Arena: eigenes Match mit 5 Bots |
| 20 s Test-Arena | 7 Ballannahmen, 9 Schüsse, 200 Bot-Proben / 0 außerhalb, Ball 0 × außerhalb; Stadion-Stand und Stadion-Ball unverändert |
| Spieler in der Test-Arena | Ballannahme zählt nur dort (Stadion-BallOwner 0); Tor bei x = 33 zählt nur dort |
| Wechsel zurück / Abmeldung | Wartepunkt der Zielarena bzw. Stadion-Lobby, Team Lobby, Bot übernimmt |
| Konsole | keine Skriptfehler (nur die absichtlich ausgelösten Ablehnungen) |

Im Test gefunden und behoben (vor dem Review): Beim Wechsel zurück fiel der Spieler neben der Test-Arena ins Leere
(Ausgangspunkt außerhalb des Bodens, Reihenfolge Abmeldung/Anmeldung). Jetzt: Abmeldung sofort, Anmeldung verzögert,
Wartepunkt auf dem Bodenrand.

## Codex-Review 2662b7f → HOLD (kein P0/P1)
| Befund | Prüfung | Korrektur 504fde0 |
|---|---|---|
| P2 Abmeldung während des Teamaufbaus hinterlässt einen leeren Kaderplatz | bestätigt | `setupTeams` füllt Lücken (abgemeldet oder Spiel verlassen) vor dem Anpfiff mit Bots |

Solo-Regression danach: vollständige Kader, Tor zählt. **Nicht getestet:** der Abmeldezeitpunkt selbst (braucht 2 Clients).
Kein Re-Review (nur P2).

## Place
`experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` gespeichert (10.11.2026 17:23, 220 807 Bytes, SHA256 `FB0A33F0F61B8A1B…`),
5/5 Skripte identisch mit dem Branch, keine Testobjekte in der Datei.

## Offen (für M2)
- Client kennt nur das Stadion: HUD, Ring, AURORA-Effekte, Matchday und Zonenlicht lesen `UltimatePitch.State` und den
  Stadion-Ball. Effekte werden an alle Clients gesendet. Für den Bolzplatz muss der Client der Arena des Spielers folgen.
- Stadion-Sounds (Pfiff, Parade) sind nicht räumlich und nur im Stadion aktiv.
- Bewegungsprüfung und `BaseSpeed` gelten serverweit (Fahrzeuge später).
- 2-Client-Prüfungen: Arenawechsel mit zwei Menschen, Abmeldung im Teamaufbau.
