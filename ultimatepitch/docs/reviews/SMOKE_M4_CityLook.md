# M4 „City Look“ – Studio-Abnahme

Datum: 11.11.2026 · Code: `5a409aa` · Ziel: `docs/art/ART_DIRECTION_Referenz_2026-11-11.md`
Place: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (Rojo Live Sync), Solo-Play in Studio

## Bilder (`docs/art/M4_2026-11-11/`)
| Bild | Inhalt |
|---|---|
| 1_plaza_dome | Plaza → Dome: UP-Monument mit Leuchtball und Goldring, Wegweiser, Rangliste, Palmen, Dome mit Name, Videowand, Banner, LED, Lichtkegel |
| 2_spawn_blick | Blick der Spielerkamera vom Spawn |
| 3_fashion_district | Schaufenster mit Puppen in Trikots, Sneaker, „TRIKOT-SHOP“, Neonrahmen, Palme |
| 4_player_agency | Agent, Schreibtisch, Taktiktafel (Formation), „VERTRÄGE · TRANSFERS · KARRIERE · BALD“, Sportwagen |
| 5_street_court | Graffiti „VOM BOLZPLATZ“, „STREET“, „UP #10“, Zuschauer auf den Stufen, Sportwagen |
| 6_ueberblick_court_dome | Überblick vom Court Richtung Dome (gleiche Kamera wie `docs/art/IST_2026-11-11/ist_court_dome.jpg`) |

Hinweis zum Ist-Bild `ist_plaza_dome.jpg`: Die Kamera (z = -268) stand versehentlich **in** der Academy hinter deren
Glasfront; Roblox-Glas wäscht das Bild aus und blendet SurfaceGuis dahinter aus. Der Vergleich der Plaza nutzt deshalb
eine Kamera knapp davor (z = -256).

## Prüfungen
| Prüfung | Ergebnis |
|---|---|
| Kompilierung aller 11 Skripte (`loadstring`) | OK |
| Start ohne Fehler aus UltimatePitch-Skripten | OK (Konsole nur mit bekannten Studio-Meldungen) |
| Aufbau | CityLook 459 Teile (Stadt gesamt 677), 8 Figuren (4 Zuschauer, 3 Puppen, 1 Agent), 41 Deko-Objekte, 8 Effekte, 2 Drehmodelle |
| Grafikprofil „Hoch“ | 41/41 Deko in der Welt, Effekte an; Ball und Ring drehen sich |
| Grafikprofil „Niedrig“ | 0/41 Deko in der Welt, 0/19 Effekte an (Partikel, Lichtkegel, Lichter, dekorative SurfaceGuis) |
| Live-Inhalte | Videowand: Spruch und Ticker „5 GEGEN 5 · PAD VOR DEM EINGANG BETRETEN“; Rangliste mit Spielername und Coins |
| Schaufenster-SurfaceGuis | sichtbar, nachdem die Scheiben von Glas auf transparentes Material umgestellt wurden (Glas blendet GUIs aus) |

## Leistung auf diesem Rechner (i5-3230M / HD 4000, Studio-Play mit Server im selben Prozess, Plaza-Blick, je 8 s)
| Profil | mit City Look | City Look lokal entfernt | Kosten |
|---|---|---|---|
| Hoch | 19,2 FPS | 24,3 FPS | ca. 21 % |
| Mittel | 17,7 FPS | – | (Mittel ändert am City Look nichts, Schwankung) |
| Niedrig (erste Fassung) | 20,7 FPS | 26,1 FPS | ca. 21 % |
| Niedrig (Lichter + dekorative GUIs aus) | 21,8 / 21,0 FPS | 24,9 FPS | ca. 14 % |

Werte schwanken um etwa ±1 FPS. Im Roblox Player (eigener Prozess, ohne Studio-Editor und Server) liegen sie höher.

## Im Test gefundene und behobene Punkte
- Leuchtball hinter Glashülle wirkte dunkel → undurchsichtiger Leuchtkern mit dunklen Feldern.
- Pad-Schild (feste Pixelgröße) verdeckte von der Plaza die Videowand → Größe in Studs, tiefer.
- Kübel-Leuchtfläche zu grell → nur goldene Kante.
- Schaufenster aus Glas blendeten Trikotnummern und Taktiktafel aus → transparentes Kunststoffmaterial.
- Auf „Niedrig“ kosteten Lichter und dekorative GUIs mit → werden dort abgeschaltet.

## Nicht geprüft
- Mobile/Touch und Roblox Player.
- Scout-Markierung: per Datenabfrage geprüft (BillboardGui am Kopf des Scouts, aktiv, „?“ auf Stufe 1), nicht im Bild.
  Talent-Karte im Scout-Dialog nur per Code geprüft (kein erneuter Match-Durchlauf).
- Mehrere Spieler in der Rangliste.

## Codex-Review (`CODEX_REVIEW_5a409aa.md`, HOLD, 1× P2) und Nachtest (`5a5ee4f`)
| Befund | Maßnahme | Nachweis (Studio, Solo) |
|---|---|---|
| P2: Monument-Drehung und Scout-Wippen ignorieren reduzierte Bewegung | gleicher Getter wie Matchday (`AuroraFX.reducedMotion`) in CityFX und CareerUI | Taste M an: Drehung 0,000 rad in 1,5 s, Marker fest bei 3,20; M aus: 0,376 rad, Marker 2,98–3,44 |
| Hinweis: Fehler in CityLook.build würde Career.init blockieren | Aufbau in `pcall`, Warnung statt Abbruch | Start fehlerfrei (wie zuvor) |
| Profilwechsel „Niedrig“ → „Hoch“ | – | Deko 41/41 wieder in der Welt |

Kein weiterer Codex-Lauf (nur P2). Place gespeichert 12:50:13, 342 194 Bytes, SHA256 `344c20cf4b296a5e…`, 11/11 Skripte identisch mit `5a5ee4f`.
