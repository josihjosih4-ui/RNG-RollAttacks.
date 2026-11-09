-- RNG ROLLATTACKS | ROLL STATE SCANNER V3 SAFE
-- Passive and low overhead. NO __namecall hooks, remote interception, or remote calls.
-- Shows UI and equipped-tool changes as the REAL in-game Roll button is used.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local p=Players.LocalPlayer
if not p then return end
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.RNG_ROLL_STATE_SCAN_CLOSE)=="function" then
    pcall(env.RNG_ROLL_STATE_SCAN_CLOSE)
end

local alive=true
local scanning=false
local connections={}
local scanConnections={}
local lines={}
local scanStart=0
local maxLines=90

local function connect(signal,fn,bucket)
    local c=signal:Connect(fn)
    table.insert(bucket or connections,c)
    return c
end
local function clear(bucket)
    for _,c in ipairs(bucket) do
        pcall(function() c:Disconnect() end)
    end
    for i=#bucket,1,-1 do bucket[i]=nil end
end
local function create(kind,parent,props)
    local obj=Instance.new(kind)
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local screen=create("ScreenGui",p:WaitForChild("PlayerGui"),{
    Name="RNG_RollState_Scanner_Safe",ResetOnSpawn=false
})
local frame=create("Frame",screen,{
    Size=UDim2.fromOffset(306,335),
    Position=UDim2.new(.5,-153,.48,-167),
    BackgroundColor3=Color3.fromRGB(18,13,29),
    BorderSizePixel=0
})
create("UICorner",frame,{CornerRadius=UDim.new(0,12)})
create("UIStroke",frame,{Color=Color3.fromRGB(155,95,255),Thickness=1})
local header=create("Frame",frame,{
    Size=UDim2.new(1,0,0,42),
    BackgroundColor3=Color3.fromRGB(40,29,61),BorderSizePixel=0
})
create("UICorner",header,{CornerRadius=UDim.new(0,12)})
create("TextLabel",header,{
    Position=UDim2.fromOffset(10,7),Size=UDim2.new(1,-52,0,27),
    BackgroundTransparency=1,Text="ROLL // SAFE SCANNER V3",
    Font=Enum.Font.GothamBold,TextSize=13,
    TextColor3=Color3.new(1,1,1),
    TextXAlignment=Enum.TextXAlignment.Left
})
local exit=create("TextButton",header,{
    Position=UDim2.new(1,-35,0,9),Size=UDim2.fromOffset(25,25),
    BackgroundColor3=Color3.fromRGB(69,47,94),BorderSizePixel=0,
    Text="X",TextColor3=Color3.new(1,1,1),
    TextSize=14,Font=Enum.Font.GothamBold
})
local status=create("TextLabel",frame,{
    Position=UDim2.fromOffset(11,46),
    Size=UDim2.new(1,-22,0,37),BackgroundTransparency=1,
    Text="Read-only. Tap START, then use normal Roll.",
    TextColor3=Color3.fromRGB(210,196,233),
    TextWrapped=true,TextSize=11,Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
})
local start=create("TextButton",frame,{
    Position=UDim2.fromOffset(11,87),Size=UDim2.fromOffset(137,34),
    BackgroundColor3=Color3.fromRGB(150,89,248),BorderSizePixel=0,
    Text="START 18S",TextSize=12,Font=Enum.Font.GothamBold,
    TextColor3=Color3.new(1,1,1)
})
local copy=create("TextButton",frame,{
    Position=UDim2.fromOffset(157,87),Size=UDim2.fromOffset(138,34),
    BackgroundColor3=Color3.fromRGB(77,54,104),BorderSizePixel=0,
    Text="COPY REPORT",TextSize=12,Font=Enum.Font.GothamBold,
    TextColor3=Color3.new(1,1,1)
})
local output=create("TextBox",frame,{
    Position=UDim2.fromOffset(11,130),
    Size=UDim2.new(1,-22,1,-141),
    BackgroundColor3=Color3.fromRGB(31,24,46),
    BorderSizePixel=0,ClearTextOnFocus=false,
    Text="No game hooks. Observes only Roll UI and tools.",
    TextWrapped=true,MultiLine=true,TextEditable=false,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    Font=Enum.Font.Code,TextSize=10,
    TextColor3=Color3.new(1,1,1)
})
local function note(message)
    if not alive or #lines>=maxLines then return end
    local t=scanning and (os.clock()-scanStart) or 0
    lines[#lines+1]=string.format("+%.1fs %s",t,tostring(message):sub(1,175))
    output.Text=table.concat(lines,"\n")
end
local function getRollUI()
    local main=p.PlayerGui:FindFirstChild("MainUI")
    local button=main and main:FindFirstChild("RollButton")
    local label=button and button:FindFirstChild("Label")
    local shadow=button and button:FindFirstChild("Shadow")
    local cooldown=main and main:FindFirstChild("RollCooldown")
    return button,label,shadow,cooldown
end
local function textOf(o)
    if o and (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then
        return tostring(o.Text):sub(1,100)
    end
    return "(missing)"
end
local function equipped()
    local char=p.Character
    if not char then return "(no character)" end
    local held={}
    for _,obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then held[#held+1]=obj.Name end
    end
    return #held==0 and "(none)" or table.concat(held,",")
end
local function attributeSummary(obj)
    if not obj then return "" end
    local names={}
    for k,v in pairs(obj:GetAttributes()) do
        local name=string.lower(k)
        if name:find("roll",1,true) or name:find("attack",1,true)
            or name:find("punch",1,true) or name:find("weapon",1,true)
            or name:find("equip",1,true) then
            names[#names+1]=k.."="..tostring(v):sub(1,50)
        end
    end
    table.sort(names)
    if #names>8 then
        for i=#names,9,-1 do names[i]=nil end
    end
    return #names>0 and table.concat(names," | ") or "(none)"
end
local function snapshot()
    local button,label,shadow,cooldown=getRollUI()
    return "Roll="..textOf(label).." / "..textOf(shadow)
        .." | Cooldown="..textOf(cooldown)
        .." | Tool="..equipped()
        .." | Player attrs="..attributeSummary(p)
        .." | Character attrs="..attributeSummary(p.Character)
end
local function watchLabel(obj,which)
    if not obj or not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    note(which.." initial: "..textOf(obj))
    connect(obj:GetPropertyChangedSignal("Text"),function()
        if scanning then note(which.." => "..textOf(obj)) end
    end,scanConnections)
end
local function begin()
    if not alive or scanning then return end
    clear(scanConnections)
    for i=#lines,1,-1 do lines[i]=nil end
    scanning=true
    scanStart=os.clock()
    start.Text="SCANNING"
    status.Text="Tap the ORIGINAL Roll button. No remote requests are made."
    note("START | PlaceId="..tostring(game.PlaceId))
    note("BEFORE "..snapshot())
    local button,label,shadow,cooldown=getRollUI()
    if not button then
        note("MainUI.RollButton not found; GUI may not be loaded.")
    else
        if button:IsA("GuiButton") then
            connect(button.Activated,function()
                if scanning then
                    note("REAL ROLL BUTTON tapped")
                    note("TAP STATE "..snapshot())
                end
            end,scanConnections)
        end
        watchLabel(label,"Roll Label")
        watchLabel(shadow,"Roll Shadow")
        watchLabel(cooldown,"Roll Cooldown")
    end
    local char=p.Character
    if char then
        connect(char.ChildAdded,function(obj)
            if scanning and obj:IsA("Tool") then note("TOOL ADDED "..obj.Name) end
        end,scanConnections)
        connect(char.ChildRemoved,function(obj)
            if scanning and obj:IsA("Tool") then note("TOOL REMOVED "..obj.Name) end
        end,scanConnections)
        connect(char.AttributeChanged,function(name)
            if not scanning then return end
            local s=name:lower()
            if s:find("roll",1,true) or s:find("attack",1,true)
               or s:find("punch",1,true) or s:find("equip",1,true) then
                note("CHAR ATTRIBUTE "..name.."="..tostring(char:GetAttribute(name)))
            end
        end,scanConnections)
    end
    connect(p.AttributeChanged,function(name)
        if not scanning then return end
        local s=name:lower()
        if s:find("roll",1,true) or s:find("attack",1,true)
           or s:find("punch",1,true) or s:find("equip",1,true) then
            note("PLAYER ATTRIBUTE "..name.."="..tostring(p:GetAttribute(name)))
        end
    end,scanConnections)
    -- One wait task per scan; no per-frame polling and no metamethod interception.
    task.delay(18,function()
        if not alive or not scanning then return end
        note("AFTER "..snapshot())
        note("END. Scanner did not send or intercept game requests.")
        scanning=false
        clear(scanConnections)
        start.Text="SCAN AGAIN"
        status.Text="Scan finished. Copy report and paste it into ChatGPT."
    end)
end
connect(start.Activated,begin)
connect(copy.Activated,function()
    if not alive then return end
    local s=table.concat(lines,"\n")
    if type(setclipboard)=="function" then
        local ok=pcall(setclipboard,s)
        if ok then
            status.Text="Report copied. Paste it into ChatGPT."
            return
        end
    end
    output.TextEditable=true
    status.Text="Clipboard unavailable; select report text manually."
end)
-- Touch drag support, restricted to one tracked touch.
local dragging=false
local dragPointer=nil
local dragFrom=nil
local panelFrom=nil
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragPointer=input
        dragFrom=input.Position
        panelFrom=frame.Position
        local changed
        changed=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if changed then changed:Disconnect() end
            end
        end)
    end
end)
connect(UIS.InputChanged,function(input)
    if not dragging or not dragFrom or not panelFrom then return end
    if input~=dragPointer and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-dragFrom
    frame.Position=UDim2.new(panelFrom.X.Scale,panelFrom.X.Offset+delta.X,
        panelFrom.Y.Scale,panelFrom.Y.Offset+delta.Y)
end)
local function shutdown()
    if not alive then return end
    alive=false
    scanning=false
    clear(scanConnections)
    clear(connections)
    pcall(function() screen:Destroy() end)
    if env.RNG_ROLL_STATE_SCAN_CLOSE==shutdown then env.RNG_ROLL_STATE_SCAN_CLOSE=nil end
end
connect(exit.Activated,shutdown)
env.RNG_ROLL_STATE_SCAN_CLOSE=shutdown
print("[RNG Roll State Scanner V3] Safe passive scanner loaded; no hooks, no remote calls.")
