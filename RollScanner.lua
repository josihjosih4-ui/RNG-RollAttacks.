-- RNG ROLLATTACKS | ROLL SCANNER v1.0
-- Read-only: monitors player GUI and outgoing remote names/types.
-- Press START, then use the game's actual Roll button.
-- Does not fire, alter, or repeat any game remote.
local P=game:GetService("Players").LocalPlayer
local RS=game:GetService("ReplicatedStorage")
if not P then return end
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.RNG_SCANNER_CLOSE)=="function" then pcall(env.RNG_SCANNER_CLOSE) end
local alive,armed=false,false
local logs,conns,scanConns={}, {}, {}
local hookInstalled=false
local hooksWork=false
local remotes=0
local function wire(signal,fn,bucket)
    local c=signal:Connect(fn)
    table.insert(bucket or conns,c)
end
local function clear(bucket)
    for _,c in ipairs(bucket) do pcall(function()c:Disconnect()end)end
    table.clear(bucket)
end
local function add(parent,kind,props)
    local o=Instance.new(kind)
    for k,v in pairs(props)do o[k]=v end
    o.Parent=parent
    return o
end
local function safeName(o)
    local ok,name=pcall(function()return o:GetFullName()end)
    return ok and name or tostring(o.Name)
end
local function typ(v)
    return typeof and typeof(v) or type(v)
