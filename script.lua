local RENDER_WEBSOCKET_URL = "wss://chat-universal-k9at.onrender.com"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SISTEMA DE ARQUIVOS LOCAL (PERSISTÊNCIA)
-- ==========================================
local fs_folder = "Mbchat_dados"
local fs_stickers = fs_folder.."/Stickers"
local fs_bg = fs_folder.."/Backgrounds"

if isfolder then
    if not isfolder(fs_folder) then makefolder(fs_folder) end
    if not isfolder(fs_stickers) then makefolder(fs_stickers) end
    if not isfolder(fs_bg) then makefolder(fs_bg) end
end

local function saveJSON(filename, data)
    if writefile then writefile(fs_folder.."/"..filename..".json", HttpService:JSONEncode(data)) end
end

local function loadJSON(filename)
    if isfile and readfile and isfile(fs_folder.."/"..filename..".json") then
        local s, r = pcall(function() return HttpService:JSONDecode(readfile(fs_folder.."/"..filename..".json")) end)
        if s then return r end
    end
    return nil
end

local myFriends = loadJSON("amigos_salvos") or {}
local chatHistories = {}
local groupHistories = {}
local recentStickers = loadJSON("stickers_recentes") or {}

local ws = nil
local activeChatId = nil
local activeGroupId = nil
local allUsersCache = {}
local isGroupOwner = false

-- ==========================================
-- ESTRUTURA BASE DA UI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPairingMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local MainScale = Instance.new("UIScale", ScreenGui)
MainScale.Scale = 1

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 520, 0, 420)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Header & Controles
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextButton", Header)
Title.Size = UDim2.new(1, -150, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA PAIRING SYSTEM"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local ConfigBtn = Instance.new("TextButton", Header)
ConfigBtn.Size = UDim2.new(0, 30, 0, 30)
ConfigBtn.Position = UDim2.new(1, -75, 0, 5)
ConfigBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ConfigBtn.Text = "⚙"
ConfigBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", ConfigBtn).CornerRadius = UDim.new(0, 15)

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -40, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 15)

-- Abas
local TabHolder = Instance.new("Frame", MainFrame)
TabHolder.Size = UDim2.new(1, -20, 0, 30)
TabHolder.Position = UDim2.new(0, 10, 0, 48)
TabHolder.BackgroundTransparency = 1
local UIListLayoutTabs = Instance.new("UIListLayout", TabHolder)
UIListLayoutTabs.FillDirection = Enum.FillDirection.Horizontal
UIListLayoutTabs.Padding = UDim.new(0, 8)

