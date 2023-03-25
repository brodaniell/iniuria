if not game:IsLoaded() then
    game.Loaded:Wait()
end

if getgenv().iniuria then
    return
end

-- globals
local drawlib = Drawing
local pairs = pairs
local tick = tick
local getgenv = getgenv

-- setting up random generator
math.randomseed(tick())
local function randomString(length: number)
	local str = ""
	for _ = 1, length do
		str = str .. string.char(math.random(97, 122))
	end
	return str
end

-- loop names
getgenv().render_loop_stepped_name = getgenv().renderloop_stepped_name or randomString(math.random(15, 35))
getgenv().update_loop_stepped_name = getgenv().update_loop_stepped_name or randomString(math.random(15, 35))
getgenv().iniuria = true

-- services
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Teams = game:GetService('Teams')
local UserInputService = game:GetService('UserInputService')
local HttpService = game:GetService('HttpService')

-- values
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera
local DummyPart = Instance.new('Part', nil)
local ignoredInstances = {}
local LastTick = 0
local StartAim = false

-- raycast
local RaycastParam = RaycastParams.new()
RaycastParam.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParam.IgnoreWater = true

-- drawing lib objects
local aimingDraw = {
    fovCircle = nil,
    line = nil
}

local espDraw = {
    box = {
        boxHolder = {},
        boxHealth = {},
        boxName = {},
    },
}

-- character parts
local CharacterParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- init drawing lib
drawlib.new('Square').Visible = false

-- ui lib
local repo = 'https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Iniuria | v0.1 | alpha'
})

-- legit
local LegitTab = Window:AddTab('Legit')
local LegitTabbox1 = LegitTab:AddLeftGroupbox('Aimbot')
LegitTabbox1:AddSlider('MaxDistance', { Text = "Max Distance", Suffix = "m", Default = 5000, Min = 0, Max = 5000, Rounding = 0})
LegitTabbox1:AddSlider('AimbotFOV', { Text = "Aimbot FOV", Suffix = "m", Default = 10, Min = 0, Max = 10, Rounding = 0})
LegitTabbox1:AddDivider()
LegitTabbox1:AddSlider('AimbotAdj', { Text = "Aim Adjustment", Suffix = "%", Default = 50, Min = 1, Max = 100, Rounding = 0})
LegitTabbox1:AddSlider('AimbotAdjStr', { Text = "Aim Adjustment Strength", Suffix = "x", Default = 5, Min = 1, Max = 5, Rounding = 0})
LegitTabbox1:AddDivider()
LegitTabbox1:AddSlider('AimbotOffsetX', { Text = "Aimbot Offset X", Default = 0, Min = -10, Max = 10, Rounding = 0})
LegitTabbox1:AddSlider('AimbotOffsetY', { Text = "Aimbot Offset Y", Default = 0, Min = -10, Max = 10, Rounding = 0})
local LegitTabbox2 = LegitTab:AddRightGroupbox('Global Aimbot Settings')
LegitTabbox2:AddToggle('VCheck', {Text = 'Visibility Check'})
LegitTabbox2:AddToggle('TCheck', {Text = 'Team Check'})
LegitTabbox2:AddToggle('Camera', {Text = 'Disable when using Camera'})

-- clanning
local ClanningTab = Window:AddTab('Clanning')
local ClanningTabbox1 = ClanningTab:AddLeftGroupbox('Useful')
ClanningTabbox1:AddLabel('Nothing here yet :)')

-- visual
local VisualTab = Window:AddTab('Visual')
local VisualTabbox1 = VisualTab:AddLeftGroupbox('Something')
VisualTabbox1:AddLabel('Nothing here yet :)')

-- settings
local SettingsTab = Window:AddTab('Settings')
local ThemesTabbox = SettingsTab:AddLeftGroupbox('Themes')
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('aimware')
SaveManager:SetFolder('aimware')
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToGroupbox(ThemesTabbox)
Library:OnUnload(function()
    Library.Unloaded = true
end)
SaveManager:LoadAutoloadConfig()

-- functions
local function newDrawing(class_name)
    return function(props)
        local inst = drawlib.new(class_name)

        for idx, val in pairs(props) do
            if idx ~= "instance" then
                inst[idx] = val
            end
        end

        return inst
    end
end

local function addOrUpdateInstance(table, child, props)
    local inst = table[child]
    if not inst then
        table[child] = newDrawing(props.instance)(props)
        return inst
    end

    for idx, val in pairs(props) do
        if idx ~= "instance" then
            inst[idx] = val
        end
    end

    return inst
end

local function getCharacter(player: Player)
    local character = game:GetService("Workspace"):FindFirstChild(player.Name) or game:GetService("Workspace"):WaitForChild(player.Name, 1000)
    if not character:IsDescendantOf(game:GetService("Workspace")) then return nil end
    return character
end

local function toViewportPoint(v3: Vector3)
    local screenPos, visible = Camera:WorldToViewportPoint(v3)
    return Vector3.new(screenPos.X, screenPos.Y, screenPos.Z), visible
