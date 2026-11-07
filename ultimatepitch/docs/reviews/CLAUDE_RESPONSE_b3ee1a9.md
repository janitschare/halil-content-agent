# Claude-Antwort: Meilenstein Bot-KI v2 (b3ee1a9), 2026-11-07

## Meilenstein
Ballführer kann Mensch oder Bot sein (`State.BallCarrier`); Bots führen den Ball mit der gemeinsamen
Ballführung, entscheiden alle 0,35 s zwischen Schuss ins vom Torwart entferntere Eck, Pass auf freien
Mitspieler (Passweg frei, Empfänger ungedeckt, nach vorn) und Dribbling mit Ausweichen. Ohne Ball: Presser +
Absicherung, bei Ballbesitz Freilaufen. Torwart torseitig hinter dem Ball, Spieleröffnung per Pass. Harte Bälle
> 75 Studs/s nicht annehmbar.

## Studio-Solo (ein regungsloser Mensch im Team Rot, verzerrt die Teamwerte)
| Lauf | Ergebnis |
|---|---|
| 1. Messung (60 s) | 16/20 Ballübergaben im Team, aber viele Rückpässe (u. a. auf den stehenden Menschen) |
| Diagnose (Verlauf) | Rückpässe bis vor das eigene Tor; Torwart lief auf den Ball zu |
| nach Korrektur (60 s) | 5 Schüsse, 3 Tore, angekommene Pässe fast nur nach vorn (Rot 3/0, Blau 1/1), 5 Ballverluste |

## Codex-Review b3ee1a9 → HOLD (kein P0/P1)
| Befund | Prüfung durch Claude | Korrektur | Studio-Nachweis |
|---|---|---|---|
| P2 Bots übernehmen den Ball per Nähe und umgehen Zweikampf-Chance/-Pause | bestätigt (auch Mitspieler-Bots hätten Menschen den Ball abgenommen) | Bots nehmen nur freie Bälle automatisch an; Abnahme vom Ballführer nur über den Zweikampf. Menschen (ohne Tackle-Taste) gewinnen den Ball weiter durch Nähe | Gegner-Bot 0,7–1,4 Studs am Ball eines Menschen, 4 × 3 s: 0 direkte Wechsel Mensch→Bot, je 1 Ballverlust über Zweikampf |
| Regression | – | – | 30 s Match: 8 Annahmen, 1 Schuss, 1 Tor, keine Fehler |

Kein Re-Review (nur P2).

## Offen
- Torrate (≈ 3 Tore/min im Solo) und Torwart-Paradequote am flüssigen Client abstimmen.
- Bot-gegen-Bot-Messung ohne regungslosen Menschen (für faire Teamwerte).
- 2-Client-Prüfung (Ballführer-Ring und Posen für Bot-Ballführer auf zweitem Client).
