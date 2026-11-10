# Claude-Antwort: M3 Karriere, Pitch Coins, Scout und Shop (ff4a01e → e1feb9b), 2026-11-10

## Bezug zur verbindlichen Place
M3 ist per Rojo direkt in `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` eingespielt und dort gespeichert
(23:14:58, 270 956 Bytes, SHA256 `ab3c52b9e3b555d3…`). Die 8 Skripte in der gespeicherten Datei stimmen mit `e1feb9b` überein
(LF-normalisiert, Länge/Hash `h = h*31 + byte mod 2^32`):

| Skript | Länge | Hash |
|---|---|---|
| UltimatePitchServer | 76045 | 4294347609 |
| UltimatePitchClient | 27899 | 2177614603 |
| Dome | 17604 | 3487982571 |
| City | 13721 | 2294750658 |
| Career (neu) | 11016 | 1944524615 |
| AuroraFX | 30885 | 2388574878 |
| Matchday | 11373 | 3227942360 |
| CareerUI (neu) | 12464 | 3812071892 |

## Umfang M3
- **Pitch Coins** (Server): 10 je vollständig gespieltem Match, +15 bei Sieg, +5 je eigenem Tor (max. 10 Tore). Abgebrochene Matches und
  Spieler, die vor dem Ende gehen, erhalten nichts. Anzeige links am Rand und in der Roblox-Rangliste (leaderstats).
- **Karriere**: Street Rookie → nach dem ersten Street-Court-Match Local Talent → nach dem Scout-Vertrag Scouted Player.
- **Talent-Scout** am Street Court (eigene Figur aus Grundfarben, kein Asset): ProximityPrompt, Dialog, Vertrag +50 Coins (einmalig).
- **Fashion District** geöffnet: Theke mit vier rein optischen Artikeln (Neon-/Goldschuhe, Kapitänsbinde, goldene Rückennummer),
  sichtbar im Matchtrikot. Kein Spielvorteil.
- **Sicherheit**: Clients senden nur Absichten. Der Server prüft Typ, Katalog, Stufe, Preis, Guthaben, Besitz, Nähe (14 Studs) und
  drosselt (0,3 s). Torgutschrift nur für das eigene Team.
- **Nicht enthalten (bewusst)**: dauerhafter Speicherstand/DataStore (Freigabe ausstehend), Robux, Zufallspakete, Asset-Uploads.

## Codex-Befunde (Bericht `CODEX_REVIEW_ff4a01e.md`, Status HOLD)
| Befund | Bewertung | Maßnahme | Nachweis |
|---|---|---|---|
| P2: Körperkontakt eines anderen Menschen/Bots aktualisiert den Torschützen nicht | berechtigt | `Ball.Touched` setzt bei Figurenkontakt `lastTouch` (Mensch) bzw. löscht ihn (Bot); Geometrie ignoriert | Studio: Kontakt ohne Ballbesitz (`BallOwner=0`), danach Tor → am Matchende 20 Coins = 10 + 2×5 (beide Testtore gutgeschrieben, keines der 7 Bot-Tore) |
| P2: Shop-Schließen-Knopf auf 375-px-Displays außerhalb des Bildschirms | berechtigt | Fenster passen sich der GUI-Fläche an (Rand 12 px, Mindestgröße 240×160), Shop-Liste scrollt, Scout-Knöpfe skalieren | Studio Desktop: Größen unverändert 440×230 / 460×360, Liste als ScrollingFrame. **375 px nicht in Studio geprüft** (Geräteemulator bietet hier nur Desktop-Profile) |
| Hinweis: Coin-Animation ohne Reduced-Motion-Schalter | P3, kurz (0,35 s, nur Icon) | offen gelassen | – |

Kein erneuter Codex-Lauf: beide Befunde waren P2 (Regel: Re-Review nur nach P1-Fix).

## Tests
Siehe `SMOKE_M3_ff4a01e.md` (Erst-Test) und Abschnitt „Nachtest“ dort. Alle Ergebnisse stammen aus Studio-Solo-Playtests auf
diesem Rechner; kein 2-Client-Test.

## Offene Punkte
- 2 echte Spieler: getrennte Coins, Körperkontakt zwischen Menschen, Rangliste.
- Shop/Scout auf echten Phone-Auflösungen und Touch.
- Kapitänsbinde und goldene Rückennummer optisch im Match prüfen.
- Dauerhafter Speicherstand: wartet auf Freigabe (DataStore).
