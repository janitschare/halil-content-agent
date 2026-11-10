-- UltimatePitch · dauerhafter Karriere-Speicherstand (ModuleScript unter UltimatePitchServer, nur Server)
-- Ein Datensatz je Spieler (Schlüssel "u_<UserId>") mit Coins, Stufe, Besitz, Ausrüstung und Statistik.
-- Alle Zugriffe laufen über UpdateAsync mit einer Sitzungssperre (lock = { job = JobId, sid = Ladekennung, t = os.time() }):
--   * Laden sperrt den Datensatz für genau diesen Ladevorgang. Ist eine Sperre noch frisch (ein anderer Server spielt
--     oder speichert gerade beim Serverwechsel), wird gewartet, bis sie freigegeben wird oder abläuft – nie übernommen.
--   * Der haltende Server erneuert seine Sperre mit jedem Autosave (Aufrufer: regelmäßig, auch ohne Änderungen);
--     eine Sperre älter als LOCK_TIMEOUT stammt von einem abgestürzten Server und darf übernommen werden.
--   * Speichern schreibt nur, solange genau die eigene Sperre im Datensatz steht; sonst "lost".
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

-- store: DataStore oder CareerStore.memory()
-- opts = { jobId, items, stages, now?, wait?, newToken?, retries?, lockWait?, maxLockWait? }
function CareerStore.new(store, opts)
	local self = {}
	local jobId = opts.jobId
	local now = opts.now or os.time
	local wait = opts.wait or task.wait
	local newToken = opts.newToken or function() return HttpService:GenerateGUID(false) end
	local retries = opts.retries or 4 -- Fehlversuche (Netz/Budget) bis "error"
	local lockWait = opts.lockWait or 5 -- Sekunden zwischen zwei Versuchen bei fremder Sperre
	-- so lange höchstens auf eine fremde, frische Sperre warten (sie läuft spätestens nach LOCK_TIMEOUT ab, weil
	-- der haltende Server sie nur durch regelmäßiges Speichern erneuert); danach "error" statt Übernahme
	local maxLockWait = opts.maxLockWait or (CareerStore.LOCK_TIMEOUT + 30)

	-- Sperre eines anderen Ladevorgangs (anderer Server oder früherer Beitritt), die noch nicht abgelaufen ist
	local function freshLock(old)
		local lock = type(old) == "table" and old.lock
		return type(lock) == "table" and type(lock.t) == "number" and now() - lock.t < CareerStore.LOCK_TIMEOUT
	end

	-- Lädt und sperrt. Jeder Ladevorgang erhält eine eigene Kennung (token); nur mit ihr darf später gespeichert
	-- werden. Eine frische Sperre wird nie übernommen, nur eine freigegebene oder abgelaufene.
	-- cancelled(): optional, bricht das Warten ab (Spieler hat das Spiel verlassen).
	-- Rückgabe: "ok", data, token | "error", Meldung | "cancelled"
	function self.load(userId, cancelled)
		local errors, waited = 0, 0
		local token = newToken()
		while true do
			local blocked, newer, raw = false, false, nil
			local ok, err = pcall(function()
				store:UpdateAsync(key(userId), function(old)
					blocked, newer, raw = false, false, old
					if type(old) == "table" and type(old.schema) == "number" and old.schema > CareerStore.SCHEMA then
						newer = true -- von einer neueren Spielversion geschrieben: nicht anfassen
						return nil
					end
					-- eigene Sperre dieses Ladevorgangs (ein früherer Versuch hat geschrieben, nur die Antwort ging
					-- verloren) ist kein Hindernis
					local lock = type(old) == "table" and old.lock
					local mine = type(lock) == "table" and lock.job == jobId and lock.sid == token
					if not mine and freshLock(old) then
						blocked = true
						return nil
					end
					local rec = type(old) == "table" and old or {}
					rec.lock = { job = jobId, sid = token, t = now() }
					return rec, { userId }
				end)
			end)
			if ok and newer then return "error", "Spielstand stammt aus einer neueren Version" end
			if ok and not blocked then return "ok", CareerStore.sanitize(raw, opts.items, opts.stages), token end
			if cancelled and cancelled() then return "cancelled" end
			if ok then
				if waited >= maxLockWait then return "error", "Spielstand wird noch von einem anderen Server gehalten" end
				waited += lockWait
				wait(lockWait)
			else
				errors += 1
				if errors >= retries then return "error", tostring(err) end
				wait(2 ^ errors)
			end
		end
	end

	-- Speichert; schreibt nur, wenn der Datensatz noch genau mit der Sperre dieses Ladevorgangs (token) belegt ist.
	-- Eine fehlende oder fremde Sperre bedeutet: ein anderer Server hat übernommen (und ggf. schon freigegeben).
	-- release = Sperre freigeben (letztes Speichern). Rückgabe: "ok" | "lost" | "error", Meldung
	function self.save(userId, data, token, release)
		local errors = 0
		while true do
			local lost = false
			local ok, err = pcall(function()
				store:UpdateAsync(key(userId), function(old)
					lost = false
					local lock = type(old) == "table" and old.lock
					if type(lock) ~= "table" or lock.sid ~= token or lock.job ~= jobId then
						-- Freigabe dieses Ladevorgangs wurde bereits geschrieben (Antwort ging verloren): erledigt
						if release and lock == nil and type(old) == "table" and old.releasedBy == token then return nil end
						lost = true
						return nil
					end
					local rec = CareerStore.serialize(data)
					if release then rec.releasedBy = token else rec.lock = { job = jobId, sid = token, t = now() } end
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
-- failNext = n lässt die nächsten n Zugriffe vor dem Schreiben scheitern; failAfterWrite = n schreibt bei den nächsten
-- n Zugriffen und meldet danach trotzdem einen Fehler (verlorene Antwort). Für Selbsttests und den Studio-Testmodus.
function CareerStore.memory()
	local m = { data = {}, failNext = 0, failAfterWrite = 0, calls = 0 }
	function m:UpdateAsync(k, fn)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("simulierter DataStore-Fehler")
		end
		local old = self.data[k] and HttpService:JSONDecode(self.data[k]) or nil
		local new = fn(old)
		if new ~= nil then self.data[k] = HttpService:JSONEncode(new) end
		if self.failAfterWrite > 0 then
			self.failAfterWrite -= 1
			error("simulierter Fehler nach dem Schreiben")
		end
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
