-- Selbsttest für src/CareerStore.lua (in Studio ausführen: Befehlsleiste oder MCP execute_luau, Edit- oder Server-Kontext).
-- Nutzt die Speicher-Attrappe CareerStore.memory() mit künstlicher Uhr und Warte-Funktion; kein DataStore nötig.
-- Ergebnis: Textzeilen "PASS"/"FAIL" je Fall und eine Summenzeile.
-- Klon statt Original: Studio hält require-Ergebnisse im Cache, ein Klon lädt immer den aktuellen Quelltext
local CareerStore = require(game:GetService("ServerScriptService").UltimatePitchServer.CareerStore:Clone())

local ITEMS = {
	boots_neon = { slot = "boots" }, boots_gold = { slot = "boots" },
	armband = { slot = "armband" }, number_gold = { slot = "number" },
}
local out, fails = {}, 0
local function check(name, cond, info)
	if not cond then fails += 1 end
	table.insert(out, (cond and "PASS " or "FAIL ") .. name .. (info and ("  [" .. tostring(info) .. "]") or ""))
end

local clock = 1000000
local waits = 0
local function mk(store, job, maxLockWait)
	return CareerStore.new(store, { jobId = job, items = ITEMS, stages = 3, lockWait = 5, maxLockWait = maxLockWait,
		now = function() return clock end,
		wait = function(s) waits += 1 clock += s end })
end
local function sample(coins)
	return { coins = coins or 120, stage = 2, owned = { boots_neon = true, armband = true }, equipped = { boots = "boots_neon" }, matches = 3, goals = 4 }
end
local K = CareerStore.key(42)

-- 1 neuer Spieler, Speichern, Freigabe, Laden auf anderem Server
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	local st, d, tok = a.load(42)
	local rec = m:read(K)
	check("neuer Spieler laedt Standardwerte", st == "ok" and d.coins == 0 and d.stage == 1 and type(tok) == "string", st)
	check("Laden setzt Sperre mit Ladekennung", rec and rec.lock and rec.lock.job == "A" and rec.lock.sid == tok)
	local s1 = a.save(42, sample(), tok, false)
	rec = m:read(K)
	check("Zwischenspeichern ok, Sperre bleibt", s1 == "ok" and rec.coins == 120 and rec.lock.sid == tok)
	local s2 = a.save(42, sample(), tok, true)
	rec = m:read(K)
	check("Abschluss gibt Sperre frei", s2 == "ok" and rec.lock == nil)
	waits = 0
	local st2, d2 = mk(m, "B").load(42)
	check("anderer Server laedt freigegebenen Stand sofort", st2 == "ok" and waits == 0 and d2.coins == 120 and d2.stage == 2
		and d2.owned.armband and d2.equipped.boots == "boots_neon" and d2.goals == 4, waits)
end

-- 2 beschaedigte/manipulierte Daten werden bereinigt
do
	local m = CareerStore.memory()
	m:write(K, { schema = 1, coins = -5, stage = 99, owned = { "boots_neon", "hack", 5 },
		equipped = { boots = "boots_gold", armband = "armband", number = "boots_neon" }, matches = "x", goals = 1.7 })
	local st, d = mk(m, "A").load(42)
	local n, e = 0, 0
	for _ in pairs(d.owned) do n += 1 end
	for _ in pairs(d.equipped) do e += 1 end
	check("Bereinigung: Coins >= 0, Stufe begrenzt, nur bekannte Artikel", st == "ok" and d.coins == 0 and d.stage == 3 and n == 1 and d.owned.boots_neon)
	check("Bereinigung: nur besessene Ausruestung im richtigen Platz", e == 0, e)
	check("Bereinigung: Zahlen ganzzahlig", d.matches == 0 and d.goals == 1)
	m:write(K, { schema = 1, coins = 1e12 })
	local _, d2 = mk(m, "C").load(42)
	check("Bereinigung: Coin-Obergrenze", d2.coins == CareerStore.MAX_COINS)
end

-- 3 frische fremde Sperre wird nie uebernommen (Codex P1): B wartet und gibt mit "error" auf, A behaelt den Stand
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	local _, _, tokA = a.load(42)
	a.save(42, sample(150), tokA, false)
	waits = 0
	local st = mk(m, "B", 60).load(42)
	local rec = m:read(K)
	check("frische Sperre: B wartet und bricht ab, keine Uebernahme", st == "error" and waits >= 10 and rec.lock.sid == tokA, st .. "/" .. waits)
	local s = a.save(42, sample(160), tokA, true)
	rec = m:read(K)
	check("A speichert danach weiter und gibt frei", s == "ok" and rec.coins == 160 and rec.lock == nil, s)
end

-- 4 Sperre wird durch Autosave erneuert: 350 s nach dem Laden, 100 s nach der letzten Erneuerung noch geschuetzt
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	local _, _, tokA = a.load(42)
	clock += 250
	a.save(42, sample(), tokA, false)
	clock += 100
	local st = mk(m, "B", 20).load(42)
	check("erneuerte Sperre bleibt geschuetzt", st == "error", st)
