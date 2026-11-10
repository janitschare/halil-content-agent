-- UltimatePitch · dauerhafter Karriere-Speicherstand (ModuleScript unter UltimatePitchServer, nur Server)
-- Ein Datensatz je Spieler (Schlüssel "u_<UserId>") mit Coins, Stufe, Besitz, Ausrüstung und Statistik.
-- Alle Zugriffe laufen über UpdateAsync mit einer Sitzungssperre (lock = { job = JobId, t = os.time() }):
--   * Laden sperrt den Datensatz für diesen Server. Hält ein anderer Server noch eine frische Sperre (er speichert
--     z. B. gerade beim Serverwechsel), wird kurz gewartet; erst nach mehreren Versuchen oder bei einer verwaisten
--     Sperre (älter als LOCK_TIMEOUT, Server abgestürzt) übernimmt dieser Server.
--   * Speichern schreibt nur, solange die Sperre diesem Server gehört; sonst "lost" (kein Überschreiben fremder Stände).
--   * Verlassen speichert ein letztes Mal und gibt die Sperre frei.
-- Schlägt das Laden fehl, liefert load "error": Der Aufrufer speichert dann für diesen Spieler nichts, damit ein
-- vorhandener Spielstand nicht durch einen leeren überschrieben wird.
local HttpService = game:GetService("HttpService")

local CareerStore = {}
CareerStore.SCHEMA = 1
CareerStore.LOCK_TIMEOUT = 300 -- Sekunden, danach gilt eine fremde Sperre als verwaist
CareerStore.MAX_COINS = 10000000

local function key(userId)
	return "u_" .. tostring(userId)
end
CareerStore.key = key

-- Gespeicherte Rohdaten in einen gültigen Spielstand überführen: falsche Typen, unbekannte Artikel, Ausrüstung
-- ohne Besitz oder im falschen Platz und Ausreißer werden verworfen bzw. begrenzt.
function CareerStore.sanitize(raw, items, stageCount)
	local d = { coins = 0, stage = 1, owned = {}, equipped = {}, matches = 0, goals = 0 }
	if type(raw) ~= "table" then return d end
	local function int(v, lo, hi)
		if type(v) ~= "number" or v ~= v then return lo end
		return math.clamp(math.floor(v), lo, hi)
	end
	d.coins = int(raw.coins, 0, CareerStore.MAX_COINS)
	d.stage = int(raw.stage, 1, stageCount)
	d.matches = int(raw.matches, 0, 1e9)
	d.goals = int(raw.goals, 0, 1e9)
	if type(raw.owned) == "table" then
		for _, id in ipairs(raw.owned) do
			if type(id) == "string" and items[id] then d.owned[id] = true end
		end
	end
	if type(raw.equipped) == "table" then
		for slot, id in pairs(raw.equipped) do
			local it = type(id) == "string" and items[id]
			if it and d.owned[id] and it.slot == slot then d.equipped[slot] = id end
		end
	end
	return d
end

function CareerStore.serialize(d)
	local owned = {}
	for id in pairs(d.owned) do table.insert(owned, id) end
	table.sort(owned)
	local equipped = {}
	for slot, id in pairs(d.equipped) do equipped[slot] = id end
	return { schema = CareerStore.SCHEMA, coins = d.coins, stage = d.stage, owned = owned, equipped = equipped,
		matches = d.matches, goals = d.goals }
end

-- store: DataStore oder CareerStore.memory(); opts = { jobId, items, stages, now?, wait?, retries?, lockWaits?, lockWait? }
function CareerStore.new(store, opts)
	local self = {}
	local jobId = opts.jobId
	local now = opts.now or os.time
	local wait = opts.wait or task.wait
	local retries = opts.retries or 4      -- Fehlversuche (Netz/Budget) bis "error"
	local lockWaits = opts.lockWaits or 5  -- Warteschleifen auf eine fremde Sperre bis zur Übernahme
	local lockWait = opts.lockWait or 3

	local function foreignLock(old, includeStale)
		local lock = type(old) == "table" and old.lock
		if type(lock) ~= "table" or lock.job == jobId then return false end
		if includeStale then return true end
		return type(lock.t) == "number" and now() - lock.t < CareerStore.LOCK_TIMEOUT
	end

	-- Lädt und sperrt. Rückgabe: "ok", data | "error", Meldung
	function self.load(userId)
		local errors, waits = 0, 0
		while true do
			local blocked, newer, raw = false, false, nil
			local steal = waits >= lockWaits
			local ok, err = pcall(function()
				store:UpdateAsync(key(userId), function(old)
					blocked, newer, raw = false, false, old
					if type(old) == "table" and type(old.schema) == "number" and old.schema > CareerStore.SCHEMA then
						newer = true -- von einer neueren Spielversion geschrieben: nicht anfassen
						return nil
					end
					if not steal and foreignLock(old, false) then
						blocked = true
						return nil
					end
					local rec = type(old) == "table" and old or {}
					rec.lock = { job = jobId, t = now() }
					return rec, { userId }
				end)
			end)
			if ok and newer then return "error", "Spielstand stammt aus einer neueren Version" end
			if ok and not blocked then return "ok", CareerStore.sanitize(raw, opts.items, opts.stages) end
			if ok then
				waits += 1
				wait(lockWait)
			else
				errors += 1
				if errors >= retries then return "error", tostring(err) end
				wait(2 ^ errors)
			end
		end
	end

	-- Speichert (release = Sperre freigeben). Rückgabe: "ok" | "lost" (anderer Server hält den Stand) | "error", Meldung
	function self.save(userId, data, release)
		local errors = 0
		while true do
			local lost = false
			local ok, err = pcall(function()
				store:UpdateAsync(key(userId), function(old)
					lost = false
					if foreignLock(old, true) then
						lost = true
						return nil
					end
					local rec = CareerStore.serialize(data)
					if not release then rec.lock = { job = jobId, t = now() } end
					return rec, { userId }
				end)
			end)
			if ok then return lost and "lost" or "ok" end
			errors += 1
			if errors >= retries then return "error", tostring(err) end
			wait(2 ^ errors)
		end
	end

	return self
end

-- Speicher-Attrappe mit derselben UpdateAsync-Schnittstelle: Werte werden wie im echten Store als JSON abgelegt.
-- failNext = n lässt die nächsten n Zugriffe mit einem Fehler scheitern. Für Selbsttests und den Studio-Testmodus.
function CareerStore.memory()
	local m = { data = {}, failNext = 0, calls = 0 }
	function m:UpdateAsync(k, fn)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("simulierter DataStore-Fehler")
		end
		local old = self.data[k] and HttpService:JSONDecode(self.data[k]) or nil
		local new = fn(old)
		if new ~= nil then self.data[k] = HttpService:JSONEncode(new) end
		return new
	end
	function m:read(k)
		return self.data[k] and HttpService:JSONDecode(self.data[k]) or nil
	end
	function m:write(k, v)
		self.data[k] = HttpService:JSONEncode(v)
	end
	return m
end

return CareerStore