end

local function canHit(originPosition, target)
    if not Toggles.VCheck.Value then
        return true
    end

    local ignoreList = {Camera, getCharacter(LocalPlayer)}
    for _, v in pairs(ignoredInstances) do
        ignoreList[#ignoreList + 1] = v
    end

    RaycastParam.FilterDescendantsInstances = ignoreList
    local raycast = workspace:Raycast(originPosition, (target.Position - originPosition).Unit * Options.MaxDistance.Value, RaycastParam)
    local resultPart = ((raycast and raycast.Instance) or DummyPart)
    if resultPart ~= DummyPart then
        if resultPart.Transparency >= 0.3 then -- ignore low transparency
            ignoredInstances[#ignoredInstances + 1] = resultPart
        end

        if resultPart.Material == Enum.Material.Glass then -- ignore glass
            ignoredInstances[#ignoredInstances + 1] = resultPart
        end
    end

    return resultPart:IsDescendantOf(target.Parent)
end

local function sameTeam(character)
    if not Toggles.TCheck.Value then
        return false
    end

    if Players:GetPlayerFromCharacter(character) then
        local target = Players:GetPlayerFromCharacter(character)
        if target.Team == LocalPlayer.Team then
            return true
        end
    end

    return false
end

local function hasHealth(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if character and humanoid then
        if humanoid.Health > 0 then
            return true
        end
    end

    return false
end

local function isInsideFOV(target)
    return ((target.X - aimingDraw.fovCircle.Position.X) ^ 2 + (target.Y - aimingDraw.fovCircle.Position.Y) ^ 2 <= aimingDraw.fovCircle.Radius ^ 2)
end

local function getClosestObjectFromMouse()
	local closest = {Distance = Options.MaxDistance.Value, Character = nil}
	local mousePos = UserInputService:GetMouseLocation()

    for _, hum in pairs(game:GetService("Workspace"):GetDescendants()) do
        if not hum:IsA("Humanoid") then continue end
        local character = hum.Parent
        local hRP = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 1000)
        if hRP then
            local position, _ = toViewportPoint(hRP.Position)
            local distance = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
            if not character or distance > Options.MaxDistance.Value or
                (closest.Distance and distance >= closest.Distance) then continue
            end
            closest = {Distance = distance, Character = character}
        end
    end
	return closest
end

local function getClosestPartFromMouse()
    local target = getClosestObjectFromMouse().Character
    local mousePos = UserInputService:GetMouseLocation()
    local closest = {Part = nil, Distance = Options.MaxDistance.Value}
    for _, parts in pairs(target:GetChildren()) do
        if not table.find(CharacterParts, parts.Name) then continue end
        local position, _ = toViewportPoint(parts.Position)
        local distance = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
        if distance > Options.MaxDistance.Value or
            (closest.Distance and distance >= closest.Distance) then continue
        end
        closest = {Part = parts, Distance = distance}
    end

    return closest
end

local function aimbot()
    local closestHitbox = getClosestPartFromMouse()
    local target = getClosestObjectFromMouse().Character
    local headPos = getCharacter(LocalPlayer):FindFirstChild("Head") or getCharacter(LocalPlayer):WaitForChild("Head", 1000)
    if not headPos then return end

    local position, visible = toViewportPoint(closestHitbox.Part.Position)
    local mousePos = UserInputService:GetMouseLocation()
    

    if closestHitbox.Part and target then
        if canHit(headPos.Position, closestHitbox.Part) and visible and isInsideFOV(position) then
            if hasHealth(target) and not sameTeam(target) then
                local aimbotStrength = Options.AimbotAdjStr.Value
                if aimbotStrength <= 0 then
                    aimbotStrength = 2
                end
                local aimbotAdjustment = Options.AimbotAdj.Value
                if aimbotAdjustment <= 0 then
                    aimbotAdjustment = 5
                end

                local stabilize = ((aimbotAdjustment * (aimbotStrength * 2))) / Camera.ViewportSize.Y

                local finalEnd = Vector2.new(math.floor((position.X - mousePos.X)), math.floor((position.Y - mousePos.Y)))

                local endX = finalEnd.X * stabilize
                local endY = finalEnd.Y * stabilize
                --printconsole("x " .. endX .. " | y " .. endY)
                mousemoverel(endX, endY)
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        StartAim = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        StartAim = false
    end
end)

local function stepped()
    if (tick() - LastTick) > (10 / 1000) then
        LastTick = tick()

        -- fov circle
        addOrUpdateInstance(aimingDraw, "fovCircle", {
            Visible = false,
            Thickness = 1,
            Radius = (Options.AimbotFOV.Value * 10),
            Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y),
            Color = Color3.new(1, 1, 1),
            instance = "Circle";
        })
    end
end

Mouse.Move:Connect(function()
    local hit = Mouse.Target
    if StartAim and not (hit and hit.Parent:FindFirstChild("Humanoid")) then
        aimbot()
    end
end)

RunService:BindToRenderStep(update_loop_stepped_name, 199, stepped)