local function createTabBtn(name, w)
    local btn = Instance.new("TextButton", TabHolder)
    btn.Size = UDim2.new(0, w, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SearchTabBtn = createTabBtn("Procurar Amigos", 115)
local ChatTabBtn = createTabBtn("Bate-Papo", 85)
local NotifTabBtn = createTabBtn("Notificações", 95)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1

-- ==========================================
-- MENUS DAS ABAS
-- ==========================================
-- 1. Procurar Amigos
local SearchFrame = Instance.new("Frame", ContentArea)
SearchFrame.Size = UDim2.new(1, 0, 1, 0)
SearchFrame.BackgroundTransparency = 1

local SearchBar = Instance.new("TextBox", SearchFrame)
SearchBar.Size = UDim2.new(1, -120, 0, 30)
SearchBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
SearchBar.PlaceholderText = " Pesquisar usuário..."
SearchBar.TextColor3 = Color3.new(1,1,1)
SearchBar.TextXAlignment = Enum.TextXAlignment.Left
SearchBar.ClearTextOnFocus = false
Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(0, 6)

local CreateGroupBtn = Instance.new("TextButton", SearchFrame)
CreateGroupBtn.Size = UDim2.new(0, 110, 0, 30)
CreateGroupBtn.Position = UDim2.new(1, -110, 0, 0)
CreateGroupBtn.BackgroundColor3 = Color3.fromRGB(180, 120, 30)
CreateGroupBtn.Text = "Criar Grupo"
CreateGroupBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", CreateGroupBtn).CornerRadius = UDim.new(0, 6)

local UsersScroll = Instance.new("ScrollingFrame", SearchFrame)
UsersScroll.Size = UDim2.new(1, 0, 1, -40)
UsersScroll.Position = UDim2.new(0, 0, 0, 40)
UsersScroll.BackgroundTransparency = 1
UsersScroll.ScrollBarThickness = 4
local UsersLayout = Instance.new("UIListLayout", UsersScroll)
UsersLayout.Padding = UDim.new(0, 6)

-- 2. Chat / Grupo
local ChatFrame = Instance.new("Frame", ContentArea)
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false

local ChatBgImage = Instance.new("ImageLabel", ChatFrame)
ChatBgImage.Size = UDim2.new(1, 0, 1, -40)
ChatBgImage.BackgroundTransparency = 1
ChatBgImage.ImageTransparency = 0.8
ChatBgImage.ZIndex = 0

local ChatLog = Instance.new("ScrollingFrame", ChatFrame)
ChatLog.Size = UDim2.new(1, 0, 1, -40)
ChatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ChatLog.BackgroundTransparency = 0.2
ChatLog.ScrollBarThickness = 4
Instance.new("UICorner", ChatLog).CornerRadius = UDim.new(0, 6)
local ChatLayout = Instance.new("UIListLayout", ChatLog)
ChatLayout.Padding = UDim.new(0, 4)

local ChatInputBox = Instance.new("Frame", ChatFrame)
ChatInputBox.Size = UDim2.new(1, 0, 0, 35)
ChatInputBox.Position = UDim2.new(0, 0, 1, -35)
ChatInputBox.BackgroundTransparency = 1

local ChatInput = Instance.new("TextBox", ChatInputBox)
ChatInput.Size = UDim2.new(1, -80, 1, 0)
ChatInput.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInput.PlaceholderText = " Mensagem, /invite, //leave..."
ChatInput.TextColor3 = Color3.new(1,1,1)
ChatInput.ClearTextOnFocus = false -- IMPEDE O TEXTO DE SUMIR AO FECHAR O TECLADO
ChatInput.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 6)

local AutocompleteFrame = Instance.new("Frame", ChatFrame)
AutocompleteFrame.Size = UDim2.new(0, 150, 0, 40)
AutocompleteFrame.Position = UDim2.new(0, 0, 1, -80)
AutocompleteFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
AutocompleteFrame.Visible = false
Instance.new("UICorner", AutocompleteFrame).CornerRadius = UDim.new(0, 6)
local AcBtn = Instance.new("TextButton", AutocompleteFrame)
AcBtn.Size = UDim2.new(1, 0, 1, 0)
AcBtn.BackgroundTransparency = 1
AcBtn.TextColor3 = Color3.new(1,1,1)

local StickerBtn = Instance.new("TextButton", ChatInputBox)
StickerBtn.Size = UDim2.new(0, 35, 0, 35)
StickerBtn.Position = UDim2.new(1, -75, 0, 0)
StickerBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
StickerBtn.Text = "🙂"
Instance.new("UICorner", StickerBtn).CornerRadius = UDim.new(0, 6)

local CloneBtn = Instance.new("TextButton", ChatInputBox)
CloneBtn.Size = UDim2.new(0, 35, 0, 35)
CloneBtn.Position = UDim2.new(1, -35, 0, 0)
CloneBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 180)
CloneBtn.Text = "👥"
Instance.new("UICorner", CloneBtn).CornerRadius = UDim.new(0, 6)

-- 3. Notificações
local NotifFrame = Instance.new("ScrollingFrame", ContentArea)
NotifFrame.Size = UDim2.new(1, 0, 1, 0)
NotifFrame.BackgroundTransparency = 1
NotifFrame.Visible = false
local NotifLayout = Instance.new("UIListLayout", NotifFrame)
NotifLayout.Padding = UDim.new(0, 6)

-- ==========================================
-- MENUS SECUNDÁRIOS (CONFIG, STICKERS, GRUPO)
-- ==========================================
local ConfigMenu = Instance.new("Frame", MainFrame)
ConfigMenu.Size = UDim2.new(1, 0, 1, 0)
ConfigMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
ConfigMenu.Visible = false
ConfigMenu.ZIndex = 10

