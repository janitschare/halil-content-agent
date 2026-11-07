-- UltimatePitch v0.5 · 2-Client-Test KickAnim (nur Test-Place, nicht Teil des Builds).
-- Ablauf: 2 Spieler im laufenden Match -> Startsignal -> warten, bis BEIDE Clients "go" melden (simulierte
-- Clients laufen im Hintergrund teils stark gedrosselt) -> 30 s lang dem ersten Spieler alle 3 s den Ball
-- vorlegen (seine Sonde spielt dann selbst einen echten Pass über das Kick-RemoteEvent) -> Stoppsignal ->
-- bis zu 60 s auf die Endberichte warten -> StudioTestService-Lauf mit strengem Ergebnis beenden.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
-- true = Negativkontrolle: Clients schalten die Kickanimation ab (Ergebnis muss dann rot sein)
local NEG_CONTROL = false

local folder = Instance.new("Folder")
folder.Name = "UP_Sec"
local report = Instance.new("RemoteEvent")
report.Name = "Report"
report.Parent = folder
folder.Parent = RS

local tStart = nil
local reports, arrived = {}, {}
report.OnServerEvent:Connect(function(plr, key, text)
	local k = plr.Name .. ":" .. tostring(key)
	reports[k] = tostring(text)
	arrived[k] = tStart and string.format("%.1f", os.clock() - tStart) or "vor Start"
end)

-- Diagnose: kommen die Pass-Anfragen des Passers am Server an?
local passReq = 0
RS:WaitForChild("UltimatePitch"):WaitForChild("Kick").OnServerEvent:Connect(function(_, kind)
	if kind == "Pass" then passReq += 1 end
end)

local function finish(result)
	pcall(function() game:GetService("StudioTestService"):EndTest(result) end)
end

local function waitFor(names, suffix, timeout)
	local t = os.clock()
	while os.clock() - t < timeout do
		local all = true
		for _, n in ipairs(names) do
			if not reports[n .. suffix] then all = false end
		end
		if all then return true end
		task.wait(0.5)
	end
	return false
end

task.spawn(function()
	local t0 = os.clock()
	while #Players:GetPlayers() < 2 and os.clock() - t0 < 120 do task.wait(0.5) end
	local State = RS:WaitForChild("UltimatePitch"):WaitForChild("State")
	while State:GetAttribute("Phase") ~= "Playing" and os.clock() - t0 < 180 do task.wait(0.5) end
	local plist = Players:GetPlayers()
	if #plist < 2 or State:GetAttribute("Phase") ~= "Playing" then
		finish({ ok = false, status = "INVALID", why = "Umgebung: kein Match mit 2 Spielern", players = #plist })
		return
	end
	local names = { plist[1].Name, plist[2].Name }
	local first = plist[1]
	folder:SetAttribute("NegControl", NEG_CONTROL)
	folder:SetAttribute("Passer", first.Name)
	tStart = os.clock()
	folder:SetAttribute("Start", true)
	local bothGo = waitFor(names, ":go", 90)
	local goWait = os.clock() - tStart
	if not bothGo then
		-- Fail-fast: ohne beide bereiten Clients kein Ball-Feed und kein Warten auf Endberichte
		folder:SetAttribute("Stop", true)
		local result = { ok = false, status = "INVALID", why = "Umgebung: nicht beide Clients nach 90 s bereit",
			goWait = string.format("%.1f", goWait) }
		for k, v in pairs(arrived) do result["t_" .. k] = v end
		finish(result)
		return
	end
	local ball = workspace.UltimatePitch.Ball
	local feeds = 0
	local tEnd = os.clock() + 30
	while os.clock() < tEnd do
		local root = first.Character and first.Character:FindFirstChild("HumanoidRootPart")
		if root and (State:GetAttribute("Phase") == "Playing" or State:GetAttribute("Phase") == "GoldenGoal") then
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
			ball.AssemblyLinearVelocity = Vector3.zero
			ball.CFrame = CFrame.new(root.Position.X, 2.1, root.Position.Z) + look * 2.6
			feeds += 1
		end
		task.wait(3)
	end
	folder:SetAttribute("Stop", true)
	waitFor(names, ":kick", 60)

	-- Getrennte Urteile (Koordinator-Review 0ca14992):
	--   status  INVALID = Umgebung untauglich (fehlender Endbericht, Client-FPS < MIN_FPS) – kein Urteil über das Spiel
	--           FAIL    = Netzwerkpfad nachweislich fehlerhaft;  PASS = Netzwerkpfad belegt
	--   network PASS/FAIL: KickAnim kommt fehlerfrei an, Pässe des anderen Spielers erreichen den Gegenclient
	--   signature PASS/FAIL/HOLD: Kicksignatur (> 1,1 rad) nur ab VISUAL_FPS bewertbar, sonst HOLD.
	--           Positivlauf erwartet Signatur auf beiden Clients, Negativkontrolle erwartet keine.
	local MIN_FPS, VISUAL_FPS = 2, 30
	local invalid, fail, sigFail, minFps = {}, {}, {}, math.huge
	for _, p in ipairs(plist) do
		local r = reports[p.Name .. ":kick"]
		if not r then
			table.insert(invalid, p.Name .. ": kein Endbericht")
		else
			local errors = tonumber(r:match("fehler=(%d+)")) or 0
			local fps = tonumber(r:match("fps=([%d%.]+)")) or 0
			local events = tonumber(r:match("events=(%d+)")) or 0
			local sig = tonumber(r:match(" kicksignatur=(%d+)")) or 0
			local otherSig = tonumber(r:match("anderer_kicksignatur=(%d+)")) or 0
			minFps = math.min(minFps, fps)
			if fps < MIN_FPS then table.insert(invalid, p.Name .. ": Client gedrosselt (fps " .. fps .. ")") end
			if errors > 0 then table.insert(fail, p.Name .. ": " .. errors .. " Formatfehler") end
			if events == 0 then table.insert(fail, p.Name .. ": keine KickAnim-Ereignisse") end
			if p ~= first and passReq > 0 and (tonumber(r:match("anderer=(%d+)")) or 0) == 0 then
				table.insert(fail, p.Name .. ": kein Pass des anderen Spielers angekommen")
			end
			if NEG_CONTROL then
				if sig > 0 then table.insert(sigFail, p.Name .. ": Kicksignatur trotz abgeschalteter Animation (" .. sig .. ")") end
			else
				if sig == 0 then table.insert(sigFail, p.Name .. ": keine Kicksignatur") end
				if p ~= first and passReq > 0 and otherSig == 0 then
					table.insert(sigFail, p.Name .. ": Pass des anderen Spielers ohne Kicksignatur")
				end
			end
		end
	end
	local status = #invalid > 0 and "INVALID" or (#fail > 0 and "FAIL" or "PASS")
	local signature = "HOLD (Client-FPS < " .. VISUAL_FPS .. ")"
	if status ~= "INVALID" and minFps >= VISUAL_FPS then signature = #sigFail > 0 and "FAIL" or "PASS" end
	local why = {}
	for _, list in ipairs({ invalid, fail, sigFail }) do
		for _, w in ipairs(list) do table.insert(why, w) end
	end
	local result = { ok = status == "PASS", status = status, network = status == "INVALID" and "-" or status,
		signature = signature, negControl = NEG_CONTROL, why = table.concat(why, "; "), passer = first.Name, feeds = feeds,
		passRequests = passReq, goWait = string.format("%.1f", goWait) }
	for k, v in pairs(reports) do result[k] = v end
	for k, v in pairs(arrived) do result["t_" .. k] = v end
	finish(result)
end)
