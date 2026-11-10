# Art Direction – Referenzbilder vom 11.11.2026

Quelle: 10 Konzeptbilder des Nutzers („Referenz für das Spiel“). Lokal gesichert unter
`experiments/art-reference-2026-11-11/` im Protokoll-Ordner, **nicht im Repo**: Die Bilder zeigen Fremdmarken (siehe unten)
und sind Konzeptkunst, keine Spiel-Assets. Ist-Stand zum Vergleich: `docs/art/IST_2026-11-11/` (Studio, Grafik „Niedrig“).

## Kern der Vision
- **Marke:** ULTIMATE PITCH – „Football Open World“, Slogan **„Vom Bolzplatz zum Superstar“**, Zeichen Krone + Ball,
  Monogramm **„UP“**.
- **Farben:** Schwarz/Gold (Heimtrikot, Kronen, Banner) · Neon-Violett und Cyan (Dome, LED, Schaufenster) · warmes Abendlicht
  (Sonnenuntergang/blaue Stunde) · nasser, glänzender Boden mit Lichtreflexen.
- **Figuren:** Roblox-Blockstil (passt zu unseren R15-Figuren), Heimtrikot schwarz-gold mit Krone und Nummer 10,
  Kapitänsbinde, goldene Schuhe. Kein Anime-Zwang.
- **Stimmung:** belebte Plaza, viele Lichtquellen, Banner, Lichtstrahlen und Feuerwerk am Dome, Autos, Palmen.

## Bereiche: Referenz → Ist → Umsetzung mit Bordmitteln (ohne Asset-Upload)
| Bereich | Referenz | Ist (11.11.) | Umsetzung |
|---|---|---|---|
| City Plaza | leuchtender Riesenball auf „UP“-Sockel mit Fontäne, Ranglisten-Tafel, Wegweiser-Stele, Bänke, Laternen, Palmen | Pad-Ring, Bänke, Laternen, runde Bäume | Monument aus Neon-Kugel, Ring, Wasserbecken mit Partikeln; Live-Rangliste (SurfaceGui, Pitch Coins/Stufe); Wegweiser mit Pfeilen (gebaute Ziele leuchten, kommende „bald“); Palmen prozedural |
| Spectra Dome außen | LED-Band, Kronen-Banner, Großbildwand mit Spieler, Eingangstunnel „STADION EINGANG“, Lichtkegel | dunkle Wand, kleines Schild | LED-Ringe (Neon), Banner aus Teilen + Text, Videowand (SurfaceGui), Tunnelportal, Beams |
| Street Court / Bolzplatz | Käfig, Graffiti-Wände, Zuschauer auf Bänken, Flutlicht, Scout mit Tablet | Käfig, Flutlicht, Scout ohne Markierung | Graffiti als SurfaceGui-Schrift (z. B. Permanent Marker), Zuschauer-NPCs, Scout-Marker „!“, Talent-Karte (Technik, Tempo, Spielintelligenz, Potenzial) im Scout-Dialog |
| Fashion District / Sneaker Store / Trikot-Shop | Schaufenster mit Puppen, Schuh- und Trikotregale, Neonrahmen | Box mit Glasfront, Theke | Schaufensterpuppen (R15-Figuren in Kits), Regale aus Teilen, Neonrahmen, Untergeschäfte als eigene Fronten |
| Player Agency | sichtbares Büro, „Verträge · Transfers · Karriere“, Sportwagen davor | Box „ERÖFFNET BALD“ | Fassade mit Innenraum-Andeutung, 2 Deko-Sportwagen (prozedural); Funktion später |
| Stadion-Einlauf (Bild 5) | Tunnel, Kapitän, Feuerwerk, Pokal auf Sockel | Matchday-Intro mit Pyro/LED | Einlauf-Kamerafahrt durch einen Tunnel als Ausbau des Matchday-Intros |
| Open World (Bild 8) | Training Camp, Club HQ, Academy, Tournament Arena, Car District, Wohnviertel, Bahn, See | 1 Bezirk | spätere Ausbaustufen; Karte im UI |

## Nicht übernehmen (Rechte)
- **Nike-Swoosh** (Bild 1, Fashion District), **Drei-Streifen-Trikots** (Bilder 3, 4, 7), **Champions-League-Sternenball /
  Henkelpott-Form** (Bild 5: Torbogen, Großbildschirm, Pokal). Eigene Formen verwenden (z. B. Kronen-Pokal).
- Keine echten Vereine, Spieler oder Wappen; Fantasienamen (z. B. „Spectra United“) sind in Ordnung.
- Berliner Fernsehturm: realer Bau; als ferne Silhouette unkritisch, eigene Skyline bevorzugt.
- Nichts aus den Bildern wird hochgeladen. Eigene Logos/Texturen sind Asset-Uploads → eigene Freigabe.

## Technische Leitplanken (schwacher Zielrechner)
- Deko über das Grafikprofil schaltbar; „Niedrig“ entfernt Deko wirklich (Ausblenden spart nachweislich nichts, s. 07.11.).
- Wenige echte Lichtquellen (SpotLights sind teuer); Leuchtwirkung über Neon-Material und Farbkorrektur.
- Himmel: ohne Skybox-Upload nur über Tageszeit, Atmosphere und Farbkorrektur färbbar.
- Glanzboden: Material/Reflectance gering halten; echte Spiegelungen gibt es in Roblox nicht.

## Vorschlag M4 „City Look“ (Vertical Slice: ein Bildausschnitt wie Referenz 4/7)
1. Abendstimmung in der Stadt (Sonnenuntergang/blaue Stunde), Neon-Akzente, glänzender Boden.
2. Plaza-Monument „UP“-Ball mit Wasserbecken.
3. Wegweiser-Stele und Live-Rangliste.
4. Dome-Fassade: LED-Ring, Kronen-Banner, Großbildwand, „STADION EINGANG“.
5. Street Court: Graffiti, Zuschauer, Scout-Marker „!“.
6. Fashion-District- und Player-Agency-Fronten, Deko-Sportwagen, Palmen.
Abnahme: Screenshots aus denselben Kamerapositionen wie `docs/art/IST_2026-11-11/` plus FPS-Messung Niedrig/Hoch.