local CfgBack = Instance.new("TextButton", ConfigMenu)
CfgBack.Size = UDim2.new(0, 80, 0, 30)
CfgBack.Position = UDim2.new(0, 10, 0, 10)
CfgBack.Text = "< Voltar"
CfgBack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)

local ScaleMinus = Instance.new("TextButton", ConfigMenu)
ScaleMinus.Size = UDim2.new(0, 40, 0, 40)
ScaleMinus.Position = UDim2.new(0.5, -80, 0.5, 0)
ScaleMinus.Text = "-"
ScaleMinus.BackgroundColor3 = Color3.fromRGB(40, 40, 50)

local ScalePlus = Instance.new("TextButton", ConfigMenu)
ScalePlus.Size = UDim2.new(0, 40, 0, 40)
ScalePlus.Position = UDim2.new(0.5, 40, 0.5, 0)
ScalePlus.Text = "+"
ScalePlus.BackgroundColor3 = Color3.fromRGB(40, 40, 50)

local ScaleReset = Instance.new("TextButton", ConfigMenu)
ScaleReset.Size = UDim2.new(0, 100, 0, 40)
ScaleReset.Position = UDim2.new(0.5, -50, 0.5, 50)
ScaleReset.Text = "Reset Size"
ScaleReset.BackgroundColor3 = Color3.fromRGB(180, 40, 40)

local StickerPanel = Instance.new("Frame", ChatFrame)
StickerPanel.Size = UDim2.new(1, 0, 0, 150)
StickerPanel.Position = UDim2.new(0, 0, 1, -190)
StickerPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
StickerPanel.Visible = false
local StickerScroll = Instance.new("ScrollingFrame", StickerPanel)
StickerScroll.Size = UDim2.new(1, 0, 1, 0)
StickerScroll.BackgroundTransparency = 1
local StickerGrid = Instance.new("UIGridLayout", StickerScroll)
StickerGrid.CellSize = UDim2.new(0, 60, 0, 60)

local BgMenu = Instance.new("Frame", MainFrame)
BgMenu.Size = UDim2.new(1, 0, 1, 0)
BgMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
BgMenu.Visible = false
BgMenu.ZIndex = 10
local BgBack = Instance.new("TextButton", BgMenu)
BgBack.Size = UDim2.new(0, 80, 0, 30)
BgBack.Position = UDim2.new(0, 10, 0, 10)
BgBack.Text = "< Voltar"

-- ==========================================
-- FUNÇÕES DE LÓGICA E UI
-- ==========================================
local function switchTab(tab)
    SearchFrame.Visible = (tab == "search")
    ChatFrame.Visible = (tab == "chat")
    NotifFrame.Visible = (tab == "notif")
    StickerPanel.Visible = false
end
SearchTabBtn.MouseButton1Click:Connect(function() switchTab("search") end)
ChatTabBtn.MouseButton1Click:Connect(function() switchTab("chat") end)
NotifTabBtn.MouseButton1Click:Connect(function() switchTab("notif") end)

-- Janela e Config
local isMinimized = false
local lastSize, lastPos
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        lastSize = MainFrame.Size
        lastPos = MainFrame.Position
        MainFrame.Size = UDim2.new(0, 50, 0, 50)
        Header.BackgroundTransparency = 1
        Title.Visible = false; ConfigBtn.Visible = false; TabHolder.Visible = false; ContentArea.Visible = false
        MinBtn.Size = UDim2.new(1, 0, 1, 0); MinBtn.Position = UDim2.new(0,0,0,0)
        MinBtn.Text = "D"; MinBtn.TextSize = 24
        MainFrame:FindFirstChild("UICorner").CornerRadius = UDim.new(1, 0)
    else
        MainFrame.Size = lastSize; MainFrame.Position = lastPos
        Header.BackgroundTransparency = 0
        Title.Visible = true; ConfigBtn.Visible = true; TabHolder.Visible = true; ContentArea.Visible = true
        MinBtn.Size = UDim2.new(0, 30, 0, 30); MinBtn.Position = UDim2.new(1, -40, 0, 5)
        MinBtn.Text = "-"; MinBtn.TextSize = 14
        MainFrame:FindFirstChild("UICorner").CornerRadius = UDim.new(0, 10)
    end
