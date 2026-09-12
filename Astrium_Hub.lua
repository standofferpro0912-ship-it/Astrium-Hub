--========================================================
-- ASTRIUM HUB - Premium UI/UX
-- Only keyboard shortcut: O = Open / Close
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local AIM_RENDER_NAME = "AstriumHub_Aimbot_Render"
local CAMERA_RENDER_NAME = "AstriumHub_Camera_Render"
local MAIN_RENDER_NAME = "AstriumHub_Main_Render"
pcall(function()
    RunService:UnbindFromRenderStep(AIM_RENDER_NAME)
    RunService:UnbindFromRenderStep(CAMERA_RENDER_NAME)
    RunService:UnbindFromRenderStep(MAIN_RENDER_NAME)
end)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    for _,name in ipairs({"AstriumHub","AstriumHUD","FPSPanel","FPSClientHUD"}) do
        local old=PlayerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local oldColor = game:GetService("Lighting"):FindFirstChild("AstriumHubLocalColor")
    if oldColor then oldColor:Destroy() end
    local oldESPFolder = workspace:FindFirstChild("AstriumHubESP")
    if oldESPFolder then oldESPFolder:Destroy() end
    for _,child in ipairs(PlayerGui:GetChildren()) do
        if child:IsA("BillboardGui") and string.sub(child.Name,1,15)=="AstriumESPInfo_" then
            child:Destroy()
        end
    end
end)

local Config = {
    Aimbot = false,
    Speed = false,
    NoClip = false,
    Fly = false,
    FlySpeed = 70,
    Invisibility = false,
    AimFOV = 180,
    MaxAimDistance = 150,
    SpeedValue = 32,

    -- Extra client-only features
    FOV = 80,
    FullBright = false,
    NoFog = false,
    Crosshair = true,
    CrosshairSize = 8,
    CrosshairGap = 4,
    CrosshairThickness = 2,
    InfiniteJump = false,
    ThirdPerson = false,
    CameraBob = true,
    FPSCounter = true,
    PingCounter = true,
    Coordinates = false,
    LowGraphics = false,
    TeamCheck = false,
    AimSmooth = false,
    AimSmoothness = 8,
    AimPrediction = false,
    AimPredictionAmount = 0.08,
    AimSticky = false,
    AimDeadzone = 0,
    AimTargetPart = "Head",
    AimTargetLock = true, -- keep one target while it remains valid; prevents target flicker
    AimRetargetDelay = 0, -- seconds to wait before acquiring a different target after loss
    AimTargetMode = "ClosestToCursor",

    -- Advanced ESP
    ESP = false,
    ESPBoxes = true,
    ESP3DBoxes = true,
    ESPBoxFill = true,
    ESPCornerBoxes = false,
    ESPTracers = true,
    ESPSkeletons = false,
    ESPHighlight = true,
    ESPNames = true,
    ESPHealth = true,
    ESPHealthText = true,
    ESPDistance = true,
    ESPTeamCheck = false,
    ESPUseTeamColors = true,
    ESPMaxDistance = 1000,
    ESPUpdateRate = 0.06,
    ESPBoxThickness = 1,
    ESPTracerThickness = 1,
    ESPSkeletonThickness = 1,
    ESPHeadDot = true,
    ESPOffscreenArrows = true,
    ESPSnapline = false,
    ESPWeapon = true,
    ESPUsername = false,
    ESPLookDirection = false,
    ESPHighlightFill = 0.82,
    ESPHighlightOutline = 0,
    ESPBoxGlow = true,
    ESPBoxGlowTransparency = 0.78,
    ESPTextScale = 1,
    ESPArrowSize = 14,
    ESPFadeAtDistance = true,
    ESPMaxRendered = 100,

    PersistenceEnabled = true,
    PersistenceFile = "AstriumHub_profiles.json",
    ActiveProfile = "Default",

    AutoSprint = false,
    FOVKick = false,
    FOVKickAmount = 8,
    CameraShake = false,
    CameraShakeAmount = 0.15,
    ReduceParticles = false,
    DisablePostFX = false,
    Saturation = 0,
    Contrast = 0,
    ColorBoost = 0,
    LocalTime = false,
    PanelKey = Enum.KeyCode.O,

}

--========================================================
-- SAVED PROFILES / PERSISTENCE
--========================================================
-- Re-execution persistence:
-- 1) Uses executor file APIs when available (readfile/writefile/isfile).
-- 2) Falls back to getgenv() / _G for same-runtime persistence.
-- Multiple named profiles are supported.

local HttpService = game:GetService("HttpService")
local Env = _G

pcall(function()
    if type(getgenv) == "function" then
        Env = getgenv()
    end
end)

if type(Env.AstriumHubESPConnections)=="table" then
    for _,connection in ipairs(Env.AstriumHubESPConnections) do
        pcall(function() connection:Disconnect() end)
    end
end
Env.AstriumHubESPConnections={}
Env.AstriumHubESPErrorNotified={}
Env.AstriumHubProfiles = Env.AstriumHubProfiles or {}

local function ConfigSnapshot()
    local snapshot = {}
    for key, value in pairs(Config) do
        local kind = typeof(value)
        if kind == "boolean" or kind == "number" or kind == "string" then
            snapshot[key] = value
        end
    end
    return snapshot
end

local function ApplySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    for key, value in pairs(snapshot) do
        if Config[key] ~= nil then
            local expected = typeof(Config[key])
            local actual = typeof(value)
            if expected == actual then
                Config[key] = value
            end
        end
    end
end

local function SaveProfilesToDisk()
    if not Config.PersistenceEnabled then
        return false
    end

    if type(writefile) ~= "function" then
        return false
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Env.AstriumHubProfiles)
    end)

    if not ok then
        return false
    end

    return pcall(function()
        writefile(Config.PersistenceFile, encoded)
    end)
end

local function LoadProfilesFromDisk()
    if not Config.PersistenceEnabled then
        return false
    end

    if type(readfile) ~= "function"
        or type(isfile) ~= "function"
        or not isfile(Config.PersistenceFile) then
        return false
    end

    local ok, raw = pcall(function()
        return readfile(Config.PersistenceFile)
    end)

    if not ok or type(raw) ~= "string" or raw == "" then
        return false
    end

    local decodedOk, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not decodedOk or type(decoded) ~= "table" then
        return false
    end

    Env.AstriumHubProfiles = decoded
    return true
end

local function SaveProfile(name)
    name = tostring(name or Config.ActiveProfile or "Default")
    Env.AstriumHubProfiles = Env.AstriumHubProfiles or {}
    Env.AstriumHubProfiles[name] = ConfigSnapshot()
    Config.ActiveProfile = name
    Env.AstriumHubLastActiveProfile = name
    local ok = SaveProfilesToDisk()
    return ok
end

local function LoadProfile(name)
    name = tostring(name or "Default")
    local snapshot = Env.AstriumHubProfiles[name]
    if type(snapshot) ~= "table" then
        return false
    end

    ApplySnapshot(snapshot)
    Config.ActiveProfile = name
    return true
end

local function GetProfileNames()
    local names = {}
    for name in pairs(Env.AstriumHubProfiles) do
        table.insert(names, tostring(name))
    end
    table.sort(names)
    return names
end

-- Default profile behavior: load the last active profile on every re-execution.
if Config.PersistenceEnabled then
    LoadProfilesFromDisk()

    local savedActive = Env.AstriumHubLastActiveProfile or Config.ActiveProfile or "Default"

    if not LoadProfile(savedActive) then
        if Env.AstriumHubProfiles.Default then
            LoadProfile("Default")
        else
            SaveProfile("Default")
        end
    end
end

local C = {
    Bg = Color3.fromRGB(7,8,12),
    Surface = Color3.fromRGB(13,15,21),
    Surface2 = Color3.fromRGB(19,21,29),
    Surface3 = Color3.fromRGB(27,30,40),
    Border = Color3.fromRGB(41,45,58),
    Text = Color3.fromRGB(248,248,252),
    Sub = Color3.fromRGB(158,162,175),
    Muted = Color3.fromRGB(91,96,111),
    Accent = Color3.fromRGB(145,103,255),
    Accent2 = Color3.fromRGB(101,70,205),
    Good = Color3.fromRGB(70,220,137),
    Bad = Color3.fromRGB(242,85,96),
    Glow = Color3.fromRGB(92,72,170),
}

local function New(class, props, parent)
    local x = Instance.new(class)
    for k,v in pairs(props or {}) do x[k] = v end
    x.Parent = parent
    return x
end
local function Corner(x,r) New("UICorner",{CornerRadius=UDim.new(0,r or 10)},x) end
local function Outline(x,color,thick,trans) New("UIStroke",{Color=color or C.Border,Thickness=thick or 1,Transparency=trans or 0},x) end
local function Gradient(x,c0,c1,r0,r1)
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c0 or C.Surface2),ColorSequenceKeypoint.new(1,c1 or C.Surface)})
    g.Rotation=r0 or 90
    g.Parent=x
    return g
end
local function Shadow(x,alpha)
    local sh=Instance.new("ImageLabel")
    sh.Name="Shadow"
    sh.AnchorPoint=Vector2.new(.5,.5)
    sh.Position=UDim2.fromScale(.5,.5)
    sh.Size=UDim2.new(1,26,1,26)
    sh.BackgroundTransparency=1
    sh.Image="rbxassetid://6015897843"
    sh.ImageColor3=Color3.new(0,0,0)
    sh.ImageTransparency=alpha or .45
    sh.ScaleType=Enum.ScaleType.Slice
    sh.SliceCenter=Rect.new(49,49,450,450)
    sh.ZIndex=0
    sh.Parent=x
    return sh
