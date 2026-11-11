-- UltimatePitch · Mesh-Requisiten (ModuleScript unter UltimatePitchServer)
-- Setzt Kopien der Cube-3D-Meshes aus ServerStorage.UP_Props in die Welt (Autos, Palmen, Laternen, Bänke, Sneaker,
-- Schreibtisch; erzeugt am 11.11.2026 in Studio, ohne Logos/Marken, Assets auf dem Konto des Entwicklers).
-- Die Vorlagen liegen nur in der Place-Datei (Rojo verwaltet ServerStorage nicht). Fehlt eine Vorlage, etwa im
-- Release-Installer, liefert Props.place nil und der Aufrufer baut die bisherige Version aus Grundteilen.
--
-- Vorlagen-Konvention (in Studio eingestellt, siehe docs/reviews/PROPS_Cube3D_2026-11-11.md):
--   MeshPart, Vorderseite zeigt nach -Z der Vorlagen-Drehung, Größe = Zielgröße im Spiel,
--   CollisionFidelity passend (Box/Hull, zur Laufzeit nicht änderbar), Attribut "BaseOffset" (Vector3, optional) =
--   Punkt der Grundfläche (z. B. Stammfuß der Palme) relativ zur Teilemitte in Studs.
local ServerStorage = game:GetService("ServerStorage")

local Props = {}

local function template(name)
	local folder = ServerStorage:FindFirstChild("UP_Props")
	local t = folder and folder:FindFirstChild(name)
	if t and t:IsA("MeshPart") then return t end
	return nil
end

function Props.has(name)
	return template(name) ~= nil
end

-- name: Vorlage; base: CFrame am Boden (Position = Fußpunkt, Blickrichtung = -Z); parent: Ziel;
-- opts (optional): Tabelle mit Eigenschaften für die Kopie (z. B. CanCollide = false, Name = "...").
-- Rückgabe: die Kopie oder nil, wenn die Vorlage fehlt.
function Props.place(name, base, parent, opts)
	local t = template(name)
	if not t then return nil end
	local p = t:Clone()
	local rot = t.CFrame.Rotation
	-- Fußpunkt: BaseOffset (Teile-Koordinaten) oder Mitte der Unterseite
	local off = t:GetAttribute("BaseOffset")
	if typeof(off) ~= "Vector3" then
		local s = t.Size
		local up = rot:VectorToObjectSpace(Vector3.yAxis)
		local halfH = math.abs(up.X) * s.X / 2 + math.abs(up.Y) * s.Y / 2 + math.abs(up.Z) * s.Z / 2
		off = rot:VectorToObjectSpace(Vector3.new(0, -halfH, 0))
	end
	p.Anchored = true
	p.CFrame = base * rot * CFrame.new(-off)
	if opts then
		for k, v in pairs(opts) do p[k] = v end
	end
	p.Parent = parent
	return p
end

return Props
