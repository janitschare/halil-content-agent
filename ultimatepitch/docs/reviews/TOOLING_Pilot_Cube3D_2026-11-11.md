# 3D-Werkzeuge und Cube-3D-Pilot (11.11.2026)

Freigabe: Nutzer „ja installiere alles was wir brauchen und was du empfiehlst“ (Antwort auf die Empfehlung: Cube 3D,
Blender, gltfpack; BlenderGIS und Houdini weglassen; Frage nach Assets für den Pilot).

## Installiert (portabel, ohne Installer und ohne Adminrechte, unter `%LOCALAPPDATA%\UltimatePitchTools`)
| Werkzeug | Quelle | Prüfung | Ergebnis |
|---|---|---|---|
| Blender 5.2.4 LTS (`blender-5.2.4-windows-x64`) | download.blender.org, ZIP 405 779 142 Bytes | SHA256 `bbd78f89…9d967c` = offizielle `.sha256`; Signatur „Blender Foundation“ gültig | ohne Oberfläche lauffähig (Python 3.13); Testmodell als `.glb` exportiert (316 Dreiecke) |
| gltfpack 1.3.0 (npm `gltfpack`, meshoptimizer von zeux) | npm, `--ignore-scripts`, WebAssembly, keine nativen Dateien | Paket-Repository github.com/zeux/meshoptimizer | Testmodell 23 776 → 10 904 Bytes |

Hinweis Blender: aus Git Bash mit gemischten Pfaden (`C:\…/…`) meldet Windows „Side-by-Side-Konfiguration ungültig“.
Zuverlässig: im Blender-Ordner starten, z. B. `cd …/blender-5.2.4-windows-x64 && ./blender.exe -b --factory-startup --python skript.py`.
Die Oberfläche von Blender wird nicht gebraucht (HD 4000 erfüllt deren OpenGL-Anforderung nicht sicher); gearbeitet wird per Skript.

Nicht installiert: BlenderGIS (fiktive Stadt, keine Geodaten nötig), SideFX Labs/Houdini (Lizenz, zu schwer für diesen Rechner).

## Cube-3D-Pilot (Studio MCP `generate_mesh`)
- Kosten: laut Roblox-DevForum („[Beta] Cube 3D Model Updates“) keine Kosten für die Mesh-Generierung, Grenze 30 pro Minute.
- Auftrag: futuristischer Sportwagen, Lack dunkelviolett mit Cyan-Akzenten, **ohne Logos, Schrift oder Markenzeichen**,
  Rahmen 6 × 3,2 × 12 Studs, höchstens 4000 Dreiecke, ein Stück.
- Ergebnis: ein MeshPart, 6 × 2,8 × 9 Studs, **3896 Dreiecke**, 3855 Punkte. Roblox hat dafür auf dem Konto ein Mesh
  (`rbxassetid://109070258849625`) und eine Textur (`rbxassetid://72916745462909`) angelegt (freigegeben).
- In `aurora2.rbxlx` unter `Workspace.UP_Pilot.PilotSportCar_Cube3D` (Attribut `Pilot`), vor der Player Agency neben den
  beiden Bauteil-Autos, verankert. Kein Code geändert; zum Entfernen genügt das Löschen des Ordners `UP_Pilot`.
- Bild: `docs/art/Pilot_Cube3D/auto_vergleich.jpg` (Studio-Play, Profil „Niedrig“ automatisch).
  Felgen, Scheiben, Spoiler und Lack sind klar detaillierter als die Bauteil-Autos dahinter.
- Leistung: ein Mesh mit 3,9 Tsd. Dreiecken; keine eigene FPS-Messung (Unterschied läge unter der Messschwankung von ±1 FPS).
- Offen: Die Form ist ein generischer Supersportwagen ohne Logos. Vor dem festen Einsatz noch einmal auf zu große Nähe zu
  einem echten Modell prüfen.

## Studio-Fenster
- Nach „Auf Roblox speichern als“ war das Fenster mit der Cloud-Place verknüpft und hielt die Dateisperre
  (`aurora2.rbxlx.lock`, PID 11064), sodass neue Fenster die Datei nur schreibgeschützt öffneten. Das leere Fenster wurde
  beendet; `aurora2.rbxlx` ist wieder lokal und beschreibbar offen (PID 12772), Rojo verbunden.
- Die MCP-Verbindung mit dem Namen „UltimatePitch_v04_aurora2.rbxlx“ (`00d07ff8…`) gehört tatsächlich zum v05-Fenster
  (PID 5984, `experiments/v05-studio/UltimatePitch_v05_0a1a1da.rbxlx`). Dort wurde nichts geändert.
- Gespeichert 14:55:16, 374 660 Bytes, SHA256 `08b7b7c87abe3368…`, 11/11 Skripte identisch mit dem Repo (`5a5ee4f`).
