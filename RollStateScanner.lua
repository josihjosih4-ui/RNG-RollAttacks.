-- RNG ROLLATTACKS | Roll State Scanner V2
-- Passive diagnostics. Does not fire remotes, change states, or auto-roll.
-- Purpose: distinguish an incomplete roll from an equip/punch lock.
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
if not player then return end
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.RNG_ROLL_STATE_SCAN_CLOSE)=="function" then pcall(env.RNG_ROLL_STATE_SCAN_CLOSE) end
local gui=Instance.new("ScreenGui")
gui.Name="RNG_RollState_Scanner"
gui.ResetOnSpawn=false
gui.Parent=player:WaitForChild("PlayerGui")
local function make(kind,parent,props)
    local o=Instance.new(kind)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local panel=make("Frame",gui,{
    Position=UDim2.new(.03,0,.36,0),Size=UDim2.fromOffset(308,345),
    BackgroundColor3=Color3.fromRGB(18,13,30),BorderSizePixel=0
})
make("UICorner",panel,{CornerRadius=UDim.new(0,13)})
make("UIStroke",panel,{Color=Color3.fromRGB(145,85,246),Thickness=1})
local head=make("Frame",panel,{
    Size=UDim2.new(1,0,0,42),BackgroundColor3=Color3.fromRGB(37,25,57),
    BorderSizePixel=0
})
make("UICorner",head,{CornerRadius=UDim.new(0,11)})
make("TextLabel",head,{
    Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-55,0,30),
    BackgroundTransparency=1,Text="ROLL // STATE SCANNER",Font=Enum.Font.GothamBold,
    TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=Enum.TextXAlignment.Left
})
local exit=make("TextButton",head,{
    Position=UDim2.new(1,-37,0,8),Size=UDim2.fromOffset(27,27),
    Text="X",TextColor3=Color3.new(1,1,1),TextSize=15,
    BackgroundColor3=Color3.fromRGB(64,46,88),BorderSizePixel=0
})
local msg=make("TextLabel",panel,{
    Position=UDim2.fromOffset(11,48),Size=UDim2.new(1,-22,0,40),
    Text="Start scan, then use the game's normal Roll button.",
    TextWrapped=true,BackgroundTransparency=1,Font=Enum.Font.Gotham,
    TextColor3=Color3.fromRGB(211,195,231),TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left
})
local start=make("TextButton",panel,{
    Position=UDim2.fromOffset(11,94),Size=UDim2.fromOffset(138,32),
    BackgroundColor3=Color3.fromRGB(143,82,245),BorderSizePixel=0,
    Text="START 18s",TextColor3=Color3.new(1,1,1),
    TextSize=12,Font=Enum.Font.GothamBold
})
local copy=make("TextButton",panel,{
    Position=UDim2.fromOffset(159,94),Size=UDim2.fromOffset(138,32),
    BackgroundColor3=Color3.fromRGB(70,48,95),BorderSizePixel=0,
    Text="COPY REPORT",TextColor3=Color3.new(1,1,1),
    TextSize=12,Font=Enum.Font.GothamBold
})
local output=make("TextBox",panel,{
    Position=UDim2.fromOffset(11,137),Size=UDim2.new(1,-22,1,-148),
    BackgroundColor3=Color3.fromRGB(29,22,45),BorderSizePixel=0,
    Font=Enum.Font.Code,TextSize=10,TextWrapped=true,
    TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,MultiLine=true,
    TextEditable=false,ClearTextOnFocus=false,
    Text="Scan records game roll requests and Punch/equipped-attack changes."
})
local alive,armed=true,false
local connections={}
local notes={}
local namecallHooked=false
local function wire(sig,fn)
    local c=sig:Connect(fn)
    connections[#connections+1]=c
end
local function note(t)
    if not alive or #notes>=95 then return end
    notes[#notes+1]=string.format("[%.1fs] %s",os.clock()%100000,tostring(t):sub(1,125))
    output.Text=table.concat(notes,"\n")
end
local function safeName(obj)
    local ok,s=pcall(function()return obj:GetFullName()end)
    return ok and s or obj.Name
end
local function toolNames()
    local ch=player.Character
    local held={}
    if ch then
        for _,o in ipairs(ch:GetChildren()) do
            if o:IsA("Tool") then held[#held+1]=o.Name end
        end
    end
    table.sort(held)
    local back={}
    local bp=player:FindFirstChildOfClass("Backpack")
    if bp then
        for _,o in ipairs(bp:GetChildren()) do
            if o:IsA("Tool") then back[#back+1]=o.Name end
        end
    end
    table.sort(back)
    return (#held>0 and table.concat(held,",") or "(none)"),(#back>0 and table.concat(back,",") or "(none)")
end
local function getText(path)
    local o=player.PlayerGui
    for _,n in ipairs(path) do
        o=o and o:FindFirstChild(n)
    end
    if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then return o.Text end
    return "(missing)"
end
local function rollSnapshot()
    local held,back=toolNames()
    local label=getText({"MainUI","RollButton","Label"})
    local cool=getText({"MainUI","RollCooldown"})
    local shadow=getText({"MainUI","RollButton","Shadow"})
    return "label="..label.." | shadow="..shadow.." | cool="..cool.." | held="..held.." | bag="..back
end
local function watchHook()
    if namecallHooked then return end
    namecallHooked=true
    if type(hookmetamethod)~="function" or type(getnamecallmethod)~="function" then
        note("Remote call observer unavailable; GUI/tool tracking works")
        return
    end
    local original
    local function observe(self,...)
        if armed and typeof(self)=="Instance" and self:IsA("RemoteFunction")
          and self.Name=="RollAttack" and getnamecallmethod()=="InvokeServer" then
            local n=select("#",...)
            note("RollAttack:InvokeServer args="..n)
            task.delay(.5,function() if armed then note("AFTER 0.5s: "..rollSnapshot()) end end)
            task.delay(2.4,function() if armed then note("AFTER 2.4s: "..rollSnapshot()) end end)
        end
        return original(self,...)
    end
    local wrapped=type(newcclosure)=="function" and newcclosure(observe) or observe
    local ok,old=pcall(function()return hookmetamethod(game,"__namecall",wrapped)end)
    if ok and type(old)=="function" then
        original=old
        note("Remote call observer ENABLED")
    else
        note("Remote call observer BLOCKED; GUI/tool tracking works")
    end
end
local function begin()
    if not alive or armed then return end
    armed=true
    table.clear(notes)
    start.Text="SCANNING"
    msg.Text="Tap NORMAL Roll once, then again when it allows. Don't use 3x TEST."
    note("START | PlaceId="..game.PlaceId)
    note("BASELINE "..rollSnapshot())
    watchHook()
    local prev=rollSnapshot()
    local untilAt=os.clock()+18
    task.spawn(function()
        while alive and armed and os.clock()<untilAt do
            local snap=rollSnapshot()
            if snap~=prev then
                note("STATE "..snap)
                prev=snap
            end
            task.wait(.18)
        end
        if not alive then return end
        armed=false
        note("END "..rollSnapshot())
        start.Text="SCAN AGAIN"
        msg.Text="Copy report and paste it into ChatGPT."
    end)
end
wire(start.Activated,begin)
wire(copy.Activated,function()
    local s=table.concat(notes,"\n")
    if type(setclipboard)=="function" and pcall(setclipboard,s) then
        msg.Text="Report copied. Paste it here."
    else
        output.TextEditable=true
        msg.Text="Clipboard unavailable. Select report text manually."
    end
end)
-- Mobile drag from header only.
local dragOrigin,panelOrigin,dragging
wire(head.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragOrigin=i.Position
        panelOrigin=panel.Position
        dragging=true
        local c
        c=i.Changed:Connect(function()
            if i.UserInputState==Enum.UserInputState.End then
                dragging=false
                c:Disconnect()
            end
        end)
    end
end)
wire(UserInputService.InputChanged,function(i)
    if dragging and dragOrigin and
      (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=i.Position-dragOrigin
        panel.Position=UDim2.new(panelOrigin.X.Scale,panelOrigin.X.Offset+d.X,panelOrigin.Y.Scale,panelOrigin.Y.Offset+d.Y)
    end
end)
local function shutdown()
    if not alive then return end
    alive=false
    armed=false
    for _,c in ipairs(connections)do pcall(function()c:Disconnect()end)end
    pcall(function()gui:Destroy()end)
    if env.RNG_ROLL_STATE_SCAN_CLOSE==shutdown then env.RNG_ROLL_STATE_SCAN_CLOSE=nil end
end
wire(exit.Activated,shutdown)
env.RNG_ROLL_STATE_SCAN_CLOSE=shutdown