end
local function T(x,props,time)
    TweenService:Create(x,TweenInfo.new(time or .16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
end

--========================================================
-- ROOT + RESPONSIVE SCALE
--========================================================
local Gui = New("ScreenGui",{
    Name="AstriumHub",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},PlayerGui)
local Scale = New("UIScale",{},Gui)
local function Resize()
    local cam=workspace.CurrentCamera
    if cam then
        local s=math.min(cam.ViewportSize.X,cam.ViewportSize.Y)
        Scale.Scale=math.clamp(s/700,.62,1)
    end
end
Resize()
local camConn
local function BindCamera()
    if camConn then camConn:Disconnect() end
    local cam=workspace.CurrentCamera
    if not cam then return end
    Resize()
    camConn=cam:GetPropertyChangedSignal("ViewportSize"):Connect(Resize)
end
BindCamera()
local currentCamConn=workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.defer(BindCamera) end)

--========================================================
-- FLOATING OPEN/CLOSE BUTTON
--========================================================
local Open = New("TextButton",{
    Size=UDim2.fromOffset(112,44),Position=UDim2.new(0,15,.5,-21),
    BackgroundColor3=C.Surface,Text="",AutoButtonColor=false,BorderSizePixel=0,
},Gui)
Corner(Open,13); Outline(Open,C.Border,1,.1); Gradient(Open,C.Surface2,C.Surface,0,90); Shadow(Open,.58)
local Dot=New("Frame",{Size=UDim2.fromOffset(7,7),Position=UDim2.new(0,13,.5,-3),BackgroundColor3=C.Accent,BorderSizePixel=0},Open); Corner(Dot,8)
local OpenLabel=New("TextLabel",{Size=UDim2.new(1,-40,1,0),Position=UDim2.fromOffset(31,0),BackgroundTransparency=1,Text="ASTRIUM  [O]",TextColor3=C.Text,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Open)

--========================================================
-- WINDOW
--========================================================
local Main=New("Frame",{
    Size=UDim2.fromOffset(470,545),Position=UDim2.new(.5,-235,.5,-272.5),
    BackgroundColor3=C.Bg,BorderSizePixel=0,ClipsDescendants=true,
},Gui)
Corner(Main,18); Outline(Main,C.Border,1,0); Gradient(Main,C.Surface,C.Bg,90,90); Shadow(Main,.52)

local Header=New("Frame",{Size=UDim2.new(1,0,0,74),BackgroundColor3=C.Surface,BorderSizePixel=0,ZIndex=2},Main); Gradient(Header,C.Surface2,C.Surface,0,90)
New("Frame",{Size=UDim2.fromOffset(4,52),Position=UDim2.fromOffset(10,10),BackgroundColor3=C.Accent,BorderSizePixel=0},Header); Corner(Header:FindFirstChildOfClass("Frame"),4)
New("TextLabel",{Size=UDim2.new(1,-145,0,26),Position=UDim2.fromOffset(27,10),BackgroundTransparency=1,Text="ASTRIUM HUB",TextColor3=C.Text,TextSize=20,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Header)
New("TextLabel",{Size=UDim2.new(1,-145,0,17),Position=UDim2.fromOffset(28,39),BackgroundTransparency=1,Text="PRECISION CONTROL CENTER",TextColor3=C.Sub,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Header)
New("TextLabel",{Size=UDim2.fromOffset(78,18),Position=UDim2.new(1,-122,0,13),BackgroundTransparency=1,Text="O  MENU",TextColor3=C.Sub,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right},Header)
local Close=New("TextButton",{Size=UDim2.fromOffset(32,32),Position=UDim2.new(1,-43,.5,-2),BackgroundColor3=C.Surface3,Text="×",TextColor3=C.Sub,TextSize=20,Font=Enum.Font.Gotham,AutoButtonColor=false,BorderSizePixel=0},Header); Corner(Close,9)

-- draggable header
local dragging=false; local dragStart; local startPos
Header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; startPos=Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

--========================================================
-- SIDEBAR + PAGES
--========================================================
local Sidebar=New("Frame",{Size=UDim2.new(0,132,1,-82),Position=UDim2.fromOffset(10,80),BackgroundColor3=C.Surface,BorderSizePixel=0},Main); Corner(Sidebar,14); Outline(Sidebar,C.Border)
New("TextLabel",{Size=UDim2.new(1,-20,0,22),Position=UDim2.fromOffset(10,10),BackgroundTransparency=1,Text="MODULES",TextColor3=C.Muted,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Sidebar)
local TabList=New("ScrollingFrame",{Size=UDim2.new(1,-14,1,-40),Position=UDim2.fromOffset(7,36),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Accent,ScrollBarImageTransparency=.25,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},Sidebar)
New("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},TabList)
local Area=New("Frame",{Size=UDim2.new(1,-152,1,-82),Position=UDim2.fromOffset(145,80),BackgroundTransparency=1,ClipsDescendants=true},Main)

local tabDefs={
    {id="Combat",label="Combat",icon="⊙",desc="Targeting"},
    {id="ESP",label="ESP",icon="◉",desc="Visual tracking"},
    {id="Movement",label="Movement",icon="↗",desc="Speed"},
    {id="Player",label="Player",icon="●",desc="Character"},
    {id="Client",label="Client",icon="◇",desc="Local only"},
    {id="Performance",label="Performance",icon="≋",desc="FPS"},
    {id="Camera",label="Camera",icon="◌",desc="View"},
    {id="Interface",label="Interface",icon="▦",desc="HUD"},
    {id="Graphics",label="Graphics",icon="◈",desc="Visuals"},
    {id="Utility",label="Utility",icon="◆",desc="Quality of life"},
    {id="Settings",label="Settings",icon="⚙",desc="Interface"},
}
local Tabs={}; local Pages={}; local CurrentTab="Combat"; local Refreshers={}

local function Page(id,title,desc)
    local p=New("ScrollingFrame",{Name=id.."Page",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Accent,ScrollBarImageTransparency=.25,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Visible=false},Area)
    New("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,7),PaddingBottom=UDim.new(0,10)},p)
    New("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},p)
    local h=New("Frame",{Size=UDim2.new(1,0,0,52),BackgroundTransparency=1},p)
    New("TextLabel",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=20,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},h)
    New("TextLabel",{Size=UDim2.new(1,0,0,18),Position=UDim2.fromOffset(0,29),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},h)
    Pages[id]=p; return p
end
for n,d in ipairs(tabDefs) do
    local b=New("TextButton",{Size=UDim2.new(1,0,0,43),BackgroundColor3=C.Surface,Text="",AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=n},TabList); Corner(b,10)
    local bar=New("Frame",{Size=UDim2.fromOffset(3,24),Position=UDim2.new(0,0,.5,-12),BackgroundColor3=C.Accent,BackgroundTransparency=1,BorderSizePixel=0},b); Corner(bar,4)
    local icon=New("TextLabel",{Size=UDim2.fromOffset(26,43),Position=UDim2.fromOffset(9,0),BackgroundTransparency=1,Text=d.icon,TextColor3=C.Sub,TextSize=15,Font=Enum.Font.GothamBold},b)
    local lab=New("TextLabel",{Size=UDim2.new(1,-41,1,0),Position=UDim2.fromOffset(38,0),BackgroundTransparency=1,Text=d.label,TextColor3=C.Sub,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},b)
    Tabs[d.id]={b=b,bar=bar,icon=icon,lab=lab}
end
for _,d in ipairs(tabDefs) do Page(d.id,d.label,d.desc) end

local function SelectTab(id)
    CurrentTab=id
    for k,t in pairs(Tabs) do
        local active=k==id
        T(t.b,{BackgroundColor3=active and C.Surface3 or C.Surface},.12)
        T(t.icon,{TextColor3=active and C.Text or C.Sub},.12)
        T(t.lab,{TextColor3=active and C.Text or C.Sub},.12)
        T(t.bar,{BackgroundTransparency=active and 0 or 1},.12)
    end
    for k,p in pairs(Pages) do p.Visible=(k==id) end
end
for id,t in pairs(Tabs) do
    t.b.Activated:Connect(function() SelectTab(id) end)
    t.b.MouseEnter:Connect(function() if CurrentTab~=id then T(t.b,{BackgroundColor3=C.Surface2},.1) end end)
    t.b.MouseLeave:Connect(function() if CurrentTab~=id then T(t.b,{BackgroundColor3=C.Surface},.1) end end)
end

--========================================================
-- COMPONENTS
--========================================================
local function Section(p,title,sub)
    local f=New("Frame",{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(f,12); Outline(f,C.Border,1,.18); Gradient(f,C.Surface2,C.Surface,0,90)
    local mark=New("Frame",{Size=UDim2.fromOffset(3,30),Position=UDim2.fromOffset(10,9),BackgroundColor3=C.Accent,BorderSizePixel=0},f); Corner(mark,3)
    New("TextLabel",{Size=UDim2.new(1,-28,0,19),Position=UDim2.fromOffset(20,6),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},f)
    New("TextLabel",{Size=UDim2.new(1,-28,0,15),Position=UDim2.fromOffset(20,27),BackgroundTransparency=1,Text=sub or "",TextColor3=C.Muted,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},f)
    return f
end
local function Toggle(p,title,desc,get,set)
    local r=New("Frame",{Size=UDim2.new(1,0,0,70),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(r,12); Outline(r,C.Border,1,.15); Gradient(r,C.Surface2,C.Surface,0,90)
    local accent=New("Frame",{Size=UDim2.fromOffset(2,42),Position=UDim2.fromOffset(0,14),BackgroundColor3=C.Accent,BackgroundTransparency=.65,BorderSizePixel=0},r); Corner(accent,3)
    New("TextLabel",{Size=UDim2.new(1,-92,0,21),Position=UDim2.fromOffset(14,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},r)
    New("TextLabel",{Size=UDim2.new(1,-92,0,24),Position=UDim2.fromOffset(14,31),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},r)
    local sw=New("TextButton",{Size=UDim2.fromOffset(54,28),Position=UDim2.new(1,-68,.5,-14),BackgroundColor3=C.Surface3,Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=3},r); Corner(sw,14); Outline(sw,C.Border,1,.1)
    local track=New("Frame",{Size=UDim2.new(1,-6,1,-6),Position=UDim2.fromOffset(3,3),BackgroundColor3=C.Surface3,BorderSizePixel=0},sw); Corner(track,12)
    local knob=New("Frame",{Size=UDim2.fromOffset(20,20),Position=UDim2.fromOffset(4,4),BackgroundColor3=C.Sub,BorderSizePixel=0},sw); Corner(knob,10)
    local stateLabel=New("TextLabel",{Size=UDim2.fromOffset(28,14),Position=UDim2.new(0,-34,.5,-7),BackgroundTransparency=1,TextColor3=C.Muted,TextSize=8,Font=Enum.Font.GothamBold,Text="OFF",TextXAlignment=Enum.TextXAlignment.Right},sw)
    local refresh=function()
        local on=not not get()
        T(track,{BackgroundColor3=on and C.Accent2 or C.Surface3},.12)
        T(knob,{Position=on and UDim2.new(1,-24,0,4) or UDim2.fromOffset(4,4),BackgroundColor3=on and Color3.new(1,1,1) or C.Sub},.14)
        T(stateLabel,{TextColor3=on and C.Accent or C.Muted},.12)
        stateLabel.Text=on and "ON" or "OFF"
        T(accent,{BackgroundTransparency=on and 0 or .65},.12)
    end
    sw.Activated:Connect(function()
        local nextValue=not not (not get())
        set(nextValue)
        refresh()
        SaveProfile(Config.ActiveProfile)
    end)
    r.MouseEnter:Connect(function() T(r,{BackgroundColor3=C.Surface2},.1) end)
    r.MouseLeave:Connect(function() T(r,{BackgroundColor3=C.Surface},.1) end)
    refresh(); table.insert(Refreshers,refresh); return refresh
end
local function Slider(p,title,desc,min,max,step,get,set)
    local r=New("Frame",{Size=UDim2.new(1,0,0,87),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(r,11); Outline(r,C.Border)
    New("TextLabel",{Size=UDim2.new(1,-70,0,20),Position=UDim2.fromOffset(12,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},r)
    local val=New("TextLabel",{Size=UDim2.fromOffset(58,20),Position=UDim2.new(1,-70,0,8),BackgroundTransparency=1,TextColor3=C.Accent,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right},r)
    New("TextLabel",{Size=UDim2.new(1,-24,0,16),Position=UDim2.fromOffset(12,29),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},r)
    local tr=New("Frame",{Size=UDim2.new(1,-24,0,7),Position=UDim2.new(0,12,1,-20),BackgroundColor3=C.Surface3,BorderSizePixel=0},r); Corner(tr,6)
    local fill=New("Frame",{Size=UDim2.new(),BackgroundColor3=C.Accent,BorderSizePixel=0},tr); Corner(fill,6)
    local knob=New("TextButton",{Size=UDim2.fromOffset(18,18),Position=UDim2.new(0,-9,.5,-9),BackgroundColor3=Color3.new(1,1,1),Text="",AutoButtonColor=false,BorderSizePixel=0},tr); Corner(knob,9); Outline(knob,C.Accent)
    local slide=false
    local function setX(x)
        local a=math.clamp((x-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
        local v=math.floor(((min+(max-min)*a)/step)+.5)*step
        set(math.clamp(v,min,max))
    end
    local function refresh()
        local v=get(); local a=(v-min)/(max-min)
        val.Text=tostring(v); fill.Size=UDim2.new(a,0,1,0); knob.Position=UDim2.new(a,-9,.5,-9)
    end
    tr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then slide=true; setX(i.Position.X); refresh() end end)
    UserInputService.InputChanged:Connect(function(i) if slide and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setX(i.Position.X); refresh() end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then slide=false; SaveProfile(Config.ActiveProfile) end end)
    refresh(); table.insert(Refreshers,refresh); return refresh
end
local function Info(p,title,desc,accent)
    local r=New("Frame",{Size=UDim2.new(1,0,0,61),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(r,11); Outline(r,C.Border)
    local line=New("Frame",{Size=UDim2.fromOffset(3,31),Position=UDim2.fromOffset(10,13),BackgroundColor3=accent or C.Accent,BorderSizePixel=0},r); Corner(line,3)
    New("TextLabel",{Size=UDim2.new(1,-38),Position=UDim2.fromOffset(20,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},r)
    New("TextLabel",{Size=UDim2.new(1,-38),Position=UDim2.fromOffset(20,28),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},r)
    return r
end
local function Action(p,title,desc,callback,color)
    local b=New("TextButton",{Size=UDim2.new(1,0,0,61),BackgroundColor3=C.Surface,Text="",AutoButtonColor=false,BorderSizePixel=0,Active=true},p); Corner(b,12); Outline(b,C.Border,1,.15); Gradient(b,C.Surface2,C.Surface,0,90)
    local line=New("Frame",{Size=UDim2.fromOffset(3,31),Position=UDim2.fromOffset(10,13),BackgroundColor3=color or C.Accent,BorderSizePixel=0},b); Corner(line,3)
    New("TextLabel",{Size=UDim2.new(1,-55,0,21),Position=UDim2.fromOffset(20,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=false},b)
    local descLabel=New("TextLabel",{Size=UDim2.new(1,-55,0,19),Position=UDim2.fromOffset(20,28),BackgroundTransparency=1,Text="",TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Active=false},b)
    local function refresh()
        local value = type(desc)=="function" and desc() or desc
        descLabel.Text=tostring(value or "")
    end
    refresh()
    local a=New("TextLabel",{Size=UDim2.fromOffset(24,57),Position=UDim2.new(1,-31,0,0),BackgroundTransparency=1,Text="›",TextColor3=C.Muted,TextSize=22,Font=Enum.Font.Gotham,Active=false},b)
    b.Activated:Connect(function()
        callback()
        refresh()
    end)
    b.MouseEnter:Connect(function() T(b,{BackgroundColor3=C.Surface2},.1); T(a,{TextColor3=C.Text},.1) end)
    b.MouseLeave:Connect(function() T(b,{BackgroundColor3=C.Surface},.1); T(a,{TextColor3=C.Muted},.1) end)
    table.insert(Refreshers,refresh)
    return b,refresh
end

--========================================================
-- FORWARD DECLARATIONS
--========================================================
-- Some UI callbacks are created before their implementations below.
-- Keep them as upvalues so callbacks never resolve to a missing global.
local ResetAimState
local Invisibility
local SetFly

--========================================================
-- BUILD TABS
--========================================================
Section(Pages.Combat,"TARGETING","Aim behaviour and target selection")
Toggle(Pages.Combat,"Aimbot","Tracks the closest visible target inside your FOV.",function() return Config.Aimbot end,function(v) Config.Aimbot=v; if not v then ResetAimState() end end)
Slider(Pages.Combat,"Aim FOV","Screen-space target radius.",50,500,10,function() return Config.AimFOV end,function(v) Config.AimFOV=v end)
Slider(Pages.Combat,"Max Distance","Maximum target distance.",25,500,5,function() return Config.MaxAimDistance end,function(v) Config.MaxAimDistance=v end)
Toggle(Pages.Combat,"Team Check","Prevents aimbot from selecting teammates using team/faction checks.",function() return Config.TeamCheck end,function(v) Config.TeamCheck=v end)
Action(Pages.Combat,"Aim Body Part",function()
    return "Target: "..tostring(Config.AimTargetPart).." • tap to cycle."
end,function()
    local parts={"Head","UpperTorso","Torso","LowerTorso","LeftArm","RightArm","LeftLeg","RightLeg","HumanoidRootPart"}
    local i=table.find(parts,Config.AimTargetPart) or 1
    Config.AimTargetPart=parts[(i % #parts)+1]
    ResetAimState()
    SaveProfile(Config.ActiveProfile)
end,C.Accent)
Action(Pages.Combat,"Target Priority",function()
    return "Mode: "..tostring(Config.AimTargetMode).." • tap to cycle."
end,function()
    local modes={"ClosestToCursor","ClosestToPlayer","LowestHealth"}
    local i=table.find(modes,Config.AimTargetMode) or 1
    Config.AimTargetMode=modes[(i % #modes)+1]
    ResetAimState()
    SaveProfile(Config.ActiveProfile)
end,C.Accent)
Toggle(Pages.Combat,"Stable Target Lock","Keeps the current valid target and prevents target flicker.",function() return Config.AimTargetLock end,function(v) Config.AimTargetLock=v; ResetAimState() end)
Slider(Pages.Combat,"Reacquire Delay","Delay before selecting another target after loss.",0,0.30,0.01,function() return Config.AimRetargetDelay end,function(v) Config.AimRetargetDelay=v end)
Toggle(Pages.Combat,"Smooth Aim","Moves the camera toward the target instead of snapping instantly.",function() return Config.AimSmooth end,function(v) Config.AimSmooth=v end)
Slider(Pages.Combat,"Aim Smoothness","Higher values feel faster and more responsive.",1,20,1,function() return Config.AimSmoothness end,function(v) Config.AimSmoothness=v end)
Info(Pages.Combat,"Target validation","Requires a live, visible and on-screen player.",C.Good)

Section(Pages.ESP,"ESP CORE","Premium layered player visualization")
Toggle(Pages.ESP,"Enable ESP","Master switch for every ESP layer.",function() return Config.ESP end,function(v) Config.ESP=v end)
Toggle(Pages.ESP,"3D Wireframe Boxes","True projected cuboids that rotate with the character.",function() return Config.ESP3DBoxes end,function(v) Config.ESP3DBoxes=v end)
Toggle(Pages.ESP,"Strong Chams Fill","Increase the Highlight/chams fill strength.",function() return Config.ESPBoxFill end,function(v) Config.ESPBoxFill=v end)
Toggle(Pages.ESP,"Corner Overlay","Adds a clean 2D corner frame over the 3D box.",function() return Config.ESPCornerBoxes end,function(v) Config.ESPCornerBoxes=v end)
Toggle(Pages.ESP,"Box Glow","Subtle outer glow around projected boxes.",function() return Config.ESPBoxGlow end,function(v) Config.ESPBoxGlow=v end)
Toggle(Pages.ESP,"Tracers","Bottom-center target tracers.",function() return Config.ESPTracers end,function(v) Config.ESPTracers=v end)
Toggle(Pages.ESP,"Snapline","Additional left-edge snaplines for dense fights.",function() return Config.ESPSnapline end,function(v) Config.ESPSnapline=v end)
Toggle(Pages.ESP,"Skeletons","R6/R15-aware joint skeletons.",function() return Config.ESPSkeletons end,function(v) Config.ESPSkeletons=v end)
Toggle(Pages.ESP,"Head Dot","Small head marker for precise target placement.",function() return Config.ESPHeadDot end,function(v) Config.ESPHeadDot=v end)
Toggle(Pages.ESP,"Look Direction","Shows the target's facing direction.",function() return Config.ESPLookDirection end,function(v) Config.ESPLookDirection=v end)
Toggle(Pages.ESP,"Off-screen Arrows","Directional arrows for targets outside the viewport.",function() return Config.ESPOffscreenArrows end,function(v) Config.ESPOffscreenArrows=v end)
Toggle(Pages.ESP,"Highlight / Chams","AlwaysOnTop 3D highlight with team-aware accents.",function() return Config.ESPHighlight end,function(v) Config.ESPHighlight=v end)

Section(Pages.ESP,"PLAYER DATA","Dense but readable combat information")
Toggle(Pages.ESP,"Display Name","Shows the player's display name above the box.",function() return Config.ESPNames end,function(v) Config.ESPNames=v end)
Toggle(Pages.ESP,"Username","Shows @username beneath the display name.",function() return Config.ESPUsername end,function(v) Config.ESPUsername=v end)
Toggle(Pages.ESP,"Weapon","Shows the currently equipped Tool when available.",function() return Config.ESPWeapon end,function(v) Config.ESPWeapon=v end)
Toggle(Pages.ESP,"Health Bar","Live vertical health bar with dynamic state color.",function() return Config.ESPHealth end,function(v) Config.ESPHealth=v end)
Toggle(Pages.ESP,"Health Text","Shows current HP beside the health bar.",function() return Config.ESPHealthText end,function(v) Config.ESPHealthText=v end)
Toggle(Pages.ESP,"Distance","Shows live distance in studs.",function() return Config.ESPDistance end,function(v) Config.ESPDistance=v end)
Toggle(Pages.ESP,"Team Check","Hide teammates from all ESP layers.",function() return Config.ESPTeamCheck end,function(v) Config.ESPTeamCheck=v end)
Toggle(Pages.ESP,"Team Colors","Use a separate teammate accent.",function() return Config.ESPUseTeamColors end,function(v) Config.ESPUseTeamColors=v end)

Section(Pages.ESP,"ESP TUNING","Performance and premium visual controls")
Slider(Pages.ESP,"Max Distance","Maximum ESP range.",50,3000,25,function() return Config.ESPMaxDistance end,function(v) Config.ESPMaxDistance=v end)
Slider(Pages.ESP,"Rendered Players","Hard cap for sorted ESP entries per update.",10,100,5,function() return Config.ESPMaxRendered end,function(v) Config.ESPMaxRendered=v end)
Slider(Pages.ESP,"Update Rate","Lower = smoother, higher = lighter CPU usage.",0.025,0.20,0.005,function() return Config.ESPUpdateRate end,function(v) Config.ESPUpdateRate=v end)
Slider(Pages.ESP,"Box Thickness","Main box outline thickness.",1,4,1,function() return Config.ESPBoxThickness end,function(v) Config.ESPBoxThickness=v end)
Slider(Pages.ESP,"Tracer Thickness","Tracer/snapline thickness.",1,4,1,function() return Config.ESPTracerThickness end,function(v) Config.ESPTracerThickness=v end)
Slider(Pages.ESP,"Skeleton Thickness","Skeleton line thickness.",1,4,1,function() return Config.ESPSkeletonThickness end,function(v) Config.ESPSkeletonThickness=v end)
Slider(Pages.ESP,"Text Scale","Scale all compact ESP labels.",0.75,1.5,0.05,function() return Config.ESPTextScale end,function(v) Config.ESPTextScale=v end)
Slider(Pages.ESP,"Arrow Size","Off-screen target arrow size.",8,24,1,function() return Config.ESPArrowSize end,function(v) Config.ESPArrowSize=v end)
Info(Pages.ESP,"Hybrid renderer","Highlight + BillboardGui info + projected 3D cuboids/tracers/skeletons, with pooling and distance culling.",C.Good)

Section(Pages.Movement,"MOVEMENT","Movement and collision controls")
Toggle(Pages.Movement,"Speed","Changes Humanoid WalkSpeed while enabled.",function() return Config.Speed end,function(v) Config.Speed=v end)
Slider(Pages.Movement,"WalkSpeed","Movement speed value.",1,150,1,function() return Config.SpeedValue end,function(v) Config.SpeedValue=v end)
Toggle(Pages.Movement,"NoClip","Disables character collision while enabled.",function() return Config.NoClip end,function(v) Config.NoClip=v end)
Toggle(Pages.Movement,"Fly","Camera-relative flight with vertical controls.",function() return Config.Fly end,function(v) Config.Fly=v; SetFly(v) end)
Slider(Pages.Movement,"Fly Speed","Horizontal and vertical flight speed.",10,250,5,function() return Config.FlySpeed end,function(v) Config.FlySpeed=v end)
Toggle(Pages.Movement,"Infinite Jump","Allows jump requests while airborne on the local client.",function() return Config.InfiniteJump end,function(v) Config.InfiniteJump=v end)
Info(Pages.Movement,"Fly controls","W/A/S/D moves relative to the camera • Space rises • LeftControl descends.",C.Good)

Section(Pages.Player,"CHARACTER","Character presentation")
Toggle(Pages.Player,"Invisibility","Makes your character locally transparent on this client.",function() return Config.Invisibility end,function(v) Config.Invisibility=v; Invisibility(v) end)
Info(Pages.Player,"Client-side","Invisibility uses local transparency and is not server-authoritative.",C.Accent)

Section(Pages.Client,"CAMERA","Local camera controls")
Slider(Pages.Client,"Field of View","Local camera field of view.",40,120,1,function() return Config.FOV end,function(v) Config.FOV=v end)
Toggle(Pages.Client,"Third Person","Switches the local camera to a simple third-person view.",function() return Config.ThirdPerson end,function(v) Config.ThirdPerson=v end)
Toggle(Pages.Client,"Camera Bob","Keeps normal first-person camera movement enabled.",function() return Config.CameraBob end,function(v) Config.CameraBob=v end)

Section(Pages.Client,"CROSSHAIR","Custom local crosshair")
Toggle(Pages.Client,"Crosshair","Shows a clean custom crosshair in the center of the screen.",function() return Config.Crosshair end,function(v) Config.Crosshair=v end)
Slider(Pages.Client,"Crosshair Size","Length of each crosshair arm.",4,20,1,function() return Config.CrosshairSize end,function(v) Config.CrosshairSize=v end)
Slider(Pages.Client,"Crosshair Gap","Center gap size.",0,14,1,function() return Config.CrosshairGap end,function(v) Config.CrosshairGap=v end)
Slider(Pages.Client,"Crosshair Thickness","Line thickness.",1,5,1,function() return Config.CrosshairThickness end,function(v) Config.CrosshairThickness=v end)

Section(Pages.Client,"LOCAL VISUALS","Client-only lighting and world presentation")
Toggle(Pages.Client,"Full Bright","Removes local darkness by increasing client lighting.",function() return Config.FullBright end,function(v) Config.FullBright=v end)
Toggle(Pages.Client,"No Fog","Extends local fog distance to make the map clearer.",function() return Config.NoFog end,function(v) Config.NoFog=v end)

Section(Pages.Performance,"MONITOR","Live client performance information")
Toggle(Pages.Performance,"FPS Counter","Shows your current client FPS.",function() return Config.FPSCounter end,function(v) Config.FPSCounter=v end)
Toggle(Pages.Performance,"Ping Counter","Shows the local player's reported ping.",function() return Config.PingCounter end,function(v) Config.PingCounter=v end)
Toggle(Pages.Performance,"Coordinates","Shows your current character coordinates.",function() return Config.Coordinates end,function(v) Config.Coordinates=v end)
Toggle(Pages.Performance,"Safe Low Graphics","Cheap, reversible local optimization; does not scan the whole workspace.",function() return Config.LowGraphics end,function(v) Config.LowGraphics=v end)
Info(Pages.Performance,"Performance first","All options in this tab are designed to affect the local client only.",C.Good)

Section(Pages.Settings,"INTERFACE","Quality-of-life controls")
Info(Pages.Settings,"Keyboard shortcut","O is the ONLY keyboard shortcut: open / close the panel.",C.Accent)
Action(Pages.Settings,"Center panel","Restore the window to the center of the screen.",function() Main.Position=UDim2.new(.5,-235,.5,-272.5) end,C.Good)
Action(Pages.Settings,"Reset features","Turn every gameplay feature off and restore movement state.",function()
    Config.Aimbot=false; Config.ESP=false; Config.Speed=false; Config.NoClip=false; Config.Fly=false; Config.Invisibility=false
    ResetAimState()
    SetFly(false)
    Invisibility(false)
    for _,refresh in ipairs(Refreshers) do refresh() end
    SaveProfile(Config.ActiveProfile)
end,C.Bad)
Section(Pages.Settings,"PROFILES","Keep your preferred panel setup between re-executions")
Action(Pages.Settings,"Save Profile",function()
    return "Save the current configuration as "..tostring(Config.ActiveProfile).."."
end,function()
    SaveProfile(Config.ActiveProfile)
end,C.Good)
Action(Pages.Settings,"Load Profile",function()
    return "Load the saved "..tostring(Config.ActiveProfile).." configuration."
end,function()
    if LoadProfile(Config.ActiveProfile) then
        Env.AstriumHubLastActiveProfile=Config.ActiveProfile
        for _,refresh in ipairs(Refreshers) do refresh() end
    end
end,C.Accent)
Action(Pages.Settings,"New Profile","Switch profile name by editing ActiveProfile in the Config block, then save.",function()
    SaveProfile(Config.ActiveProfile)
end,C.Accent)
Info(Pages.Settings,"Persistence","Uses file APIs when available; otherwise uses the current runtime environment.",C.Good)
Action(Pages.Settings,"Mobile optimized","Responsive scaling, touch toggles, sliders, scrolling and drag support.",function() Resize() end,C.Good)

--========================================================
-- ADDITIONAL CLIENT FEATURES
--========================================================

Section(Pages.Combat,"AIM ADVANCED","More precise local target handling")
Toggle(Pages.Combat,"Sticky Aim","Keeps the selected target while it remains valid.",function() return Config.AimSticky end,function(v) Config.AimSticky=v end)
Toggle(Pages.Combat,"Prediction","Uses target velocity for a small local lead.",function() return Config.AimPrediction end,function(v) Config.AimPrediction=v end)
Slider(Pages.Combat,"Prediction","Prediction amount.",0,0.30,0.01,function() return Config.AimPredictionAmount end,function(v) Config.AimPredictionAmount=v end)
Slider(Pages.Combat,"Deadzone","Ignore tiny aim corrections.",0,30,1,function() return Config.AimDeadzone end,function(v) Config.AimDeadzone=v end)
Info(Pages.Combat,"Smoothness fixed","Smoothing is now frame-rate independent.",C.Good)

Section(Pages.Movement,"MOVEMENT EXTRAS","More local quality-of-life controls")
Toggle(Pages.Movement,"Auto Sprint","Marks the client as sprint-ready while moving.",function() return Config.AutoSprint end,function(v) Config.AutoSprint=v end)

Section(Pages.Client,"CAMERA FEEL","Extra local camera effects")
Toggle(Pages.Client,"FOV Kick","Adds a small movement-based FOV pulse.",function() return Config.FOVKick end,function(v) Config.FOVKick=v end)
Slider(Pages.Client,"FOV Kick Amount","Maximum extra FOV.",0,20,1,function() return Config.FOVKickAmount end,function(v) Config.FOVKickAmount=v end)
Toggle(Pages.Client,"Camera Shake","Adds subtle local camera feedback.",function() return Config.CameraShake end,function(v) Config.CameraShake=v end)
Slider(Pages.Client,"Shake Amount","Camera shake strength.",0,1,0.01,function() return Config.CameraShakeAmount end,function(v) Config.CameraShakeAmount=v end)

Section(Pages.Camera,"CAMERA","Dedicated camera controls")
Slider(Pages.Camera,"Field of View","Local camera FOV.",40,120,1,function() return Config.FOV end,function(v) Config.FOV=v end)
Toggle(Pages.Camera,"Third Person","Use a local third-person view.",function() return Config.ThirdPerson end,function(v) Config.ThirdPerson=v end)
Toggle(Pages.Camera,"Camera Bob","Add subtle movement bob.",function() return Config.CameraBob end,function(v) Config.CameraBob=v end)
Info(Pages.Camera,"Smooth aim","Uses frame-rate independent interpolation.",C.Good)

Section(Pages.Interface,"CROSSHAIR","Local reticle and HUD")
Toggle(Pages.Interface,"Crosshair","Show a custom local crosshair.",function() return Config.Crosshair end,function(v) Config.Crosshair=v end)
Slider(Pages.Interface,"Size","Crosshair arm length.",4,24,1,function() return Config.CrosshairSize end,function(v) Config.CrosshairSize=v end)
Slider(Pages.Interface,"Gap","Crosshair center gap.",0,20,1,function() return Config.CrosshairGap end,function(v) Config.CrosshairGap=v end)
Slider(Pages.Interface,"Thickness","Crosshair thickness.",1,6,1,function() return Config.CrosshairThickness end,function(v) Config.CrosshairThickness=v end)
Toggle(Pages.Interface,"FPS Counter","Show live client FPS.",function() return Config.FPSCounter end,function(v) Config.FPSCounter=v end)
Toggle(Pages.Interface,"Ping Counter","Show local network ping.",function() return Config.PingCounter end,function(v) Config.PingCounter=v end)
Toggle(Pages.Interface,"Coordinates","Show character coordinates.",function() return Config.Coordinates end,function(v) Config.Coordinates=v end)
Toggle(Pages.Interface,"Local Time","Show local time.",function() return Config.LocalTime end,function(v) Config.LocalTime=v end)

Section(Pages.Graphics,"LIGHTING","Client-side visual improvements")
Toggle(Pages.Graphics,"Full Bright","Brighten local lighting.",function() return Config.FullBright end,function(v) Config.FullBright=v end)
Toggle(Pages.Graphics,"No Fog","Extend local fog distance.",function() return Config.NoFog end,function(v) Config.NoFog=v end)
Toggle(Pages.Graphics,"Reduce Particles","Disable common local particles, beams and trails.",function() return Config.ReduceParticles end,function(v) Config.ReduceParticles=v end)
Toggle(Pages.Graphics,"Disable Post FX","Disable common local post-processing.",function() return Config.DisablePostFX end,function(v) Config.DisablePostFX=v end)
Slider(Pages.Graphics,"Saturation","Local saturation.",-1,1,0.05,function() return Config.Saturation end,function(v) Config.Saturation=v end)
Slider(Pages.Graphics,"Contrast","Local contrast.",-1,1,0.05,function() return Config.Contrast end,function(v) Config.Contrast=v end)
Slider(Pages.Graphics,"Color Boost","Local brightness boost.",-0.5,0.5,0.05,function() return Config.ColorBoost end,function(v) Config.ColorBoost=v end)

Section(Pages.Utility,"UTILITY","Small client-only quality-of-life tools")
Toggle(Pages.Utility,"Infinite Jump","Allow repeated local jump requests.",function() return Config.InfiniteJump end,function(v) Config.InfiniteJump=v end)
Toggle(Pages.Utility,"Auto Sprint","Keep the player sprint-ready locally.",function() return Config.AutoSprint end,function(v) Config.AutoSprint=v end)
Info(Pages.Utility,"Client-only","These controls are designed for local presentation and convenience.",C.Accent)

SelectTab("Combat")

--========================================================
-- OPEN / CLOSE
--========================================================
local visible=true
local openPos=Main.Position
local closedPos=UDim2.new(openPos.X.Scale,openPos.X.Offset,openPos.Y.Scale,openPos.Y.Offset+14)
local function SetVisible(v)
    visible=v
    if v then
        Main.Visible=true; Main.Position=closedPos; Main.BackgroundTransparency=1
        T(Main,{Position=openPos,BackgroundTransparency=0},.19)
        OpenLabel.Text="ASTRIUM  •  [O]"; Dot.BackgroundColor3=C.Good
    else
        local tw=TweenService:Create(Main,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=closedPos,BackgroundTransparency=1})
        tw.Completed:Connect(function() if not visible then Main.Visible=false end end); tw:Play()
        OpenLabel.Text="ASTRIUM  •  [O]"; Dot.BackgroundColor3=C.Accent
    end
end
Open.Activated:Connect(function() SetVisible(not visible) end)
Close.Activated:Connect(function() SetVisible(false) end)
Open.MouseEnter:Connect(function() T(Open,{BackgroundColor3=C.Surface2},.1) end); Open.MouseLeave:Connect(function() T(Open,{BackgroundColor3=C.Surface},.1) end)
Close.MouseEnter:Connect(function() T(Close,{BackgroundColor3=C.Bad,TextColor3=Color3.new(1,1,1)},.1) end); Close.MouseLeave:Connect(function() T(Close,{BackgroundColor3=C.Surface3,TextColor3=C.Sub},.1) end)

-- ONLY hotkey: O
ContextActionService:BindActionAtPriority("AstriumHub_OpenClose",function(_,state)
    if state==Enum.UserInputState.Begin then SetVisible(not visible) end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value,Config.PanelKey)

--========================================================
-- CLIENT HUD
--========================================================
local ClientHUD=New("ScreenGui",{Name="AstriumHUD",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=101,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},PlayerGui)
local ESPOverlay=New("Frame",{Name="ESPOverlay",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=10},ClientHUD)

local Crosshair=New("Frame",{Name="Crosshair",Size=UDim2.fromOffset(1,1),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1},ClientHUD)
local ChTop=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair); local ChBottom=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair)
local ChLeft=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair); local ChRight=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair)
local Status=New("TextLabel",{Size=UDim2.fromOffset(210,58),Position=UDim2.new(1,-225,0,14),BackgroundTransparency=.35,BackgroundColor3=C.Surface,TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Text=""},ClientHUD); Corner(Status,10); Outline(Status,C.Border)
New("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingTop=UDim.new(0,7),PaddingRight=UDim.new(0,6)},Status)

local function UpdateCrosshair()
    Crosshair.Visible=Config.Crosshair
    local size=Config.CrosshairSize; local gap=Config.CrosshairGap; local thick=Config.CrosshairThickness
    ChTop.Size=UDim2.fromOffset(thick,size); ChTop.Position=UDim2.new(.5,-thick/2,0,-gap-size)
    ChBottom.Size=UDim2.fromOffset(thick,size); ChBottom.Position=UDim2.new(.5,-thick/2,0,gap)
    ChLeft.Size=UDim2.fromOffset(size,thick); ChLeft.Position=UDim2.new(0,-gap-size,.5,-thick/2)
    ChRight.Size=UDim2.fromOffset(size,thick); ChRight.Position=UDim2.new(0,gap,.5,-thick/2)
end
UpdateCrosshair()

local LightBackup={Ambient=nil,Brightness=nil,ClockTime=nil,FogEnd=nil,FogStart=nil,GlobalShadows=nil}
local TerrainBackup={WaveSize=nil,WaveSpeed=nil,Reflectance=nil,Transparency=nil}
local ParticleBackup={}
local Lighting=game:GetService("Lighting")
local LocalColor=Lighting:FindFirstChild("AstriumHubLocalColor")
if not LocalColor then
    LocalColor=Instance.new("ColorCorrectionEffect")
    LocalColor.Name="AstriumHubLocalColor"
    LocalColor.Parent=Lighting
end
LocalColor.Enabled=false
local PostFXBackup={}
local function ApplyLocalVisuals()
    if Config.FullBright then
        if LightBackup.Ambient==nil then
            LightBackup.Ambient=Lighting.Ambient; LightBackup.Brightness=Lighting.Brightness; LightBackup.ClockTime=Lighting.ClockTime; LightBackup.GlobalShadows=Lighting.GlobalShadows
        end
        Lighting.Ambient=Color3.new(1,1,1); Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false
    elseif LightBackup.Ambient~=nil then
        Lighting.Ambient=LightBackup.Ambient; Lighting.Brightness=LightBackup.Brightness; Lighting.ClockTime=LightBackup.ClockTime; Lighting.GlobalShadows=LightBackup.GlobalShadows
        LightBackup.Ambient=nil
    end
    if Config.NoFog then
        if LightBackup.FogEnd==nil then LightBackup.FogEnd=Lighting.FogEnd; LightBackup.FogStart=Lighting.FogStart end
        Lighting.FogStart=0; Lighting.FogEnd=100000
    elseif LightBackup.FogEnd~=nil then
        Lighting.FogEnd=LightBackup.FogEnd; Lighting.FogStart=LightBackup.FogStart; LightBackup.FogEnd=nil
    end
end

local bobTime=0
local savedCameraOffset=nil
local lastCharacterForCamera=nil
local function ApplyCameraSettings(dt)
    local cam=workspace.CurrentCamera
    if not cam then return end

    local c=Character()
    local h=Humanoid()

    if c~=lastCharacterForCamera then
        lastCharacterForCamera=c
        savedCameraOffset=nil
    end

    if h then
        if savedCameraOffset==nil then
            savedCameraOffset=h.CameraOffset
        end

        if Config.CameraBob and not Config.ThirdPerson and h.MoveDirection.Magnitude>0.05 then
            bobTime+=(dt or 0.016)
            local speed=math.max(h.WalkSpeed,1)
            local amount=math.clamp(speed/32,0.65,1.8)
            local base=savedCameraOffset or Vector3.new(0,0,0)
            h.CameraOffset=base+Vector3.new(0,math.sin(bobTime*10)*0.035*amount,0)
        else
            if savedCameraOffset~=nil then
                h.CameraOffset=savedCameraOffset
            end
        end
    end

    if Config.ThirdPerson then
        local root=c and c:FindFirstChild("HumanoidRootPart")
        if root then
            local target=root.Position-root.CFrame.LookVector*8+Vector3.new(0,3,0)
            cam.CFrame=CFrame.lookAt(target,root.Position+Vector3.new(0,1.5,0))
        end
    end

    -- FOV and camera feel are applied here; the aimbot runs at Camera+1
    -- so it gets the final camera state and can snap without being overwritten.
    local baseFOV=tonumber(Config.FOV) or 80
    local extraFOV=0
    if Config.FOVKick and h then
        local move=math.clamp(h.MoveDirection.Magnitude,0,1)
        extraFOV=(tonumber(Config.FOVKickAmount) or 0)*move
    end
    local targetFOV=math.clamp(baseFOV+extraFOV,40,120)
    cam.FieldOfView=targetFOV

    if Config.CameraShake and h then
        local amount=math.clamp(tonumber(Config.CameraShakeAmount) or 0,0,1)
        if amount>0 then
            local t=time()
            local x=math.sin(t*31.0)*amount*0.0025
            local y=math.cos(t*27.0)*amount*0.0020
            local z=math.sin(t*23.0)*amount*0.0015
            cam.CFrame=cam.CFrame*CFrame.Angles(x,y,z)
        end
    end
end

--========================================================
-- SAFE GRAPHICS / PERFORMANCE
--========================================================
-- IMPORTANT: Low Graphics deliberately does NOT scan workspace descendants.
-- Large descendant scans and heavy work inside render-related loops can stall
-- the client, so Low Graphics is now limited to cheap, reversible settings.
local lowGraphicsApplied=false
local reduceParticlesApplied=false
local reducedParticleBackup={}

local function ApplyLowGraphics()
    local terrain=workspace:FindFirstChildOfClass("Terrain")
    if Config.LowGraphics then
        if terrain and TerrainBackup.WaveSize==nil then
            TerrainBackup.WaveSize=terrain.WaterWaveSize
            TerrainBackup.WaveSpeed=terrain.WaterWaveSpeed
            TerrainBackup.Reflectance=terrain.WaterReflectance
            TerrainBackup.Transparency=terrain.WaterTransparency
        end
        if terrain then
            terrain.WaterWaveSize=0
            terrain.WaterWaveSpeed=0
            terrain.WaterReflectance=0
            terrain.WaterTransparency=.5
        end
        lowGraphicsApplied=true
    else
        if terrain and TerrainBackup.WaveSize~=nil then
            terrain.WaterWaveSize=TerrainBackup.WaveSize
            terrain.WaterWaveSpeed=TerrainBackup.WaveSpeed
            terrain.WaterReflectance=TerrainBackup.Reflectance
            terrain.WaterTransparency=TerrainBackup.Transparency
            TerrainBackup.WaveSize=nil
            TerrainBackup.WaveSpeed=nil
            TerrainBackup.Reflectance=nil
            TerrainBackup.Transparency=nil
        end
        lowGraphicsApplied=false
    end
end

local function ApplyAdvancedGraphics()
    LocalColor.Enabled =
        Config.Saturation ~= 0
        or Config.Contrast ~= 0
        or Config.ColorBoost ~= 0

    LocalColor.Saturation=Config.Saturation
    LocalColor.Contrast=Config.Contrast
    LocalColor.Brightness=Config.ColorBoost

    if Config.DisablePostFX then
        for _,effect in ipairs(Lighting:GetChildren()) do
            if effect ~= LocalColor and (
                effect:IsA("BloomEffect")
                or effect:IsA("BlurEffect")
                or effect:IsA("ColorCorrectionEffect")
                or effect:IsA("DepthOfFieldEffect")
                or effect:IsA("SunRaysEffect")
            ) then
                if PostFXBackup[effect]==nil then
                    PostFXBackup[effect]=effect.Enabled
                end
                effect.Enabled=false
            end
        end
    else
        for effect,enabled in pairs(PostFXBackup) do
            if effect and effect.Parent then effect.Enabled=enabled end
        end
        table.clear(PostFXBackup)
    end
end

-- Explicit particle reduction remains separate from Low Graphics and runs only
-- when the user enables it. It does NOT attach a global DescendantAdded hook.
local function ApplyParticleReduction()
    if Config.ReduceParticles then
        if not reduceParticlesApplied then
            table.clear(reducedParticleBackup)
            for _,object in ipairs(workspace:GetDescendants()) do
                if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
                    reducedParticleBackup[object]=object.Enabled
                    object.Enabled=false
                end
            end
            reduceParticlesApplied=true
        end
    elseif reduceParticlesApplied then
        for object,enabled in pairs(reducedParticleBackup) do
            if object and object.Parent then object.Enabled=enabled end
        end
        table.clear(reducedParticleBackup)
        reduceParticlesApplied=false
    end
end

--========================================================
-- GAMEPLAY FEATURES
--========================================================
local savedSpeed=nil
local savedCollision={}
local flyConnection=nil
local flyKeys={W=false,A=false,S=false,D=false,Space=false,LeftControl=false}
local flyHumanoid=nil
local flyOldAutoRotate=nil

--========================================================
-- AIM / GAMEPLAY CORE
--========================================================
local function Character(player)
    player = player or LocalPlayer
    return player and player.Character
end

local function Humanoid(player)
    local c = Character(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end

SetFly=function(enabled)
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection=nil
    end

    local character=Character()
    local humanoid=Humanoid()
    flyHumanoid=humanoid

    if not enabled or not character or not humanoid then
        if flyHumanoid and flyOldAutoRotate~=nil then
            flyHumanoid.AutoRotate=flyOldAutoRotate
        end
        flyOldAutoRotate=nil
        if flyHumanoid then
            local root=flyHumanoid.Parent:FindFirstChild("HumanoidRootPart")
            if root then root.AssemblyLinearVelocity=Vector3.zero end
        end
        flyHumanoid=nil
        return
    end

    flyOldAutoRotate=humanoid.AutoRotate
    humanoid.AutoRotate=false
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    flyConnection=RunService.Heartbeat:Connect(function()
        if not Config.Fly then return end
        local c=Character()
        local h=Humanoid()
        local root=c and c:FindFirstChild("HumanoidRootPart")
        local camera=workspace.CurrentCamera
        if not c or not h or h.Health<=0 or not root or not camera then return end

        local forward=camera.CFrame.LookVector
        local right=camera.CFrame.RightVector
        local move=Vector3.zero

        if flyKeys.W then move+=forward end
        if flyKeys.S then move-=forward end
        if flyKeys.D then move+=right end
        if flyKeys.A then move-=right end

        move=Vector3.new(move.X,0,move.Z)
        if move.Magnitude>1 then move=move.Unit end

        local vertical=0
        if flyKeys.Space then vertical+=1 end
        if flyKeys.LeftControl then vertical-=1 end

        local speed=math.max(10,tonumber(Config.FlySpeed) or 70)
        root.AssemblyLinearVelocity=(move*speed)+Vector3.new(0,vertical*speed,0)

        if move.Magnitude>0.01 then
            root.CFrame=CFrame.lookAt(root.Position,root.Position+move)
        end

        h:ChangeState(Enum.HumanoidStateType.Physics)
    end)
end

local function IsTeammate(player)
    if not player or player==LocalPlayer then return true end
    if LocalPlayer.Team ~= nil and player.Team ~= nil then
        return LocalPlayer.Team == player.Team
    end
    if LocalPlayer.TeamColor and player.TeamColor then
        return LocalPlayer.TeamColor == player.TeamColor
    end
    for _, key in ipairs({"Team","TeamName","Faction","Side","Squad"}) do
        local mine = LocalPlayer:GetAttribute(key)
        local theirs = player:GetAttribute(key)
        if mine ~= nil and theirs ~= nil and mine ~= "" and theirs ~= "" then
            return tostring(mine) == tostring(theirs)
        end
    end
    return false
end

local function GetAimPart(character)
    if not character then return nil end
    local requested = tostring(Config.AimTargetPart or "Head")
    local aliases = {
        LeftArm={"LeftUpperArm","LeftArm"},
        RightArm={"RightUpperArm","RightArm"},
        LeftLeg={"LeftUpperLeg","LeftLeg"},
        RightLeg={"RightUpperLeg","RightLeg"},
        Torso={"UpperTorso","Torso"},
    }
    local direct = character:FindFirstChild(requested)
    if direct and direct:IsA("BasePart") then return direct end
    local list = aliases[requested]
    if list then
        for _, name in ipairs(list) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then return part end
        end
    end
    local fallback = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    return fallback and fallback:IsA("BasePart") and fallback or nil
end

local aimRayParams=RaycastParams.new()
aimRayParams.FilterType=Enum.RaycastFilterType.Exclude
aimRayParams.IgnoreWater=true

local CurrentAimPlayer=nil
local CurrentAimPart=nil
local aimLostUntil=0

ResetAimState=function()
    CurrentAimPlayer=nil
    CurrentAimPart=nil
    aimLostUntil=0
end

local function IsTargetVisible(camera,targetPart,targetCharacter)
    if not camera or not targetPart or not targetCharacter then return false end
    local origin=camera.CFrame.Position
    local destination=targetPart.Position
    local direction=destination-origin
    if direction.Magnitude<=0.001 then return true end

    aimRayParams.FilterDescendantsInstances={Character()}
    local result=workspace:Raycast(origin,direction,aimRayParams)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetCharacter)
end

local function GetTargetPoint(targetPart)
    if not targetPart then return nil end
    if Config.AimPrediction then
        local velocity=targetPart.AssemblyLinearVelocity
        return targetPart.Position+velocity*math.max(0,tonumber(Config.AimPredictionAmount) or 0)
    end
    return targetPart.Position
end

local function IsValidAimTarget(camera,player)
    if not camera or not player or player==LocalPlayer then return false,nil end
    if Config.TeamCheck and IsTeammate(player) then return false,nil end

    local character=Character(player)
    local humanoid=Humanoid(player)
    local targetPart=GetAimPart(character)
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local localCharacter=Character()
    local localRoot=localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or humanoid.Health<=0 or not targetPart or not root then
        return false,nil
    end

    local distance=localRoot and (root.Position-localRoot.Position).Magnitude or math.huge
    if distance>Config.MaxAimDistance then return false,nil end

    local screen,onScreen=camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen or screen.Z<=0 then return false,nil end

    local center=Vector2.new(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
    local screenPos=Vector2.new(screen.X,screen.Y)
    if (screenPos-center).Magnitude>Config.AimFOV then return false,nil end

    if not IsTargetVisible(camera,targetPart,character) then return false,nil end
    return true,targetPart
end

local function GetAimbotTarget(camera)
    if not camera then return nil,nil end

    -- Stable target lock prevents the camera from bouncing between targets.
    if Config.AimTargetLock and CurrentAimPlayer then
        local valid,part=IsValidAimTarget(camera,CurrentAimPlayer)
        if valid then
            CurrentAimPart=part
            return CurrentAimPlayer,part
        end
        CurrentAimPlayer=nil
        CurrentAimPart=nil
        aimLostUntil=time()+(tonumber(Config.AimRetargetDelay) or 0)
    end

    if time()<aimLostUntil then
        return nil,nil
    end

    local viewport=camera.ViewportSize
    local center=Vector2.new(viewport.X*.5,viewport.Y*.5)
    local localCharacter=Character()
    local localRoot=localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local bestPlayer,bestPart,bestMetric=nil,nil,nil

    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local valid,targetPart=IsValidAimTarget(camera,player)
            if valid and targetPart then
                local character=Character(player)
                local humanoid=Humanoid(player)
                local root=character and character:FindFirstChild("HumanoidRootPart")
                local distance=localRoot and root and (root.Position-localRoot.Position).Magnitude or math.huge
                local screen=camera:WorldToViewportPoint(targetPart.Position)
                local cursorDistance=(Vector2.new(screen.X,screen.Y)-center).Magnitude
                local metric
                if Config.AimTargetMode=="ClosestToPlayer" then
                    metric=distance
                elseif Config.AimTargetMode=="LowestHealth" then
                    metric=humanoid.Health*100000+distance
                else
                    metric=cursorDistance
                end
                if bestMetric==nil or metric<bestMetric then
                    bestMetric=metric
                    bestPlayer=player
                    bestPart=targetPart
                end
            end
        end
    end

    CurrentAimPlayer=bestPlayer
    CurrentAimPart=bestPart
    return bestPlayer,bestPart
end

local function Aimbot(_dt)
    if not Config.Aimbot then
        ResetAimState()
        return
    end

    local camera=workspace.CurrentCamera
    if not camera then return end

    local player,targetPart=GetAimbotTarget(camera)
    if not player or not targetPart then
        -- IMPORTANT: do not touch Camera.CFrame here.
        -- The player is free to move the camera manually after target loss.
        return
    end

    local aimPoint=GetTargetPoint(targetPart)
    if not aimPoint then return end

    if Config.AimDeadzone and Config.AimDeadzone>0 then
        local screen=camera:WorldToViewportPoint(aimPoint)
        if screen.Z>0 then
            local center=Vector2.new(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
            if (Vector2.new(screen.X,screen.Y)-center).Magnitude<=Config.AimDeadzone then
                return
            end
        end
    end

    local cameraPosition=camera.CFrame.Position
    local direction=aimPoint-cameraPosition
    if direction.Magnitude<=0.001 then return end

    local desired=CFrame.lookAt(cameraPosition,aimPoint)
    if Config.AimSmooth then
        local smoothness=math.max(1,tonumber(Config.AimSmoothness) or 8)
        local alpha=1-math.exp(-smoothness*6*(_dt or (1/60)))
        camera.CFrame=camera.CFrame:Lerp(desired,math.clamp(alpha,0,1))
    else
        -- Instant snap. Never restore an old camera orientation.
        camera.CFrame=desired
    end
end

local function UpdateSpeed()
    local h=Humanoid()
    if not h then return end
    if Config.Speed then
        if savedSpeed==nil then savedSpeed=h.WalkSpeed end
        h.WalkSpeed=Config.SpeedValue
    elseif savedSpeed~=nil then
        h.WalkSpeed=savedSpeed
        savedSpeed=nil
    end
end

local function UpdateNoClip()
    local c=Character()
    if not c then return end
    if Config.NoClip then
        for _,obj in ipairs(c:GetDescendants()) do
            if obj:IsA("BasePart") then
                if savedCollision[obj]==nil then savedCollision[obj]=obj.CanCollide end
                obj.CanCollide=false
            end
        end
    else
        for obj,canCollide in pairs(savedCollision) do
            if obj and obj.Parent then obj.CanCollide=canCollide end
        end
        table.clear(savedCollision)
    end
end

local invisBackup={}
Invisibility=function(enabled)
    local c=Character()
    if not c then return end
    if enabled then
        for _,obj in ipairs(c:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Decal") then
                if invisBackup[obj]==nil then invisBackup[obj]=obj.Transparency end
                obj.Transparency=1
            end
        end
    else
        for obj,transparency in pairs(invisBackup) do
            if obj and obj.Parent then obj.Transparency=transparency end
        end
        table.clear(invisBackup)
    end
end

--========================================================
-- HYBRID PREMIUM ESP CORE
--========================================================
-- Layer 1: Highlight = native AlwaysOnTop chams.
-- Layer 2: BillboardGui = player info that stays attached to the target.
-- Layer 3: ScreenGui = projected world-space cuboids, tracers, skeletons,
--          head markers, look direction and off-screen arrows.
-- Everything is pooled per player and aggressively hidden when culled.

local ESPEntries={}
local ESPPlayerConnections={}
local ESPLastUpdate=0
local ESPViewportSize=Vector2.new(0,0)

local function ESPTrackConnection(connection)
    table.insert(Env.AstriumHubESPConnections,connection)
    return connection
end

local ESPHighlightFolder=workspace:FindFirstChild("AstriumHubESP")
if not ESPHighlightFolder then
    ESPHighlightFolder=Instance.new("Folder")
    ESPHighlightFolder.Name="AstriumHubESP"
    ESPHighlightFolder.Parent=workspace
end

local function ESPNew(class,props,parent)
    local x=Instance.new(class)
    for k,v in pairs(props or {}) do x[k]=v end
    x.Parent=parent
    return x
end

local function ESPLine(parent,name,z,thickness)
    local line=ESPNew("Frame",{
        Name=name,
        AnchorPoint=Vector2.new(.5,.5),
        BackgroundColor3=C.Accent,
        BackgroundTransparency=0,
        BorderSizePixel=0,
        Visible=false,
        ZIndex=z or 25,
    },parent)
    Corner(line,2)
    line.Size=UDim2.fromOffset(thickness or 1,thickness or 1)
    return line
end

local function ESPSetLine(line,a,b,thickness,visible)
    if not line or not line.Parent or not a or not b or visible==false then
        if line then line.Visible=false end
        return false
    end
    local d=b-a
    local len=d.Magnitude
    if len<0.5 then line.Visible=false return false end
    line.Position=UDim2.fromOffset((a.X+b.X)*0.5,(a.Y+b.Y)*0.5)
    line.Size=UDim2.fromOffset(math.max(1,len),math.max(1,tonumber(thickness) or 1))
    line.Rotation=math.deg(math.atan2(d.Y,d.X))
    line.Visible=true
    return true
end

local function ESPText(parent,name,z,size)
    local t=ESPNew("TextLabel",{
        Name=name,
        BackgroundTransparency=1,
        Text="",
        TextColor3=C.Text,
        TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=.15,
        Font=Enum.Font.GothamBold,
        TextSize=size or 10,
        TextXAlignment=Enum.TextXAlignment.Center,
        TextYAlignment=Enum.TextYAlignment.Center,
        Visible=false,
        ZIndex=z or 28,
    },parent)
    return t
end

local function ESPProject(camera,worldPosition)
    if not camera or not worldPosition then return nil,false,nil end
    local point,onScreen=camera:WorldToViewportPoint(worldPosition)
    local p=Vector2.new(point.X,point.Y)
    return p,onScreen==true,point.Z
end

local function ESPGetColor(player)
    if Config.ESPUseTeamColors and IsTeammate(player) then
        return C.Good
    end
    return C.Accent
end

local function ESPGetDistanceFade(distance)
    if not Config.ESPFadeAtDistance then return 1 end
    local maxD=math.max(1,tonumber(Config.ESPMaxDistance) or 1000)
    local t=math.clamp(distance/maxD,0,1)
    return 1-.45*t*t
end

local function ESPHealthColor(ratio)
    ratio=math.clamp(ratio,0,1)
    if ratio<=.25 then return Color3.fromRGB(255,72,72) end
    if ratio<=.55 then return Color3.fromRGB(255,186,72) end
    return Color3.fromRGB(72,230,140)
end

local function ESPGetWeapon(character)
    if not character then return nil end
    for _,child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then return child.Name end
    end
    return nil
end

local function ESPHideBillboard(entry)
    if entry.billboard then entry.billboard.Enabled=false end
end

local function ESPCreateBillboard(player,entry)
    local billboard=ESPNew("BillboardGui",{
        Name="AstriumESPInfo_"..tostring(player.UserId),
        AlwaysOnTop=true,
        LightInfluence=0,
        MaxDistance=tonumber(Config.ESPMaxDistance) or 1000,
        Size=UDim2.fromOffset(190,70),
        StudsOffsetWorldSpace=Vector3.new(0,3.15,0),
        Enabled=false,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    },PlayerGui)
    local frame=ESPNew("Frame",{
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        BorderSizePixel=0,
    },billboard)
    local name=ESPText(frame,"DisplayName",40,12)
    name.Size=UDim2.new(1,0,0,20)
    name.Position=UDim2.fromOffset(0,0)
    local username=ESPText(frame,"Username",40,9)
    username.Size=UDim2.new(1,0,0,15)
    username.Position=UDim2.fromOffset(0,17)
    local meta=ESPText(frame,"Meta",40,9)
    meta.Size=UDim2.new(1,0,0,15)
    meta.Position=UDim2.fromOffset(0,33)
    local hpBack=ESPNew("Frame",{
        Name="HealthBack",
        AnchorPoint=Vector2.new(.5,0),
        Position=UDim2.new(.5,0,0,50),
        Size=UDim2.fromOffset(112,6),
        BackgroundColor3=Color3.fromRGB(18,20,26),
        BackgroundTransparency=.08,
        BorderSizePixel=0,
    },frame)
    Corner(hpBack,3)
    Outline(hpBack,Color3.new(0,0,0),1,.2)
    local hpFill=ESPNew("Frame",{
        Name="Fill",
        Size=UDim2.fromScale(1,1),
        BackgroundColor3=C.Good,
        BorderSizePixel=0,
    },hpBack)
    Corner(hpFill,3)
    entry.billboard=billboard
    entry.billboardFrame=frame
    entry.billboardName=name
    entry.billboardUsername=username
    entry.billboardMeta=meta
    entry.billboardHPBack=hpBack
    entry.billboardHPFill=hpFill
end

local function ESPCreateEntry(player)
    if ESPEntries[player] then return ESPEntries[player] end
    local root=ESPNew("Frame",{
        Name="ESP_"..tostring(player.UserId),
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Visible=true,
        ZIndex=20,
    },ESPOverlay)

    local boxGlowLines={}
    local boxLines={}
    local cornerGlowLines={}
    local cornerLines={}
    for i=1,12 do
        boxGlowLines[i]=ESPLine(root,"BoxGlow"..i,20,5)
        boxLines[i]=ESPLine(root,"BoxEdge"..i,22,1)
    end
    for i=1,8 do
        cornerGlowLines[i]=ESPLine(root,"CornerGlow"..i,20,5)
        cornerLines[i]=ESPLine(root,"Corner"..i,23,1)
    end

    local tracer=ESPLine(root,"Tracer",24,1)
    local snapline=ESPLine(root,"Snapline",23,1)
    local lookLine=ESPLine(root,"LookDirection",25,1)
    local headDot=ESPNew("Frame",{
        Name="HeadDot",AnchorPoint=Vector2.new(.5,.5),
        BackgroundColor3=C.Accent,BorderSizePixel=0,
        Visible=false,ZIndex=27,
    },root)
    Corner(headDot,20)
    Outline(headDot,Color3.new(1,1,1),1,.25)
    local displayLabel=ESPText(root,"DisplayNameScreen",30,12)
    displayLabel.AnchorPoint=Vector2.new(.5,1)
    displayLabel.Size=UDim2.fromOffset(220,20)
    displayLabel.TextWrapped=false
    displayLabel.Visible=false
    local usernameLabel=ESPText(root,"UsernameScreen",30,9)
    usernameLabel.AnchorPoint=Vector2.new(.5,1)
    usernameLabel.Size=UDim2.fromOffset(220,16)
    usernameLabel.TextWrapped=false
    usernameLabel.Visible=false
    local arrow=ESPNew("TextLabel",{
        Name="OffscreenArrow",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,
        Text="▲",TextColor3=C.Accent,TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=.1,Font=Enum.Font.GothamBlack,TextSize=14,Visible=false,ZIndex=31,
    },root)
    local skeleton={}
    for i=1,15 do skeleton[i]=ESPLine(root,"Skeleton"..i,25,1) end

    local highlight=Instance.new("Highlight")
    highlight.Name="AstriumESP"
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency=tonumber(Config.ESPHighlightFill) or .82
    highlight.OutlineTransparency=tonumber(Config.ESPHighlightOutline) or 0
    highlight.Enabled=false
    highlight.Parent=ESPHighlightFolder

    local entry={
        player=player,root=root,boxGlowLines=boxGlowLines,boxLines=boxLines,
        cornerGlowLines=cornerGlowLines,cornerLines=cornerLines,
        tracer=tracer,snapline=snapline,lookLine=lookLine,headDot=headDot,
        displayLabel=displayLabel,usernameLabel=usernameLabel,arrow=arrow,
        skeleton=skeleton,highlight=highlight,character=nil,billboard=nil,
    }
    ESPEntries[player]=entry
    ESPCreateBillboard(player,entry)
    return entry
end

local function ESPHideEntry(entry)
    if not entry then return end
    for _,line in ipairs(entry.boxGlowLines) do line.Visible=false end
    for _,line in ipairs(entry.boxLines) do line.Visible=false end
    for _,line in ipairs(entry.cornerGlowLines) do line.Visible=false end
    for _,line in ipairs(entry.cornerLines) do line.Visible=false end
    for _,line in ipairs(entry.skeleton) do line.Visible=false end
    entry.tracer.Visible=false
    entry.snapline.Visible=false
    entry.lookLine.Visible=false
    entry.headDot.Visible=false
    if entry.displayLabel then entry.displayLabel.Visible=false end
    if entry.usernameLabel then entry.usernameLabel.Visible=false end
    entry.arrow.Visible=false
    entry.highlight.Enabled=false
    ESPHideBillboard(entry)
end

local function ESPDestroyEntry(player)
    local entry=ESPEntries[player]
    if not entry then return end
    local conns=ESPPlayerConnections[player]
    if conns then
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        ESPPlayerConnections[player]=nil
    end
    if entry.root then pcall(function() entry.root:Destroy() end) end
    if entry.billboard then pcall(function() entry.billboard:Destroy() end) end
    if entry.highlight then pcall(function() entry.highlight:Destroy() end) end
    ESPEntries[player]=nil
end

local function ESPBindPlayer(player)
    if player==LocalPlayer then return end
    local entry=ESPCreateEntry(player)
    ESPPlayerConnections[player]={}
    local function bindCharacter(character)
        entry.character=character
        entry.highlight.Adornee=character
        entry.billboard.Adornee=character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")) or nil
        entry.highlight.Enabled=false
        entry.billboard.Enabled=false
    end
    table.insert(ESPPlayerConnections[player],ESPTrackConnection(player.CharacterAdded:Connect(bindCharacter)))
    table.insert(ESPPlayerConnections[player],ESPTrackConnection(player.CharacterRemoving:Connect(function(character)
        if entry.character==character then
            entry.character=nil
            entry.highlight.Adornee=nil
            entry.billboard.Adornee=nil
            ESPHideEntry(entry)
        end
    end)))
    bindCharacter(player.Character)
end

for _,player in ipairs(Players:GetPlayers()) do ESPBindPlayer(player) end
ESPTrackConnection(Players.PlayerAdded:Connect(ESPBindPlayer))
ESPTrackConnection(Players.PlayerRemoving:Connect(ESPDestroyEntry))

local ESPChainsR15={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local ESPChainsR6={
    {"Head","Torso"},{"Torso","Left Arm"},{"Left Arm","Left Leg"},{"Torso","Right Arm"},
    {"Right Arm","Right Leg"},{"Torso","Left Leg"},{"Torso","Right Leg"},{"Torso","HumanoidRootPart"},
}

local function ESPBuildCuboid(cf,size)
    local x=size.X*.5
    local y=size.Y*.5
    local z=size.Z*.5
    return {
        cf*CFrame.new(-x,-y,-z), cf*CFrame.new(x,-y,-z),
        cf*CFrame.new(x,y,-z), cf*CFrame.new(-x,y,-z),
        cf*CFrame.new(-x,-y,z), cf*CFrame.new(x,-y,z),
        cf*CFrame.new(x,y,z), cf*CFrame.new(-x,y,z),
    }
end

local ESPBoxEdges={
    {1,2},{2,3},{3,4},{4,1},
    {5,6},{6,7},{7,8},{8,5},
    {1,5},{2,6},{3,7},{4,8},
}

local function ESPGetCharacterBox(character)
    local ok,cf,size=pcall(function() return character:GetBoundingBox() end)
    if not ok or not cf or not size then return nil end
    size=Vector3.new(math.max(size.X,1.4),math.max(size.Y,2.2),math.max(size.Z,1.0))
    return cf,size
end

local function ESPProjectCuboid(camera,cf,size)
    local corners=ESPBuildCuboid(cf,size)
    local projected={}
    local depths={}
    local anyFront=false
    local anyOn=false
    for i,c in ipairs(corners) do
        local p,on,z=ESPProject(camera,c.Position)
        projected[i]=p
        depths[i]=z or -math.huge
        if z and z>0 then anyFront=true end
        if on then anyOn=true end
    end
    if not anyFront then return nil,false,nil end
    return projected,anyOn,depths
end

local function ESPClampArrow(camera,worldPosition,padding)
    local vp=camera.ViewportSize
    local center=Vector2.new(vp.X*.5,vp.Y*.5)
    local _,cameraOn,z=ESPProject(camera,worldPosition)
    local cameraSpace=camera.CFrame:PointToObjectSpace(worldPosition)
    local dir=Vector2.new(cameraSpace.X,-cameraSpace.Y)
    if z and z<0 then dir=-dir end
    if dir.Magnitude<0.001 then dir=Vector2.new(0,-1) end
    dir=dir.Unit
    local pad=math.clamp(tonumber(padding) or 30,12,90)
    local half=Vector2.new(vp.X*.5-pad,vp.Y*.5-pad)
    local scaleX=math.abs(dir.X)>0.0001 and half.X/math.abs(dir.X) or math.huge
    local scaleY=math.abs(dir.Y)>0.0001 and half.Y/math.abs(dir.Y) or math.huge
    local scale=math.min(scaleX,scaleY)
    local pos=center+dir*math.max(1,scale)
    return Vector2.new(math.clamp(pos.X,pad,vp.X-pad),math.clamp(pos.Y,pad,vp.Y-pad)),cameraOn
end

local ESPCornerSegments={
    {1,2},{1,4},{2,3},{3,4},{5,6},{5,8},{6,7},{7,8}
}

local function ESPDrawCornerOverlay(entry,projected,color,thickness,fade)
    local minX,minY=math.huge,math.huge
    local maxX,maxY=-math.huge,-math.huge
    for _,p in ipairs(projected) do
        minX=math.min(minX,p.X); minY=math.min(minY,p.Y)
        maxX=math.max(maxX,p.X); maxY=math.max(maxY,p.Y)
    end
    local w=maxX-minX
    local h=maxY-minY
    if w<4 or h<8 then return end
    local len=math.clamp(math.min(w,h)*.22,8,28)
    local pts={
        Vector2.new(minX,minY), Vector2.new(minX+len,minY),
        Vector2.new(minX,minY+len), Vector2.new(maxX,minY),
        Vector2.new(maxX-len,minY), Vector2.new(maxX,minY+len),
        Vector2.new(minX,maxY), Vector2.new(minX+len,maxY),
        Vector2.new(minX,maxY-len), Vector2.new(maxX,maxY),
        Vector2.new(maxX-len,maxY), Vector2.new(maxX,maxY-len),
    }
    local segs={
        {1,2},{1,3},{4,5},{4,6},{7,8},{7,9},{10,11},{10,12}
    }
    for i,pair in ipairs(segs) do
        local main=entry.cornerLines[i]
        local glow=entry.cornerGlowLines[i]
        local a,b=pts[pair[1]],pts[pair[2]]
        main.BackgroundColor3=color
        main.BackgroundTransparency=math.clamp(1-fade,0,.5)
        ESPSetLine(main,a,b,thickness,true)
        glow.BackgroundColor3=color
        glow.BackgroundTransparency=math.clamp(tonumber(Config.ESPBoxGlowTransparency) or .78,0,1)
        ESPSetLine(glow,a,b,math.max(4,thickness*3),Config.ESPBoxGlow)
    end
end

local function ESPUpdateBillboard(entry,player,character,humanoid,color,distance,fade)
    local bb=entry.billboard
    if not bb then return end
    local adornee=character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if bb.Adornee~=adornee then bb.Adornee=adornee end
    bb.MaxDistance=tonumber(Config.ESPMaxDistance) or 1000
    if not adornee then bb.Enabled=false return end
    local textScale=math.clamp(tonumber(Config.ESPTextScale) or 1,.75,1.5)
    entry.billboardName.Text=player.DisplayName
    entry.billboardName.TextSize=math.floor(12*textScale+.5)
    local textTransparency=math.clamp(1-fade,0,.45)
    entry.billboardName.TextColor3=color
    entry.billboardName.TextTransparency=textTransparency
    entry.billboardName.Visible=Config.ESPNames
    entry.billboardUsername.Text="@"..player.Name
    entry.billboardUsername.TextSize=math.floor(9*textScale+.5)
    entry.billboardUsername.TextColor3=C.Sub
    entry.billboardUsername.TextTransparency=math.clamp(textTransparency+.05,0,.55)
    entry.billboardUsername.Visible=Config.ESPUsername
    local tool=ESPGetWeapon(character)
    local meta={}
    if Config.ESPDistance then table.insert(meta,string.format("%d studs",math.floor(distance+.5))) end
    if Config.ESPWeapon and tool then table.insert(meta,"▰ "..tool) end
    entry.billboardMeta.Text=table.concat(meta,"  •  ")
    entry.billboardMeta.TextSize=math.floor(9*textScale+.5)
    entry.billboardMeta.TextColor3=C.Sub
    entry.billboardMeta.TextTransparency=textTransparency
    entry.billboardMeta.Visible=#meta>0
    local maxHealth=math.max(humanoid.MaxHealth,1)
    local ratio=math.clamp(humanoid.Health/maxHealth,0,1)
    local hc=ESPHealthColor(ratio)
    entry.billboardHPBack.Visible=Config.ESPHealth
    entry.billboardHPFill.BackgroundColor3=hc
    entry.billboardHPFill.Size=UDim2.fromScale(ratio,1)
    entry.billboardHPFill.Visible=Config.ESPHealth
    if Config.ESPHealthText then
        entry.billboardMeta.Text=(entry.billboardMeta.Text~="" and entry.billboardMeta.Text.."  •  " or "")..string.format("%d HP",math.floor(humanoid.Health+.5))
        entry.billboardMeta.TextColor3=hc
        entry.billboardMeta.Visible=true
    end
    bb.Enabled=(Config.ESPNames or Config.ESPUsername or Config.ESPWeapon or Config.ESPDistance or Config.ESPHealth)
end

local function ESPUpdateEntry(player,entry,camera,localRoot)
    ESPHideEntry(entry)
    if not Config.ESP or not camera or not localRoot then return false end
    if Config.ESPTeamCheck and IsTeammate(player) then return false end
    local character=Character(player)
    local humanoid=Humanoid(player)
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local head=character and character:FindFirstChild("Head")
    if not character or not humanoid or humanoid.Health<=0 or not root then return false end
    local distance=(root.Position-localRoot.Position).Magnitude
    local maxDistance=math.max(1,tonumber(Config.ESPMaxDistance) or 1000)
    if distance>maxDistance then return false end

    entry.character=character
    local color=ESPGetColor(player)
    local fade=ESPGetDistanceFade(distance)
    entry.highlight.Adornee=character
    entry.highlight.FillColor=color
    entry.highlight.OutlineColor=color
    local configuredFill=math.clamp(tonumber(Config.ESPHighlightFill) or .82,0,1)
    if Config.ESPBoxFill then configuredFill=math.max(.35,configuredFill-.30) end
    entry.highlight.FillTransparency=configuredFill
    entry.highlight.OutlineTransparency=math.clamp(tonumber(Config.ESPHighlightOutline) or 0,0,1)
    entry.highlight.Enabled=Config.ESPHighlight
    ESPUpdateBillboard(entry,player,character,humanoid,color,distance,fade)

    local boxCF,boxSize=ESPGetCharacterBox(character)
    local projected,anyOn,depths=nil,false,nil
    if boxCF then
        projected,anyOn,depths=ESPProjectCuboid(camera,boxCF,boxSize)
    end
    if projected then
        if Config.ESP3DBoxes then
            local thickness=math.clamp(tonumber(Config.ESPBoxThickness) or 1,1,4)
            if Config.ESPCornerBoxes then
                local frontCount=0
                for _,z in ipairs(depths) do if z>0 then frontCount+=1 end end
                if frontCount>=4 then ESPDrawCornerOverlay(entry,projected,color,thickness,fade) end
            else
                local boxEdges = {
                    {1,2},{2,3},{3,4},{4,1},
                    {5,6},{6,7},{7,8},{8,5},
                    {1,5},{2,6},{3,7},{4,8},
                }
                depths = depths or {}
                for i,edge in ipairs(boxEdges) do
                    if edge and edge[1] and edge[2] then
                        local a=projected[edge[1]]
                        local b=projected[edge[2]]
                        local valid=(depths[edge[1]] or -math.huge)>0 and (depths[edge[2]] or -math.huge)>0
                        if a and b then
                            local glow=entry.boxGlowLines[i]
                            local main=entry.boxLines[i]
                            if glow and main then
                                glow.BackgroundColor3=color
                                glow.BackgroundTransparency=math.clamp(tonumber(Config.ESPBoxGlowTransparency) or .78,0,1)
                                ESPSetLine(glow,a,b,math.max(4,thickness*3),Config.ESPBoxGlow and valid)
                                main.BackgroundColor3=color
                                main.BackgroundTransparency=math.clamp(1-fade,0,.5)
                                ESPSetLine(main,a,b,thickness,valid)
                            end
                        end
                    end
                end
            end
        end
        if Config.ESPSkeletons then
            local chains=character:FindFirstChild("UpperTorso") and ESPChainsR15 or ESPChainsR6
            for i,chain in ipairs(chains) do
                local line=entry.skeleton[i]
                local pa=character:FindFirstChild(chain[1])
                local pb=character:FindFirstChild(chain[2])
                if line and pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
                    local a,ao,az=ESPProject(camera,pa.Position)
                    local b,bo,bz=ESPProject(camera,pb.Position)
                    line.BackgroundColor3=color
                    if a and b and az>0 and bz>0 and (ao or bo or anyOn) then
                        ESPSetLine(line,a,b,Config.ESPSkeletonThickness,true)
                    end
                end
            end
        end
    end

    local vp=camera.ViewportSize
    local center=Vector2.new(vp.X*.5,vp.Y*.5)
    local headPos,headOn,headDepth=nil,false,nil
    if head then
        headPos,headOn,headDepth=ESPProject(camera,head.Position)
    end
    if Config.ESPHeadDot and headPos and headOn then
        entry.headDot.Position=UDim2.fromOffset(headPos.X,headPos.Y)
        entry.headDot.Size=UDim2.fromOffset(7,7)
        entry.headDot.BackgroundColor3=color
        entry.headDot.Visible=true
    end
    if headPos and headOn then
        local textScale=math.clamp(tonumber(Config.ESPTextScale) or 1,.75,1.5)
        local y=headPos.Y-9
        if entry.displayLabel then
            entry.displayLabel.Position=UDim2.fromOffset(headPos.X,y)
            entry.displayLabel.Text=player.DisplayName
            entry.displayLabel.TextSize=math.floor(12*textScale+.5)
            entry.displayLabel.TextColor3=color
            entry.displayLabel.TextTransparency=math.clamp(1-fade,0,.45)
            entry.displayLabel.Visible=Config.ESPNames==true
            if entry.displayLabel.Visible then y-=18*textScale end
        end
        if entry.usernameLabel then
            entry.usernameLabel.Position=UDim2.fromOffset(headPos.X,y)
            entry.usernameLabel.Text="@"..player.Name
            entry.usernameLabel.TextSize=math.floor(9*textScale+.5)
            entry.usernameLabel.TextColor3=C.Sub
            entry.usernameLabel.TextTransparency=math.clamp((1-fade)+.05,0,.55)
            entry.usernameLabel.Visible=Config.ESPUsername==true
        end
    end
    if Config.ESPLookDirection and head and headOn and headPos then
        local lookPos,lookOn=ESPProject(camera,head.Position+head.CFrame.LookVector*2.75)
        if lookPos and lookOn then
            entry.lookLine.BackgroundColor3=color
            ESPSetLine(entry.lookLine,headPos,lookPos,1,true)
        end
    end
    if Config.ESPTracers and projected then
        -- Use the projected bottom-center of the cuboid for a grounded tracer target.
        local bottom=(projected[1]+projected[2]+projected[5]+projected[6])*.25
        entry.tracer.BackgroundColor3=color
        ESPSetLine(entry.tracer,Vector2.new(vp.X*.5,vp.Y-8),bottom,Config.ESPTracerThickness,true)
    end
    if Config.ESPSnapline and projected then
        local target=center
        local sum=Vector2.new(0,0)
        local count=0
        for _,p in ipairs(projected) do
            sum+=p; count+=1
        end
        if count>0 then target=sum/count end
        entry.snapline.BackgroundColor3=color
        ESPSetLine(entry.snapline,Vector2.new(0,vp.Y*.5),target,Config.ESPTracerThickness,true)
    end

    if Config.ESPOffscreenArrows and (not projected or not anyOn) then
        local arrowPos,on=ESPClampArrow(camera,root.Position,30)
        local d=arrowPos-center
        entry.arrow.Position=UDim2.fromOffset(arrowPos.X,arrowPos.Y)
        entry.arrow.Rotation=math.deg(math.atan2(d.Y,d.X))+90
        entry.arrow.TextSize=math.floor((tonumber(Config.ESPArrowSize) or 14)*fade+.5)
        entry.arrow.TextColor3=color
        entry.arrow.Visible=not on
    end
    return true
end

local function UpdateESP(now)
    if not Config.ESP then
        for _,entry in pairs(ESPEntries) do ESPHideEntry(entry) end
        return
    end
    local camera=workspace.CurrentCamera
    local c=Character()
    local localRoot=c and c:FindFirstChild("HumanoidRootPart")
    if not camera or not localRoot then
        for _,entry in pairs(ESPEntries) do ESPHideEntry(entry) end
        return
    end
    if ESPViewportSize.X~=camera.ViewportSize.X or ESPViewportSize.Y~=camera.ViewportSize.Y then
        ESPViewportSize=camera.ViewportSize
        ESPLastUpdate=0
    end
    local rate=math.clamp(tonumber(Config.ESPUpdateRate) or .06,.025,.20)
    if now-ESPLastUpdate<rate then return end
    ESPLastUpdate=now

    local list={}
    for player,entry in pairs(ESPEntries) do
        local char=player.Character
        local r=char and char:FindFirstChild("HumanoidRootPart")
        local d=math.huge
        if r then d=(r.Position-localRoot.Position).Magnitude end
        list[#list+1]={player=player,entry=entry,distance=d}
    end
    table.sort(list,function(a,b) return a.distance<b.distance end)
    local maxRendered=math.max(1,math.floor(tonumber(Config.ESPMaxRendered) or 100))
    for i,item in ipairs(list) do
        if item.player.Parent~=Players or i>maxRendered then
            ESPHideEntry(item.entry)
        else
            local ok,err=xpcall(function()
                return ESPUpdateEntry(item.player,item.entry,camera,localRoot)
            end,function(e)
                return debug.traceback(tostring(e),2)
            end)
            if not ok then
                warn("[ASTRIUM ESP RUNTIME ERROR] "..item.player.Name.."\n"..tostring(err))
                if not Env.AstriumHubESPErrorNotified then Env.AstriumHubESPErrorNotified={} end
                if not Env.AstriumHubESPErrorNotified[item.player] then
                    Env.AstriumHubESPErrorNotified[item.player]=true
                end
            end
        end
    end
end

local fpsValue=60
local fpsAccum=0
local fpsFrames=0
local function UpdateFPSClock(dt)
    fpsAccum+=(dt or 0)
    fpsFrames+=1
    if fpsAccum>=.5 then
        fpsValue=math.floor(fpsFrames/fpsAccum+.5)
        fpsAccum=0
        fpsFrames=0
    end
end

local function RenderStatus()
    local lines={}
    if Config.FPSCounter then table.insert(lines,"FPS   "..tostring(fpsValue)) end
    if Config.PingCounter then
        local ok,ping=pcall(function() return LocalPlayer:GetNetworkPing()*1000 end)
        if ok then table.insert(lines,"PING  "..tostring(math.floor(ping+0.5)).." ms") end
    end
    if Config.Coordinates then
        local c=Character(); local r=c and c:FindFirstChild("HumanoidRootPart")
        if r then table.insert(lines,string.format("POS   %d, %d, %d",r.Position.X,r.Position.Y,r.Position.Z)) end
    end
    if Config.LocalTime then
        table.insert(lines,"TIME  "..os.date("%H:%M:%S"))
    end
    Status.Text=table.concat(lines,"\n")
    Status.Visible=#lines>0
end

local function ApplyClientSettings(dt)
    ApplyCameraSettings(dt)
end

UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local h=Humanoid()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

UserInputService.InputBegan:Connect(function(input,gameProcessed)
    if gameProcessed then return end
    local key=input.KeyCode
    if key==Enum.KeyCode.W then flyKeys.W=true
    elseif key==Enum.KeyCode.A then flyKeys.A=true
    elseif key==Enum.KeyCode.S then flyKeys.S=true
    elseif key==Enum.KeyCode.D then flyKeys.D=true
    elseif key==Enum.KeyCode.Space then flyKeys.Space=true
    elseif key==Enum.KeyCode.LeftControl then flyKeys.LeftControl=true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local key=input.KeyCode
    if key==Enum.KeyCode.W then flyKeys.W=false
    elseif key==Enum.KeyCode.A then flyKeys.A=false
    elseif key==Enum.KeyCode.S then flyKeys.S=false
    elseif key==Enum.KeyCode.D then flyKeys.D=false
    elseif key==Enum.KeyCode.Space then flyKeys.Space=false
    elseif key==Enum.KeyCode.LeftControl then flyKeys.LeftControl=false
    end
end)

--========================================================
-- LIGHTWEIGHT LOOP
--========================================================
local speedT=0
local noclipT=0
local invisT=0
local visualT=0
local graphicsT=0
local hudT=0
local lastSprintState=nil

-- Camera work is intentionally bound AFTER Roblox's camera priority.
-- Roblox documents Camera as priority 200; Camera+1 runs after default camera updates.
RunService:BindToRenderStep(CAMERA_RENDER_NAME,Enum.RenderPriority.Camera.Value+1,function(dt)
    ApplyClientSettings(dt)
end)

RunService:BindToRenderStep(AIM_RENDER_NAME,Enum.RenderPriority.Camera.Value+2,function(dt)
    Aimbot(dt)
end)

task.defer(function()
    UpdateCrosshair()
    ApplyLocalVisuals()
    ApplyLowGraphics()
    ApplyAdvancedGraphics()
    ApplyParticleReduction()
    if Config.Fly then SetFly(true) end
end)

RunService:BindToRenderStep(MAIN_RENDER_NAME,Enum.RenderPriority.Character.Value+1,function(dt)
    speedT+=dt
    noclipT+=dt
    invisT+=dt
    visualT+=dt
    graphicsT+=dt
    hudT+=dt

    UpdateFPSClock(dt)
    UpdateESP(time())

    if visualT>=0.10 then
        visualT=0
        UpdateCrosshair()
        ApplyLocalVisuals()
    end

    if graphicsT>=0.50 then
        graphicsT=0
        ApplyLowGraphics()
        ApplyAdvancedGraphics()
        ApplyParticleReduction()
    end

    if hudT>=0.20 then
        hudT=0
        RenderStatus()
    end

    if lastSprintState~=Config.AutoSprint then
        lastSprintState=Config.AutoSprint
        pcall(function() LocalPlayer:SetAttribute("AstriumHubSprint",lastSprintState) end)
    end

    if speedT>=.08 then
        speedT=0
        if Config.Speed or savedSpeed~=nil then UpdateSpeed() end
    end

    if noclipT>=.05 then
        noclipT=0
        if Config.NoClip or next(savedCollision) then UpdateNoClip() end
    end

    if Config.Fly and not flyConnection then
        SetFly(true)
    elseif not Config.Fly and flyConnection then
        SetFly(false)
    end

    if invisT>=.20 then
        invisT=0
        if Config.Invisibility then Invisibility(true) end
    end
end)

print("ASTRIUM HUB loaded | Only hotkey: O | Premium UI")

-- Remember the active profile for the next execution in the same environment.
Env.AstriumHubLastActiveProfile = Config.ActiveProfile
SaveProfile(Config.ActiveProfile)