end)

ConfigBtn.MouseButton1Click:Connect(function() ConfigMenu.Visible = true end)
CfgBack.MouseButton1Click:Connect(function() ConfigMenu.Visible = false end)
ScalePlus.MouseButton1Click:Connect(function() MainScale.Scale = math.clamp(MainScale.Scale + 0.1, 0.5, 2) end)
ScaleMinus.MouseButton1Click:Connect(function() MainScale.Scale = math.clamp(MainScale.Scale - 0.1, 0.5, 2) end)
ScaleReset.MouseButton1Click:Connect(function() MainScale.Scale = 1 end)

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function renderMessage(sender, text, isSticker)
    local msgFrame = Instance.new("Frame", ChatLog)
    msgFrame.BackgroundTransparency = 1
    
    local nameL = Instance.new("TextLabel", msgFrame)
    nameL.Size = UDim2.new(1, 0, 0, 20)
    nameL.BackgroundTransparency = 1
    nameL.Text = "  ["..sender.."]:"
    nameL.TextColor3 = Color3.fromRGB(150, 150, 160)
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    
    if isSticker then
        msgFrame.Size = UDim2.new(1, -10, 0, 120)
        local img = Instance.new("ImageLabel", msgFrame)
        img.Size = UDim2.new(0, 100, 0, 100)
        img.Position = UDim2.new(0, 10, 0, 20)
        img.Image = text
        img.BackgroundTransparency = 1
    else
        msgFrame.Size = UDim2.new(1, -10, 0, 45)
        local txt = Instance.new("TextLabel", msgFrame)
        txt.Size = UDim2.new(1, -20, 1, -20)
        txt.Position = UDim2.new(0, 10, 0, 20)
        txt.BackgroundTransparency = 1
        txt.Text = text
        txt.TextColor3 = Color3.new(1,1,1)
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextWrapped = true
    end
    
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
end

local function saveChat(id, isGroup)
    local prefix = isGroup and "gp_" or "chat_"
    local t = isGroup and groupHistories[id] or chatHistories[id]
    saveJSON(prefix..id, t)
end

local function addFriendCard(user)
    local card = Instance.new("Frame", UsersScroll)
    card.Size = UDim2.new(1, -6, 0, 50)
    card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    
    local avatar = Instance.new("ImageLabel", card)
    avatar.Size = UDim2.new(0, 40, 0, 40)
    avatar.Position = UDim2.new(0, 5, 0, 5)
    avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..user.userId.."&w=150&h=150"
    avatar.BackgroundTransparency = 1
    
    local nameL = Instance.new("TextLabel", card)
    nameL.Size = UDim2.new(1, -140, 1, 0)
    nameL.Position = UDim2.new(0, 55, 0, 0)
    nameL.BackgroundTransparency = 1
    nameL.Text = user.username .. (myFriends[user.userId] and " (Amigo)" or "")
    nameL.TextColor3 = Color3.new(1,1,1)
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    
    if not myFriends[user.userId] then
        local addBtn = Instance.new("TextButton", card)
        addBtn.Size = UDim2.new(0, 75, 0, 30)
        addBtn.Position = UDim2.new(1, -85, 0, 10)
        addBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        addBtn.Text = "Adicionar"
        Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
        
        addBtn.MouseButton1Click:Connect(function()
            sendWS({ type = "friend_request", targetId = user.userId })
            addBtn.Text = "Enviado"; addBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
        end)
    end
end

