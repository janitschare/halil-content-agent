# Claude-Antwort: Meilenstein R15-Bewegung (ab5ec5c), 2026-11-07

## Meilenstein
Prozedurale R15-Bewegungsebene im Client (`AuroraFX.startMotion`), rein optisch:
Sprint-Vorlage, Fußtipps beim Dribbeln, Annahme-Pose bei Besitzwechsel, Torjubel des Torteams (Arme im V);
Server lässt die Bots des Torteams beim Tor zweimal springen. Gelenkachsen vorher in Studio gemessen
(Schulter +X = vorn/oben, rechte +Z / linke −Z = seitlich hoch).

## Studio-Solo
| Prüfung | Ergebnis |
|---|---|
| Sprint (echte Eingabe Shift+W) | Tempo bis 26,1; 58/59 Sprint-Frames mit Oberkörper-Vorlage 0,20 rad |
| Dribbel-Fußtipps | 26 Tipps in 319 Besitz-Frames |
| Annahme | Server-Annahme bestätigt; Hüfte in den ersten 0,35 s max 0,70 rad (Sollwert) |
| Torjubel | eigener Spieler und Bots des Torteams je 113 Frames Arme im V (Schulter bis 2,58 rad); Bild bestätigt |
| Konsole | keine Skriptfehler |

## Codex-Review ab5ec5c → HOLD (kein P0/P1)
| Befund | Prüfung durch Claude | Korrektur |
|---|---|---|
| P2 `receive`/`celebrate` mit starken Character-Schlüsseln (entfernte Figuren bleiben hängen) | bestätigt | beide Tabellen mit schwachen Schlüsseln |
| Hinweis: `jointsOf` cached evtl. unvollständige Gelenke beim Spawn | plausibel | Cache nur bei vollständig gefundenen Gelenken |

Kein Re-Review (nur P2, Bridge-Regel). Regression nach der Korrektur: Jubel und Annahme-Pose unverändert, keine Fehler.

## Offen
- 2-Client-Sichtprüfung (Posen anderer Spieler, konkurrierende Gelenkzugriffe, Kamera > 150 Studs, Respawn) – braucht Client-FPS ≥ 30.
- Reduced Motion: Figurenposen bleiben aktiv (keine Kamera-/Bildschirmbewegung); bewusst so, kann bei Bedarf eingeschränkt werden.
