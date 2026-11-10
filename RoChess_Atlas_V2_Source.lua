--[[
ROCHESS / ATLAS CHESS V2.0
Local chess search + clean mobile UI + square highlights + guarded Auto Play.
RoChess current PlaceId: 130878180532794 (new listing).
No external AI API; no hooks or blind network calls.
An AUTO-SYNC data source must expose a valid FEN. If not, use LOAD FEN
for local chess advice, and run a board scan to learn about the game's UI.
Auto Play never moves from manually entered FEN; avoids desync.
]]

local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
if not player then return end
local E=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then E=v end
end
if type(E.ROCHESS_ATLAS_CLOSE)=="function" then pcall(E.ROCHESS_ATLAS_CLOSE) end
if game.PlaceId~=130878180532794 then
    warn("[ATLAS] This build targets RoChess place 130878180532794.")
end

local active=true
local auto=false
local esp=true
local mySide=1
local oriented=1
local synced=false
local dataGetter=nil
local sourceName="Not connected"
local s=nil
local currentFen=""
local analysisVersion=0
local lastSentFen=""
local suggestion=nil
local calib={}
local lastAnalysis=0
local busy=false
local engineHealthy=true
local engineTier=2
-- Time-boxed search presets for iOS. Depth is an upper limit, not a guarantee.
local engineOptions={
    {name="QUICK",time=.12,depth=3,nodes=4500,q=2},
    {name="STRONG",time=.33,depth=5,nodes=14500,q=4},
    {name="EXPERT",time=.72,depth=6,nodes=30000,q=5}
}
local connections={}
local logs={}
local oppMoves,oppCaptures,oppChecks=0,0,0
local oppLast=""
local boardName=""

local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function hook(signal,fn)
    local c=signal:Connect(fn)
    connections[#connections+1]=c
    return c
end
local C={
    bg=Color3.fromRGB(17,19,24),
    surface=Color3.fromRGB(27,31,39),
    muted=Color3.fromRGB(39,45,56),
    line=Color3.fromRGB(54,60,73),
    text=Color3.fromRGB(242,244,248),
    sub=Color3.fromRGB(154,163,180),
    accent=Color3.fromRGB(139,92,246),
    success=Color3.fromRGB(100,211,168),
    warn=Color3.fromRGB(239,178,103),
}
local pg=player:WaitForChild("PlayerGui")
local gui=make("ScreenGui",pg,{Name="Atlas_RoChess_LocalAI",ResetOnSpawn=false,DisplayOrder=120,IgnoreGuiInset=false})
local overlay=make("ScreenGui",pg,{Name="Atlas_RoChess_ESP",ResetOnSpawn=false,DisplayOrder=110,IgnoreGuiInset=true})
local window=make("Frame",gui,{
    Name="Window",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.46),
    Size=UDim2.fromOffset(334,443),BackgroundColor3=C.bg,BorderSizePixel=0
})
make("UICorner",window,{CornerRadius=UDim.new(0,14)})
make("UIStroke",window,{Color=C.line,Thickness=1})
local scale=make("UIScale",window,{Scale=1})
local function fit()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local size=camera.ViewportSize
    scale.Scale=math.min(1,(size.X-22)/334,(size.Y-86)/443)
end
fit()
if workspace.CurrentCamera then hook(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end

local header=make("Frame",window,{Size=UDim2.new(1,0,0,62),BackgroundColor3=C.surface,BorderSizePixel=0})
make("UICorner",header,{CornerRadius=UDim.new(0,14)})
make("TextLabel",header,{
    BackgroundTransparency=1,Position=UDim2.fromOffset(16,10),Size=UDim2.new(1,-80,0,24),
    Text="ATLAS",Font=Enum.Font.GothamBold,TextSize=19,TextColor3=C.text,
    TextXAlignment=Enum.TextXAlignment.Left
})
make("TextLabel",header,{
    BackgroundTransparency=1,Position=UDim2.fromOffset(16,34),Size=UDim2.new(1,-80,0,15),
    Text="ROCHESS / ATLAS ENGINE V2",Font=Enum.Font.GothamMedium,TextSize=10,
    TextColor3=C.sub,TextXAlignment=Enum.TextXAlignment.Left
})
local close=make("TextButton",header,{
    Position=UDim2.new(1,-40,0,16),Size=UDim2.fromOffset(27,27),
    Text="X",Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=C.text,BackgroundColor3=C.muted,BorderSizePixel=0
})
make("UICorner",close,{CornerRadius=UDim.new(0,7)})
local collapse=make("TextButton",header,{
    Position=UDim2.new(1,-72,0,16),Size=UDim2.fromOffset(27,27),
    Text="-",Font=Enum.Font.GothamBold,TextSize=16,
    TextColor3=C.text,BackgroundColor3=C.muted,BorderSizePixel=0
})
make("UICorner",collapse,{CornerRadius=UDim.new(0,7)})
local body=make("Frame",window,{
    Position=UDim2.fromOffset(0,63),Size=UDim2.new(1,0,1,-63),
    BackgroundTransparency=1
})
local tabs=make("Frame",body,{
    Position=UDim2.fromOffset(13,6),Size=UDim2.new(1,-26,0,38),
    BackgroundColor3=C.surface,BorderSizePixel=0
})
make("UICorner",tabs,{CornerRadius=UDim.new(0,9)})
local page=make("Frame",body,{
    Position=UDim2.fromOffset(13,51),Size=UDim2.new(1,-26,1,-58),
    BackgroundTransparency=1
})
local pages,tabButtons={},{}
local function text(parent,value,y,h,size,bold,color)
    return make("TextLabel",parent,{
        Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,h),
        BackgroundTransparency=1,Text=value,TextWrapped=true,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextColor3=color or C.sub,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center
    })
