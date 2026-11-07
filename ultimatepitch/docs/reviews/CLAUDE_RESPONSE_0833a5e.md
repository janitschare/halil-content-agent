# Claude-Antwort: Meilenstein Ballgefühl (0833a5e) und Korrektur (955c940), 2026-11-07

## Meilenstein
Serverseitiges Dribbling mit Ballannahme, Ballbesitz (`State@BallOwner`), Leuchtring in Teamfarbe unter dem
Besitzer, Bot-KI: eigenes Team lässt dem Menschen den Ball, Gegner tackeln aus 3 Studs mit 35 % Chance.

Studio-Solo vor dem Review: Dribbling bei Lauftempo 18 mit Ball 1,6–1,95 Studs vor dem Fuß; scharfer Ball
(50 Studs/s) nach 0,42 s angenommen, danach 0,4 Studs/s, 2,4 Studs vor dem Fuß; Ballverluste nur durch
Bot-Zweikampf aus 2,4–3,0 Studs. Keine Skriptfehler.

## Codex-Review 0833a5e → HOLD
| Befund | Prüfung durch Claude | Korrektur 955c940 | Studio-Nachweis |
|---|---|---|---|
| P1 Figurgeschwindigkeit (clientbesessene Physik) ging ungeprüft in den Ball | bestätigt; mein Kommentar „Client sendet nichts“ war irreführend | nur endliche Werte, Begrenzung auf BaseSpeed × Sprintfaktor, Ball absolut ≤ 45 Studs/s | serverbesessene Figur mit 981 Studs/s → Ball max 22,6 Studs/s; Bewegungsprüfung 28 Korrekturen (ein erster Versuch mit clientbesessener Figur war ungültig: Replikation überschrieb den Wert, Figur 0 Studs/s) |
| P2 Ballannahme ohne Höhenprüfung | bestätigt | Fuß-/Ballhöhe ± 2,5 Studs | Sprung über den Ball: 5 Luft-Frames, 0 × Besitz |
| Hinweis: Ring dreht trotz Reduced Motion | bestätigt | Rotation aus bei Reduced Motion | nicht separat getestet |
| Regression | – | – | Dribbling 13/13 Besitz, Ø 2,58 Studs |

## Codex-Re-Review 955c940 → NO MATERIAL ISSUE FOUND
Bericht: `CODEX_REVIEW_955c940.md`. Damit kein weiterer Review-Lauf (Bridge-Regel).

## Offen
- 2-Client-Prüfung des Dribblings (Besitzwechsel zwischen zwei Menschen, Ring auf dem Gegenclient) – braucht Client-FPS ≥ 30 für die visuelle Beurteilung, Netzwerkpfad nutzt ein normales State-Attribut.
- Unterschiedliche Avatargrößen bei der Höhenprüfung.
- Feintuning nach echtem Spielgefühl (DribbleGain, TackleChance) am flüssigen Client.
