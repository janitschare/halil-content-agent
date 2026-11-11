**HOLD:** Die neuen Daueranimationen müssen Reduced Motion berücksichtigen; anschließend genügt ein gezielter SOLO-Test.

Bewerteter Vergleich: `5ab7fe94…` → `5a409aa3…`, ausschließlich anhand des gelieferten Diffs. **Tatsächlicher HEAD: UNKNOWN** — der Shellzugriff scheiterte. Keine Dateien verändert, Builds ausgeführt oder Studio-Tests durchgeführt.

**CONFIRMED FROM CODE**

1. **P2 — Reduced Motion wird von neuen Stadtanimationen ignoriert.**  
   **Fundstellen:** `ultimatepitch/src/CityFX.lua:65` und `ultimatepitch/src/CareerUI.lua:297`.  
   **Mechanismus:** Die Monumentrotation prüft ausschließlich Grafikprofil und Kameraentfernung; die Scout-Markierung ausschließlich `bb.Enabled`. Beide laufen unabhängig von `AuroraFX.reducedMotion`. Dass dieser Zustand bereits verfügbar ist, zeigt die bestehende Übergabe an `Matchday.start` im Client.  
   **Minimale Reproduktion:** Reduced Motion aktivieren, Grafikprofil „Mittel“ oder „Hoch“ wählen und zum Monument beziehungsweise Scout gehen. Rotation und Wippen laufen nach Code unverändert weiter. Die sichtbare Reproduktion wurde von mir nicht ausgeführt.  
   **Minimaler Fix:** Beiden Modulen denselben Reduced-Motion-Getter wie Matchday übergeben. Bei aktivierter Einstellung Rotation anhalten und die Scout-Markierung auf einen festen Offset setzen; Änderungen während der Sitzung berücksichtigen.  
   **Gezielter Abschlusstest:** Ein SOLO-Client, Reduced Motion an/aus bei sichtbaren Objekten; zusätzlich „Niedrig“ → „Hoch“ wechseln und Wiederherstellung prüfen.

Im geänderten Code ist **kein konkreter neuer Client→Gameplay-Autoritätsbypass** erkennbar. CityFX verändert lokale Darstellung; die bewegten Monumentteile sind serverseitig verankert und ohne Kollision. Die neuen Karriereattribute dienen der Anzeige. Daraus folgt keine Freigabe der unveränderten Spielmechanik.

Die neuen Module sind in PowerShell-Build, Python-Build und Rojo-Zuordnung konsistent eingebunden. Der bestehende Ersetzungs- und Backupmechanismus des Installers wird durch diesen Diff nicht geändert.

**NEEDS ROBLOX STUDIO**

- Ein gezielter Starttest muss bestätigen, dass `CityLook.build` vollständig durchläuft: Der neue synchrone Aufruf steht vor `Career.init`; ein dortiger Laufzeitfehler würde die anschließende Karriereinitialisierung und Pad-Anbindung verhindern. **Kein solcher Fehler ist aus dem Diff bestätigt.**
- Profilwechsel und verspätet eintreffende Stadtfiguren müssen einmal auf korrekte Entfernung/Wiederherstellung geprüft werden. `GetTagged` liefert nur Instanzen innerhalb des DataModel; für ausgelagerte Objekte ist daher tatsächlich `stash` maßgeblich. Das entspricht der [Roblox-Dokumentation](https://create.roblox.com/docs/reference/engine/classes/CollectionService).
- Touch-Layout des vergrößerten Scoutdialogs sowie Rendering und Leistung der zusätzlichen Stadtobjekte sind **UNVERIFIED**. Eine neue FPS-Zusage ist daraus nicht ableitbar.

**INFORMATION MISSING**

Der Diff zeigt weder die Handler für Kick/Pass/Shot/Aurora noch deren Schemaprüfung, Rate-Limits, Torattribution, Kausalitätstoken, Stamina- oder Bewegungsvalidierung. Auch KickAnim-Überlagerung, Cleanup, Fokusbehandlung und Soundimplementierung fehlen. Diese Bereiche sind hier **nicht vollständig auditierbar**; dafür erfunde ich keine Befunde.

Git-Historie und dort möglicherweise dokumentierte grüne Tests waren nicht zugänglich und wurden **nicht erneut ausgeführt**. Auch die im Projektkontext genannten SOLO-/Live-Sync- und Soundnachweise habe ich nicht wiederholt; der bereits offene Zwei-Client-KickAnim-Nachweis bleibt offen.

Keine Komponenten übernommen oder Custom-Code erstellt: reine Leseprüfung. Kein vollständiger Zehn-Client-Test erforderlich.