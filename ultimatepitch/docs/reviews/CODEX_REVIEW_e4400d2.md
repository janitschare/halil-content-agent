**HOLD — zwei P2-Befunde vor dem Merge schließen; gezielte Tests mit höchstens zwei Clients genügen.**

Geprüft wurde der bereitgestellte Diff `3ffad297… → e4400d27…`. Die Shell scheiterte beim Prozessstart: Tatsächliches HEAD, Arbeitsbaum und Git-Historie sind **UNVERIFIED**. Keine Dateien geändert, keine Builds oder Studio-Tests ausgeführt.

**CONFIRMED FROM CODE**

1. **P2 — Pad-Beitritt vertraut ungeprüft replizierten Berührungen**  
   **Ort:** `ultimatepitch/src/Server.server.lua:1609`, Anmeldung in Zeile **1617**.  
   **Mechanismus:** Der Handler prüft Charakter, Lebenspunkte und 1,5 Sekunden Entprellzeit. Eine Prüfung des serverseitigen Abstands zum Pad oder plausibler Bewegung fehlt. Die Behauptung im Kommentar, der Client könne sich nicht selbst anmelden, ist dadurch zu stark: Laut [Roblox-Dokumentation zur Netzwerkhoheit](https://create.roblox.com/docs/physics/network-ownership) können Clients Berührungen eigener Physikobjekte melden, obwohl der Server keinen Kontakt sieht. Das umgeht den vorgesehenen Arena-Zugang; ein Ball-, Tor- oder Belohnungsbypass ist damit allein **nicht** nachgewiesen.  
   **Minimalreproduktion:** Mit lebendem, unangemeldetem Charakter fern vom Pad eine manipulierte Berührungsmeldung zwischen eigener Körperkomponente und Pad erzeugen; prüfen, ob der Server `UP_Arena` setzt. Nicht von mir ausgeführt.  
   **Minimalfix:** Vor der Anmeldung aktuelle Charakteridentität und HRP-Abstand zur Pad-Geometrie mit kleiner Toleranz prüfen; bei auffälliger Bewegung Anmeldung ablehnen. Entprellzeit beibehalten.

2. **P2 — Fehlender Arena-Zustand führt zu dauerhaft falscher Client-Sicht**  
   **Ort:** `ultimatepitch/src/Client.client.lua:43`, insbesondere **51–55**.  
   **Mechanismus:** Kommt `UP_Arena="StreetCourt"` vor dessen Zustandsordner an, liefert `sourceState()` `nil`. `bindArena()` setzt „Free“ und beendet sich. Für später eintreffende Ordner existiert kein Wiederholungsmechanismus. Bis zur nächsten Attributänderung fehlen Match-HUD und Ereignisbindung. Auch die Leave-Bedienung bleibt wirkungslos, weil sie bei „Free“ nichts sendet. Roblox garantiert die [Replikationsreihenfolge von Objekten und Änderungen](https://create.roblox.com/docs/scripting/attributes) nicht. Dies ist ein Funktionsfehler, kein Gameplay-Autoritätsbypass.  
   **Minimalreproduktion:** Im isolierten Test `UP_Arena` auf „StreetCourt“ setzen, den zugehörigen replizierten Zustandsordner erst danach verfügbar machen. Erwarteter Fehler: Client bleibt „Free“. Nicht von mir ausgeführt.  
   **Minimalfix:** Fehlende Zustandsobjekte abwarten beziehungsweise bei ihrem Eintreffen erneut binden. Einen Generationstoken verwenden, damit ein inzwischen erfolgter Arenawechsel oder Leave eine alte wartende Bindung ungültig macht.

**NEEDS ROBLOX STUDIO**

Kleinste Tests zum Schließen der Befunde:

- Ein Client: entfernter beziehungsweise manipulierter Pad-Kontakt wird abgelehnt; echter Kontakt meldet genau einmal an.
- Ein Client: verzögerte Zustandsverfügbarkeit bindet nachträglich korrekt; Leave während des Wartens verhindert eine veraltete Bindung.
- Zwei Clients: gleichzeitig unterschiedliche Arenen benutzen; normalen Schuss und Aurora beobachten, anschließend während des Aurora-Anlaufs verlassen. Prüfen: kein späterer Schuss aus der verlassenen Arena, korrekter Ballbezug, keine hängenden R15-Posen.

**INFORMATION MISSING**

Der Diff enthält die vollständige Remote-Schemavalidierung, Rate-Limits, Bewegungsprüfung, Abmeldebereinigung und Torwertung nicht. Deshalb lässt sich insbesondere nicht bestätigen, dass Leave laufende Aurora-Holds, Ladung und Bewegungshistorie zuverlässig löscht oder dass jede fremde Ballaktion den Aurora-Tortoken beendet.

**SUPPORTED:** Die sichtbaren Schusspfade setzen Geschwindigkeit serverseitig; Schussladung wird serverseitig gemessen, Aurora-Ausdauer und Cooldown ebenfalls. `kickBall()` löscht den Aurora-Token und setzt Netzwerkhoheit auf den Server. Die geänderten FX-Nachrichten schaffen keinen erkennbaren Rückkanal zur Gameplay-Autorität.

Die City-Einbindung ist zwischen `build.ps1`, `build.py` und Rojo statisch konsistent. Kein zusätzlicher materialer Befund in diesen Änderungen; Builds und Import wurden nicht ausgeführt. Die vorhandenen R15-, Focus-, Touch- und Reduced-Motion-Implementierungen sind nur ausschnittweise sichtbar und damit nicht vollständig geprüft.

**Test-/Evidenzstatus:** Keine automatisierten Tests erneut ausgeführt. In der Git-Historie dokumentierte grüne Tests konnte ich weder einsehen noch rerunnen. Die mitgelieferten Angaben zu Live Sync und SOLO sind Fremdnachweise; Zwei-Client-KickAnim, Mobile und dynamisches Lighting bleiben unbestätigt. Keine Komponenten übernommen oder eigene Implementierung erstellt.