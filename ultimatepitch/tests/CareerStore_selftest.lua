-- Selbsttest für src/CareerStore.lua (in Studio ausführen: Befehlsleiste oder MCP execute_luau, Edit- oder Server-Kontext).
-- Nutzt die Speicher-Attrappe CareerStore.memory() mit künstlicher Uhr und Warte-Funktion; kein DataStore nötig.
-- Ergebnis: Textzeilen "PASS"/"FAIL" je Fall und eine Summenzeile.
local CareerStore = require(game:GetService("ServerScriptService").UltimatePitchServer.CareerStore)

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
local function mk(store, job)
	return CareerStore.new(store, { jobId = job, items = ITEMS, stages = 3,
		now = function() return clock end,
		wait = function(s) waits += 1 clock += s end })
end
local function sample()
	return { coins = 120, stage = 2, owned = { boots_neon = true, armband = true }, equipped = { boots = "boots_neon" }, matches = 3, goals = 4 }
end
local K = CareerStore.key(42)

-- 1 neuer Spieler: Standardwerte, Sperre gesetzt
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	local st, d = a.load(42)
	local rec = m:read(K)
	check("neuer Spieler laedt Standardwerte", st == "ok" and d.coins == 0 and d.stage == 1, st)
	check("Laden setzt Sperre", rec and rec.lock and rec.lock.job == "A")
	-- 2 Speichern behaelt Sperre, Freigeben entfernt sie, Werte kommen beim naechsten Laden zurueck
	local s1 = a.save(42, sample(), false)
	rec = m:read(K)
	check("Zwischenspeichern ok, Sperre bleibt", s1 == "ok" and rec.coins == 120 and rec.lock.job == "A")
	local s2 = a.save(42, sample(), true)
	rec = m:read(K)
	check("Abschluss gibt Sperre frei", s2 == "ok" and rec.lock == nil)
	local b = mk(m, "B")
	waits = 0
	local st2, d2 = b.load(42)
	check("anderer Server laedt freigegebenen Stand sofort", st2 == "ok" and waits == 0 and d2.coins == 120 and d2.stage == 2
		and d2.owned.armband and d2.equipped.boots == "boots_neon" and d2.goals == 4, waits)
end

-- 3 beschaedigte/manipulierte Daten werden bereinigt
do
	local m = CareerStore.memory()
	m:write(K, { schema = 1, coins = -5, stage = 99, owned = { "boots_neon", "hack", 5 },
		equipped = { boots = "boots_gold", armband = "armband", number = "boots_neon" }, matches = "x", goals = 1.7 })
	local st, d = mk(m, "A").load(42)
	local n = 0
	for _ in pairs(d.owned) do n += 1 end
	local e = 0
	for _ in pairs(d.equipped) do e += 1 end
	check("Bereinigung: Coins >= 0, Stufe begrenzt, nur bekannte Artikel", st == "ok" and d.coins == 0 and d.stage == 3 and n == 1 and d.owned.boots_neon)
	check("Bereinigung: nur besessene Ausruestung im richtigen Platz", e == 0, e)
	check("Bereinigung: Zahlen ganzzahlig", d.matches == 0 and d.goals == 1)
	m:write(K, { schema = 1, coins = 1e12 })
	local _, d2 = mk(m, "C").load(42)
	check("Bereinigung: Coin-Obergrenze", d2.coins == CareerStore.MAX_COINS)
end

-- 4 frische fremde Sperre: warten, dann Uebernahme; alter Server darf danach nicht mehr schreiben
do
	local m = CareerStore.memory()
	local a = mk(m, "A")
	a.load(42)
	a.save(42, sample(), false)
	local b = mk(m, "B")
	waits = 0
	local st, d = b.load(42)
	local rec = m:read(K)
	check("frische Sperre: erst warten (5x), dann uebernehmen", st == "ok" and waits == 5 and rec.lock.job == "B" and d.coins == 120, waits)
	local late = sample()
	late.coins = 999
	local s = a.save(42, late, true)
	rec = m:read(K)
	check("alter Server: Speichern abgelehnt (lost), Stand unveraendert", s == "lost" and rec.coins == 120 and rec.lock.job == "B", s)
end

-- 5 verwaiste Sperre (aelter als LOCK_TIMEOUT): sofort uebernehmen
do
	local m = CareerStore.memory()
	m:write(K, { schema = 1, coins = 50, lock = { job = "Z", t = clock - CareerStore.LOCK_TIMEOUT - 10 } })
	waits = 0
	local st, d = mk(m, "A").load(42)
	check("verwaiste Sperre: ohne Warten uebernommen", st == "ok" and waits == 0 and d.coins == 50, waits)
end

-- 6 voruebergehende Fehler werden wiederholt; dauerhafte Fehler liefern "error" ohne Schreiben
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
	a.load(42)
	m3.failNext = 10
	local s = a.save(42, sample(), true)
	check("Speichern bei dauerhaftem Fehler: error", s == "error", s)
end

-- 7 Stand aus neuerer Spielversion wird nicht angefasst
do
	local m = CareerStore.memory()
	m:write(K, { schema = 2, coins = 300 })
	local st = mk(m, "A").load(42)
	local rec = m:read(K)
	check("neueres Schema: error, keine Sperre, keine Aenderung", st == "error" and rec.coins == 300 and rec.lock == nil, st)
end

table.insert(out, string.format("SUMME: %d Fehler", fails))
return table.concat(out, "\n")
