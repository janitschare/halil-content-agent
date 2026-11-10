# Claude-Antwort: M3b dauerhafter Speicherstand (76e072f → 1f1903b → f1c99f7), 2026-11-10

Freigabe: Der Nutzer hat den DataStore am 10.11.2026 ausdrücklich freigegeben („Ja, DataStore bauen“). Keine Veröffentlichung,
kein Robux, keine Asset-Uploads.

## Bezug zur verbindlichen Place
Per Rojo in `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` eingespielt und gespeichert (23:49:34, 291 223 Bytes,
SHA256 `556546d7c1bc470a…`). 9/9 Skripte identisch mit `f1c99f7` (LF-normalisiert, `h = h*31 + byte mod 2^32`):

| Skript | Länge | Hash |
|---|---|---|
| UltimatePitchServer | 76045 | 4294347609 |
| UltimatePitchClient | 27899 | 2177614603 |
| Dome | 17604 | 3487982571 |
| City | 13721 | 2294750658 |
| Career | 21034 | 3125612940 |
| CareerStore (neu) | 8361 | 3661040779 |
| AuroraFX | 30885 | 2388574878 |
| Matchday | 11373 | 3227942360 |
| CareerUI | 13465 | 27594358 |

## Codex-Runde 1 (`CODEX_REVIEW_76e072f.md`, HOLD)
| Befund | Bewertung | Maßnahme (`1f1903b`) | Nachweis |
|---|---|---|---|
| P1: alter Server darf nach fremder Freigabe wieder schreiben (fehlende Sperre galt nicht als fremd) | berechtigt | Speichern nur mit exakt eigener Sperre (job + Ladekennung `sid`), fehlende Sperre = „lost“ | Selbsttest: Codex-Sequenz A/B/Freigabe/A → „lost“, 200 bleibt; alte Kennung nach Wiederbeitritt → „lost“ |
| P1: frische Sperre nach ~15 s übernommen; keine Erneuerung ohne Änderung | berechtigt | Frische Sperren nie übernehmen (Warten bis Freigabe/Ablauf, dann „error“); Autosave erneuert jede Minute | Selbsttest: frische und erneuerte Sperre geschützt; Studio: Fremdsperre nach 7 s freigegeben → nach 10 s geladen, keine Übernahme |
| P2: Studio nutzt bei veröffentlichter Place den Live-Bestand | berechtigt | Studio: ohne Attribut „off“; Attrappe per `UP_CareerMemoryStore`; getrennter Bestand `UP_Career_v1_STUDIO` nur per `UP_CareerStudioDataStore` | Studio: ohne Attribut `[Career] Speicherstand: aus` |

## Codex-Re-Review (`CODEX_REVIEW_1f1903b.md`, HOLD, nur P2)
| Befund | Maßnahme (`f1c99f7`) | Nachweis |
|---|---|---|
| P2: verlorene Antwort nach erfolgreichem Schreiben → Laden wartet auf eigene Sperre | eigene Sperre desselben Ladevorgangs anerkannt; Freigabe-Marker `releasedBy` für den Abschluss | Selbsttest (Attrappe mit `failAfterWrite`): 4 neue Fälle PASS |
| P2: gescheiterter Abschluss verwirft den Sitzungsstand | Warteschlange `retryFinal`: Autosave (bis 6 Versuche) und Herunterfahren schreiben erneut; Verlassen während des Ladens läuft durch denselben Pfad | Studio: Kauf ungespeichert, Verlassen bei Störung → nach Störungsende 60 Coins + Schuhe gespeichert, Sperre frei |
| P2: Schreibstörung als „AUTOSAVE AN“ angezeigt | eigener Anzeigezustand „retry“, nach Erfolg zurück auf „ok“; nur für die aktuelle Sitzung | Studio: `retry` → `ok` |

Kein weiterer Codex-Lauf (Regel: höchstens ein Re-Review nach P1-Fix).

## Tests
`SMOKE_M3b_DataStore.md`: Selbsttest `tests/CareerStore_selftest.lua` 25/25 PASS (Studio), Anbindung im Spiel mit der
Speicher-Attrappe (Laden, Kauf, Autosave, Wiederbeitritt, Störungen, Fremdsperre), Fallback in der unveröffentlichten Place.

## Offen
- **Echter DataStore ungetestet**: Die verbindliche Place ist unveröffentlicht (PlaceId 0); DataStore braucht eine
  veröffentlichte Place. Vorschlag: private Test-Place, Studio-API-Zugriff an, Attribut `UP_CareerStudioDataStore = true`
  (getrennter Bestand) – nur nach Freigabe zum Veröffentlichen.
- Serverwechsel mit zwei echten Servern und BindToClose eines Live-Servers.
- Testhinweis: Studio cached `require` im Edit-Kontext; der Selbsttest lädt das Modul deshalb als Klon.