end

-- 5 Codex-Sequenz: A laedt, A haengt (keine Erneuerung), B uebernimmt die abgelaufene Sperre, speichert 200 und gibt frei;
--   danach darf A seinen alten Stand (100) nicht mehr schreiben
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	local _, _, tokA = a.load(42)
	clock += CareerStore.LOCK_TIMEOUT + 10
	waits = 0
	local b = mk(m, "B")
	local stB, _, tokB = b.load(42)
	check("abgelaufene Sperre: ohne Warten uebernommen", stB == "ok" and waits == 0, waits)
	b.save(42, sample(200), tokB, true)
	local sA = a.save(42, sample(100), tokA, true)
	local rec = m:read(K)
	check("alter Server nach fremder Freigabe: lost, 200 bleibt", sA == "lost" and rec.coins == 200, sA)
	local sA2 = a.save(42, sample(100), tokA, false)
	rec = m:read(K)
	check("alter Server Zwischenspeichern: lost, keine neue Sperre", sA2 == "lost" and rec.coins == 200 and rec.lock == nil, sA2)
end

-- 6 Wiederbeitritt auf demselben Server: alte Ladekennung darf nicht mehr schreiben
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	local _, _, tok1 = a.load(42)
	a.save(42, sample(10), tok1, true)
	local _, _, tok2 = a.load(42)
	local s = a.save(42, sample(999), tok1, false)
	local rec = m:read(K)
	check("gleicher Server, alte Kennung: lost", s == "lost" and rec.coins == 10 and rec.lock.sid == tok2, s)
end

-- 7 Warten abbrechen, wenn der Spieler geht
do
	local m = CareerStore.memory()
	local _, _, tokA = mk(m, "A").load(42)
	local st = mk(m, "B").load(42, function() return true end)
	local rec = m:read(K)
	check("Abbruch beim Warten: cancelled, Sperre unveraendert", st == "cancelled" and rec.lock.sid == tokA, st)
end

-- 8 voruebergehende Fehler werden wiederholt; dauerhafte Fehler liefern "error" ohne Schreiben
do
	local m = CareerStore.memory()
	m:write(K, { schema = 1, coins = 70 })
	m.failNext = 2
	local st, d = mk(m, "A").load(42)
	check("2 Fehler, dann Laden ok", st == "ok" and d.coins == 70, st)
	local m2 = CareerStore.memory()
	m2:write(K, { schema = 1, coins = 70 })
	m2.failNext = 10
	local st2 = mk(m2, "A").load(42)
	local rec = m2:read(K)
	check("dauerhafter Fehler: error, Stand unangetastet", st2 == "error" and rec.coins == 70 and rec.lock == nil, st2)
	local m3 = CareerStore.memory()
	local a = mk(m3, "A")
	local _, _, tok = a.load(42)
	m3.failNext = 10
	local s = a.save(42, sample(), tok, true)
	check("Speichern bei dauerhaftem Fehler: error", s == "error", s)
end

-- 9 Stand aus neuerer Spielversion wird nicht angefasst
do
	local m = CareerStore.memory()
	m:write(K, { schema = 2, coins = 300 })
	local st = mk(m, "A").load(42)
	local rec = m:read(K)
	check("neueres Schema: error, keine Sperre, keine Aenderung", st == "error" and rec.coins == 300 and rec.lock == nil, st)
end

-- 10 Schreiben gelungen, Antwort verloren (Codex-Re-Review P2): Wiederholung erkennt die eigene Sperre bzw. Freigabe
do
	local m = CareerStore.memory()
	m:write(K, { schema = 1, coins = 40 })
	m.failAfterWrite = 1
	waits = 0
	local st, d, tok = mk(m, "A").load(42)
	local rec = m:read(K)
	check("Laden: verlorene Antwort, eigene Sperre blockiert nicht", st == "ok" and d.coins == 40 and rec.lock.sid == tok and waits == 1, st .. "/" .. waits)
	local a = mk(m, "A", 20)
	local _, _, tok2 = a.load(42) -- neuer Ladevorgang desselben Servers: andere Kennung, frische Sperre -> kein Laden
	check("Laden: Sperre eines anderen Ladevorgangs bleibt respektiert", tok2 == nil)
	m:write(K, { schema = 1, coins = 40 })
	local b = mk(m, "B")
	local _, _, tokB = b.load(42)
	m.failAfterWrite = 1
	local s1 = b.save(42, sample(55), tokB, false)
	rec = m:read(K)
	check("Zwischenspeichern: verlorene Antwort, Wiederholung ok", s1 == "ok" and rec.coins == 55 and rec.lock.sid == tokB, s1)
	m.failAfterWrite = 1
	local s2 = b.save(42, sample(66), tokB, true)
	rec = m:read(K)
	check("Abschluss: verlorene Antwort, Freigabe als erledigt erkannt", s2 == "ok" and rec.coins == 66 and rec.lock == nil, s2)
end

table.insert(out, string.format("SUMME: %d Fehler", fails))
return table.concat(out, "\n")