-- ==========================================
-- AUTOCOMPLETE & COMANDOS NO CHAT
-- ==========================================
local currentTargetAC = nil
ChatInput:GetPropertyChangedSignal("Text"):Connect(function()
    local t = ChatInput.Text
    if string.match(t, "^/invite @") or string.match(t, "^//invitegp @") or string.match(t, "^//ban @") or string.match(t, "^//kick @") then
        local search = string.match(t, "@(%w*)")
        if search and search ~= "" then
            for id, name in pairs(myFriends) do
                if string.find(string.lower(name), string.lower(search)) then
                    AcBtn.Text = name
                    currentTargetAC = id
                    AutocompleteFrame.Visible = true
                    return
                end
            end
        end
    end
    AutocompleteFrame.Visible = false
end)

AcBtn.MouseButton1Click:Connect(function()
    local baseCmd = string.match(ChatInput.Text, "^(/?/?%w+)")
    if baseCmd and currentTargetAC then
        ChatInput.Text = baseCmd .. " @" .. AcBtn.Text .. " "
        AutocompleteFrame.Visible = false
    end
end)

ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and ChatInput.Text ~= "" then
        local text = ChatInput.Text
        local args = string.split(text, " ")
        local cmd = args[1]:lower()

        if cmd == "/invite" and args[2] then
            if currentTargetAC then sendWS({ type = "chat_invite", targetId = currentTargetAC }) end
        elseif cmd == "//leave" then
            sendWS({ type = "leave_chat" })
            activeChatId = nil
        elseif cmd == "//invitegp" and args[2] then
            if currentTargetAC then sendWS({ type = "invite_group", targetId = currentTargetAC }) end
        elseif cmd == "//ban" or cmd == "//kick" then
            if currentTargetAC then sendWS({ type = "group_command", action = string.gsub(cmd, "//", ""), targetId = currentTargetAC }) end
        elseif cmd == "//deletegp" then
            sendWS({ type = "group_command", action = "delete" })
        else
            if activeChatId then
                sendWS({ type = "chat_message", message = text, isSticker = false })
                if not chatHistories[activeChatId] then chatHistories[activeChatId] = {} end
                table.insert(chatHistories[activeChatId], {s = LocalPlayer.Name, m = text, st = false})
                saveChat(activeChatId, false)
            elseif activeGroupId then
                sendWS({ type = "group_message", message = text, isSticker = false })
                if not groupHistories[activeGroupId] then groupHistories[activeGroupId] = {} end
                table.insert(groupHistories[activeGroupId], {s = LocalPlayer.Name, m = text, st = false})
                saveChat(activeGroupId, true)
            end
        end
        ChatInput.Text = "" -- Limpa APENAS se o enterPressed for verdadeiro
    end
end)

-- ==========================================
-- SISTEMA DE CLONAGEM & BACKGROUND
-- ==========================================
local activeClone = nil
local cloneConn = nil

local function stopClone()
    if cloneConn then cloneConn:Disconnect() end
    if activeClone then activeClone:Destroy(); activeClone = nil end
end

CloneBtn.MouseButton1Click:Connect(function()
    if activeChatId then sendWS({ type = "clone_request", targetId = activeChatId }) end
end)

Title.MouseButton1Click:Connect(function()
    if activeGroupId and isGroupOwner then BgMenu.Visible = true end
end)

