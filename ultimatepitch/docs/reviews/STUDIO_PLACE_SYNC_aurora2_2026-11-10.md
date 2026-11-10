# Bestehende Studio-Place auf aktuellen Stand gebracht, 2026-11-10

## Ergebnis
| Punkt | Ergebnis |
|---|---|
| Tatsächlich verwendeter Code-Commit | `0a1a1da3d1c1e8ad2a43215c6f8cc6191a0bfe99` (Branch-HEAD `ffe4e78`; `8d533fd`, `7a5e831`, `ffe4e78` nur Berichte; `git diff 0a1a1da..HEAD -- src default.project.json` leer) |
| Rojo verbunden | **JA** (Rojo 7.7.1, `rojo serve default.project.json`, Port 34872; für die Wiederöffnungsprüfung danach bewusst gestoppt) |
| Vier Skripte identisch | **JA** (4/4 vor dem Speichern, in der gespeicherten Datei und nach erneutem Öffnen) |
| Aktualisierte lokale Datei dauerhaft gespeichert | **JA** – `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx`, 190 629 Bytes, 10.11.2026 16:02:29, SHA256 `6A252D308A512A30F6AF98A86A44B39B315B1E99D8795BFCDB4096623C5569BA` |
| Erneutes Öffnen erfolgreich | **JA** – Place geschlossen, Rojo gestoppt, Datei neu geöffnet, Skripte direkt aus dem geladenen Dokument geprüft: 4/4 |
| Backup vorhanden und geprüft | **JA** – siehe unten |

## Backup (vor jeder Änderung angelegt, danach unverändert)
Ordner `experiments/v04-studio/backup_2026-11-10_vor_sync/` (lokal, `*.rbxlx` gitignored):
- `UltimatePitch_v04_aurora2_6ea6b03.rbxlx` – 66 447 Bytes, SHA256 `36547579877875A5A012DF39801CE79D43C0C3D06327335CBAE6F2DE1732E4A8`
  = SHA256 des Originals vor dem Speichern. Enthält Server/Dome/Client = Commit `6ea6b03` und den einzigartigen alten
  AuroraFX (10634 / 1547154470).
- `AuroraFX_alt_aus_aurora2.lua` – derselbe alte AuroraFX als Einzeldatei, 10 634 Bytes, SHA256 `6B989ECE00309EC3…`.
Wiederherstellung: Backup-Datei zurück nach `UltimatePitch_v04_aurora2.rbxlx` kopieren (Studio vorher schließen).

## Prüfsummen (Länge / h = (h·31 + Byte) mod 2³², LF-normalisiert)
| Skript | Branch `0a1a1da` | nach Rojo-Sync | in Datei | nach erneutem Öffnen |
|---|---|---|---|---|
| Server.server.lua | 58065 / 408373590 | ✓ | ✓ | ✓ |
| Dome.lua | 17604 / 3487982571 | ✓ | ✓ | ✓ |
| Client.client.lua | 19409 / 1672929634 | ✓ | ✓ | ✓ |
| AuroraFX.lua | 30967 / 1548070162 | ✓ | ✓ | ✓ |

Lighting: `LightingStyle = Realistic`, `PrioritizeLightingQuality = false` (nach Sync, in der Datei als Token 0, nach
erneutem Öffnen). `VERSION = "0.5"`. In ServerScriptService/StarterPlayerScripts nur die beiden UltimatePitch-Skripte.

## Abweichungen / Hinweise
- Rojo setzte im geöffneten Dokument den DataModel-Namen auf den Projektnamen „UltimatePitch“; ohne Einfluss auf Inhalt.
- Beim erneuten Öffnen zeigte Studio den Hinweis „Migration von Kompatibilitäts- zu Voxel-Beleuchtung“ (automatische
  Umstellung einer alten Technology-Einstellung im geöffneten Dokument, nur „Fortfahren“ möglich). Nicht gespeichert;
  `LightingStyle` blieb Realistic. Die Datei wurde nach dem Wiederöffnen nicht erneut gespeichert.
- Zusätzlich existiert aus dem vorherigen Schritt `experiments/v05-studio/UltimatePitch_v05_0a1a1da.rbxlx` (gleicher Stand).
- Keine Experience erstellt, nichts veröffentlicht, keine Monetarisierung, keine neuen Funktionen, kein Spieltest.
