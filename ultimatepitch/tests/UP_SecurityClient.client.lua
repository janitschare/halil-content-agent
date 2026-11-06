-- UltimatePitch v0.4 Sicherheits- und Regressions-Harness (Client). Nicht Teil des Builds:
-- nur für Testläufe nach StarterPlayerScripts kopieren. Bleibt inaktiv, bis ein Test
-- ReplicatedStorage.UP_Sec (Folder mit RemoteEvent "Report") anlegt.
-- Steuerung: UP_Sec@Actor = Spielername, UP_Sec@Step = Schritt, UP_Sec@Arg = Zahl, UP_Sec@Seq = Zähler (erzwingt Auslösung).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local folder = RS:FindFirstChild("UP_Sec")
while not folder do
	local child = RS.ChildAdded:Wait()
	if child.Name == "UP_Sec" then folder = child end
end
local me = Players.LocalPlayer
local report = folder:WaitForChild("Report")
local Kick = RS:WaitForChild("UltimatePitch"):WaitForChild("Kick")

local received = {}
Kick.OnClientEvent:Connect(function(what) table.insert(received, tostring(what)) end)

local function root()
	local char = me.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

-- Läuft dt-weise in Blickrichtung (echte Client-Bewegung) und liefert die gemessene Strecke
local function walk(seconds)
	local r, hum = root()
	if not r or not hum then return 0 end
	local start = r.Position
	local dir = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		hum:Move(dir, false)
		RunService.Heartbeat:Wait()
	end
	hum:Move(Vector3.zero, false)
	return (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude
end

local STEPS = {
	-- P1 Schussladung
	shot_nocharge = function() Kick:FireServer("Shot", 1) end,
	shot_fakepower = function() Kick:FireServer("ChargeStart"); Kick:FireServer("Shot", 1) end,
	shot_stale = function() Kick:FireServer("ChargeStart"); task.wait(4.5); Kick:FireServer("Shot", 1) end,
	-- P1 Ausdauer/Sprint: Dauer-Sprint 6 s
	sprint_hold = function()
		Kick:FireServer("Sprint", true)
		local d = walk(6)
		Kick:FireServer("Sprint", false)
		local _, hum = root()
		return ("strecke=%.1f walkspeed_jetzt=%s"):format(d, tostring(hum and hum.WalkSpeed))
	end,
	-- Bewegungsplausibilität: lokaler Teleport bzw. lokal erhöhte Laufgeschwindigkeit
	teleport = function()
		local r = root()
		if r then r.CFrame = r.CFrame + r.CFrame.LookVector * 60 end
		task.wait(1)
		return ("pos_nach_1s=(%.1f,%.1f)"):format(r.Position.X, r.Position.Z)
	end,
	speedhack = function()
		local _, hum = root()
		if hum then hum.WalkSpeed = 80 end
		local d = walk(2)
		return ("strecke_2s=%.1f"):format(d)
	end,
	aurora_spam = function() for _ = 1, 10 do Kick:FireServer("Aurora") end end,
	-- Reguläre Aktionen für den Regressionslauf (Arg = Ladedauer in s)
	pass = function() Kick:FireServer("Pass") end,
	shot = function()
		Kick:FireServer("ChargeStart")
		task.wait(tonumber(folder:GetAttribute("Arg")) or 0.5)
		Kick:FireServer("Shot")
	end,
	aurora = function() Kick:FireServer("Aurora") end,
	-- Blick (nur Drehung, keine Positionsänderung) auf das gegnerische Tor; Arg = Ziel-Z
	face_goal = function()
		local r = root()
		if not r then return end
		local goalX = (me.Team and me.Team.Name == "Rot") and 81 or -81
		local z = tonumber(folder:GetAttribute("Arg")) or 0
		r.CFrame = CFrame.lookAt(r.Position, Vector3.new(goalX, r.Position.Y, z))
	end,
}

folder:GetAttributeChangedSignal("Seq"):Connect(function()
	local step = folder:GetAttribute("Step")
	local run = STEPS[step]
	if not run or folder:GetAttribute("Actor") ~= me.Name then return end
	table.clear(received)
	local info = run()
	task.wait(0.6)
	report:FireServer(step, (info or "") .. " | rueckmeldungen=" .. table.concat(received, ","))
end)
report:FireServer("ready", me.Name)