end
local gui=add(P:WaitForChild("PlayerGui"),"ScreenGui",{Name="RNG_Roll_Scanner",ResetOnSpawn=false,IgnoreGuiInset=false})
local box=add(gui,"Frame",{
    Size=UDim2.fromOffset(315,355),Position=UDim2.new(.5,-157,.5,-177),
    BackgroundColor3=Color3.fromRGB(13,11,23),BorderSizePixel=0
})
add(box,"UICorner",{CornerRadius=UDim.new(0,13)})
add(box,"UIStroke",{Color=Color3.fromRGB(151,89,255),Thickness=1})
local heading=add(box,"TextLabel",{
    Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-50,0,26),
    BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left,
    Text="RNG // ROLL SCANNER"
})
local close=add(box,"TextButton",{
    Position=UDim2.new(1,-36,0,10),Size=UDim2.fromOffset(26,26),
    BackgroundColor3=Color3.fromRGB(51,43,71),BorderSizePixel=0,
    Text="X",TextSize=13,TextColor3=Color3.new(1,1,1)
})
local status=add(box,"TextLabel",{
    Position=UDim2.fromOffset(12,39),Size=UDim2.new(1,-24,0,36),
    BackgroundTransparency=1,Text="Press START then tap the real Roll button.",
    Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true,
    TextColor3=Color3.fromRGB(209,196,238),
    TextXAlignment=Enum.TextXAlignment.Left
})
local start=add(box,"TextButton",{
    Position=UDim2.fromOffset(12,81),Size=UDim2.fromOffset(140,35),
    BackgroundColor3=Color3.fromRGB(151,89,255),BorderSizePixel=0,
    Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),Text="START SCAN"
})
local copy=add(box,"TextButton",{
    Position=UDim2.fromOffset(162,81),Size=UDim2.fromOffset(140,35),
    BackgroundColor3=Color3.fromRGB(73,52,98),BorderSizePixel=0,
    Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),Text="COPY REPORT"
})
local report=add(box,"TextBox",{
    Position=UDim2.fromOffset(12,126),Size=UDim2.new(1,-24,1,-138),
    BackgroundColor3=Color3.fromRGB(31,25,46),BorderSizePixel=0,
    Text="Start scan and press the ORIGINAL Roll button.",
    TextColor3=Color3.new(1,1,1),Font=Enum.Font.Code,TextSize=10,
    TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    ClearTextOnFocus=false,MultiLine=true,TextEditable=false
})
local function note(t)
    if not alive or #logs>=100 then return end
    logs[#logs+1]=string.format("%.1fs %s",os.clock()%100000,tostring(t):sub(1,200))
    report.Text=table.concat(logs,"\n")
end
local function hook()
    if hookInstalled then return end
    hookInstalled=true
    if type(hookmetamethod)~="function" or type(getnamecallmethod)~="function" then
        note("REMOTE HOOK UNAVAILABLE; GUI scan still works")
        return
    end
    local original
    local function observe(self,...)
        if alive and armed and typ(self)=="Instance" then
            local method=getnamecallmethod()
            if (method=="FireServer" or method=="InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                if remotes<40 then
                    remotes=remotes+1
                    local kinds={}
                    local n=select("#",...)
                    for i=1,math.min(n,5)do
                        kinds[i]=typ(select(i,...))
                    end
                    note("REMOTE "..method.." "..safeName(self).." args="..table.concat(kinds,","))
                end
            end
        end
        return original(self,...)
    end
    local wrapped=type(newcclosure)=="function" and newcclosure(observe) or observe
    local ok,old=pcall(function() return hookmetamethod(game,"__namecall",wrapped) end)
    if ok and type(old)=="function" then
        original=old
        hooksWork=true
        note("REMOTE OBSERVATION ENABLED (names/types only)")
    else
        note("REMOTE OBSERVATION BLOCKED; GUI scan still works")
    end
end
local function startScan()
    if not alive or armed then return end
    table.clear(logs)
    clear(scanConns)
    remotes=0
    armed=true
    start.Text="SCANNING..."
    status.Text="Now press the game's real Roll button 2-3 times."
    note("PlaceId "..tostring(game.PlaceId).." | no requests sent by scanner")
    local candidates=0
    for _,r in ipairs(RS:GetDescendants())do
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
            local name=r.Name:lower()
            if name:find("roll",1,true) or name:find("attack",1,true) or name:find("spin",1,true) then
                if candidates<12 then note("CANDIDATE "..safeName(r).." ["..r.ClassName.."]")end
                candidates=candidates+1
            end
        end
    end
    note("Candidate remotes: "..tostring(candidates))
    for _,b in ipairs(P.PlayerGui:GetDescendants())do
        if b:IsA("GuiButton") and not b:IsDescendantOf(gui) then
            wire(b.Activated,function()
                if not armed then return end
                local t=b:IsA("TextButton") and b.Text or ""
                note("BUTTON "..safeName(b).." text="..tostring(t):sub(1,35))
            end,scanConns)
        end
    end
    local previous={}
    local token=os.clock()
    hook()
    task.spawn(function()
        while alive and armed and os.clock()-token<15 do
            for _,o in ipairs(P.PlayerGui:GetDescendants())do
                if (o:IsA("TextLabel") or o:IsA("TextButton")) and not o:IsDescendantOf(gui) then
                    local n=o.Name:lower()
                    local t=o.Text:lower()
                    if n:find("roll",1,true) or n:find("cooldown",1,true)
                      or t:find("roll",1,true) or t:find("cooldown",1,true) then
                        local key=safeName(o)
                        local now=o.Text.." active="..tostring(o:IsA("GuiButton") and o.Active)
                        if previous[key] and previous[key]~=now then
                            note("UI CHANGED "..key:sub(1,65).." -> "..now:sub(1,75))
                        end
                        previous[key]=now
                    end
                end
            end
            task.wait(.3)
        end
        if not alive then return end
        armed=false
        clear(scanConns)
        start.Text="SCAN AGAIN"
        note("END: "..tostring(remotes).." outgoing remote calls observed")
        if not hooksWork then note("Observer unavailable: no remote capture possible")end
        status.Text="Scan finished. Tap COPY REPORT, then paste it here."
    end)
end
alive=true
wire(start.Activated,startScan)
wire(copy.Activated,function()
    local s=table.concat(logs,"\n")
    if type(setclipboard)=="function" then
        local ok=pcall(setclipboard,s)
        status.Text=ok and "Copied! Paste the report into ChatGPT." or "Clipboard error. Select the text below."
    else
        report.TextEditable=true
        status.Text="Clipboard unavailable; select report text manually."
    end
end)
local function shutdown()
    if not alive then return end
    alive=false
    armed=false
    clear(scanConns)
    clear(conns)
    pcall(function()gui:Destroy()end)
    if env.RNG_SCANNER_CLOSE==shutdown then env.RNG_SCANNER_CLOSE=nil end
end
wire(close.Activated,shutdown)
env.RNG_SCANNER_CLOSE=shutdown
print("[RollScanner] START SCAN, press original ROLL button, COPY REPORT.")
