--[[
RNG ROLLATTACKS | AUTO ROLL V3 + ANTI VOID
Target place: 119338513416973
Behaviors:
* Automatically invoke the scanner-confirmed RollAttack RemoteFunction at normal readiness.
* No repeated requests while Rolling, while waiting for a response, or before RollReadyAt.
* Stop when the completed roll is Gojo/Sukuna/Sunkuna or displayed rarity >= 1/2000.
* Anti-void saves last grounded CFrame and restores if falling far below it.
* Simple Delta iOS-friendly mobile UI. No metamethod hooks.
This code DOES NOT bypass server cooldowns. Roll results/odds are game-controlled.
]]
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local LP=Players.LocalPlayer
if not LP then return end
local env=_G
if type(getgenv)=="function" then
    local ok,t=pcall(getgenv)
    if ok and type(t)=="table" then env=t end
end
if type(env.RNG_AUTOROLL_V3_CLOSE)=="function" then
    pcall(env.RNG_AUTOROLL_V3_CLOSE)
end
if game.PlaceId~=119338513416973 then
    warn("[RNG Auto Roll V3] This game is not the scanned RNG RollAttacks place.")
    return
end

local alive=true
local auto=true
local antivoid=true
local goalReached=false
local pending=false
local rollStarted=false
local attempts=0
local finished=0
local lastRequest=-1e6
local lastSafe=nil
local lastRescue=-1e6
local statusMessage="Starting..."
local connections={}
local pg=LP:WaitForChild("PlayerGui")

