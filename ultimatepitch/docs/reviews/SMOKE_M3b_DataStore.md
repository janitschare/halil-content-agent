# M3b – Dauerhafter Speicherstand: Studio-Prüfung

Datum: 10.11.2026 · Code: `76e072f` (erste Fassung), `1f1903b` (nach Codex-Fixes) · Freigabe DataStore: Nutzer, 10.11.2026
Place: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (lokal, **nicht veröffentlicht**, PlaceId 0)

## Grenze dieser Prüfung
Roblox erlaubt DataStore-Zugriffe nur in veröffentlichten Places (in Studio zusätzlich „Studio-Zugriff auf API-Dienste“).
Die verbindliche Place ist lokal und unveröffentlicht. Deshalb wurde **kein echter DataStore** angesprochen. Geprüft wurden:
1. die Speicherlogik (`CareerStore`) mit einer Speicher-Attrappe, die dieselbe `UpdateAsync`-Schnittstelle bietet und Werte
   wie der echte Store als JSON ablegt;
2. die vollständige Anbindung im laufenden Spiel über den Studio-Testmodus (Attrappe statt DataStore, sonst identischer Code);
3. das Verhalten der unveröffentlichten Place ohne Testmodus.

Ein Test gegen einen echten DataStore erfordert Veröffentlichen in eine Test-Place (Studio nutzt dann den getrennten Bestand
`UP_Career_v1_STUDIO`) – nicht ohne Freigabe.

## Erste Fassung (`76e072f`)
- Selbsttest 16/16 PASS; Anbindung im Spiel: Laden eines älteren Stands (500 Coins), Kauf, Autosave, Neubeitritt (440 Coins +
  Binde), Störung (Laden „error“ nach ~28 s, gespeicherter Stand unangetastet), Fallback „off“ – alles wie erwartet.
- Codex (`CODEX_REVIEW_76e072f.md`): HOLD mit 2× P1 (Sperrlogik) und 1× P2 (Studio auf Live-Bestand). Behoben in `1f1903b`.

## Nach den Codex-Fixes (`1f1903b`)

### Selbsttest `tests/CareerStore_selftest.lua` (Studio, Edit-Kontext) – 21/21 PASS
Neuer Spieler · Sperre mit Ladekennung · Zwischenspeichern · Freigabe · anderer Server lädt freigegebenen Stand sofort ·
Bereinigung (4 Fälle) · **frische fremde Sperre wird nicht übernommen** (Warten, dann „error“; Halter speichert weiter) ·
**erneuerte Sperre bleibt geschützt** · abgelaufene Sperre ohne Warten übernommen · **Codex-Sequenz A lädt / B übernimmt
abgelaufene Sperre, speichert 200, gibt frei / A speichert 100 → „lost“, 200 bleibt** · alter Server kann auch keine neue Sperre
setzen · **Wiederbeitritt auf demselben Server: alte Ladekennung „lost“** · Warten bei Spieleraustritt abgebrochen · Fehler-
wiederholung · Dauerfehler · neueres Schema.

Hinweis: Studio hält `require`-Ergebnisse im Edit-Kontext im Cache; ein erster Lauf traf deshalb noch das alte Modul (9 FAIL).
Der Test lädt das Modul seither als Klon; danach 21/21.

### Anbindung im Spiel (Studio-Testmodus, Solo)
| Schritt | Ergebnis |
|---|---|
| Beitritt | `CareerSave=ok`, Sperre mit eigener Ladekennung |
| Älterer Stand (320 Coins, goldene Schuhe), Neubeitritt | 320 Coins, „Local Talent“, goldene Schuhe angelegt, neue Ladekennung |
| Autosave ohne Änderung | Sperre erneuert (gleiche Kennung, neue Zeit), Werte unverändert |
| Fremde frische Sperre, nach 7 s freigegeben (777 Coins) | Zustand `loading` → `ok` nach 10 s, 777 Coins geladen, **keine Übernahme** |

### Unveröffentlichte Place ohne Testmodus
`[Career] Speicherstand: aus (nur diese Sitzung)`, `CareerSave=off`, keine Prüfschnittstelle, keine Fehler, Anzeige
„● OHNE SPEICHERN (TEST)“ (Screenshot 7). Test-Attribute vor dem Speichern der Place entfernt (geprüft: beide `nil`).

## Nicht geprüft
- Echter DataStore (Budget, Drosselung, Persistenz über echte Server) – braucht Veröffentlichung in eine Test-Place.
- Serverwechsel mit zwei echten Servern – nur mit simulierten Servern im Selbsttest und mit nachgestellter Fremdsperre im Spiel.
- BindToClose beim Herunterfahren eines Live-Servers.
