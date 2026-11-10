# Synchronisationsstatus Studio ↔ Branch, 2026-11-10 (nur lesende Prüfung)

**Ergebnis: NICHT SYNCHRON. Rojo ist nicht verbunden.**

## Branch
- `claude/intelligent-einstein-d3v7qz`: lokal = GitHub = `0a1a1da3d1c1e8ad2a43215c6f8cc6191a0bfe99`, keine uncommitteten Änderungen.

## Studio
- 1 Instanz (gestartet 10.11.2026 13:56), geöffnet: lokale Datei
  `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (PlaceId 0, Edit-Modus, kein laufender Test).
- Dateistand der .rbxlx: zuletzt gespeichert 06.11.2026 23:48.

## Rojo
- Kein Rojo-Prozess; `http://localhost:34872/api/rojo` antwortet nicht.
- Der Rojo-Server aus der Sitzung vom 07.11. endete mit dieser Sitzung. Die damaligen Live-Syncs lagen nur im
  geöffneten Studio-Dokument und wurden nie in die .rbxlx gespeichert.

## Vergleich der vier Skripte (Länge/Prüfsumme, LF-normalisiert, h = (h·31 + Byte) mod 2³²)
| Skript | Branch `0a1a1da` | Studio | Status |
|---|---|---|---|
| Server.server.lua | 58065 / 408373590 | 35587 / 3500056897 | **abweichend** – identisch mit Commit `6ea6b03` (06.11.) |
| Dome.lua | 17604 / 3487982571 | 10039 / 437813099 | **abweichend** – identisch mit `6ea6b03` |
| Client.client.lua | 19409 / 1672929634 | 8887 / 361166754 | **abweichend** – identisch mit `6ea6b03` |
| AuroraFX.lua | 30967 / 1548070162 | 10634 / 1547154470 | **abweichend** – passt zu keinem Commit (Zwischenstand vor `6ea6b03`) |

Weitere Merkmale des Studio-Stands: `VERSION = "0.4"`, kein Dribbling, kein `BallCarrier`, `Lighting.LightingStyle = Soft`.
Damit fehlen in Studio alle Arbeiten ab 07.11. (Aurora-Zuordnung, Speedhack-Abwehr, Trikots, Watchdog, v0.5-Slice,
Ballgefühl, R15-Bewegung, Bot-KI v2, Lighting Realistic).

## Nicht verändert
Keine Place erstellt, nichts wiederhergestellt, keine Datei überschrieben, nichts gespeichert oder veröffentlicht.

## Möglicher nächster Schritt (nicht ausgeführt, Freigabe nötig)
`rojo serve` starten und das Rojo-Plugin verbinden: Rojo würde die vier Skripte in der geöffneten Place durch den
Branch-Stand ersetzen (Live Sync, die .rbxlx-Datei bleibt bis zum Speichern unverändert).
