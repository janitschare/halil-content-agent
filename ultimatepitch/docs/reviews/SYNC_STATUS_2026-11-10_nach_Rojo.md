# Synchronisationsstatus nach Rojo-Sync, 2026-11-10

**Ergebnis: SYNCHRON (4/4). Rojo verbunden.**

Vorher (siehe `SYNC_STATUS_2026-11-10.md`): Studio-Place enthielt Stand `6ea6b03`, Rojo nicht verbunden.

## Ablauf (mit Freigabe des Nutzers)
1. `rojo serve default.project.json` (Rojo 7.7.1, Port 34872) aus dem Branch-Stand `0a1a1da` gestartet.
2. In Studio (geöffnet: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx`) das Rojo-Plugin verbunden.
   Bestätigungsdialog listete nur: Place-Name, Lighting, UltimatePitchServer + Dome, UltimatePitchClient + AuroraFX.
3. Sync bestätigt.

## Prüfung danach (Länge/Prüfsumme, h = (h·31 + Byte) mod 2³²)
| Skript | Branch `0a1a1da` | Studio | |
|---|---|---|---|
| Server.server.lua | 58065 / 408373590 | 58065 / 408373590 | ✓ |
| Dome.lua | 17604 / 3487982571 | 17604 / 3487982571 | ✓ |
| Client.client.lua | 19409 / 1672929634 | 19409 / 1672929634 | ✓ |
| AuroraFX.lua | 30967 / 1548070162 | 30967 / 1548070162 | ✓ |

Weitere Merkmale: `VERSION = "0.5"`, `Lighting.LightingStyle = Realistic`, `PrioritizeLightingQuality = false`.
In ServerScriptService/StarterPlayerScripts nur die beiden UltimatePitch-Skripte (keine Testskripte).

## Wichtig
- Der Sync liegt im geöffneten Studio-Dokument. Die Datei `UltimatePitch_v04_aurora2.rbxlx` auf der Festplatte ist
  **nicht gespeichert** und enthält weiter den alten Stand. Rojo-Server läuft nur, solange die Claude-Code-Sitzung läuft.
- Keine neue Place erstellt, nichts wiederhergestellt, nichts veröffentlicht. Kein Spieltest ausgeführt.
