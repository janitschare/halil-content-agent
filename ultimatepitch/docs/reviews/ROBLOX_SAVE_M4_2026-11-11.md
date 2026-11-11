# Sicherung auf Roblox – Stand M4 (11.11.2026)

Auftrag des Nutzers: „speichere erstmal alles ab auf roblox damit wir erstmal alle sicher haben was wir bis jetzt gemacht haben“.

## Was gespeichert wurde
- Quelle: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (lokal gespeichert 12:50:13, 342 194 Bytes), Code `5a5ee4f`.
- Vorher geprüft: 11/11 Skripte in Studio identisch mit dem Repo (Länge und Prüfsumme).
- Studio: Datei → **„Auf Roblox speichern als“** → Experience „UltimatePitch v0.4 Test (privat)“ → Ort überschreiben.
- Studio-Ausgabe 14:10:14: „„UltimatePitch v0.4 Test (privat)“ auf Roblox gespeichert.“, Dialog „Erfolgreich gespeichert!“.
- Danach im Fenster: PlaceId 123907912172096, GameId 10775152808, 11/11 Skripte mit denselben Prüfsummen.

## Was sich nicht geändert hat
- Die Experience bleibt **privat**. Keine Veröffentlichung für Spieler, keine Monetarisierung, keine Asset-Uploads.
- „Auf Roblox speichern“ legt eine neue Version im Versionsverlauf an. Live-Server (Roblox Player) starten weiterhin mit der
  zuletzt **veröffentlichten** Version vom 11.11. 00:05 (Stand M3b). Für einen Player-Test mit M4 wäre „Veröffentlichen“ nötig
  (eigene Freigabe).
- Ältere Versionen bleiben im Versionsverlauf der Experience wiederherstellbar.
- Die lokale Datei `aurora2.rbxlx` ist unverändert und bleibt die verbindliche Arbeitsdatei.

## Hinweis für die weitere Arbeit
Das Studio-Fenster (Prozess 11064) ist nach dem Speichern mit der Cloud-Place verknüpft (Titel „UltimatePitch v0.4 Test (privat)“).
Strg+S speichert dort auf Roblox, nicht in die Datei. Für die weitere Arbeit `aurora2.rbxlx` wieder über „Aus Datei öffnen“ laden
oder ausdrücklich „In Datei speichern als“ nutzen. Das Workspace-Attribut `UP_CareerStudioDataStore` fehlt in diesem Stand; Studio
speichert in der Cloud-Place deshalb keine Karriere (Status „off“) und greift nie auf den Live-Bestand zu.