end
local function button(parent,title,y,width,x)
    local b=make("TextButton",parent,{
        Position=UDim2.new(0,x or 0,0,y),Size=UDim2.new(width or 1,0,0,38),
        BackgroundColor3=C.surface,BorderSizePixel=0,
        Text=title,TextColor3=C.text,Font=Enum.Font.GothamSemibold,TextSize=12,
        AutoButtonColor=true
    })
    make("UICorner",b,{CornerRadius=UDim.new(0,9)})
    return b
end
local function showPage(which)
    for id,fr in pairs(pages) do fr.Visible=id==which end
    for id,b in pairs(tabButtons) do
        b.BackgroundColor3=id==which and C.muted or C.surface
        b.TextColor3=id==which and C.text or C.sub
    end
end
for i,id in ipairs({"ASSIST","SETUP","DEBUG"}) do
    local b=make("TextButton",tabs,{
        Position=UDim2.new((i-1)/3,2,0,3),Size=UDim2.new(1/3,-4,1,-6),
        BorderSizePixel=0,Text=id,Font=Enum.Font.GothamBold,TextSize=11,
        TextColor3=C.sub,BackgroundColor3=C.surface
    })
    make("UICorner",b,{CornerRadius=UDim.new(0,7)})
    tabButtons[id]=b
    local p=make("Frame",page,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
    pages[id]=p
    hook(b.Activated,function()showPage(id)end)
end

local assist=pages.ASSIST
local modeLabel=text(assist,"SOURCE  /  WAITING FOR BOARD",0,23,10,true,C.sub)
local bestLabel=text(assist,"No position loaded",28,54,20,true,C.text)
local engineLabel=text(assist,"Local search  •  no cloud engine",82,20,11,false,C.sub)
local hintButton=button(assist,"FIND BEST MOVE",114,1,0)
hintButton.BackgroundColor3=C.accent
local espButton=button(assist,"BOARD ESP  [ON]",163,1,0)
local autoButton=button(assist,"AUTO PLAY  [OFF]",209,1,0)
local sideButton=button(assist,"SIDE  WHITE",255,.49,0)
local strengthButton=button(assist,"AI  STRONG",255,.49,157)
local statsLabel=text(assist,"Opponent profile: observing moves",297,28,11,false,C.sub)

local setup=pages.SETUP
text(setup,"BOARD CONNECTION",0,22,11,true,C.text)
local scanButton=button(setup,"SCAN GAME BOARD",29,1,0)
local syncLabel=text(setup,"No live board detected yet.",75,39,11,false,C.sub)
local calibrate=button(setup,"CALIBRATE ESP  (a8 > h1)",124,1,0)
local orient=button(setup,"BOARD ORIENTATION  WHITE",168,1,0)
text(setup,"MANUAL POSITION  /  FEN",213,20,11,true,C.text)
local fenBox=make("TextBox",setup,{
    Position=UDim2.fromOffset(0,239),Size=UDim2.new(1,0,0,42),
    BackgroundColor3=C.surface,BorderSizePixel=0,TextColor3=C.text,
    PlaceholderColor3=C.sub,PlaceholderText="Paste FEN for local hints",
    Text="",TextSize=11,Font=Enum.Font.Code,
    ClearTextOnFocus=false,TextWrapped=true
})
make("UICorner",fenBox,{CornerRadius=UDim.new(0,8)})
local fenButton=button(setup,"LOAD FEN  (HINTS ONLY)",288,1,0)

local debug=pages.DEBUG
text(debug,"CONNECTION & MATCH LOG",0,23,11,true,C.text)
local debugText=make("TextBox",debug,{
    Position=UDim2.fromOffset(0,27),Size=UDim2.new(1,0,0,240),
    BackgroundColor3=C.surface,BorderSizePixel=0,
    Text="",Font=Enum.Font.Code,TextSize=11,TextColor3=C.sub,
    TextWrapped=true,TextEditable=false,MultiLine=true,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    ClearTextOnFocus=false
})
make("UICorner",debugText,{CornerRadius=UDim.new(0,8)})
local copyLog=button(debug,"COPY DIAGNOSTIC",276,1,0)

local function log(message)
    if not active then return end
    if #logs>=34 then table.remove(logs,1) end
    logs[#logs+1]=tostring(message):sub(1,165)
    debugText.Text=table.concat(logs,"\n")
end
local function status(value)
    if not active then return end
    engineLabel.Text=value
end
local function paint()
    autoButton.Text="AUTO PLAY  ["..(auto and "ON" or "OFF").."]"
    espButton.Text="BOARD ESP  ["..(esp and "ON" or "OFF").."]"
    sideButton.Text="SIDE  "..(mySide==1 and "WHITE" or "BLACK")
    strengthButton.Text="AI  "..engineOptions[engineTier].name
    orient.Text="BOARD ORIENTATION  "..(oriented==1 and "WHITE" or "BLACK")
    calibrate.Text="CALIBRATE ESP  "..(#calib==2 and "[READY]" or "(a8 > h1)")
end

-- Chess engine: 8x8 with a8=1, h1=64; full king safety,
-- castling, en passant, and four promotion choices.
local files="abcdefgh"
local pieceValue={p=100,n=320,b=330,r=500,q=900,k=20000}
local function color(p)
    if not p or p=="." then return 0 end
    return p:upper()==p and 1 or -1
end
local function rank(i) return 9-math.ceil(i/8) end
local function file(i) return ((i-1)%8)+1 end
local function square(i) return files:sub(file(i),file(i))..rank(i) end
local function clone(t)
    local c={}
    for i=1,64 do c[i]=t[i] end
    return c
end
local function parseFen(raw)
    if type(raw)~="string" then return nil end
    local parts={}
    for word in raw:gmatch("%S+") do parts[#parts+1]=word end
    if #parts<4 or (parts[2]~="w" and parts[2]~="b") then return nil end
    local bd={}
    local k=0
    for row in parts[1]:gmatch("[^/]+") do
        local count=0
        for j=1,#row do
            local p=row:sub(j,j)
            if p:match("^[1-8]$") then
                for _=1,tonumber(p) do bd[#bd+1]=".";count=count+1 end
            elseif p:match("^[prnbqkPRNBQK]$") then
                bd[#bd+1]=p;count=count+1
            else return nil end
        end
        if count~=8 then return nil end
        k=k+1
    end
    if k~=8 or #bd~=64 then return nil end
    local wk,bk=0,0
    for _,p in ipairs(bd) do
        if p=="K" then wk=wk+1 elseif p=="k" then bk=bk+1 end
    end
    if wk~=1 or bk~=1 then return nil end
    local cast=parts[3]
    if not cast:match("^[KQkq]+$") and cast~="-" then return nil end
    local ep=parts[4]
    if ep~="-" and not ep:match("^[a-h][36]$") then return nil end
    return {b=bd,turn=parts[2]=="w" and 1 or -1,castle=cast,ep=ep,
        half=tonumber(parts[5]) or 0,full=tonumber(parts[6]) or 1}
end
local function fen(s0)
    local ranks={}
    for r=1,8 do
        local row,empty="",0
        for f=1,8 do
            local p=s0.b[(r-1)*8+f]
            if p=="." then empty=empty+1 else
                if empty>0 then row=row..empty;empty=0 end
                row=row..p
            end
        end
        if empty>0 then row=row..empty end
        ranks[#ranks+1]=row
    end
    return table.concat(ranks,"/").." "..(s0.turn==1 and "w" or "b")..
        " "..(s0.castle=="" and "-" or s0.castle).." "..s0.ep.." "..s0.half.." "..s0.full
end
local function at(f,r)
    if f<1 or f>8 or r<1 or r>8 then return nil end
    return (8-r)*8+f
end
local knight={{1,2},{1,-2},{-1,2},{-1,-2},{2,1},{2,-1},{-2,1},{-2,-1}}
local bishop={{1,1},{1,-1},{-1,1},{-1,-1}}
local rook={{1,0},{-1,0},{0,1},{0,-1}}
local king={{1,1},{1,-1},{-1,1},{-1,-1},{1,0},{-1,0},{0,1},{0,-1}}
local function attacked(s0,dest,by)
    local df,dr=file(dest),rank(dest)
    for i=1,64 do
        local piece=s0.b[i]
        if color(piece)==by then
            local p=piece:lower()
            local f,r=file(i),rank(i)
            if p=="p" then
                if dr==r+by and math.abs(df-f)==1 then return true end
            elseif p=="n" then
                if (math.abs(df-f)==1 and math.abs(dr-r)==2)
                    or (math.abs(df-f)==2 and math.abs(dr-r)==1) then return true end
            elseif p=="k" then
                if math.max(math.abs(df-f),math.abs(dr-r))==1 then return true end
            else
                local dd=p=="b" and bishop or p=="r" and rook or king
                for _,v in ipairs(dd) do
                    local x,y=f+v[1],r+v[2]
                    while x>=1 and x<=8 and y>=1 and y<=8 do
                        local j=at(x,y)
                        if j==dest then return true end
                        if s0.b[j]~="." then break end
                        x=x+v[1];y=y+v[2]
                    end
                end
            end
        end
    end
    return false
end
local function inCheck(s0,by)
    local k=by==1 and "K" or "k"
    for i=1,64 do
        if s0.b[i]==k then return attacked(s0,i,-by) end
    end
    return true
end
local function apply(s0,m)
    local b=clone(s0.b)
    local piece=b[m.f]
    local taken=b[m.t]
    b[m.f]="."
    b[m.t]=m.promo and (s0.turn==1 and m.promo:upper() or m.promo) or piece
    if m.ep then b[m.t+(s0.turn==1 and 8 or -8)]="." end
    if m.castle then
        local rf,rt
        if file(m.t)>file(m.f) then rf=m.f+3;rt=m.f+1
        else rf=m.f-4;rt=m.f-1 end
        b[rt]=b[rf];b[rf]="."
    end
    local castle=s0.castle
    if piece=="K" then castle=castle:gsub("[KQ]","")
    elseif piece=="k" then castle=castle:gsub("[kq]","") end
    local rs={[64]="K",[57]="Q",[8]="k",[1]="q"}
    if piece:lower()=="r" then
        local flag=rs[m.f]
        if flag then castle=castle:gsub(flag,"") end
    end
    if taken:lower()=="r" then
        local flag=rs[m.t]
        if flag then castle=castle:gsub(flag,"") end
    end
    local ep="-"
    if piece:lower()=="p" and math.abs(m.t-m.f)==16 then
        ep=square(math.floor((m.f+m.t)/2))
    end
    local capture=taken~="." or m.ep
    return {b=b,turn=-s0.turn,castle=castle,ep=ep,
        half=(piece:lower()=="p" or capture) and 0 or s0.half+1,
        full=s0.full+(s0.turn==-1 and 1 or 0)}
end
local function pseudo(s0)
    local out={}
    local b=s0.b
    local t=s0.turn
    local function add(i,j,promo,ep,castle)
        if not j or color(b[j])==t or b[j]:lower()=="k" then return end
        out[#out+1]={f=i,t=j,promo=promo,ep=ep,castle=castle}
    end
    local function push(i,j,ep)
        if j and (rank(j)==1 or rank(j)==8) then
            for _,p in ipairs({"q","r","b","n"}) do add(i,j,p,ep,false) end
        else add(i,j,nil,ep,false) end
    end
    for i=1,64 do
        if color(b[i])==t then
            local p=b[i]:lower()
            local f,r=file(i),rank(i)
            if p=="p" then
                local dir=t==1 and 1 or -1
                local one=at(f,r+dir)
                if one and b[one]=="." then
                    push(i,one)
                    if r==(t==1 and 2 or 7) then
                        local two=at(f,r+dir*2)
                        if two and b[two]=="." then add(i,two) end
                    end
                end
                for _,d in ipairs({-1,1}) do
                    local j=at(f+d,r+dir)
                    if j then
                        if color(b[j])==-t then push(i,j)
                        elseif square(j)==s0.ep and b[j]=="." then
                            local captured=b[j+(t==1 and 8 or -8)]
                            if captured==(t==1 and "p" or "P") then push(i,j,true) end
                        end
                    end
                end
            else
                local dd=p=="n" and knight or p=="b" and bishop
                    or p=="r" and rook or king
                for _,v in ipairs(dd) do
                    local x,y=f+v[1],r+v[2]
                    while x>=1 and x<=8 and y>=1 and y<=8 do
                        local j=at(x,y)
                        if color(b[j])==t then break end
                        add(i,j)
                        if b[j]~="." or p=="n" or p=="k" then break end
                        x=x+v[1];y=y+v[2]
                    end
                end
                if p=="k" and not inCheck(s0,t) then
                    local home=t==1 and 61 or 5
                    local rt=t==1 and "R" or "r"
                    local kFlag=t==1 and "K" or "k"
                    local qFlag=t==1 and "Q" or "q"
                    if i==home then
                        if s0.castle:find(kFlag,1,true)
                            and b[i+3]==rt and b[i+1]=="." and b[i+2]=="."
                            and not attacked(s0,i+1,-t)
                            and not attacked(s0,i+2,-t) then
                            out[#out+1]={f=i,t=i+2,castle=true}
                        end
                        if s0.castle:find(qFlag,1,true)
                            and b[i-4]==rt and b[i-1]=="." and b[i-2]=="."
                            and b[i-3]=="." and not attacked(s0,i-1,-t)
                            and not attacked(s0,i-2,-t) then
                            out[#out+1]={f=i,t=i-2,castle=true}
                        end
                    end
                end
            end
        end
    end
    return out
end
local function legal(s0)
    local out={}
    for _,m in ipairs(pseudo(s0)) do
        if not inCheck(apply(s0,m),s0.turn) then out[#out+1]=m end
    end
    return out
end
local function moveUci(m)
    return square(m.f)..square(m.t)..(m.promo or "")
end
-- ATLAS V2 search: iterative deepening negamax, alpha-beta pruning,
-- quiescence captures, move ordering, tactical opponent profiling, and
-- bounded transposition entries. This is an original compact Luau engine,
-- not Stockfish or a trained neural network.
local function eval(s0)
    local b=s0.b
    local score=0
    local pawns={[1]={},[-1]={}}
    local pawnFiles={[1]={},[-1]={}}
    local bishops={[1]=0,[-1]=0}
    local kings={}
    local phase=0
    for i=1,64 do
        local p=b[i]
        if p~="." then
            local sign=color(p)
            local kind=p:lower()
            local f,r=file(i),rank(i)
            local c=(3.5-math.abs(f-4.5))+(3.5-math.abs(r-4.5))
            local v=pieceValue[kind]
            if kind=="p" then
                local advance=sign==1 and r-2 or 7-r
                v=v+math.floor(c*4)+math.max(0,advance)*5
                local arr=pawns[sign]
                arr[#arr+1]={f=f,r=r}
                pawnFiles[sign][f]=(pawnFiles[sign][f] or 0)+1
            elseif kind=="n" then
                v=v+math.floor(c*11)
                phase=phase+320
            elseif kind=="b" then
                v=v+math.floor(c*7)
                bishops[sign]=bishops[sign]+1
                phase=phase+330
            elseif kind=="r" then
                v=v+math.floor(c*2)
                phase=phase+500
            elseif kind=="q" then
                v=v+math.floor(c*2)
                phase=phase+900
            elseif kind=="k" then
                kings[sign]={f=f,r=r}
            end
            score=score+sign*v
        end
    end
    for _,sign in ipairs({1,-1}) do
        if bishops[sign]>=2 then score=score+sign*28 end
        local counts=pawnFiles[sign]
        local enemy=pawns[-sign]
        for f=1,8 do
            local count=counts[f] or 0
            if count>1 then score=score-sign*(count-1)*17 end
            if count>0 and (counts[f-1] or 0)==0
                and (counts[f+1] or 0)==0 then
                score=score-sign*13*count
            end
        end
        for _,pawn in ipairs(pawns[sign]) do
            local passed=true
            for _,other in ipairs(enemy) do
                if math.abs(other.f-pawn.f)<=1 and
                   ((sign==1 and other.r>pawn.r)
                   or (sign==-1 and other.r<pawn.r)) then
                    passed=false;break
                end
            end
            if passed then
                local steps=sign==1 and pawn.r-2 or 7-pawn.r
                score=score+sign*(21+math.max(0,steps)*13)
            end
        end
        local kingSquare=kings[sign]
        if kingSquare then
            local f,r=kingSquare.f,kingSquare.r
            local middle=math.min(1,phase/4000)
            local advance=sign==1 and 1 or -1
            local shield=0
            for df=-1,1 do
                local sqIndex=at(f+df,r+advance)
                if sqIndex and b[sqIndex]==(sign==1 and "P" or "p") then
                    shield=shield+1
                end
            end
            local safety=(shield*18+((f<=3 or f>=6) and 17 or -12))*middle
            local endCenter=(7-(math.abs(f-4.5)+math.abs(r-4.5)))*9*(1-middle)
            score=score+sign*(safety+endCenter)
        end
    end
    -- Opponent behavior adjusts risk preference, not chess rules.
    if oppMoves>=5 and oppCaptures*100>=oppMoves*40 then
        local kingPos=kings[mySide]
        if kingPos and phase>2200 then
            local shield=0
            for df=-1,1 do
                local j=at(kingPos.f+df,kingPos.r+mySide)
                if j and b[j]==(mySide==1 and "P" or "p") then shield=shield+1 end
            end
            score=score+mySide*shield*7
        end
    end
    return score*s0.turn
end

local function isTactical(s0,m)
    return m.ep or m.promo~=nil or s0.b[m.t]~="."
end
local function movePriority(s0,m,ttMove,killerTable,history,ply)
    local id=moveUci(m)
    if ttMove and id==ttMove then return 100000000 end
    local target=s0.b[m.t]
    if m.promo then return 250000+(pieceValue[m.promo] or 0) end
    if target~="." or m.ep then
        local victim=m.ep and 100 or pieceValue[target:lower()]
        local attacker=pieceValue[s0.b[m.f]:lower()] or 100
        return 100000+victim*16-attacker
    end
    local killers=killerTable[ply]
    if killers then
        if killers[1]==id then return 80000 end
        if killers[2]==id then return 75000 end
    end
    return history[id] or 0
end

local function getBest(s0,requestedVersion)
    local preset=engineOptions[engineTier]
    local began=os.clock()
    local deadline=began+preset.time
    local nodes=0
    local stop=false
    local TT={}
    local ttCount=0
    local killers={}
    local history={}
    local MATE=99000
    local MAX_PLY=24
    local completedDepth=0
    local function tick()
        nodes=nodes+1
        if nodes%64==0 then
            if not active or analysisVersion~=requestedVersion
                or os.clock()>deadline or nodes>=preset.nodes then
                stop=true
            end
            if not stop and nodes%640==0 then
                task.wait()
                if not active or analysisVersion~=requestedVersion
                    or os.clock()>deadline then stop=true end
            end
        end
        return stop
    end
    local function keyOf(pos)
        return table.concat(pos.b)..":"..pos.turn..":"..
            pos.castle..":"..pos.ep..":"..pos.half
    end
    local function sorted(pos,moves,ttMove,ply)
        table.sort(moves,function(a,b)
            return movePriority(pos,a,ttMove,killers,history,ply)>
                movePriority(pos,b,ttMove,killers,history,ply)
        end)
    end
    local quiesce
    quiesce=function(pos,alpha,beta,ply,qleft)
        if tick() then return 0 end
        local check=inCheck(pos,pos.turn)
        if pos.half>=100 then return 0 end
        if ply>=MAX_PLY then return eval(pos) end
        local stand=eval(pos)
        if not check then
            if stand>=beta then return stand end
            if stand>alpha then alpha=stand end
        end
        if qleft<=0 then return check and stand-75 or stand end
        local moves=legal(pos)
        if #moves==0 then return check and -MATE+ply or 0 end
        local tactical={}
        for _,m in ipairs(moves) do
            if check or isTactical(pos,m) then tactical[#tactical+1]=m end
        end
        sorted(pos,tactical,nil,ply)
        for _,m in ipairs(tactical) do
            local score=-quiesce(apply(pos,m),-beta,-alpha,ply+1,qleft-1)
            if stop then return 0 end
            if score>alpha then alpha=score end
            if alpha>=beta then break end
        end
        return alpha
    end
    local function negamax(pos,depth,alpha,beta,ply)
        if tick() then return 0 end
        if pos.half>=100 then return 0 end
        if depth<=0 then return quiesce(pos,alpha,beta,ply,preset.q) end
        if ply>=MAX_PLY then return eval(pos) end
        local tableKey=keyOf(pos)
        local found=TT[tableKey]
        local alphaOriginal=alpha
        if found and found.depth>=depth then
            if found.flag=="EXACT" then return found.score end
            if found.flag=="LOWER" and found.score>=beta then return found.score end
            if found.flag=="UPPER" and found.score<=alpha then return found.score end
        end
        local moves=legal(pos)
        if #moves==0 then
            return inCheck(pos,pos.turn) and (-MATE+ply) or 0
        end
        sorted(pos,moves,found and found.best or nil,ply)
        local best=-MATE*2
        local bestId=nil
        for _,m in ipairs(moves) do
            local value=-negamax(apply(pos,m),depth-1,-beta,-alpha,ply+1)
            if stop then return 0 end
            if value>best then best=value;bestId=moveUci(m) end
            if value>alpha then alpha=value end
            if alpha>=beta then
                if not isTactical(pos,m) then
                    local id=moveUci(m)
                    local entry=killers[ply] or {}
                    if entry[1]~=id then killers[ply]={id,entry[1]} end
                    history[id]=math.min(50000,(history[id] or 0)+depth*depth*8)
                end
                break
            end
        end
        if not stop and (found or ttCount<10000) then
            if not found then ttCount=ttCount+1 end
            local flag=best<=alphaOriginal and "UPPER" or
                best>=beta and "LOWER" or "EXACT"
            TT[tableKey]={depth=depth,score=best,flag=flag,best=bestId}
        end
        return best
    end
    local moves=legal(s0)
    if #moves==0 then return nil,0,0,0 end
    sorted(s0,moves,nil,0)
    local best=moves[1]
    local score=eval(apply(s0,best))*(-1)
    local principal=nil
    for depth=1,preset.depth do
        local localBest=nil
        local localScore=-MATE*2
        local alpha=-MATE*2
        sorted(s0,moves,principal,0)
        for _,m in ipairs(moves) do
            local value=-negamax(apply(s0,m),depth-1,-MATE*2,-alpha,1)
            if stop then break end
            if value>localScore then
                localScore=value
                localBest=m
            end
            if value>alpha then alpha=value end
        end
        if stop then break end
        if localBest then
            best=localBest
            score=localScore
            principal=moveUci(localBest)
            completedDepth=depth
        end
        if os.clock()>=deadline then break end
        if nodes>=preset.nodes then break end
    end
    return best,score,nodes,completedDepth
end
local function extractFEN(raw)
    if type(raw)~="string" or #raw>1200 then return nil end
    if parseFen(raw) then return raw end
    local guess=raw:match("([prnbqkPRNBQK1-8/]+%s+[wb]%s+[%a%-]+%s+[%a%d%-]+%s+%d+%s+%d+)")
    if guess and parseFen(guess) then return guess end
    return nil
end

-- Two marked centers on RoChess: top-left square, then bottom-right square.
local arrowLine=make("Frame",overlay,{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(1,5),
    BackgroundColor3=C.accent,BorderSizePixel=0,Visible=false,Active=false,ZIndex=3})
make("UICorner",arrowLine,{CornerRadius=UDim.new(1,0)})
local fromDot=make("Frame",overlay,{AnchorPoint=Vector2.new(.5,.5),
    Size=UDim2.fromOffset(22,22),BackgroundColor3=C.warn,
    BorderSizePixel=0,Visible=false,Active=false,ZIndex=4})
make("UICorner",fromDot,{CornerRadius=UDim.new(1,0)})
local toDot=make("Frame",overlay,{AnchorPoint=Vector2.new(.5,.5),
    Size=UDim2.fromOffset(22,22),BackgroundColor3=C.accent,
    BorderSizePixel=0,Visible=false,Active=false,ZIndex=4})
make("UICorner",toDot,{CornerRadius=UDim.new(1,0)})
local arrowText=make("TextLabel",overlay,{
    AnchorPoint=Vector2.new(.5,1),Size=UDim2.fromOffset(122,23),
    BackgroundColor3=C.bg,BorderSizePixel=0,Visible=false,Active=false,ZIndex=5,
    Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.text,Text=""
})
make("UICorner",arrowText,{CornerRadius=UDim.new(0,7)})
local function pixelFor(i)
    if #calib~=2 then return nil end
    local p1,p2=calib[1],calib[2]
    local col=oriented==1 and file(i)-1 or 8-file(i)
    local row=oriented==1 and 8-rank(i) or rank(i)-1
    return Vector2.new(p1.X+(p2.X-p1.X)*col/7,
        p1.Y+(p2.Y-p1.Y)*row/7)
end
local function clearESP()
    arrowLine.Visible=false;fromDot.Visible=false;toDot.Visible=false;arrowText.Visible=false
end
local function drawESP()
    if not active or not esp or #calib~=2 or not suggestion then clearESP();return end
    local a,b=pixelFor(suggestion.f),pixelFor(suggestion.t)
    if not a or not b then clearESP();return end
    local delta=b-a
    local center=(a+b)/2
    arrowLine.Position=UDim2.fromOffset(center.X,center.Y)
    arrowLine.Size=UDim2.fromOffset(delta.Magnitude,5)
    arrowLine.Rotation=math.deg(math.atan2(delta.Y,delta.X))
    fromDot.Position=UDim2.fromOffset(a.X,a.Y)
    toDot.Position=UDim2.fromOffset(b.X,b.Y)
    arrowText.Position=UDim2.fromOffset(b.X,b.Y-16)
    arrowText.Text=moveUci(suggestion)
    arrowLine.Visible=true;fromDot.Visible=true;toDot.Visible=true;arrowText.Visible=true
end
local function profile()
    if oppMoves==0 then return "Opponent: waiting for moves..." end
    local pct=math.floor(100*oppCaptures/oppMoves+.5)
    return "Opponent: "..(pct>=35 and "Tactical" or "Positional")
        .." / captures "..pct.."% / checks "..tostring(oppChecks)
        .." ("..oppMoves.." moves)"
end
local function learn(previous,nextState)
    if not previous or previous.turn==mySide then return end
    local before=legal(previous)
    local expected=fen(nextState):match("^([^ ]+)%s+([wb])")
    for _,m in ipairs(before) do
        local after=apply(previous,m)
        if fen(after):match("^([^ ]+)%s+([wb])")==expected then
            oppMoves=oppMoves+1
            if previous.b[m.t]~="." or m.ep then oppCaptures=oppCaptures+1 end
            if inCheck(after,after.turn) then oppChecks=oppChecks+1 end
            oppLast=moveUci(m)
            statsLabel.Text=profile()
            log("OPPONENT "..oppLast.." | "..(oppCaptures).." captures in "..oppMoves.." moves")
            return
        end
    end
end
local function checkAuto()
    if not engineHealthy then return end
    if not auto or not synced or not suggestion or not s or #calib~=2 then return end
    if s.turn~=mySide or lastSentFen==currentFen then return end
    local fine,virtual=pcall(function()return game:GetService("VirtualInputManager")end)
    if not fine or not virtual then
        auto=false
        paint()
        status("Auto Play unavailable: executor can't simulate taps.")
        log("AUTO stopped: VirtualInputManager unavailable")
        return
    end
    local from,to=pixelFor(suggestion.f),pixelFor(suggestion.t)
    if not from or not to then return end
    local thisFen=currentFen
    local move=suggestion
    lastSentFen=thisFen
    task.spawn(function()
        local function tap(pos)
            local x,y=math.floor(pos.X),math.floor(pos.Y)
            virtual:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(.07)
            virtual:SendMouseButtonEvent(x,y,0,false,game,0)
        end
        local ok,err=pcall(function()
            tap(from)
            task.wait(.12)
            if not active or not auto or currentFen~=thisFen then return end
            tap(to)
        end)
        if ok then
            log("AUTO TAP "..moveUci(move).." (waiting for game board update)")
        else
            auto=false;paint()
            log("AUTO disabled: tap simulation failed "..tostring(err):sub(1,60))
        end
    end)
end
local function analyze()
    if not engineHealthy or not s or busy then return end
    local version=analysisVersion
    local snap=s
    busy=true
    task.spawn(function()
        local move,score,nodes,depth=getBest(snap,version)
        busy=false
        if not active then return end
        if version~=analysisVersion then task.defer(analyze);return end
        suggestion=move
        if move then
            bestLabel.Text=moveUci(move)
            engineLabel.Text=engineOptions[engineTier].name.."  /  D"..tostring(depth)
                .."  /  "..tostring(nodes).." nodes"
                .."  /  "..(score>=0 and "+" or "")..math.floor(score).." cp"
            log("BEST "..moveUci(move).." | local search "..nodes.." nodes")
        else
            bestLabel.Text=inCheck(snap,snap.turn) and "CHECKMATE" or "NO LEGAL MOVES"
            engineLabel.Text="Position is terminal."
        end
        drawESP()
        if move and synced then checkAuto() end
    end)
end
local function acceptFEN(fenText,isLive)
    local new=parseFen(fenText)
    if not new then status("Invalid FEN. Check the board notation.");return end
    local normalized=fen(new)
    if normalized==currentFen and isLive==synced then return end
    if isLive and synced and s then learn(s,new) end
    s=new
    currentFen=normalized
    synced=isLive
    analysisVersion=analysisVersion+1
    suggestion=nil
    clearESP()
    modeLabel.Text=isLive and "SOURCE  /  LIVE FEN" or "SOURCE  /  MANUAL FEN"
    sourceName=isLive and sourceName or "Manual position"
    syncLabel.Text=isLive and ("Connected: "..sourceName) or "Manual FEN: hints only, Auto Play disabled."
    bestLabel.Text="Analyzing..."
    status("Reading chess position...")
    if not isLive then auto=false;paint() end
    analyze()
end
local function candidateGetter()
    local roots={pg,player}
    local inspected=0
    for _,root in ipairs(roots) do
        local items={root}
        for _,v in ipairs(root:GetDescendants()) do
            items[#items+1]=v
            if #items>1700 then break end
        end
        for _,o in ipairs(items) do
            inspected=inspected+1
            if o:IsA("StringValue") then
                local valid=extractFEN(o.Value)
                if valid then
                    return function()return extractFEN(o.Value)end,o:GetFullName(),inspected
                end
            elseif (o:IsA("TextLabel") or o:IsA("TextBox") or o:IsA("TextButton"))
                and o.Name:lower():find("fen",1,true) then
                local valid=extractFEN(o.Text)
                if valid then
                    return function()return extractFEN(o.Text)end,o:GetFullName(),inspected
                end
            end
            for _,key in ipairs({"FEN","Fen","fen","CurrentFEN","BoardFEN","PositionFEN"}) do
                local ok,v=pcall(function()return o:GetAttribute(key)end)
                if ok and extractFEN(v) then
                    local obj=o
                    return function()return extractFEN(obj:GetAttribute(key))end,
                        obj:GetFullName().."/@"..key,inspected
                end
            end
        end
    end
    return nil,nil,inspected
end
local function scan()
    status("Scanning visible game data...")
    task.spawn(function()
        local getter,where,count=candidateGetter()
        if not active then return end
        if getter then
            dataGetter=getter;sourceName=where
            log("LIVE FEN found: "..where)
            acceptFEN(getter(),true)
        else
            dataGetter=nil;synced=false;auto=false;paint()
            syncLabel.Text="No live FEN in accessible UI/attributes."
            status("No board feed. Use manual FEN and calibrate ESP.")
            log("SCAN: "..count.." objects; no readable FEN. Need RoChess UI report.")
            local names={}
            for _,item in ipairs(pg:GetChildren()) do
                if item~=gui and item~=overlay then
                    names[#names+1]=item.Name.." ["..item.ClassName.."]"
                end
            end
            log("GUI roots: "..table.concat(names,", "):sub(1,130))
            local found=0
            local total=0
            for _,o in ipairs(pg:GetDescendants()) do
                if o~=gui and not o:IsDescendantOf(gui)
                   and o~=overlay and not o:IsDescendantOf(overlay) then
                    total=total+1
                    local n=o.Name:lower()
                    if (n:find("board",1,true) or n:find("square",1,true)
                        or n:find("piece",1,true) or n:find("chess",1,true)
                        or n:find("tile",1,true) or n:find("game",1,true))
                        and found<14 then
                        log("UI CANDIDATE "..o.Name.." / "..o.ClassName..
                            " / parent "..(o.Parent and o.Parent.Name or "?"))
                        found=found+1
                    end
                    if total>=1500 then break end
                end
            end
            log("UI SCAN SUMMARY: "..total.." objects; "..found.." candidates")
        end
    end)
end

local calibrating=0
hook(UserInputService.InputBegan,function(input)
    if calibrating==0 or not active then return end
    if input.UserInputType~=Enum.UserInputType.Touch and
        input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local pos=Vector2.new(input.Position.X,input.Position.Y)
    local win=window.AbsolutePosition
    local size=window.AbsoluteSize
    if pos.X>=win.X and pos.Y>=win.Y and pos.X<=win.X+size.X
        and pos.Y<=win.Y+size.Y then return end
    if calibrating==1 then
        calib={pos}
        calibrating=2
        status("Now tap the CENTER of bottom-right board square.")
    else
        if math.abs(pos.X-calib[1].X)<130 or math.abs(pos.Y-calib[1].Y)<130 then
            status("Calibration too small. Tap bottom-right square again.")
            return
        end
        calib[2]=pos
        calibrating=0
        paint();drawESP()
        log("ESP calibrated to on-screen chessboard.")
        status("Board ESP ready. Use HINT for a suggested move.")
    end
end)
hook(calibrate.Activated,function()
    calibrating=1;calib={}
    clearESP()
    status("Tap CENTER of top-left chessboard square.")
end)
hook(scanButton.Activated,scan)
hook(fenButton.Activated,function()
    dataGetter=nil
    acceptFEN(fenBox.Text,false)
end)
hook(hintButton.Activated,function()
    if not s then
        status("Connect or enter FEN before analyzing.")
    else
        analysisVersion=analysisVersion+1
        analyze()
    end
end)
hook(espButton.Activated,function()
    esp=not esp;paint();drawESP()
end)
hook(sideButton.Activated,function()
    mySide=-mySide;paint()
    status("Playing as "..(mySide==1 and "White" or "Black"))
end)
hook(strengthButton.Activated,function()
    engineTier=(engineTier%#engineOptions)+1
    paint()
    status("Engine: "..engineOptions[engineTier].name.." / bounded local search")
    log("ENGINE PRESET "..engineOptions[engineTier].name)
    if s and engineHealthy then
        analysisVersion=analysisVersion+1
        if not busy then analyze() end
    end
end)
hook(orient.Activated,function()
    oriented=-oriented;paint();drawESP()
end)
hook(autoButton.Activated,function()
    if not synced then
        status("Auto Play needs a VERIFIED live FEN feed. Manual FEN is hints-only.")
        return
    end
    if #calib~=2 then
        status("Calibrate chessboard squares before enabling Auto Play.")
        return
    end
    auto=not auto;paint()
    if auto then
        status("Auto Play on. Moves require synced FEN and tap support.")
        checkAuto()
    else status("Auto Play paused.") end
end)
hook(copyLog.Activated,function()
    local msg="ATLAS ROCHESS DIAGNOSTIC\nPlaceId="..game.PlaceId
        .."\nSync="..tostring(synced).."\nSource="..sourceName
        .."\nESP calibrated="..tostring(#calib==2)
        .."\n"..table.concat(logs,"\n")
    if type(setclipboard)=="function" then
        local ok=pcall(setclipboard,msg)
        status(ok and "Diagnostic copied." or "Clipboard unavailable.")
    else status("Clipboard unavailable in this executor.") end
end)
local minimized=false
hook(collapse.Activated,function()
    minimized=not minimized
    body.Visible=not minimized
    window.Size=UDim2.fromOffset(334,minimized and 62 or 443)
    collapse.Text=minimized and "+" or "-"
end)
local drag=false
local fromPos,fromWin,dragInput
hook(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch or
        input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true;dragInput=input;fromPos=input.Position;fromWin=window.Position
        local endConnection
        endConnection=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                drag=false
                if endConnection then endConnection:Disconnect() end
            end
        end)
    end
end)
hook(UserInputService.InputChanged,function(input)
    if not drag or not fromPos or not fromWin then return end
    if input~=dragInput and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local d=input.Position-fromPos
    window.Position=UDim2.new(fromWin.X.Scale,fromWin.X.Offset+d.X,
        fromWin.Y.Scale,fromWin.Y.Offset+d.Y)
end)
local function shutdown()
    if not active then return end
    active=false;auto=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()gui:Destroy()end)
    pcall(function()overlay:Destroy()end)
    if E.ROCHESS_ATLAS_CLOSE==shutdown then E.ROCHESS_ATLAS_CLOSE=nil end
end
hook(close.Activated,shutdown)
E.ROCHESS_ATLAS_CLOSE=shutdown
-- Verify core movement rules on the device before offering any suggestion.
local function engineSelfTest()
    local initial=parseFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    assert(initial and initial.turn==1,"cannot parse standard initial FEN")
    local moves=legal(initial)
    assert(#moves==20,"expected 20 legal starting moves, found "..#moves)
    local first=nil
    for _,m in ipairs(moves) do
        if moveUci(m)=="e2e4" then first=m;break end
    end
    assert(first~=nil,"e2e4 missing")
    local replyPosition=apply(initial,first)
    assert(replyPosition.turn==-1,"turn didn't switch")
    local replies=legal(replyPosition)
    assert(#replies==20,"expected 20 legal black replies, found "..#replies)
    -- Tactical legality: Qxg7# should be available and leave Black mated.
    local tactic=parseFen("7k/6pp/5KQ1/8/8/8/8/8 w - - 0 1")
    assert(tactic~=nil,"tactical test FEN failed")
    local foundMate=false
    for _,m in ipairs(legal(tactic)) do
        local nextPos=apply(tactic,m)
        if inCheck(nextPos,nextPos.turn) and #legal(nextPos)==0 then
            foundMate=true
            break
        end
    end
    assert(foundMate,"mate-in-one legal generator test failed")
    local mated=parseFen("7k/6Q1/5K2/8/8/8/8/8 b - - 0 1")
    assert(mated and inCheck(mated,-1) and #legal(mated)==0,
        "terminal checkmate test failed")
    -- Special moves are critical for a reliable chess engine.
    local castle=parseFen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    local bothCastles=0
    for _,m in ipairs(legal(castle)) do
        if m.castle and m.f==61 then bothCastles=bothCastles+1 end
    end
    assert(bothCastles==2,"castling generation test failed")
    local enPassant=parseFen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
    local canEP=false
    for _,m in ipairs(legal(enPassant)) do
        if m.ep and moveUci(m)=="e5d6" then canEP=true;break end
    end
    assert(canEP,"en passant test failed")
    local promotion=parseFen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
    local promotions=0
    for _,m in ipairs(legal(promotion)) do
        if m.f==9 and m.t==1 and m.promo then promotions=promotions+1 end
    end
    assert(promotions==4,"promotion choice test failed")
end
local valid,err=pcall(engineSelfTest)
if not valid then
    engineHealthy=false
    auto=false
    log("ENGINE SELF-CHECK FAILED: "..tostring(err):sub(1,150))
    status("Engine check failed. Auto Play disabled.")
else
    log("ENGINE SELF-CHECK PASSED: legal opening moves, mate and FEN")
end
paint()
showPage("ASSIST")
log("ATLAS launched. RoChess current place ID: "..game.PlaceId)
log("Local AI enabled. Auto Play OFF until board feed verified.")
scan()
task.spawn(function()
    while active do
        if dataGetter then
            local ok,value=pcall(dataGetter)
            if ok and value then
                if value~=currentFen then acceptFEN(value,true) end
            elseif not ok then
                dataGetter=nil;synced=false;auto=false;paint()
                log("Lost board data source; Auto Play stopped.")
            end
        end
        task.wait(.85)
    end
end)
