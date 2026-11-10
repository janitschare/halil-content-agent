# M3 – Studio-Smoke-Test (Karriere, Pitch Coins, Scout, Shop)

Datum: 10.11.2026 · Code-Commit: `ff4a01e` · Place: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (Rojo Live Sync)
Umfang: ein gezielter Solo-Playtest in Studio (1 Client, 3v3 Street Court mit Bots), keine Testschleife.

## Ergebnisse (tatsächlich in Studio ausgeführt)

| Prüfung | Ergebnis | Nachweis |
|---|---|---|
| Kompilierung aller 8 Skripte (`loadstring`, Edit) | OK | Server, Client, Dome, City, Career, AuroraFX, Matchday, CareerUI |
| Start: Attribute, leaderstats, Scout-NPC, Theke, RemoteEvent | OK | PitchCoins=0, Stufe "Street Rookie", Scout (86,4,-211), Theke (-56,2.7,-261) |
| Server-Konsole beim Start | keine Fehler aus UltimatePitch-Skripten | nur bekannte CoreGui-Timeouts des schwachen Rechners |
| Server-Teleport eines Spielers | vom Bewegungs-Anti-Cheat zurückgesetzt (gewollt) | Spieler danach über `character_navigation` bewegt |
| Pad-Beitritt Street Court | OK | `UP_Arena=StreetCourt`, Phase Intermission → Playing, Team Rot |
| Tor ohne menschliche Berührung (Ball per Skript ins +X-Tor) | Tor für Rot, **keine** Torgutschrift | Score 1:4, später 0 Coins für dieses Tor |
| Tor nach Ballführung durch den Spieler | Tor für Rot, Gutschrift an den Spieler | `BallOwner` = UserId, danach Score 2:4 |
| Matchende 4:8 (verloren) | 15 Coins = 10 Match + 5 für 1 eigenes Tor, kein Siegbonus | `PitchCoins=15`, leaderstats 15 |
| Karriere nach erstem Street-Court-Match | "Local Talent" | Attribut + leaderstats |
| Scout-Gespräch (E am NPC) | Dialog mit Angebot +50 | Screenshot 1 |
| "Unterschreiben" (echter Mausklick im Spiel) | 65 Coins, "Scouted Player", zwei Meldungen | Screenshot 2 |
| Shop (E an der Theke) | 4 Artikel, Preise nach Guthaben eingefärbt | Screenshot 3 |
| Kauf Neon-Schuhe (echter Mausklick) | 25 Coins, "ANGELEGT", Meldung | Screenshot 4 |
| Zu teuer (Binde 60 bei 25) | abgelehnt, Meldung "Dir fehlen noch 35 Pitch Coins." | Client-Remote-Test |
| Unbekannte Artikel-Id, Tabelle statt Id | ignoriert | Coins/Besitz unverändert |
| Scout-Bonus erneut anfordern | ignoriert | Coins unverändert |
| Zwei Anfragen innerhalb 0,3 s | zweite verworfen (Drossel) | nur ein Umschalten |
| Ausrüsten aus 32,8 Studs Entfernung | abgelehnt, Shop-Fenster automatisch geschlossen | Attribut unverändert |
| Gekaufte Schuhe im nächsten Match | Fußfarbe (70,255,150) im Trikot | Server-Abfrage LeftFoot/RightFoot |

## Im Test gefundene und behobene Punkte (vor dem Commit)
- Coin-Anzeige überdeckte die Phasen-Zeile unter der Anzeigetafel und lag unter dem Roblox-Chat → an den linken Rand (40 % Höhe) verlegt, Screenshot 5 (geprüft).
- Schließen-Symbol "✕" wird von Gotham nicht dargestellt (Kästchen) → "X".
- `lastTouch` überlebte Anstoß/Ball-Reset → wird in `resetBall` gelöscht (im Nachtest mitgeprüft: kein Bot-Tor wurde gutgeschrieben).

## Nachtest nach den Codex-Fixes (`e1feb9b`)
| Prüfung | Ergebnis |
|---|---|
| Kompilierung Server + CareerUI | OK |
| Ball auf Brusthöhe gegen den Spieler (Touched durch Spieler, `BallOwner=0`), dann ins +X-Tor | Tor für Rot |
| Matchende 9:11 (verloren), Spieler hatte 2 Testtore (1× Dribbling, 1× nur Körperkontakt) | 20 Coins = 10 + 2×5 → beide gutgeschrieben, keines der 7 Bot-Tore |
| Scout-/Shop-Fenster auf Desktop (1617×592) | 440×230 bzw. 460×360, Shop-Liste ScrollingFrame |
| Schmale Displays (375 px) | **nicht in Studio geprüft** (Emulator nur mit Desktop-Profilen) |

## Nicht geprüft
- Mehrere echte Spieler gleichzeitig (Coins pro Spieler, Rangliste) – kein 2-Client-Test auf diesem Rechner.
- Sieg-Bonus (das Testmatch ging verloren); Logik identisch zum Matchbonus-Pfad.
- Kapitänsbinde und goldene Rückennummer im Trikot (nur Schuhe sichtbar geprüft).
- Mobile/Touch-Bedienung der Fenster.
- Dauerhafter Speicherstand: bewusst nicht vorhanden (DataStore erst nach Freigabe).

Screenshots: `docs/reviews/M3_screens/`
