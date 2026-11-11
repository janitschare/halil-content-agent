# M5 „Requisiten“ – Cube-3D-Meshes statt Bauteil-Deko (11.11.2026)

Auftrag: Nutzer „Ja, ersetzen“ (nach dem Pilot-Sportwagen). Code `3bf73c2`, Place `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx`.

## Was ersetzt wurde
| Objekt | Anzahl | Vorlage (`ServerStorage.UP_Props`) | Dreiecke | Größe (Studs) | Kollision |
|---|---|---|---|---|---|
| Sportwagen gold / violett | 2 | `SportCarGold`, `SportCarViolet` | 3930 / 3896 | 6,9×3,5×10,7 / 7,2×3,4×10,8 | Box (geplant, s. u.) |
| Palme | 6 | `Palm` | 3000 | 13,2×17×12,9 | Mesh aus; unsichtbarer Stamm-Zylinder |
| Laterne | 6 | `StreetLamp` | 782 | 2,2×14,7×5,2 | ja; PointLight am Lampenkopf |
| Bank | 4 | `Bench` | 1034 | 6,4×3,7×2,6 | Box (geplant, s. u.) |
| Sneaker (Schaufenster) | 4 | `Sneaker` | 798 | 0,9×1,3×2,3 (Ausstellungsgröße 1,5×) | aus |
| Agentur-Schreibtisch | 1 | `AgencyDesk` | 944 | 8×2,4×2 | aus |

Zusammen rund 39 000 Dreiecke. Alle Meshes mit Cube 3D in Studio erzeugt (laut Roblox-DevForum ohne Kosten), Aufträge jeweils
mit „no logos, no text, no brand badges“. Assets liegen auf dem Konto des Entwicklers (freigegeben 11.11.).
Ein erster Laternen-Versuch lieferte nur ein flaches Teil (0,3×1,8×3) und wurde verworfen; ein Auftrag scheiterte beim Download.

Bewusst nicht ersetzt: Figuren (Zuschauer, Schaufensterpuppen mit Trikotnummern, Agent) und das UP-Monument (eigenes Design,
Schrift/Neon). Fahnen, Schilder und Fassaden bleiben Bauteile mit SurfaceGuis.

## Umsetzung
- Neues Modul `src/Props.lua`: `Props.place(name, base, parent, opts)` klont die Vorlage, setzt sie mit dem Fußpunkt
  (Mitte der Unterseite oder Attribut `BaseOffset`, bei Palme/Laterne aus den Mesh-Punkten berechnet) auf `base`.
  Fehlt die Vorlage, gibt es `nil` zurück und City/CityLook bauen wie bisher aus Grundteilen.
- `City.lua`: Palme (Mesh + Kübel mit Goldkante bleibt), Laterne (Ausleger zur Plaza-Mitte), Bank.
- `CityLook.lua`: Sportwagen (Mesh + Neon-Unterbodenlicht), Sneaker (Seitenansicht zur Straße), Schreibtisch.
  Sneaker, Schreibtisch und Unterbodenlicht bleiben `UP_CityDetail` (auf „Niedrig“ lokal entfernt).
- `default.project.json`, `build.ps1`, `build.py`: Modul `Props` ergänzt. Release-Datei und Installer enthalten die
  Vorlagen nicht und nutzen deshalb die Bauteil-Version.

## Prüfungen in Studio (Solo-Play, dieser Rechner)
| Prüfung | Ergebnis |
|---|---|
| Aufbau mit Vorlagen | PalmMesh 6, StreetLamp 6 (mit Licht), Bench 4, CarMesh 2, Sneaker 4, AgencyDesk 1; Stadt 566 statt 677 Bauteile |
| Aufbau ohne Vorlagen (Ordner umbenannt) | Bauteil-Version: PalmTrunk 24, LampPole 6, BenchSeat 4, CarBody 2, SneakerSole 4, Schreibtisch 1; 694 Bauteile; keine Fehler aus UltimatePitch-Skripten |
| Grafikprofil „Niedrig“ | Sneaker 0 in der Welt (entfernt), Palmen/Laternen/Bänke/Autos bleiben |
| Ausrichtung | Testaufstellung mit Markierung nach −Z: Autos, Bank, Schreibtisch richtig; Palmen- und Laternenfuß auf der Markierung |
| FPS Plaza-Blick, je 8 s | Hoch 18,2 · Mittel 18,2 · Niedrig 19,9 (M4: 19,2 / – / 21,0–21,8) |
| Gegentest „Niedrig“ | ohne Mesh-Requisiten 18,1 FPS, mit 19,4 FPS → kein messbarer Mehraufwand; Unterschiede zu M4 sind Schwankung/Systemlast |
| Release-Build (`build.ps1`) | `Props` in `UltimatePitch_v0.5.rbxlx` und Installer, 12/12 Skripte identisch |
| Kollision (nach Codex-Hinweis, Raycast auf Spielerhöhe) | Palmenstamm-Zylinder und Bank halten auf; PalmMesh, Sneaker, Schreibtisch CanCollide/CanQuery aus (jetzt im Code erzwungen); Laterne, Bank, Autos kollidieren |
| Kollisionsform | überall `Default` (Mesh-Umriss). Box/Hull lässt sich per Skript nicht setzen – Studio ignoriert die Zuweisung ohne Fehler; die Tabelle oben nennt nur die beabsichtigte Form |
| Place gespeichert | 15:34:36, 478 990 Bytes, SHA256 `0d3b28a83bc6686d…`, 12/12 Skripte identisch mit dem Fix-Commit, 7 Vorlagen enthalten, keine Testreste |

Bilder: `docs/art/M5_Props/` (0 Vorlagen, 1 Plaza, 2 Agentur mit Autos auf „Hoch“, 3 Sneaker-Schaufenster).

## Nicht geprüft / offen
- Handy und Roblox Player; Laufen gegen Palmen-/Laternen-Kollision nur per Aufbau geprüft, nicht mit der Spielfigur.
- Die Autos sind generische Supersportwagen ohne Logos; vor einer Veröffentlichung noch einmal auf zu große Nähe zu echten
  Modellen ansehen.
- Die Sneaker haben jetzt alle dieselbe Farbgebung (Weiß/Violett/Cyan); die vier Farben der Bauteil-Version entfallen.
