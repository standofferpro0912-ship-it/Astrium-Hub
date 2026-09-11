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
    local old = PlayerGui:FindFirstChild("FPSPanel")
    if old then old:Destroy() end
    local oldHUD = PlayerGui:FindFirstChild("FPSClientHUD")
    if oldHUD then oldHUD:Destroy() end
    local oldColor = game:GetService("Lighting"):FindFirstChild("AstriumHubLocalColor")
    if oldColor then oldColor:Destroy() end
end)

local Config = {
    Aimbot = false,
    ESP = false,
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
    PersistenceEnabled = true,
    PersistenceFile = "AstriumHub_profiles.json",
    ActiveProfile = "Default",

    -- ESP 2.0: clean tactical nameplate style (boxes/tracers disabled by default)
    ESPBoxes = false,
    ESPTracers = false,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTeamColor = true,
    ESPHighlight = true,
    ESPOffscreen = true,
    ESPHeadDot = false,
    ESPMaxDistance = 500,
    ESPUpdateRate = 0.045,
    ESPBoxThickness = 2,
    ESPTracerThickness = 2,
    ESPShowTeammates = true,

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
local TabList=New("Frame",{Size=UDim2.new(1,-14,1,-40),Position=UDim2.fromOffset(7,36),BackgroundTransparency=1},Sidebar)
New("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},TabList)
local Area=New("Frame",{Size=UDim2.new(1,-152,1,-82),Position=UDim2.fromOffset(145,80),BackgroundTransparency=1,ClipsDescendants=true},Main)

local tabDefs={
    {id="Combat",label="Combat",icon="⊙",desc="Targeting"},
    {id="Visuals",label="Visuals",icon="◉",desc="ESP"},
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
local UpdateESP
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

Section(Pages.Visuals,"PLAYER ESP 2.0","Clean tactical overlay — no giant boxes or screen-crossing tracers")
Toggle(Pages.Visuals,"ESP","Master switch for the local ESP system.",function() return Config.ESP end,function(v) Config.ESP=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Nameplates","Floating player card with name and status.",function() return Config.ESPNames end,function(v) Config.ESPNames=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Health","Show compact HP bar and values.",function() return Config.ESPHealth end,function(v) Config.ESPHealth=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Distance","Show distance beside the player card.",function() return Config.ESPDistance end,function(v) Config.ESPDistance=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Highlight","Subtle full-body outline instead of a box.",function() return Config.ESPHighlight end,function(v) Config.ESPHighlight=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Off-Screen Arrows","Shows a directional arrow for players outside the viewport.",function() return Config.ESPOffscreen end,function(v) Config.ESPOffscreen=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Head Dot","Small precise head marker.",function() return Config.ESPHeadDot end,function(v) Config.ESPHeadDot=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Legacy Boxes","Compatibility option; off by default.",function() return Config.ESPBoxes end,function(v) Config.ESPBoxes=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Legacy Tracers","Compatibility option; off by default.",function() return Config.ESPTracers end,function(v) Config.ESPTracers=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Team Colors","Use team color when available.",function() return Config.ESPTeamColor end,function(v) Config.ESPTeamColor=v; task.defer(UpdateESP) end)
Toggle(Pages.Visuals,"Show Teammates","Keep teammates visible in ESP.",function() return Config.ESPShowTeammates end,function(v) Config.ESPShowTeammates=v; task.defer(UpdateESP) end)
Slider(Pages.Visuals,"Max Distance","Do not render ESP beyond this distance.",50,1000,10,function() return Config.ESPMaxDistance end,function(v) Config.ESPMaxDistance=v; task.defer(UpdateESP) end)
Slider(Pages.Visuals,"Box Thickness","Thickness of the tactical box.",1,5,1,function() return Config.ESPBoxThickness end,function(v) Config.ESPBoxThickness=v; task.defer(UpdateESP) end)
Slider(Pages.Visuals,"Tracer Thickness","Thickness of the target tracer.",1,5,1,function() return Config.ESPTracerThickness end,function(v) Config.ESPTracerThickness=v; task.defer(UpdateESP) end)
Info(Pages.Visuals,"ESP 3.0","Screen-space bounds are calculated from the character model, with stable tracers, health, distance and off-screen tracking.",C.Accent)

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
        task.defer(UpdateESP)
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
-- ESP SYSTEM 3.0
--========================================================
local espOverlay=New("Frame",{
    Name="ESPOverlay",
    Size=UDim2.fromScale(1,1),
    Position=UDim2.fromScale(0,0),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    Active=false,
},Gui)
espOverlay.ZIndex=51

local espObjects={}

local function GetESPColor(player)
    if not Config.ESPTeamColor then return C.Accent end
    local ok,color=pcall(function()
        return player.TeamColor and player.TeamColor.Color
    end)
    if ok and color then return color end
    return C.Accent
end

local function MakeESPLine(parent)
    local line=New("Frame",{
        AnchorPoint=Vector2.new(.5,.5),
        BackgroundColor3=C.Accent,
        BorderSizePixel=0,
        ZIndex=50,
        Visible=false,
    },parent)
    Corner(line,2)
    return line
end

local function RemoveESP(player)
    local e=espObjects[player]
    if not e then return end
    if e.container then e.container:Destroy() end
    if e.highlight then e.highlight:Destroy() end
    espObjects[player]=nil
end

local function CreateESP(player)
    if player==LocalPlayer or not player.Character then return end
    RemoveESP(player)

    local char=player.Character

    local container=New("Frame",{
        Name="ESP_"..tostring(player.UserId),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Size=UDim2.fromScale(1,1),
        Position=UDim2.fromScale(0,0),
        Active=false,
        Visible=false,
        ClipsDescendants=false,
    },espOverlay)

    local box=New("Frame",{
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Size=UDim2.fromOffset(0,0),
        Position=UDim2.fromOffset(0,0),
        ZIndex=52,
        Visible=false,
    },container)
    Outline(box,GetESPColor(player),Config.ESPBoxThickness,.05)

    local card=New("Frame",{
        AnchorPoint=Vector2.new(.5,1),
        Size=UDim2.fromOffset(194,56),
        Position=UDim2.fromOffset(0,0),
        BackgroundColor3=Color3.fromRGB(10,12,16),
        BackgroundTransparency=.08,
        BorderSizePixel=0,
        ZIndex=56,
        Visible=false,
    },container)
    Corner(card,10)
    Outline(card,C.Border,1,.05)

    local accent=New("Frame",{
        Size=UDim2.fromOffset(3,38),
        Position=UDim2.fromOffset(8,9),
        BackgroundColor3=GetESPColor(player),
        BorderSizePixel=0,
        ZIndex=57,
    },card)
    Corner(accent,2)

    local name=New("TextLabel",{
        Size=UDim2.new(1,-72,0,19),
        Position=UDim2.fromOffset(18,6),
        BackgroundTransparency=1,
        Text=player.DisplayName,
        TextColor3=C.Text,
        TextSize=11,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
        ZIndex=58,
    },card)

    local distance=New("TextLabel",{
        Size=UDim2.fromOffset(55,18),
        Position=UDim2.new(1,-64,0,6),
        BackgroundTransparency=1,
        Text="0m",
        TextColor3=C.Sub,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Right,
        ZIndex=58,
    },card)

    local hpBack=New("Frame",{
        Size=UDim2.new(1,-45,0,6),
        Position=UDim2.fromOffset(18,30),
        BackgroundColor3=Color3.fromRGB(38,41,48),
        BorderSizePixel=0,
        ZIndex=57,
    },card)
    Corner(hpBack,3)

    local hpFill=New("Frame",{
        Size=UDim2.fromScale(1,1),
        BackgroundColor3=C.Good,
        BorderSizePixel=0,
        ZIndex=58,
    },hpBack)
    Corner(hpFill,3)

    local hpText=New("TextLabel",{
        Size=UDim2.fromOffset(80,14),
        Position=UDim2.fromOffset(18,39),
        BackgroundTransparency=1,
        TextColor3=C.Text,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=58,
    },card)

    local headDot=New("Frame",{
        AnchorPoint=Vector2.new(.5,.5),
        Size=UDim2.fromOffset(7,7),
        BackgroundColor3=GetESPColor(player),
        BorderSizePixel=0,
        ZIndex=59,
        Visible=false,
    },container)
    Corner(headDot,4)

    local arrow=New("TextLabel",{
        AnchorPoint=Vector2.new(.5,.5),
        Size=UDim2.fromOffset(30,30),
        BackgroundTransparency=1,
        Text="▲",
        TextColor3=GetESPColor(player),
        TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=.15,
        TextSize=19,
        Font=Enum.Font.GothamBold,
        ZIndex=60,
        Visible=false,
    },espOverlay)

    local tracer=MakeESPLine(espOverlay)

    espObjects[player]={
        container=container,
        box=box,
        highlight=New("Highlight",{
            Name="ESPHighlight",
            Adornee=char,
            DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency=.93,
            OutlineTransparency=.03,
            FillColor=GetESPColor(player),
            OutlineColor=GetESPColor(player),
            Enabled=false,
        },Gui),
        card=card,
        accent=accent,
        name=name,
        distance=distance,
        hpBack=hpBack,
        hpFill=hpFill,
        hpText=hpText,
        headDot=headDot,
        arrow=arrow,
        tracer=tracer,
    }
end

local function HideESPObject(e)
    if not e then return end
    e.container.Visible=false
    e.box.Visible=false
    e.card.Visible=false
    e.headDot.Visible=false
    e.arrow.Visible=false
    e.tracer.Visible=false
    e.highlight.Enabled=false
end

local function SetLine(line,a,b,color,thickness)
    local delta=b-a
    local length=delta.Magnitude
    if length<1 then
        line.Visible=false
        return
    end
    line.BackgroundColor3=color
    line.Size=UDim2.fromOffset(math.max(1,thickness),length)
    line.Position=UDim2.fromOffset((a.X+b.X)*.5,(a.Y+b.Y)*.5)
    line.Rotation=math.deg(math.atan2(delta.Y,delta.X))+90
    line.Visible=true
end

local function GetBoxCorners(cf,size)
    local hx,hy,hz=size.X*.5,size.Y*.5,size.Z*.5
    local corners={
        Vector3.new(-hx,-hy,-hz),Vector3.new(-hx,-hy,hz),
        Vector3.new(-hx,hy,-hz),Vector3.new(-hx,hy,hz),
        Vector3.new(hx,-hy,-hz),Vector3.new(hx,-hy,hz),
        Vector3.new(hx,hy,-hz),Vector3.new(hx,hy,hz),
    }
    for i,p in ipairs(corners) do
        corners[i]=cf:PointToWorldSpace(p)
    end
    return corners
end

local function GetScreenBounds(camera,char,view)
    local cf,size=char:GetBoundingBox()
    local corners=GetBoxCorners(cf,size)
    local minX,minY=math.huge,math.huge
    local maxX,maxY=-math.huge,-math.huge
    local visibleCount=0

    for _,world in ipairs(corners) do
        local p=camera:WorldToViewportPoint(world)
        if p.Z>0 then
            visibleCount+=1
            minX=math.min(minX,p.X)
            minY=math.min(minY,p.Y)
            maxX=math.max(maxX,p.X)
            maxY=math.max(maxY,p.Y)
        end
    end

    local root=char:FindFirstChild("HumanoidRootPart")
    local rootPoint,rootOn=camera:WorldToViewportPoint(root and root.Position or cf.Position)
    local root2d=Vector2.new(rootPoint.X,rootPoint.Y)
    local onScreen=rootPoint.Z>0 and (
        rootOn or
        (root2d.X>=0 and root2d.X<=view.X and root2d.Y>=0 and root2d.Y<=view.Y)
    )

    if visibleCount<2 then
        return nil,root2d,rootPoint.Z>0,onScreen
    end

    minX=math.clamp(minX,-10000,10000)
    minY=math.clamp(minY,-10000,10000)
    maxX=math.clamp(maxX,-10000,10000)
    maxY=math.clamp(maxY,-10000,10000)

    return {
        min=Vector2.new(minX,minY),
        max=Vector2.new(maxX,maxY),
        center=Vector2.new((minX+maxX)*.5,(minY+maxY)*.5),
        top=Vector2.new((minX+maxX)*.5,minY),
        bottom=Vector2.new((minX+maxX)*.5,maxY),
        width=math.max(2,maxX-minX),
        height=math.max(2,maxY-minY),
    },root2d,rootPoint.Z>0,onScreen
end

local function GetOffscreenPoint(camera,worldPosition,view)
    local projected=camera:WorldToViewportPoint(worldPosition)
    local center=Vector2.new(view.X*.5,view.Y*.5)
    local p=Vector2.new(projected.X,projected.Y)

    if projected.Z<0 then
        p=center-(p-center)
    end

    local direction=p-center
    if direction.Magnitude<0.01 then
        direction=Vector2.new(0,-1)
    end

    local half=Vector2.new(view.X*.5-48,view.Y*.5-48)
    local scale=1
    if math.abs(direction.X)>0 then scale=math.max(scale,math.abs(direction.X)/math.max(half.X,1)) end
    if math.abs(direction.Y)>0 then scale=math.max(scale,math.abs(direction.Y)/math.max(half.Y,1)) end
    local point=center+direction/scale

    return Vector2.new(
        math.clamp(point.X,34,view.X-34),
        math.clamp(point.Y,34,view.Y-34)
    )
end

UpdateESP=function()
    local cam=workspace.CurrentCamera
    local mine=Character()
    local myRoot=mine and mine:FindFirstChild("HumanoidRootPart")

    if not Config.ESP or not cam or not myRoot then
        for _,e in pairs(espObjects) do HideESPObject(e) end
        return
    end

    local view=cam.ViewportSize
    local center=Vector2.new(view.X*.5,view.Y*.5)
    local seen={}

    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer then
            local char=plr.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local head=char and char:FindFirstChild("Head")

            local teammate=(Config.ESPShowTeammates==false and IsTeammate(plr))
            if not teammate and char and hum and root and hum.Health>0 then
                local distanceStuds=(root.Position-myRoot.Position).Magnitude
                if distanceStuds<=Config.ESPMaxDistance then
                    if not espObjects[plr] or not espObjects[plr].container.Parent then
                        CreateESP(plr)
                    end

                    local e=espObjects[plr]
                    seen[plr]=true

                    local color=GetESPColor(plr)
                    e.highlight.Adornee=char
                    e.highlight.FillColor=color
                    e.highlight.OutlineColor=color
                    e.highlight.Enabled=Config.ESPHighlight
                    e.accent.BackgroundColor3=color
                    e.headDot.BackgroundColor3=color
                    e.arrow.TextColor3=color

                    local bounds,root2d,rootInFront,onScreen=GetScreenBounds(cam,char,view)
                    local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                    local hpColor=Color3.fromRGB(
                        math.floor(255*(1-ratio)),
                        math.floor(220*ratio),
                        70
                    )

                    e.hpFill.Size=UDim2.new(ratio,0,1,0)
                    e.hpFill.BackgroundColor3=hpColor
                    e.hpText.Text=string.format("%d / %d HP",math.floor(hum.Health+.5),math.floor(hum.MaxHealth+.5))
                    e.distance.Text=string.format("%d studs",math.floor(distanceStuds+.5))
                    e.name.Text=plr.DisplayName

                    local headPoint=head and cam:WorldToViewportPoint(head.Position)
                    if bounds and onScreen and rootInFront then
                        e.container.Visible=true
                        e.box.Visible=Config.ESPBoxes
                        e.box.Position=UDim2.fromOffset(bounds.min.X,bounds.min.Y)
                        e.box.Size=UDim2.fromOffset(bounds.width,bounds.height)
                        local stroke=e.box:FindFirstChildOfClass("UIStroke")
                        if stroke then
                            stroke.Color=color
                            stroke.Thickness=Config.ESPBoxThickness
                        end

                        e.card.Visible=Config.ESPNames or Config.ESPHealth or Config.ESPDistance
                        e.card.Position=UDim2.fromOffset(bounds.center.X,bounds.min.Y-10)
                        e.name.Visible=Config.ESPNames
                        e.distance.Visible=Config.ESPDistance
                        e.hpBack.Visible=Config.ESPHealth
                        e.hpFill.Visible=Config.ESPHealth
                        e.hpText.Visible=Config.ESPHealth

                        e.headDot.Visible=Config.ESPHeadDot and headPoint and headPoint.Z>0
                        if e.headDot.Visible then
                            e.headDot.Position=UDim2.fromOffset(headPoint.X,headPoint.Y)
                        end

                        e.tracer.Visible=false
                        if Config.ESPTracers then
                            SetLine(
                                e.tracer,
                                Vector2.new(center.X,view.Y-8),
                                bounds.bottom,
                                color,
                                Config.ESPTracerThickness
                            )
                        end
                        e.arrow.Visible=false
                    else
                        e.container.Visible=false
                        e.box.Visible=false
                        e.card.Visible=false
                        e.headDot.Visible=false
                        e.tracer.Visible=false

                        if Config.ESPOffscreen and (rootInFront==true or not onScreen) then
                            local point=GetOffscreenPoint(cam,root.Position,view)
                            local delta=point-center
                            e.arrow.Position=UDim2.fromOffset(point.X,point.Y)
                            e.arrow.Rotation=math.deg(math.atan2(delta.Y,delta.X))+90
                            e.arrow.Visible=true
                        else
                            e.arrow.Visible=false
                        end
                    end
                end
            end
        end
    end

    for plr,e in pairs(espObjects) do
        if not seen[plr] then
            HideESPObject(e)
        end
    end
end

local function HookPlayer(player)
    if player==LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(.1)
        if Config.ESP then
            CreateESP(player)
        end
    end)
    player.CharacterRemoving:Connect(function()
        if CurrentAimPlayer==player then ResetAimState() end
        RemoveESP(player)
    end)
    if player.Character and Config.ESP then
        CreateESP(player)
    end
end

for _,player in ipairs(Players:GetPlayers()) do
    HookPlayer(player)
end
Players.PlayerAdded:Connect(HookPlayer)

Players.PlayerRemoving:Connect(function(player)
    if CurrentAimPlayer==player then ResetAimState() end
    RemoveESP(player)
end)
LocalPlayer.CharacterAdded:Connect(function()
    ResetAimState()
    if flyConnection then flyConnection:Disconnect(); flyConnection=nil end
    flyHumanoid=nil
    flyOldAutoRotate=nil
    savedSpeed=nil; table.clear(savedCollision); task.wait(.5)
    if Config.Speed then UpdateSpeed() end
    if Config.NoClip then UpdateNoClip() end
    if Config.Fly then SetFly(true) end
    if Config.Invisibility then Invisibility(true) end
end)


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
local espT=0
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
    if Config.ESP then UpdateESP() end
    if Config.Fly then SetFly(true) end
end)

RunService:BindToRenderStep(MAIN_RENDER_NAME,Enum.RenderPriority.Character.Value+1,function(dt)
    espT+=dt
    speedT+=dt
    noclipT+=dt
    invisT+=dt
    visualT+=dt
    graphicsT+=dt
    hudT+=dt

    UpdateFPSClock(dt)

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

    if espT>=Config.ESPUpdateRate then
        espT=0
        if Config.ESP or next(espObjects) then UpdateESP() end
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
