-- UltimatePitch Test-Harness (Server). Nur aktiv in StudioTestService-Laeufen mit Args "UP_MP2"
-- oder wenn Workspace-Attribut UP_RunMP gesetzt ist (Studio-Testmodus "Server & Clients").
-- Nicht Teil von build.py: bei Bedarf nach ServerScriptService kopieren.
-- Sitzung bleibt offen: Bericht per MCP lesen (ReplicatedStorage.UP_Test@Report),
-- danach StudioTestService:EndTest(report) auf dem Server aufrufen.
local STS = game:GetService("StudioTestService")
local ok, args = pcall(function() return STS:GetTestArgs() end)
local viaSTS = ok and args == "UP_MP2"
if not (viaSTS or workspace:GetAttribute("UP_RunMP")) then return end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local folder = Instance.new("Folder"); folder.Name = "UP_Test"; folder.Parent = RS
local reportEv = Instance.new("RemoteEvent"); reportEv.Name = "Report"; reportEv.Parent = folder

local lines = {}
local function log(s)
	table.insert(lines, s)
	print("[UP_TEST] " .. s)
	folder:SetAttribute("Report", table.concat(lines, "\n"))
end
local function finish()
	folder:SetAttribute("Done", true)
end
local function waitFor(cond, timeout)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > timeout then return false end
		task.wait(0.2)
	end
	return true
end

-- Clients melden "ready", sobald ihr Harness laeuft (Test-Clients laden teils >90 s)
local clientReports, ready = {}, {}
reportEv.OnServerEvent:Connect(function(plr, key, val)
	if key == "ready" then ready[plr] = true end
	clientReports[plr.Name .. ":" .. tostring(key)] = val
end)
local function allReady()
	for _, p in ipairs(Players:GetPlayers()) do
		if not ready[p] then return false end
	end
	return true
end

if not waitFor(function() return #Players:GetPlayers() >= 2 and allReady() end, 240) then
	log("FAIL Clients nicht bereit, Spieler=" .. #Players:GetPlayers()); return finish()
end
log("Spieler verbunden und bereit: " .. #Players:GetPlayers())
-- Test-Clients haengen kurz nach dem Beitritt oft >15 s in CoreScripts: Zeit zum Beruhigen geben
task.wait(20)

-- Frisches Match abwarten, damit alle Schritte in dieselbe Spielzeit passen
local State = RS:WaitForChild("UltimatePitch"):WaitForChild("State")
if not waitFor(function()
	return State:GetAttribute("Phase") == "Playing" and (State:GetAttribute("TimeLeft") or 0) >= 150
end, 400) then
	log("FAIL kein frisches Match, Phase=" .. tostring(State:GetAttribute("Phase"))); return finish()
end
task.wait(1.5)
local Bots = workspace.UltimatePitch.Bots
local Ball = workspace.UltimatePitch.Ball
local Kick = RS.UltimatePitch.Kick
local plist = Players:GetPlayers()
log("Phase Playing, Bots=" .. #Bots:GetChildren())
local teams = {}
for _, p in ipairs(plist) do
	teams[#teams + 1] = p.Team and p.Team.Name or "nil"
	log(p.Name .. " Team=" .. teams[#teams])
end
log(teams[1] ~= teams[2] and "OK Spieler in verschiedenen Teams" or "FAIL Spieler im selben Team")
log(#Bots:GetChildren() == 8 and "OK 8 Bots fuellen auf 5v5 auf" or "FAIL Botzahl " .. #Bots:GetChildren())

-- Ball-Replikation bei ruhendem Ball + HUD je Client
Ball.Anchored = true
Ball.CFrame = CFrame.new(5, 2.1, 10)
task.wait(1)
folder:SetAttribute("Step", "ball")
waitFor(function()
	return clientReports[plist[1].Name .. ":ball"] and clientReports[plist[2].Name .. ":ball"]
end, 30)
for _, p in ipairs(plist) do
	local cp = clientReports[p.Name .. ":ball"]
	if cp then
		local dev = (cp - Ball.Position).Magnitude
		log(("%s Ball %s: Abweichung Client/Server %.2f Studs"):format(dev < 0.5 and "OK" or "FAIL", p.Name, dev))
	else
		log("FAIL kein Ball-Report von " .. p.Name)
	end
	log("HUD " .. p.Name .. ": " .. tostring(clientReports[p.Name .. ":hud"]))
end
Ball.Anchored = false

-- Echter Schuss je Client (LocalScript feuert das RemoteEvent)
for i, p in ipairs(plist) do
	p.Character:PivotTo(CFrame.lookAt(Vector3.new(-3, 4.5, -40), Vector3.new(10, 4.5, -40)))
	Ball.AssemblyLinearVelocity = Vector3.zero
	Ball.CFrame = CFrame.new(-0.5, 2.1, -40)
	task.wait(0.3)
	local res
	local conn = Kick.OnServerEvent:Connect(function(plr)
		if plr == p then task.defer(function() res = Ball.AssemblyLinearVelocity.Magnitude end) end
	end)
	folder:SetAttribute("Kicker", p.Name)
	folder:SetAttribute("Step", "kick" .. i)
	waitFor(function() return res ~= nil end, 20)
	conn:Disconnect()
	log((res and res > 40) and ("OK Schuss " .. p.Name .. " v=" .. math.floor(res)) or ("FAIL Schuss " .. p.Name .. " v=" .. tostring(res)))
	task.wait(0.5)
end

-- Spaet beitreten: dritter Spieler mitten im Match (nur ueber StudioTestService moeglich)
if viaSTS then
	local before = {}
	for _, p in ipairs(Players:GetPlayers()) do before[p] = true end
	local botsBefore = #Bots:GetChildren()
	local okAdd, err = pcall(function() STS:AddPlayers(1) end)
	if not okAdd then
		log("FAIL AddPlayers: " .. tostring(err))
	else
		local newP
		waitFor(function()
			for _, p in ipairs(Players:GetPlayers()) do
				if not before[p] then newP = p end
			end
			return newP ~= nil and newP.Character ~= nil
		end, 240)
		task.wait(2)
		if not newP then
			log("FAIL kein dritter Spieler beigetreten")
		else
			local tn = newP.Team and newP.Team.Name or "nil"
			log(("Spaeter Spieler %s: Team=%s, Phase=%s, Bots %d -> %d"):format(newP.Name, tn,
				tostring(State:GetAttribute("Phase")), botsBefore, #Bots:GetChildren()))
			log(((tn == "Rot" or tn == "Blau") and #Bots:GetChildren() == botsBefore - 1)
				and "OK spaeter Spieler ersetzt Feldspieler-Bot" or "FAIL spaeter Spieler nicht eingewechselt")
		end
	end
end

-- Disconnect mitten im Match -> Bot ersetzt Spieler
local leaver = plist[2]
local botsBefore = #Bots:GetChildren()
folder:SetAttribute("Leaver", leaver.Name)
folder:SetAttribute("Step", "leave")
local left = waitFor(function() return leaver.Parent == nil end, 15)
task.wait(1)
log(left and "OK Client getrennt" or "FAIL Client nicht getrennt")
log(#Bots:GetChildren() == botsBefore + 1 and ("OK Bot ersetzt Spieler (Bots=" .. #Bots:GetChildren() .. ")") or ("FAIL Bots=" .. #Bots:GetChildren()))
task.wait(3)
log("Nach Disconnect: Phase=" .. tostring(State:GetAttribute("Phase")) .. ", Spieler=" .. #Players:GetPlayers() .. ", Spielstand " .. State:GetAttribute("RedScore") .. ":" .. State:GetAttribute("BlueScore"))
finish()
