# Claude-Antwort auf CODEX_REVIEW_3bf73c2 (M5 Requisiten)

Codex-Ergebnis: **MERGE – no material issue found** (Diff `19095e5 → 3bf73c2`). Kein P0/P1, daher kein zweiter Codex-Lauf.

| Hinweis | Bewertung | Maßnahme / Nachweis |
|---|---|---|
| Palme wird im Kommentar als nicht kollidierend beschrieben, `Props.place` erzwingt das aber nicht; offen, ob Sneaker/Schreibtisch kollidieren | berechtigt (hing allein an der Vorlage) | PalmMesh, Sneaker, AgencyDesk setzen jetzt im Code `CanCollide/CanQuery/CanTouch = false`. Studio-Play: Werte bestätigt, Raycast auf Spielerhöhe trifft PalmTrunkCollider bzw. Bank |
| Solo-Start mit und ohne `UP_Props` prüfen | erledigt | mit Vorlagen: alle 23 Meshes; ohne (Ordner umbenannt): Bauteil-Version, 694 Teile, keine Skriptfehler |
| „Niedrig“: ausgeblendete Detail-Meshes dürfen keine Hindernisse hinterlassen | erfüllt | Detail-Meshes werden auf „Niedrig“ aus der Welt genommen (Sneaker 0 in der Welt) und kollidieren ohnehin nicht |
| Vorlagen, Mesh-IDs, Herkunft nicht im Diff | richtig | Herkunft/Größen/Dreiecke in `PROPS_Cube3D_2026-11-11.md`; Meshes mit Roblox Cube 3D in Studio erzeugt, Aufträge ohne Logos/Marken; Vorlagen liegen nur in der Place-Datei |

Zusätzlich gefunden: Die Kollisionsform (Box/Hull) lässt sich per Skript nicht setzen; alle Vorlagen nutzen `Default`. Funktion per
Raycast bestätigt, Aufwand bei 23 verankerten Objekten vernachlässigbar. Im Protokoll vermerkt.