-- ==========================================
-- ROTEAMENTO WEBSOCKET
-- ==========================================
local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "user_list" then
            allUsersCache = data.users
            for _, c in ipairs(UsersScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for _, u in ipairs(data.users) do
                if u.userId ~= tostring(LocalPlayer.UserId) then addFriendCard(u) end
            end
            
        elseif data.type == "friend_notification" or data.type == "chat_notification" or data.type == "group_notification" or data.type == "clone_prompt" then
            local nCard = Instance.new("Frame", NotifFrame)
            nCard.Size = UDim2.new(1, -6, 0, 50)
            nCard.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
            local txt = Instance.new("TextLabel", nCard)
            txt.Size = UDim2.new(1, -100, 1, 0)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.new(1,1,1)
            txt.TextWrapped = true
            
            if data.type == "friend_notification" then txt.Text = data.fromName .. " enviou pedido de amizade."
            elseif data.type == "chat_notification" then txt.Text = data.fromName .. " chamou pro chat 1v1."
            elseif data.type == "group_notification" then txt.Text = data.fromName .. " te convidou para o grupo " .. data.groupName
            elseif data.type == "clone_prompt" then txt.Text = data.fromName .. " enviou convite de Clone Perfeito." end
            
            local accBtn = Instance.new("TextButton", nCard)
            accBtn.Size = UDim2.new(0, 40, 0, 30)
            accBtn.Position = UDim2.new(1, -95, 0, 10)
            accBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
            accBtn.Text = "Sim"
            
            accBtn.MouseButton1Click:Connect(function()
                if data.type == "friend_notification" then sendWS({ type = "friend_accept", targetId = data.fromId })
                elseif data.type == "chat_notification" then sendWS({ type = "chat_accept", targetId = data.fromId })
                elseif data.type == "group_notification" then sendWS({ type = "accept_group", groupId = data.groupId })
                elseif data.type == "clone_prompt" then sendWS({ type = "clone_accept", targetId = data.fromId }) end
                nCard:Destroy()
            end)
            
        elseif data.type == "friend_added" then
            myFriends[data.id] = data.name
            saveJSON("amigos_salvos", myFriends)
            
        elseif data.type == "chat_connected" then
            activeChatId = data.targetId; activeGroupId = nil
            Title.Text = "Chat Privado"
            switchTab("chat")
            for _, c in ipairs(ChatLog:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            local hist = loadJSON("chat_"..activeChatId)
            if hist then
                chatHistories[activeChatId] = hist
                for _, m in ipairs(hist) do renderMessage(m.s, m.m, m.st) end
            end
            
        elseif data.type == "group_joined" then
            activeGroupId = data.groupId; activeChatId = nil
            isGroupOwner = data.isOwner
            Title.Text = "Grupo: " .. data.name
            switchTab("chat")
            for _, c in ipairs(ChatLog:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            
        elseif data.type == "request_group_history" then
            -- O dono do grupo envia o histórico local para o servidor repassar ao novo membro
            if isGroupOwner and groupHistories[data.groupId] then
                sendWS({ type = "sync_group_history", targetId = data.targetId, history = groupHistories[data.groupId] })
            end
            
        elseif data.type == "receive_group_history" then
            groupHistories[activeGroupId] = data.history
            saveChat(activeGroupId, true)
            for _, c in ipairs(ChatLog:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for _, m in ipairs(data.history) do renderMessage(m.s, m.m, m.st) end
            
        elseif data.type == "chat_receive" or data.type == "group_message" then
            renderMessage(data.sender, data.message, data.isSticker)
            if data.type == "chat_receive" and activeChatId then
                table.insert(chatHistories[activeChatId], {s = data.sender, m = data.message, st = data.isSticker})
                saveChat(activeChatId, false)
            elseif data.type == "group_message" and activeGroupId then
                table.insert(groupHistories[activeGroupId], {s = data.sender, m = data.message, st = data.isSticker})
                saveChat(activeGroupId, true)
            end
            
        elseif data.type == "clone_start" then
            stopClone()
            activeClone = Instance.new("Model", workspace)
            activeClone.Name = "Clone_Virtual"
            local root = Instance.new("Part", activeClone)
            root.Name = "HumanoidRootPart"
            root.Anchored = true; root.Size = Vector3.new(2,2,1); root.Transparency = 0.5
            local hum = Instance.new("Humanoid", activeClone)
            
            cloneConn = RunService.Heartbeat:Connect(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local cf = LocalPlayer.Character.HumanoidRootPart.CFrame
                    sendWS({ type = "clone_sync", targetId = data.targetId, cframe = {cf.X, cf.Y, cf.Z} })
                end
            end)
            
        elseif data.type == "clone_update" and activeClone then
            if activeClone:FindFirstChild("HumanoidRootPart") then
                activeClone.HumanoidRootPart.CFrame = CFrame.new(unpack(data.cframe, 1, 3))
            end
        end
    end)
    
    sendWS({ type = "register", userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name })
end

-- Criar Grupo
CreateGroupBtn.MouseButton1Click:Connect(function()
    if SearchBar.Text ~= "" then sendWS({ type = "create_group", name = SearchBar.Text }) end
end)
