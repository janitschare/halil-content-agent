**HOLD — Das neue Dribbling übernimmt ungeprüfte Figurphysik in die Ballsteuerung und erlaubt Ballannahmen ohne vertikale Nähe.**

Reviewbasis: ausschließlich der bereitgestellte Diff von `822141f…` nach `0833a5e…`. Der Shell-Zugriff scheiterte; tatsächlicher HEAD, Working Tree und Git-Historie sind **UNKNOWN**. Keine Dateien geändert, keine Tests oder Studio-Sitzungen ausgeführt. Zeilennummern beziehen sich auf die neue Diff-Seite.

**CONFIRMED FROM CODE**

1. **P1 — Unbegrenzte Figurgeschwindigkeit wird zur Ballgeschwindigkeit**  
   **`ultimatepitch/src/Server.server.lua:1062`, `:1066`, `:1069`**

   `dribble()` übernimmt `bestRoot.AssemblyLinearVelocity` unmittelbar. Auch das vermeintliche Limit wächst mit diesem ungeprüften Wert. Bei `runVel = (1000, 0, 0)` und `pull = 0` wird deshalb eine Ballgeschwindigkeit von 1000 Studs/s zugelassen. Endlichkeitsprüfungen fehlen ebenfalls.

   Der Kommentar „Server-Positionen, der Client sendet dafür nichts“ begründet keine Autorität: Bei clientbesessenen Figuren kann deren Physiksimulation manipuliert werden. Das dokumentiert [Roblox ausdrücklich](https://create.roblox.com/docs/scripting/security/network-ownership). Der Server schreibt den Ball, vertraut dabei aber einer potenziell clientbestimmten Eingabe.

   **Minimalreproduktion:** Nach Ablauf von `KickGrace` Ball 2,4 Studs vor einer gültigen Figur platzieren; unmittelbar vor der Dribbling-Auswertung eine horizontale Figurgeschwindigkeit von 1000 setzen. Der gezeigte Rechenpfad übernimmt diese Geschwindigkeit. Anschließend denselben Versuch mit clientbesessener Figur durchführen.

   **Minimalfix:** Nur aus bereits validierter Bewegung abgeleitete Geschwindigkeit verwenden; Komponenten auf endliche Werte prüfen und Figur- sowie resultierende Dribblinggeschwindigkeit unabhängig von Rohphysik begrenzen. Das Limit muss zum serverseitigen Sprint-/Ausdauerzustand passen.

   **Evidenzgrenze:** Der unbeschränkte Datenfluss ist bestätigt. Ob die außerhalb des Diffs liegende Bewegungsprüfung den realen Clientangriff rechtzeitig verhindert, bleibt offen.

2. **P2 — Ballannahme funktioniert trotz fehlenden Fußkontakts aus beliebiger Höhe**  
   **`ultimatepitch/src/Server.server.lua:1052`, `:1060`**

   Die Auswahl verwendet ausschließlich horizontalen Abstand. `bp.Y` begrenzt nur die Ballhöhe; die Höhe der Figur wird überhaupt nicht geprüft. Eine lebende Teamfigur weit über dem Ball kann deshalb Besitzer werden, dessen Bewegung übernehmen und das Aurora-Token löschen. Schon normales Überspringen kann eine Annahme ohne tatsächliche Berührung auslösen.

   **Minimalreproduktion:** Im Match eine gültige Figur serverseitig zehn Studs über einen bodennahen Ball setzen, horizontal innerhalb von 3,6 Studs; `KickGrace` abwarten. Trotz fehlender räumlicher Nähe wird sie ausgewählt.

   **Minimalfix:** Zusätzlich eine avatarverträgliche vertikale Fuß-Ball-Distanz prüfen, bevor Besitzerwahl oder Tokenlöschung erfolgen.

**NEEDS ROBLOX STUDIO**

Die kleinsten gezielten Blockertests sind:

- Mit zwei Clients den Geschwindigkeitsversuch aus Befund 1 ausführen; serverseitig Figurgeschwindigkeit, Ballgeschwindigkeit und Zeitpunkt der Bewegungskorrektur beobachten. Auch erschöpfte Ausdauer prüfen.
- Ballannahme beim Springen und bei deutlich erhöhter Figur prüfen; anschließend normale Bodenannahme und Besitzwechsel gegenprüfen.
- Aurora gezielt testen: direkte Torfahrt behält die Zuordnung; tatsächliche neue Ballannahme, Pass, Schuss und Bot-Kick löschen sie.

Für die erwähnte offene `KickAnim`-Regression genügt zunächst ein Zweiclienttest mit R15: schnelle Kick-/Pass-/Aurora-Folge, anschließend Tod/Respawn; Überlagerung und Cleanup auf beiden Clients beobachten. Ich habe diese Tests **nicht** ausgeführt.

**INFORMATION MISSING**

Remote-Handler, vollständige Bewegungs-/Ausdauerprüfung, `releaseAurora()`, R15-Animationsverwaltung sowie Focus-/Touch-Logik fehlen im Ausschnitt. Deshalb keine belastbare Freigabe für Schema, Rate Limits, Cooldowns oder Animation-Cleanup.

`AuroraFX`, Grafikprofile, `build.ps1`, `build.py` und `default.project.json` sind im gelieferten Diff unverändert; ihre Inhalte liegen hier nicht vor. Keine erneuten Befunde dazu. Der neue lokale Ring eröffnet im sichtbaren Code keinen Gameplay-Autoritätsbypass; seine Rotation berücksichtigt allerdings den gezeigten Reduced-Motion-Zustand nicht.

**Tests/Evidenz:** Grüne Tests aus der Git-Historie wurden von mir weder eingesehen noch erneut ausgeführt. Die bereitgestellten Angaben zu SOLO-/Live-Sync-Tests sind übernommene Statusinformationen, keine eigene Verifikation. Mobile-, Leistungs- oder API-Kompatibilität wird damit nicht bestätigt.