# M3b – Test mit echtem DataStore in der privaten Test-Place

Datum: 10./11.11.2026 · Code: `f1c99f7` · Freigabe: Nutzer („Ja, Test-Place“, Antwort auf „Soll ich die private Test-Place
veröffentlichen, um den echten DataStore zu testen?“)

## Test-Place
- „UltimatePitch v0.4 Test (privat)“, **PlaceId 123907912172096**, GameId 10775152808 (am 07.11. von Claude als neue, private
  Experience angelegt). Team Create aus.
- Vorher: Version 2 mit v0.4-Code + inaktiven Test-Sonden (`UP_SecurityClient`, `UP_VisualProbe`, `UP_PerfProbe`, warten auf
  `ReplicatedStorage.UP_Sec` bzw. messen nur). Version 2 bleibt im Versionsverlauf der Experience wiederherstellbar.
- In Studio über die Startseite geöffnet (kein zusätzlicher Studio-Prozess). Rojo hat den aktuellen Code eingespielt;
  9/9 Skripte identisch mit `f1c99f7` (Längen/Hashes wie in `CLAUDE_RESPONSE_M3b_f1c99f7.md`). Test-Sonden unverändert gelassen.

## Geänderte Einstellungen (nur diese Test-Experience)
- Spieleinstellungen → Sicherheit → **„Zugriff auf API-Dienste für Studio aktivieren“: an** (vorher aus).
  HTTP-Anfragen, Drittanbieter-Verkäufe und -Teleports blieben aus.
- Workspace-Attribut `UP_CareerStudioDataStore = true`: Studio nutzt den **getrennten** Bestand `UP_Career_v1_STUDIO`.
  Live-Server der Test-Place nutzen `UP_Career_v1`. Das Attribut ist bewusst in der Test-Place geblieben.

## Ergebnisse (echter Roblox-DataStore `UP_Career_v1_STUDIO`, Studio-Play, Spieler Eray260614)
| Schritt | Ergebnis |
|---|---|
| Edit-Kontext vor Freischaltung | `502 … Access forbidden` (erwartet) |
| Edit-Kontext nach Freischaltung | weiterhin „forbidden“ (Studio übernimmt die Einstellung im Edit-Kontext offenbar erst nach Neustart); Play-Kontext funktioniert |
| Sitzung 1, Beitritt | `CareerSave=ok`; Datensatz `u_4059885341` neu angelegt mit Sperre (job + sid), Version 1, **UserIds-Metadaten [4059885341]** |
| Street-Court-Match (3v3, verloren 5:9) | 10 Coins, „Local Talent“; DataStore zeigt zu dem Zeitpunkt den letzten Autosave (Sperre erneuert) |
| Scout-Vertrag, Kauf Neon-Schuhe | 60 → 20 Coins, „Scouted Player“, Neon-Schuhe angelegt |
| Play beenden (Verlassen + BindToClose) | Abschluss geschrieben, Sperre freigegeben (`releasedBy` = Kennung von Sitzung 1) |
| Sitzung 2, Beitritt | **nach 0,3 s geladen: 20 Coins, „Scouted Player“, Neon-Schuhe angelegt, 1 Match**, leaderstats 20; neue Sperre (neue job/sid); Datensatz-Version 8 |

## Veröffentlichung
- Datei → Veröffentlichen: Studio-Ausgabe „Neue Änderungen in „UltimatePitch v0.4-Test (privat)“ auf Roblox veröffentlicht.“
  (00:05:22). Ein zweiter Auslöser (Alt+P) kann eine inhaltsgleiche weitere Version erzeugt haben.
- Die Experience bleibt privat; Sichtbarkeit wurde nicht geändert. Keine Monetarisierung, keine Asset-Uploads.
- Danach Rojo in diesem Fenster getrennt und die Test-Place geschlossen (keine weiteren Änderungen).

## Nicht geprüft
- Live-Server im Roblox Player (Bestand `UP_Career_v1`): der Player-Start war am 07.11. am Login blockiert.
- Serverwechsel zwischen zwei echten Servern.
