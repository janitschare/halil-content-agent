**HOLD – ein bestätigter P2-Korrektheitsfehler: Bot-Ballannahme umgeht die begrenzte Zweikampflogik.**

Prüfgrundlage: ausschließlich der bereitgestellte Diff `9550f57… → b3ee1a9…`. Der Shell-Aufruf scheiterte; tatsächlicher HEAD und Git-Historie sind **UNVERIFIED**. Keine Dateien verändert, keine Tests oder Studio-Sitzungen ausgeführt.

**CONFIRMED FROM CODE**

1. **P2 – Automatischer Besitzwechsel trotz fehlgeschlagenem oder gesperrtem Bot-Zweikampf**  
   **Ort:** `ultimatepitch/src/Server.server.lua:1192`, `:1203`, `:1207`.

   **Mechanismus:** `consider()` bewertet sämtliche Feldspieler-Bots nach Entfernung, ohne gegnerischen Ballbesitz, `botCd`, `TackleChance` oder `TackleRetry` zu berücksichtigen. `setCarrier(best, bestPlr)` überträgt anschließend unmittelbar den Besitz. Damit existiert neben dem begrenzten Zweikampf in `thinkTeam()` ein deterministischer Weg zur Ballabnahme.

   **Minimale Reproduktion:** Ein Mensch führt einen langsamen Bodenball; `KickGrace` ist abgelaufen. Abstand Mensch–Ball: 2,4 Studs, gegnerischer Bot–Ball: 1 Stud; beide erfüllen die Höhenprüfung. Die Bewertung des Menschen beträgt wegen Bias und Hysterese `2,4 − 0,3 − 0,6 = 1,5`, die des Bots `1`. Beim nächsten `dribble()` gewinnt der Bot selbst dann den Ball, wenn seine Zweikampfsperre noch läuft oder sein vorheriger Versuch misslungen ist. Dies ist eine aus dem Code abgeleitete Reproduktion, kein ausgeführter Studio-Test.

   **Minimaler Fix:** Bei bestehendem gegnerischem Ballbesitz Bots aus der automatischen Annahme ausschließen; Abnahmen weiterhin ausschließlich über die serverseitige Zweikampfentscheidung ausführen. Freie Bälle bleiben annehmbar.

   **Gezielter Abschlusstest:** Obige Situation mit laufender Sperre und erzwungenem Fehlversuch prüfen: kein Besitzwechsel. Anschließend erfolgreichen Zweikampf sowie freie Ballannahme durch Mensch und Bot prüfen.

Die sichtbaren Client-Änderungen konsumieren `BallCarrier` für Darstellung; darin ist **kein konkreter Client→Gameplay-Autoritätsbypass** erkennbar. `ObjectValue.Changed` liefert tatsächlich die referenzierte Instanz; der neue Callback verwendet die API korrekt. [Roblox-Referenz](https://create.roblox.com/docs/reference/engine/classes/ObjectValue)

Die sichtbare Ballannahme löscht `auroraShot` auch bei Bot-Annahme. Das bestätigt diesen einzelnen Invalidierungspfad, keine vollständige Aurora-Kausalitätsprüfung.

**NEEDS ROBLOX STUDIO**

- Den beschriebenen Besitzwechsel und den Fix gezielt mit einem Spieler und einem gegnerischen Bot verifizieren.
- Den ausdrücklich offenen **2-Client-KickAnim-Test** durchführen: überlappende Aktionen, Respawn während Animation, anschließende Rückkehr zur normalen Pose. Fokusverlust während Laden/Sprint, Touch-Abbruch und Reduced Motion gezielt ergänzen.
- `Motor6D.Transform` in `PreSimulation` ist grundsätzlich mit dem dokumentierten Animator-Ablauf vereinbar; tatsächliche Überlagerung und Cleanup sind damit noch nicht bewiesen. [Roblox-Referenz](https://create.roblox.com/docs/reference/engine/classes/Motor6D)

**INFORMATION MISSING**

- Remote-Handler einschließlich Schema, Rate-Limits, Reichweiten, Ladungszeit und Staminaverbrauch fehlen im Ausschnitt. Ebenso fehlen vollständige Bewegungsprüfung, Netzwerkbesitz, Torwertung und übrige Aurora-Invalidierungen. Hierfür gibt es weder eine bestätigte neue Schwachstelle noch eine belastbare Freigabe.
- KickAnim-Implementierung, vollständiger Animations-Cleanup sowie Fokus-/Touch-Handler fehlen. HUD, Grafikprofile und Sounds zeigen keinen einschlägigen Änderungsumfang.
- Für `build.ps1`, `build.py` und `default.project.json` enthält der Diff keine Änderungen oder Dateiinhalte; Installer-Sicherheit und Rojo-Zuordnung wurden nicht erneut geprüft.
- **Keine grünen Tests wurden von mir erneut ausgeführt.** Die bereitgestellten Projektangaben nennen Rojo-Live-Sync und Studio-SOLO als dokumentiert. Ohne Git-Zugriff kann ich entsprechende historische Testergebnisse keinem Commit zuordnen. Mobile, Player-Benchmarks, dynamische Lighting-Kompatibilität und finale Sound-Rechte bleiben unbestätigt.

Für die Merge-Blockade genügt der gezielte Besitzwechsel-Fix mit den genannten Regressionen; ein pauschaler neuer 10-Client-Test ist nicht erforderlich.