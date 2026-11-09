-- RNG ROLLATTACKS | LOCAL ROLL COOLDOWN PROBE V1
-- Targeted test based on observed attributes RollReadyAt, Rolling, EquippedAttack.
-- NEVER fires/removes/hooks a RemoteFunction. Changes only local RollReadyAt,
-- and only after Rolling is false. Does not change RollCooldownLen.
local Players=game:GetService("Players")
local p=Players.LocalPlayer
if not p then return end
local env=_G
if type(getgenv)=="function" then
    local ok,e=pcall(getgenv)
    if ok and type(e)=="table" then env=e end
end
if type(env.RNG_ROLL_CD_PROBE_CLOSE)=="function" then
    pcall(env.RNG_ROLL_CD_PROBE_CLOSE)
end
local alive=true
local wires={}
local log={}
local saved=nil
local trackedCount=0
local function conn(signal,fn)
    local c=signal:Connect(fn)
    wires[#wires+1]=c
end
local function make(k,parent,props)
    local v=Instance.new(k)
    for name,value in pairs(props)do v[name]=value end
    v.Parent=parent
    return v
end
local gui=make("ScreenGui",p:WaitForChild("PlayerGui"),{
    Name="RNG_CooldownProbe",ResetOnSpawn=false
})
local panel=make("Frame",gui,{
    Size=UDim2.fromOffset(316,351),
    Position=UDim2.new(.5,-158,.48,-175),
    BackgroundColor3=Color3.fromRGB(17,12,28),BorderSizePixel=0
})
make("UICorner",panel,{CornerRadius=UDim.new(0,12)})
make("UIStroke",panel,{Color=Color3.fromRGB(150,88,250),Thickness=1})
local title=make("TextLabel",panel,{
    Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-55,0,24),
    BackgroundTransparency=1,Text="RNG // ROLL COOLDOWN PROBE",
    Font=Enum.Font.GothamBold,TextSize=14,
    TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left
})
local x=make("TextButton",panel,{
    Position=UDim2.new(1,-37,0,9),Size=UDim2.fromOffset(27,27),
    BackgroundColor3=Color3.fromRGB(62,43,84),BorderSizePixel=0,
    Text="X",Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=Color3.new(1,1,1)
})
local help=make("TextLabel",panel,{
    Position=UDim2.fromOffset(10,38),Size=UDim2.new(1,-20,0,44),
    BackgroundTransparency=1,TextWrapped=true,
    Text="Roll normally, wait until Rolling=false, tap CLEAR LOCAL TIMER, then use the game's ORIGINAL Roll button.",
    Font=Enum.Font.Gotham,TextSize=11,
    TextColor3=Color3.fromRGB(199,187,227),
    TextXAlignment=Enum.TextXAlignment.Left
})
local clear=make("TextButton",panel,{
    Position=UDim2.fromOffset(10,89),Size=UDim2.fromOffset(192,42),
    BackgroundColor3=Color3.fromRGB(150,88,250),BorderSizePixel=0,
    Text="CLEAR LOCAL TIMER",Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=Color3.new(1,1,1)
})
local restore=make("TextButton",panel,{
    Position=UDim2.fromOffset(211,89),Size=UDim2.fromOffset(95,42),
    BackgroundColor3=Color3.fromRGB(72,52,101),BorderSizePixel=0,
    Text="RESTORE",Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=Color3.new(1,1,1)
})
local status=make("TextLabel",panel,{
    Position=UDim2.fromOffset(10,138),Size=UDim2.new(1,-20,0,32),
    BackgroundTransparency=1,Text="Ready. No changes have been made.",
    TextColor3=Color3.fromRGB(92,232,166),
    TextWrapped=true,Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,TextSize=11
})
local report=make("TextBox",panel,{
    Position=UDim2.fromOffset(10,177),Size=UDim2.new(1,-20,1,-235),
    BackgroundColor3=Color3.fromRGB(29,23,42),BorderSizePixel=0,
    ClearTextOnFocus=false,Text="",
    TextColor3=Color3.new(1,1,1),
    Font=Enum.Font.Code,TextSize=10,
    TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    MultiLine=true,TextEditable=false
})
local copy=make("TextButton",panel,{
    Position=UDim2.new(0,10,1,-51),Size=UDim2.new(1,-20,0,41),
    BackgroundColor3=Color3.fromRGB(74,51,108),BorderSizePixel=0,
    Text="COPY TEST REPORT",Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=Color3.new(1,1,1)
})
local startClock=os.clock()
local function add(message)
    if not alive or #log>=50 then return end
    log[#log+1]=string.format("+%.1fs %s",os.clock()-startClock,tostring(message):sub(1,180))
    report.Text=table.concat(log,"\n")
end
local function cooldownText()
    local ui=p.PlayerGui:FindFirstChild("MainUI")
    local label=ui and ui:FindFirstChild("RollCooldown")
    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        return tostring(label.Text)
    end
    return "(not found)"
end
local function snapshot()
    return "Rolling="..tostring(p:GetAttribute("Rolling"))
        .." ReadyAt="..tostring(p:GetAttribute("RollReadyAt"))
        .." Len="..tostring(p:GetAttribute("RollCooldownLen"))
        .." Attack="..tostring(p:GetAttribute("EquippedAttack"))
        .." UI="..cooldownText()
end
local function getOriginalRollButton()
    local ui=p.PlayerGui:FindFirstChild("MainUI")
    local b=ui and ui:FindFirstChild("RollButton")
    return (b and b:IsA("GuiButton")) and b or nil
end
local function clearTimer()
    if not alive then return end
    if p:GetAttribute("Rolling")==true then
        status.Text="Roll is still running. Wait until it finishes first."
        add("BLOCKED: Rolling is true; no attributes changed")
        return
    end
    local now=p:GetAttribute("RollReadyAt")
    if typeof(now)~="number" then
        status.Text="RollReadyAt not detected. Roll once normally first."
        add("BLOCKED: RollReadyAt is not numeric")
        return
    end
    saved=now
    add("BEFORE "..snapshot())
    local ok,err=pcall(function()p:SetAttribute("RollReadyAt",0)end)
    if not ok then
        status.Text="Could not change local timer."
        add("ERROR "..tostring(err))
        return
    end
    status.Text="Local ReadyAt cleared. Tap the game's original Roll button NOW."
    add("CLEARED local RollReadyAt to 0; server values not changed")
    task.delay(.5,function()
        if alive then add("AFTER .5s "..snapshot()) end
    end)
end
local function restoreTimer()
    if not alive then return end
    if saved==nil then
        status.Text="Nothing to restore."
        return
    end
    if p:GetAttribute("Rolling")==true then
        add("RESTORE skipped: game currently rolling")
        status.Text="Wait until the roll finishes to restore."
        return
    end
    -- Don't overwrite a new value that arrived after our local edit.
    if p:GetAttribute("RollReadyAt")~=0 then
        add("RESTORE skipped: game has already updated ReadyAt")
        status.Text="Game already refreshed timer; no restore needed."
        saved=nil
        return
    end
    local restoreValue=saved
    saved=nil
    local ok=pcall(function()p:SetAttribute("RollReadyAt",restoreValue)end)
    if ok then
        add("RESTORED local ReadyAt="..tostring(restoreValue))
        status.Text="Local timer restored."
    else
        status.Text="Restore failed; rejoining resets local changes."
    end
end
conn(clear.Activated,clearTimer)
conn(restore.Activated,restoreTimer)
conn(copy.Activated,function()
    local s=table.concat(log,"\n")
    if type(setclipboard)=="function" and pcall(setclipboard,s) then
        status.Text="Report copied. Paste it into ChatGPT."
    else
        report.TextEditable=true
        status.Text="Clipboard unavailable; select the text manually."
    end
end)
conn(p:GetAttributeChangedSignal("Rolling"),function()
    add("Rolling -> "..tostring(p:GetAttribute("Rolling")))
    if p:GetAttribute("Rolling")==false then
        task.delay(.3,function()if alive then add("ROLL COMPLETE "..snapshot())end end)
    end
end)
conn(p:GetAttributeChangedSignal("EquippedAttack"),function()
    add("EquippedAttack -> "..tostring(p:GetAttribute("EquippedAttack")))
end)
conn(p:GetAttributeChangedSignal("RollReadyAt"),function()
    if trackedCount<12 then
        trackedCount=trackedCount+1
        add("RollReadyAt changed -> "..tostring(p:GetAttribute("RollReadyAt")))
    end
end)
local button=getOriginalRollButton()
if button then
    conn(button.Activated,function()
        add("ORIGINAL BUTTON tap "..snapshot())
        task.delay(3.3,function()
            if alive then add("3.3s AFTER TAP "..snapshot()) end
        end)
    end)
else
    add("Original Roll button not found: start test after game UI loads")
end
local function shutdown()
    if not alive then return end
    alive=false
    for _,c in ipairs(wires) do pcall(function()c:Disconnect()end) end
    pcall(function()gui:Destroy()end)
    if env.RNG_ROLL_CD_PROBE_CLOSE==shutdown then env.RNG_ROLL_CD_PROBE_CLOSE=nil end
end
conn(x.Activated,shutdown)
env.RNG_ROLL_CD_PROBE_CLOSE=shutdown
add("START "..snapshot())
add("Read-only until CLEAR LOCAL TIMER is pressed; no remote hook or remote call")