local function connect(signal,callback)
    local c=signal:Connect(callback)
    connections[#connections+1]=c
    return c
end
local function make(kind,parent,props)
    local v=Instance.new(kind)
    for k,value in pairs(props) do v[k]=value end
    v.Parent=parent
    return v
end
local screen=make("ScreenGui",pg,{
    Name="RNG_AutoRoll_V3",ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
local panel=make("Frame",screen,{
    Size=UDim2.fromOffset(300,306),
    Position=UDim2.new(.5,-150,.46,-153),
    BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(17,13,28)
})
make("UICorner",panel,{CornerRadius=UDim.new(0,13)})
make("UIStroke",panel,{Color=Color3.fromRGB(152,87,250),Thickness=1.25})
local head=make("Frame",panel,{
    Size=UDim2.new(1,0,0,55),BorderSizePixel=0,
    BackgroundColor3=Color3.fromRGB(35,25,52)
})
make("UICorner",head,{CornerRadius=UDim.new(0,12)})
make("TextLabel",head,{
    Position=UDim2.fromOffset(13,7),Size=UDim2.new(1,-56,0,22),
    BackgroundTransparency=1,Text="RNG // AUTO ROLL",
    Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left
})
make("TextLabel",head,{
    Position=UDim2.fromOffset(13,30),Size=UDim2.new(1,-56,0,15),
    BackgroundTransparency=1,Text="V3  |  AUTO ROLL + ANTI VOID",
    Font=Enum.Font.Gotham,TextSize=10,
    TextColor3=Color3.fromRGB(182,168,207),TextXAlignment=Enum.TextXAlignment.Left
})
local close=make("TextButton",head,{
    Position=UDim2.new(1,-38,0,12),Size=UDim2.fromOffset(26,27),
    BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(65,47,87),
    Text="X",Font=Enum.Font.GothamBold,TextSize=13,
    TextColor3=Color3.new(1,1,1)
})
local accent=make("Frame",panel,{
    Position=UDim2.fromOffset(11,56),Size=UDim2.new(1,-22,0,2),
    BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(157,92,249)
})
make("UIGradient",accent,{Color=ColorSequence.new(
    Color3.fromRGB(155,84,245),Color3.fromRGB(255,66,125))})
local goal=make("TextLabel",panel,{
    Position=UDim2.fromOffset(12,67),Size=UDim2.new(1,-24,0,38),
    BackgroundTransparency=1,
    Text="STOP AT: Gojo / Sukuna / 1 in 2,000+",
    TextWrapped=true,Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=Color3.fromRGB(255,200,106),
    TextXAlignment=Enum.TextXAlignment.Left
})
local autoButton=make("TextButton",panel,{
    Position=UDim2.fromOffset(12,112),Size=UDim2.new(1,-24,0,42),
    BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(53,35,80),
    Text="",Font=Enum.Font.GothamBold,TextSize=13,
    TextColor3=Color3.new(1,1,1)
})
make("UICorner",autoButton,{CornerRadius=UDim.new(0,9)})
local voidButton=make("TextButton",panel,{
    Position=UDim2.fromOffset(12,164),Size=UDim2.new(1,-24,0,42),
    BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(53,35,80),
    Text="",Font=Enum.Font.GothamBold,TextSize=13,
    TextColor3=Color3.new(1,1,1)
})
make("UICorner",voidButton,{CornerRadius=UDim.new(0,9)})
local status=make("TextLabel",panel,{
    Position=UDim2.fromOffset(13,218),Size=UDim2.new(1,-26,0,44),
    BackgroundTransparency=1,TextWrapped=true,Text="",
    Font=Enum.Font.Gotham,TextSize=11,
    TextColor3=Color3.fromRGB(205,193,224),
    TextXAlignment=Enum.TextXAlignment.Left
})
local footer=make("TextLabel",panel,{
    Position=UDim2.fromOffset(13,269),Size=UDim2.new(1,-26,0,27),
    BackgroundTransparency=1,Text="Rolls: 0  |  No cooldown bypass",
    Font=Enum.Font.Gotham,TextSize=10,
    TextColor3=Color3.fromRGB(168,149,190),
    TextXAlignment=Enum.TextXAlignment.Left
})

local function refreshButtons()
    autoButton.Text="AUTO ROLL   "..(goalReached and "[GOAL FOUND]" or (auto and "[ON]" or "[OFF]"))
    voidButton.Text="ANTI VOID   "..(antivoid and "[ON]" or "[OFF]")
    autoButton.BackgroundColor3=auto and Color3.fromRGB(104,50,153) or Color3.fromRGB(53,35,80)
    voidButton.BackgroundColor3=antivoid and Color3.fromRGB(104,50,153) or Color3.fromRGB(53,35,80)
end
local function notify(s)
    statusMessage=s
    if alive then status.Text=s end
end
local function currentSeconds()
    return DateTime.now().UnixTimestampMillis/1000
end
local function getRollButton()
    local main=pg:FindFirstChild("MainUI")
    return main and main:FindFirstChild("RollButton")
end
local function resultLabel()
    local button=getRollButton()
    local label=button and button:FindFirstChild("Label")
    return (label and label:IsA("TextLabel")) and label.Text or ""
end
local function cooldownText()
    local main=pg:FindFirstChild("MainUI")
    local label=main and main:FindFirstChild("RollCooldown")
    return label and label:IsA("TextLabel") and label.Text or ""
end
local function parseOdds(s)
    if type(s)~="string" then return nil end
    local n,suffix=s:match("1%s*/%s*([%d%,%.]+)%s*([kKmM]?)")
    if not n then
        n,suffix=s:lower():match("1%s+in%s+([%d%,%.]+)%s*([km]?)")
    end
    if not n then return nil end
    local value=tonumber((n:gsub(",","")))
    if not value then return nil end
    if suffix=="k" or suffix=="K" then value=value*1000 end
    if suffix=="m" or suffix=="M" then value=value*1000000 end
    return value
end
local function isGoal(attack,label)
    attack=tostring(attack or "")
    label=tostring(label or "")
    local a=attack:lower()
    local l=label:lower()
    for _,needle in ipairs({"gojo","sukuna","sunkuna"}) do
        if a:find(needle,1,true) or l:find(needle,1,true) then
            return true,needle
        end
    end
    local odds=parseOdds(label)
    if odds and odds>=2000 then
        return true,"1/"..tostring(math.floor(odds))
    end
    return false,nil
end
local function recordResult()
    if not alive then return end
    if LP:GetAttribute("Rolling")==true then return end
    local attack=LP:GetAttribute("EquippedAttack")
    local label=resultLabel()
    finished=finished+1
    footer.Text="Rolls observed: "..finished.." | Last: "..tostring(attack or "?")
    local good,reason=isGoal(attack,label)
    if good then
        goalReached=true
        auto=false
        refreshButtons()
        notify("GOAL HIT! "..tostring(attack or label).." ("..tostring(reason).."). Auto Roll stopped.")
        print("[RNG Auto Roll V3] GOAL HIT",attack,label,reason)
    elseif auto then
        notify("Got "..tostring(attack or label)..". Waiting for next allowed roll.")
    end
end
local function bindCharacter(character)
    lastSafe=nil
    local hum=character:WaitForChild("Humanoid",10)
    local root=character:WaitForChild("HumanoidRootPart",10)
    if not hum or not root then return end
    -- Low-cost check: one character, every 0.25s. No world descendant scans.
    task.spawn(function()
        while alive and character==LP.Character and hum.Parent and root.Parent do
            if antivoid and hum.Health>0 then
                if hum.FloorMaterial~=Enum.Material.Air
                    and root.AssemblyLinearVelocity.Y>-6 then
                    lastSafe=root.CFrame
                end
                if lastSafe and os.clock()-lastRescue>2 then
                    local threshold=math.max(workspace.FallenPartsDestroyHeight+55,
                                             lastSafe.Position.Y-65)
                    if root.Position.Y<threshold and root.AssemblyLinearVelocity.Y<0 then
                        lastRescue=os.clock()
                        local back=lastSafe*CFrame.new(0,4,0)
                        local ok=pcall(function()
                            root.CFrame=back
                            root.AssemblyLinearVelocity=Vector3.zero
                            root.AssemblyAngularVelocity=Vector3.zero
                        end)
                        if ok then notify("Anti-Void: returned to last safe platform") end
                    end
                end
            end
            task.wait(.25)
        end
    end)
end
local function aliveCharacter()
    local ch=LP.Character
    local hum=ch and ch:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health>0
end
local function mayRoll()
    if not alive or not auto or goalReached or pending then return false end
    if LP:GetAttribute("Rolling")==true or not aliveCharacter() then return false end
    local cd=LP:GetAttribute("RollCooldownLen")
    if typeof(cd)~="number" or cd<1 then cd=8 end
    local timeElapsed=os.clock()-lastRequest
    -- The game recorded RollCooldownLen=8 in the scanner. Never spam the server.
    if timeElapsed<math.max(1,cd-.05) then return false end
    local readyAt=LP:GetAttribute("RollReadyAt")
    local shown=cooldownText():lower()
    if typeof(readyAt)=="number" and readyAt>currentSeconds()+.05 then return false end
    if shown:find("next roll",1,true)
        or shown:find("dead",1,true)
        or shown:find("jump down",1,true) then return false end
    if typeof(readyAt)~="number" and not shown:find("ready",1,true) then
        return false
    end
    return true
end
local function attemptRoll()
    if not mayRoll() then return end
    local folder=ReplicatedStorage:FindFirstChild("Remotes")
    local remote=folder and folder:FindFirstChild("RollAttack")
    if not remote or not remote:IsA("RemoteFunction") then
        notify("Waiting for RollAttack remote to load...")
        return
    end
    pending=true
    attempts=attempts+1
    lastRequest=os.clock()
    local n=attempts
    notify("Auto Roll: requesting roll #"..n)
    task.spawn(function()
        local ok,response=pcall(function()return remote:InvokeServer()end)
        pending=false
        if not alive or not auto then return end
        if not ok then
            notify("Request error; retry after normal cooldown.")
        elseif response==false then
            notify("Server declined roll; waiting for normal cooldown.")
        elseif LP:GetAttribute("Rolling")~=true then
            -- Attribute may arrive after the response; wait for game to update.
            task.delay(1.5,function()
                if alive and auto and LP:GetAttribute("Rolling")~=true then
                    notify("Request completed; waiting for next allowed roll.")
                end
            end)
        end
    end)
end

connect(autoButton.Activated,function()
    if goalReached then
        notify("Target obtained! Re-execute to begin a new run.")
        return
    end
    auto=not auto
    refreshButtons()
    notify(auto and "Auto Roll ON - waiting until ready" or "Auto Roll paused")
end)
connect(voidButton.Activated,function()
    antivoid=not antivoid
    refreshButtons()
    notify(antivoid and "Anti-Void enabled" or "Anti-Void disabled")
end)
connect(LP:GetAttributeChangedSignal("Rolling"),function()
    local value=LP:GetAttribute("Rolling")
    if value==true then
        rollStarted=true
        if auto then notify("Rolling... waiting for attack result") end
    elseif value==false and rollStarted then
        rollStarted=false
        task.delay(.45,recordResult)
    end
end)
connect(LP:GetAttributeChangedSignal("EquippedAttack"),function()
    if LP:GetAttribute("Rolling")~=true then
        local isRare=isGoal(LP:GetAttribute("EquippedAttack"),resultLabel())
        if isRare then
            task.delay(.15,function()
                if alive and not goalReached then
                    local ok=isGoal(LP:GetAttribute("EquippedAttack"),resultLabel())
                    if ok then
                        goalReached=true
                        auto=false
                        refreshButtons()
                        notify("Rare attack equipped! Auto Roll stopped.")
                    end
                end
            end)
        end
    end
end)
connect(LP.CharacterAdded,bindCharacter)
if LP.Character then bindCharacter(LP.Character) end
refreshButtons()
local existingGoal,existingName=isGoal(LP:GetAttribute("EquippedAttack"),resultLabel())
if existingGoal then
    goalReached=true
    auto=false
    refreshButtons()
    notify("Already holding "..tostring(existingName)..". Auto Roll stopped.")
else
    notify("Auto Roll ON - waiting for the game's ready state")
end
task.spawn(function()
    while alive do
        if auto then attemptRoll() end
        task.wait(.35)
    end
end)
local dragging=false
local dragPointer=nil
local dragFrom=nil
local originalPos=nil
connect(head.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragPointer=input
        dragFrom=input.Position
        originalPos=panel.Position
        local link
        link=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if link then link:Disconnect() end
            end
        end)
    end
end)
connect(UIS.InputChanged,function(input)
    if not dragging or not dragFrom or not originalPos then return end
    if input~=dragPointer and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-dragFrom
    panel.Position=UDim2.new(originalPos.X.Scale,originalPos.X.Offset+delta.X,
        originalPos.Y.Scale,originalPos.Y.Offset+delta.Y)
end)
local function shutdown()
    if not alive then return end
    alive=false
    auto=false
    antivoid=false
    for _,connection in ipairs(connections) do
        pcall(function()connection:Disconnect()end)
    end
    pcall(function()screen:Destroy()end)
    if env.RNG_AUTOROLL_V3_CLOSE==shutdown then
        env.RNG_AUTOROLL_V3_CLOSE=nil
    end
end
connect(close.Activated,shutdown)
env.RNG_AUTOROLL_V3_CLOSE=shutdown
print("[RNG Auto Roll V3] Started. Respecting RollReadyAt, stopping at 1/2000 or Gojo/Sukuna.")
