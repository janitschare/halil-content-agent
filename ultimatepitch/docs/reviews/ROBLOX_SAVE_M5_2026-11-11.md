# Sicherung auf Roblox – Stand M5 „Requisiten“ (11.11.2026)

Auftrag des Nutzers: „Ja, speichern“ (Rückfrage nach M5, ob der neue Stand in die private Test-Place soll).

## Was gespeichert wurde
- Quelle: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (lokal gespeichert 15:34:36, 478 990 Bytes,
  SHA256 `0d3b28a83bc6686d9481aa66f16d5899f0f5e95ef38a0cbe78c4b516345a6309`), Code `fab1c3f` (Docs `6257801`).
- Vorher geprüft: 12/12 Skripte in Studio identisch mit dem Repo (Prüfsumme), 7 Mesh-Vorlagen in `ServerStorage.UP_Props`.
- Studio: Datei → **„Auf Roblox speichern als“** → Experience „UltimatePitch v0.4 Test (privat)“ → Ort überschreiben.
- Studio-Ausgabe 18:17:34: „„UltimatePitch v0.4 Test (privat)“ auf Roblox gespeichert.“, Dialog „Erfolgreich gespeichert!“.
- Danach im Fenster: PlaceId 123907912172096, GameId 10775152808, 12/12 Skripte mit denselben Prüfsummen, 7 Vorlagen.

## Was sich nicht geändert hat
- Die Experience bleibt **privat**. Keine Veröffentlichung, keine Monetarisierung. Die Mesh-Assets stammen aus Cube 3D
  (Freigabe 11.11.), es wurden für diese Sicherung keine weiteren Assets hochgeladen.
- „Auf Roblox speichern“ legt nur eine neue Version im Versionsverlauf an; Live-Server (Roblox Player) starten weiter mit der
  zuletzt veröffentlichten Version (Stand M3b). Ein Player-Test mit M5 bräuchte „Veröffentlichen“ (eigene Freigabe).
- Die M4-Sicherung von 14:10 bleibt im Versionsverlauf wiederherstellbar.
- `UP_CareerStudioDataStore` fehlt weiterhin; Studio speichert in der Cloud-Place keine Karriere.

## Lokale Arbeitsdatei
- Nach dem Speichern war das Fenster mit der Cloud-Place verknüpft. Ort über Datei → „Ort schließen“ geschlossen; die Sperrdatei
  wurde freigegeben, `aurora2.rbxlx` unverändert (gleiche Größe, Zeit und SHA256).
- `aurora2.rbxlx` im selben Studio-Prozess (12772) wieder aus der Datei geöffnet, Rojo verbunden; 12/12 Skripte identisch,
  7 Vorlagen vorhanden. Die Datei bleibt die verbindliche Arbeitsdatei.
