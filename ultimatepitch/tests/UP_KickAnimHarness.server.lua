-- UltimatePitch v0.5 · 2-Client-Test KickAnim (nur Test-Place, nicht Teil des Builds).
-- Wartet auf 2 Spieler im laufenden Match, legt dem ersten Spieler alle 3 s den Ball vor die Füße
-- (der Client-Probe spielt dann selbst einen echten Pass über das Kick-RemoteEvent), sammelt nach
-- 30 s die Berichte beider Clients und beendet den StudioTestService-Lauf mit dem Ergebnis.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "UP_Sec"
local report = Instance.new("RemoteEvent")
report.Name = "Report"
report.Parent = folder
folder.Parent = RS

local reports = {}
report.OnServerEvent:Connect(function(plr, key, text)
	reports[plr.Name .. ":" .. tostring(key)] = tostring(text)
end)

-- Diagnose: kommen die Pass-Anfragen des Passers am Server an?
local passReq = 0
RS:WaitForChild("UltimatePitch"):WaitForChild("Kick").OnServerEvent:Connect(function(_, kind)
	if kind == "Pass" then passReq += 1 end
end)

local function finish(result)
	pcall(function() game:GetService("StudioTestService"):EndTest(result) end)
end

task.spawn(function()
	local t0 = os.clock()
	while #Players:GetPlayers() < 2 and os.clock() - t0 < 120 do task.wait(0.5) end
	local State = RS:WaitForChild("UltimatePitch"):WaitForChild("State")
	while State:GetAttribute("Phase") ~= "Playing" and os.clock() - t0 < 180 do task.wait(0.5) end
	local plist = Players:GetPlayers()
	if #plist < 2 or State:GetAttribute("Phase") ~= "Playing" then
		finish({ ok = false, why = "kein Match mit 2 Spielern", players = #plist })
		return
	end
	local first = plist[1]
	folder:SetAttribute("Passer", first.Name)
	folder:SetAttribute("Start", true)
	local ball = workspace.UltimatePitch.Ball
	local feeds = 0
	local tEnd = os.clock() + 30
	while os.clock() < tEnd do
		local root = first.Character and first.Character:FindFirstChild("HumanoidRootPart")
		if root and State:GetAttribute("Phase") == "Playing" then
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
			ball.AssemblyLinearVelocity = Vector3.zero
			ball.CFrame = CFrame.new(root.Position.X, 2.1, root.Position.Z) + look * 2.6
			feeds += 1
		end
		task.wait(3)
	end
	folder:SetAttribute("Stop", true)
	local t1 = os.clock()
	while os.clock() - t1 < 20 do
		local n = 0
		for k in pairs(reports) do if string.sub(k, -5) == ":kick" then n += 1 end end -- nur Endberichte zählen
		if n >= 2 then break end
		task.wait(0.5)
	end
	local result = { ok = true, passer = first.Name, feeds = feeds, passRequests = passReq }
	for k, v in pairs(reports) do result[k] = v end
	finish(result)
end)
