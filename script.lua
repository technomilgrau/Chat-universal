local RENDER_WEBSOCKET_URL = "wss://chat-universal-online.onrender.com"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SISTEMA DE ARQUIVOS (DELTA / KRNL API)
-- ==========================================
local folderName = "Mbchat_dados"
if not isfolder(folderName) then makefolder(folderName) end
if not isfolder("Stickers") then makefolder("Stickers") end
if not isfolder("Background_images") then makefolder("Background_images") end

local function SaveData(fileName, data)
    pcall(function() writefile(folderName .. "/" .. fileName .. ".json", HttpService:JSONEncode(data)) end)
end

local function LoadData(fileName, defaultData)
    local path = folderName .. "/" .. fileName .. ".json"
    if isfile(path) then
        local success, result = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success then return result end
    end
    return defaultData
end

local db_friends = LoadData("friends", {})
local db_history = LoadData("history", {})
local db_groups = LoadData("groups", {})
local db_recent_stickers = LoadData("recent_stickers", {})
local db_settings = LoadData("settings", { UIScale = 1, PosX = 0.5, PosY = 0.5, MinimizedPosX = 0.1, MinimizedPosY = 0.5 })

-- ==========================================
-- CONSTRUÇÃO DA INTERFACE PRINCIPAL
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaUniversalChat"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local UIScale = Instance.new("UIScale", ScreenGui)
UIScale.Scale = db_settings.UIScale

-- Botão Minimizado (Bolinha "D")
local MinimizedBtn = Instance.new("TextButton")
MinimizedBtn.Size = UDim2.new(0, 50, 0, 50)
MinimizedBtn.Position = UDim2.new(db_settings.MinimizedPosX, 0, db_settings.MinimizedPosY, 0)
MinimizedBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
MinimizedBtn.Text = "D"
MinimizedBtn.TextColor3 = Color3.fromRGB(0, 150, 255)
MinimizedBtn.Font = Enum.Font.GothamBlack
MinimizedBtn.TextSize = 24
MinimizedBtn.Visible = false
MinimizedBtn.Draggable = true
MinimizedBtn.Active = true
MinimizedBtn.Parent = ScreenGui
Instance.new("UICorner", MinimizedBtn).CornerRadius = UDim.new(1, 0)

MinimizedBtn:GetPropertyChangedSignal("Position"):Connect(function()
    db_settings.MinimizedPosX = MinimizedBtn.Position.X.Scale
    db_settings.MinimizedPosY = MinimizedBtn.Position.Y.Scale
    SaveData("settings", db_settings)
end)

-- Janela Principal
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Position = UDim2.new(db_settings.PosX, -280, db_settings.PosY, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

MainFrame:GetPropertyChangedSignal("Position"):Connect(function()
    db_settings.PosX = MainFrame.Position.X.Scale
    db_settings.PosY = MainFrame.Position.Y.Scale
    SaveData("settings", db_settings)
end)

-- Background Dinâmico
local ChatBackground = Instance.new("ImageLabel", MainFrame)
ChatBackground.Size = UDim2.new(1, 0, 1, 0)
ChatBackground.BackgroundTransparency = 1
ChatBackground.ImageTransparency = 0.8
ChatBackground.ZIndex = 0

-- Topbar
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Header.ZIndex = 2
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA UNIVERSAL"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local ConfigBtn = Instance.new("TextButton", Header)
ConfigBtn.Size = UDim2.new(0, 30, 0, 30)
ConfigBtn.Position = UDim2.new(1, -75, 0, 5)
ConfigBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ConfigBtn.Text = "⚙️"
Instance.new("UICorner", ConfigBtn).CornerRadius = UDim.new(0, 6)

local MinimizeTopBtn = Instance.new("TextButton", Header)
MinimizeTopBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeTopBtn.Position = UDim2.new(1, -35, 0, 5)
MinimizeTopBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
MinimizeTopBtn.Text = "-"
MinimizeTopBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", MinimizeTopBtn).CornerRadius = UDim.new(0, 6)

-- Abas
local TabHolder = Instance.new("ScrollingFrame", MainFrame)
TabHolder.Size = UDim2.new(1, -20, 0, 35)
TabHolder.Position = UDim2.new(0, 10, 0, 45)
TabHolder.BackgroundTransparency = 1
TabHolder.CanvasSize = UDim2.new(0, 600, 0, 0)
TabHolder.ScrollBarThickness = 0
TabHolder.ZIndex = 2

local TabLayout = Instance.new("UIListLayout", TabHolder)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 6)

local function createTabBtn(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SearchFriendsBtn = createTabBtn("Procurar Amigos")
local NotifBtn = createTabBtn("Notificações")
local ChatBtn = createTabBtn("Bate-Papo")
local GroupBtn = createTabBtn("Grupos")
local ActionsBtn = createTabBtn("Ações")

SearchFriendsBtn.Parent = TabHolder
NotifBtn.Parent = TabHolder
ChatBtn.Parent = TabHolder
GroupBtn.Parent = TabHolder
ActionsBtn.Parent = TabHolder
ActionsBtn.Visible = false

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 2

-- ==========================================
-- LÓGICA DAS ABAS (CONTAINERS)
-- ==========================================

-- 1. Procurar Amigos
local SearchFrame = Instance.new("Frame", ContentArea)
SearchFrame.Size = UDim2.new(1, 0, 1, 0)
SearchFrame.BackgroundTransparency = 1
local SearchInput = Instance.new("TextBox", SearchFrame)
SearchInput.Size = UDim2.new(1, 0, 0, 30)
SearchInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
SearchInput.PlaceholderText = " Pesquisar usuário conectado..."
SearchInput.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", SearchInput).CornerRadius = UDim.new(0, 6)
local SearchScroll = Instance.new("ScrollingFrame", SearchFrame)
SearchScroll.Size = UDim2.new(1, 0, 1, -40)
SearchScroll.Position = UDim2.new(0, 0, 0, 40)
SearchScroll.BackgroundTransparency = 1
SearchScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
local SearchLayout = Instance.new("UIListLayout", SearchScroll)
SearchLayout.Padding = UDim.new(0, 5)

-- 2. Notificações
local NotifFrame = Instance.new("Frame", ContentArea)
NotifFrame.Size = UDim2.new(1, 0, 1, 0)
NotifFrame.BackgroundTransparency = 1
NotifFrame.Visible = false
local NotifScroll = Instance.new("ScrollingFrame", NotifFrame)
NotifScroll.Size = UDim2.new(1, 0, 1, 0)
NotifScroll.BackgroundTransparency = 1
local NotifLayout = Instance.new("UIListLayout", NotifScroll)
NotifLayout.Padding = UDim.new(0, 5)

-- 3. Bate-Papo
local ChatFrame = Instance.new("Frame", ContentArea)
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false

local ChatLog = Instance.new("ScrollingFrame", ChatFrame)
ChatLog.Size = UDim2.new(1, 0, 1, -40)
ChatLog.BackgroundTransparency = 1
local ChatLayout = Instance.new("UIListLayout", ChatLog)
ChatLayout.Padding = UDim.new(0, 4)

local ChatInputBox = Instance.new("TextBox", ChatFrame)
ChatInputBox.Size = UDim2.new(1, -45, 0, 35)
ChatInputBox.Position = UDim2.new(0, 0, 1, -35)
ChatInputBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInputBox.PlaceholderText = "Digite a mensagem, /invite @nick ou //leave"
ChatInputBox.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ChatInputBox).CornerRadius = UDim.new(0, 6)

local StickerBtn = Instance.new("TextButton", ChatFrame)
StickerBtn.Size = UDim2.new(0, 35, 0, 35)
StickerBtn.Position = UDim2.new(1, -35, 1, -35)
StickerBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
StickerBtn.Text = "🙂"
Instance.new("UICorner", StickerBtn).CornerRadius = UDim.new(0, 6)

-- Autocomplete (Discord style)
local AutocompleteFrame = Instance.new("ScrollingFrame", ChatFrame)
AutocompleteFrame.Size = UDim2.new(0, 200, 0, 120)
AutocompleteFrame.Position = UDim2.new(0, 0, 1, -160)
AutocompleteFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AutocompleteFrame.Visible = false
AutocompleteFrame.ZIndex = 5
local AutoCompLayout = Instance.new("UIListLayout", AutocompleteFrame)

-- 4. Grupos
local GroupFrame = Instance.new("Frame", ContentArea)
GroupFrame.Size = UDim2.new(1, 0, 1, 0)
GroupFrame.BackgroundTransparency = 1
GroupFrame.Visible = false
local GroupCreateBtn = Instance.new("TextButton", GroupFrame)
GroupCreateBtn.Size = UDim2.new(1, 0, 0, 35)
GroupCreateBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
GroupCreateBtn.Text = "Criar Novo Grupo"
GroupCreateBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", GroupCreateBtn).CornerRadius = UDim.new(0, 6)

local GroupScroll = Instance.new("ScrollingFrame", GroupFrame)
GroupScroll.Size = UDim2.new(1, 0, 1, -45)
GroupScroll.Position = UDim2.new(0, 0, 0, 45)
GroupScroll.BackgroundTransparency = 1
local GroupLayout = Instance.new("UIListLayout", GroupScroll)

-- 5. Ações (Clone)
local ActionsFrame = Instance.new("Frame", ContentArea)
ActionsFrame.Size = UDim2.new(1, 0, 1, 0)
ActionsFrame.BackgroundTransparency = 1
ActionsFrame.Visible = false
local CloneBtn = Instance.new("TextButton", ActionsFrame)
CloneBtn.Size = UDim2.new(1, 0, 0, 40)
CloneBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 210)
CloneBtn.Text = "Enviar Convite de Clone"
CloneBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", CloneBtn).CornerRadius = UDim.new(0, 6)

-- ==========================================
-- PAINEL DE CONFIGURAÇÕES (GEAR) E MENUS EXTRAS
-- ==========================================
local ConfigFrame = Instance.new("Frame", MainFrame)
ConfigFrame.Size = UDim2.new(1, 0, 1, 0)
ConfigFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
ConfigFrame.Visible = false
ConfigFrame.ZIndex = 10

local ConfigTitle = Instance.new("TextLabel", ConfigFrame)
ConfigTitle.Size = UDim2.new(1, 0, 0, 40)
ConfigTitle.Text = "Configurações da Interface"
ConfigTitle.TextColor3 = Color3.new(1,1,1)
ConfigTitle.BackgroundTransparency = 1

local SizeLabel = Instance.new("TextLabel", ConfigFrame)
SizeLabel.Size = UDim2.new(1, 0, 0, 30)
SizeLabel.Position = UDim2.new(0, 0, 0, 60)
SizeLabel.Text = "Menu Size:"
SizeLabel.TextColor3 = Color3.new(1,1,1)
SizeLabel.BackgroundTransparency = 1

local SizeMinus = Instance.new("TextButton", ConfigFrame)
SizeMinus.Size = UDim2.new(0, 30, 0, 30)
SizeMinus.Position = UDim2.new(0.5, -90, 0, 100)
SizeMinus.Text = "-"
SizeMinus.BackgroundColor3 = Color3.fromRGB(40,40,50)
SizeMinus.TextColor3 = Color3.new(1,1,1)

local SizeDisplay = Instance.new("TextBox", ConfigFrame)
SizeDisplay.Size = UDim2.new(0, 100, 0, 30)
SizeDisplay.Position = UDim2.new(0.5, -50, 0, 100)
SizeDisplay.Text = tostring(db_settings.UIScale)
SizeDisplay.BackgroundColor3 = Color3.fromRGB(30,30,40)
SizeDisplay.TextColor3 = Color3.new(1,1,1)

local SizePlus = Instance.new("TextButton", ConfigFrame)
SizePlus.Size = UDim2.new(0, 30, 0, 30)
SizePlus.Position = UDim2.new(0.5, 60, 0, 100)
SizePlus.Text = "+"
SizePlus.BackgroundColor3 = Color3.fromRGB(40,40,50)
SizePlus.TextColor3 = Color3.new(1,1,1)

local SizeReset = Instance.new("TextButton", ConfigFrame)
SizeReset.Size = UDim2.new(0, 100, 0, 30)
SizeReset.Position = UDim2.new(0.5, -50, 0, 140)
SizeReset.Text = "Resetar"
SizeReset.BackgroundColor3 = Color3.fromRGB(60,60,70)
SizeReset.TextColor3 = Color3.new(1,1,1)

local CloseConfig = Instance.new("TextButton", ConfigFrame)
CloseConfig.Size = UDim2.new(0, 100, 0, 30)
CloseConfig.Position = UDim2.new(0.5, -50, 1, -50)
CloseConfig.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
CloseConfig.Text = "Voltar"
CloseConfig.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", CloseConfig).CornerRadius = UDim.new(0,6)

-- Menus de Figurinhas
local StickerMenu = Instance.new("Frame", MainFrame)
StickerMenu.Size = UDim2.new(1, -20, 0, 200)
StickerMenu.Position = UDim2.new(0, 10, 1, -240)
StickerMenu.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
StickerMenu.Visible = false
StickerMenu.ZIndex = 8
Instance.new("UICorner", StickerMenu).CornerRadius = UDim.new(0, 10)

local StickerScroll = Instance.new("ScrollingFrame", StickerMenu)
StickerScroll.Size = UDim2.new(1, -10, 1, -10)
StickerScroll.Position = UDim2.new(0, 5, 0, 5)
StickerScroll.BackgroundTransparency = 1
local StickerGrid = Instance.new("UIGridLayout", StickerScroll)
StickerGrid.CellSize = UDim2.new(0, 60, 0, 60)
StickerGrid.CellPadding = UDim2.new(0, 5, 0, 5)

-- ==========================================
-- LÓGICA DE INTERFACE E EVENTOS BÁSICOS
-- ==========================================
local function SwitchTab(tab)
    SearchFrame.Visible = (tab == "search")
    NotifFrame.Visible = (tab == "notif")
    ChatFrame.Visible = (tab == "chat")
    GroupFrame.Visible = (tab == "group")
    ActionsFrame.Visible = (tab == "actions")
    StickerMenu.Visible = false
end

SearchFriendsBtn.MouseButton1Click:Connect(function() SwitchTab("search") end)
NotifBtn.MouseButton1Click:Connect(function() SwitchTab("notif") end)
ChatBtn.MouseButton1Click:Connect(function() SwitchTab("chat") end)
GroupBtn.MouseButton1Click:Connect(function() SwitchTab("group") end)
ActionsBtn.MouseButton1Click:Connect(function() SwitchTab("actions") end)

MinimizeTopBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinimizedBtn.Visible = true
end)

MinimizedBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MinimizedBtn.Visible = false
end)

ConfigBtn.MouseButton1Click:Connect(function() ConfigFrame.Visible = true end)
CloseConfig.MouseButton1Click:Connect(function() ConfigFrame.Visible = false end)

local function updateScale(newScale)
    UIScale.Scale = newScale
    SizeDisplay.Text = tostring(newScale)
    db_settings.UIScale = newScale
    SaveData("settings", db_settings)
end

SizeMinus.MouseButton1Click:Connect(function() updateScale(math.max(0.5, UIScale.Scale - 0.1)) end)
SizePlus.MouseButton1Click:Connect(function() updateScale(math.min(2.0, UIScale.Scale + 0.1)) end)
SizeReset.MouseButton1Click:Connect(function() updateScale(1.0) end)
SizeDisplay.FocusLost:Connect(function()
    local val = tonumber(SizeDisplay.Text)
    if val then updateScale(val) end
end)

StickerBtn.MouseButton1Click:Connect(function()
    StickerMenu.Visible = not StickerMenu.Visible
end)

-- ==========================================
-- WEBSOCKET & SISTEMA CENTRAL
-- ==========================================
local ws = nil
local activeChatId = nil
local activeGroupId = nil
local activeClone = nil
local clonedRig = nil
local onlineUsers = {}

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function addChatMessage(sender, text, isSystem)
    local msg = Instance.new("TextLabel", ChatLog)
    msg.Size = UDim2.new(1, -10, 0, 0)
    msg.BackgroundTransparency = 1
    msg.Text = (isSystem and "⚙️ " or (sender .. ": ")) .. text
    msg.TextColor3 = isSystem and Color3.fromRGB(150, 150, 255) or Color3.fromRGB(240, 240, 240)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 13
    msg.TextWrapped = true
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.AutomaticSize = Enum.AutomaticSize.Y
    
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
end

local function loadChatHistory(id)
    for _, child in ipairs(ChatLog:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    if db_history[id] then
        for _, msgData in ipairs(db_history[id]) do
            addChatMessage(msgData.sender, msgData.message, false)
        end
    end
end

-- ==========================================
-- COMANDOS E ENVIO DE MENSAGENS (COM PROTEÇÃO DO TECLADO)
-- ==========================================
ChatInputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local txt = ChatInputBox.Text
        if txt == "" then return end
        
        local isCommand = false
        
        if txt:match("^/invite @") then
            isCommand = true
            local targetNick = txt:gsub("/invite @", "")
            local found = false
            for uid, data in pairs(db_friends) do
                if data.username:lower() == targetNick:lower() then
                    sendWS({type = "chat_invite", targetId = uid, sender = LocalPlayer.Name, senderId = tostring(LocalPlayer.UserId)})
                    addChatMessage("Sistema", "Convite enviado para " .. data.username, true)
                    found = true
                    break
                end
            end
            if not found then addChatMessage("Erro", "Amigo não encontrado.", true) end
            
        elseif txt:match("^//invitegp @") then
            isCommand = true
            if not activeGroupId then
                addChatMessage("Erro", "Você não está em um grupo ativo.", true)
            else
                local targetNick = txt:gsub("//invitegp @", "")
                for uid, data in pairs(db_friends) do
                    if data.username:lower() == targetNick:lower() then
                        sendWS({type = "group_invite", targetId = uid, groupId = activeGroupId, sender = LocalPlayer.Name})
                        addChatMessage("Sistema", "Convite de grupo enviado.", true)
                    end
                end
            end
            
        elseif txt:match("^//ban @") or txt:match("^//kick @") or txt:match("^//unban @") then
            isCommand = true
            local cmd, targetNick = txt:match("^(//%w+) @(.*)")
            if activeGroupId then
                for uid, data in pairs(db_friends) do
                    if data.username:lower() == targetNick:lower() then
                        local wsType = cmd == "//ban" and "group_ban" or (cmd == "//kick" and "group_kick" or "group_unban")
                        sendWS({type = wsType, targetId = uid, groupId = activeGroupId})
                    end
                end
            end
            
        elseif txt == "//leave" then
            isCommand = true
            activeChatId = nil
            activeGroupId = nil
            addChatMessage("Sistema", "Você saiu do bate-papo/grupo.", true)
            
        elseif txt == "//deletegp" then
            isCommand = true
            addChatMessage("Sistema", "Deseja deletar? Escreva //sim ou //nao", true)
            -- A lógica de confirmação poderia setar uma variável de estado aguardando
        end
        
        -- Envio normal
        if not isCommand then
            if not activeChatId and not activeGroupId then
                addChatMessage("Erro", "Você não está conectado a um bate-papo ou grupo. Use /invite ou crie um grupo.", true)
            else
                local payload = {
                    type = "chat_message",
                    targetId = activeChatId,
                    groupId = activeGroupId,
                    sender = LocalPlayer.Name,
                    senderId = tostring(LocalPlayer.UserId),
                    message = txt
                }
                sendWS(payload)
                
                local saveId = activeGroupId or activeChatId
                if saveId then
                    if not db_history[saveId] then db_history[saveId] = {} end
                    table.insert(db_history[saveId], payload)
                    SaveData("history", db_history)
                end
            end
        end
        
        ChatInputBox.Text = ""
    end
end)

-- Autocomplete do TextBox
ChatInputBox:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = ChatInputBox.Text
    if txt:match("^/invite @") or txt:match("^//invitegp @") or txt:match("^//ban @") or txt:match("^//kick @") then
        local query = txt:match("@(.*)"):lower()
        AutocompleteFrame.Visible = true
        for _, c in ipairs(AutocompleteFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        
        for uid, data in pairs(db_friends) do
            if data.username:lower():find(query) then
                local btn = Instance.new("TextButton", AutocompleteFrame)
                btn.Size = UDim2.new(1, 0, 0, 30)
                btn.Text = " " .. data.username
                btn.TextColor3 = Color3.new(1,1,1)
                btn.BackgroundTransparency = 1
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.MouseButton1Click:Connect(function()
                    local prefix = txt:match("^(.*@)")
                    ChatInputBox.Text = prefix .. data.username
                    ChatInputBox:CaptureFocus()
                    AutocompleteFrame.Visible = false
                end)
            end
        end
    else
        AutocompleteFrame.Visible = false
    end
end)

-- ==========================================
-- SISTEMA DE AMIZADES (PESQUISA E NOTIF)
-- ==========================================
local function createFriendCard(user, isSearch)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 50)
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    
    local img = Instance.new("ImageLabel", card)
    img.Size = UDim2.new(0, 40, 0, 40)
    img.Position = UDim2.new(0, 5, 0, 5)
    img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. user.userId .. "&w=150&h=150"
    img.BackgroundTransparency = 1
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)
    
    local name = Instance.new("TextLabel", card)
    name.Size = UDim2.new(1, -120, 1, 0)
    name.Position = UDim2.new(0, 55, 0, 0)
    name.Text = user.username .. " (@" .. user.username .. ")"
    name.TextColor3 = Color3.new(1,1,1)
    name.BackgroundTransparency = 1
    name.TextXAlignment = Enum.TextXAlignment.Left
    
    if isSearch then
        local addBtn = Instance.new("TextButton", card)
        addBtn.Size = UDim2.new(0, 60, 0, 30)
        addBtn.Position = UDim2.new(1, -65, 0, 10)
        addBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        addBtn.Text = "Adicionar"
        addBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
        
        addBtn.MouseButton1Click:Connect(function()
            sendWS({type = "friend_request", targetId = user.userId, sender = LocalPlayer.Name, senderId = tostring(LocalPlayer.UserId)})
            addBtn.Text = "Enviado"
            addBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end)
    end
    return card
end

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text:lower()
    for _, c in ipairs(SearchScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    if query == "" then return end
    
    for _, user in ipairs(onlineUsers) do
        if user.userId ~= tostring(LocalPlayer.UserId) and user.username:lower():find(query) then
            local card = createFriendCard(user, true)
            card.Parent = SearchScroll
        end
    end
    SearchScroll.CanvasSize = UDim2.new(0, 0, 0, SearchLayout.AbsoluteContentSize.Y + 10)
end)

local function receiveNotif(msgText, onAccept, onDecline)
    local card = Instance.new("Frame", NotifScroll)
    card.Size = UDim2.new(1, -10, 0, 60)
    card.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    
    local txt = Instance.new("TextLabel", card)
    txt.Size = UDim2.new(1, -10, 0, 30)
    txt.Position = UDim2.new(0, 5, 0, 5)
    txt.Text = msgText
    txt.TextColor3 = Color3.new(1,1,1)
    txt.BackgroundTransparency = 1
    
    local accept = Instance.new("TextButton", card)
    accept.Size = UDim2.new(0, 80, 0, 20)
    accept.Position = UDim2.new(0, 5, 1, -25)
    accept.BackgroundColor3 = Color3.fromRGB(40, 120, 200)
    accept.Text = "Aceitar"
    accept.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", accept).CornerRadius = UDim.new(0,4)
    
    local decline = Instance.new("TextButton", card)
    decline.Size = UDim2.new(0, 80, 0, 20)
    decline.Position = UDim2.new(0, 95, 1, -25)
    decline.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
    decline.Text = "Recusar"
    decline.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", decline).CornerRadius = UDim.new(0,4)
    
    accept.MouseButton1Click:Connect(function()
        if onAccept then onAccept() end
        card:Destroy()
    end)
    decline.MouseButton1Click:Connect(function()
        if onDecline then onDecline() end
        card:Destroy()
    end)
end

-- ==========================================
-- CLONE CROSS-GAME & ANIMAÇÕES R6/R15
-- ==========================================
local function BuildCloneRig(targetUserId)
    pcall(function()
        if clonedRig then clonedRig:Destroy() end
        clonedRig = Players:CreateHumanoidModelFromUserId(targetUserId)
        clonedRig.Parent = workspace
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local targetPos = hrp.CFrame * CFrame.new(0, 0, -4)
            clonedRig:SetPrimaryPartCFrame(CFrame.lookAt(targetPos.Position, hrp.Position))
        end
        addChatMessage("Sistema", "Clone perfeitamente espelhado carregado.", true)
    end)
end

local function SyncCloneData()
    if not activeClone or not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    local anims = {}
    for _, track in pairs(hum:GetPlayingAnimationTracks()) do
        table.insert(anims, track.Animation.AnimationId)
    end
    
    sendWS({
        type = "sync_clone",
        targetId = activeClone,
        cframe = {x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z, rx = hrp.Orientation.X, ry = hrp.Orientation.Y, rz = hrp.Orientation.Z},
        animations = anims
    })
end

RunService.Heartbeat:Connect(function()
    if tick() % 0.1 < 0.05 and activeClone then
        SyncCloneData()
    end
end)

CloneBtn.MouseButton1Click:Connect(function()
    if activeChatId then
        sendWS({type = "clone_invite", targetId = activeChatId, senderId = tostring(LocalPlayer.UserId)})
        addChatMessage("Sistema", "Convite de clone enviado.", true)
    else
        addChatMessage("Erro", "Conecte-se a um bate-papo 1x1 primeiro.", true)
    end
end)

-- ==========================================
-- RECEPÇÃO WEBSOCKET
-- ==========================================
local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "user_list" then
            onlineUsers = data.users
            
        elseif data.type == "chat_message" then
            local saveId = data.groupId or data.senderId
            if saveId == activeChatId or saveId == activeGroupId or data.senderId == tostring(LocalPlayer.UserId) then
                addChatMessage(data.sender, data.message, false)
            end
            if saveId then
                if not db_history[saveId] then db_history[saveId] = {} end
                table.insert(db_history[saveId], data)
                SaveData("history", db_history)
            end
            
        elseif data.type == "friend_request" then
            receiveNotif(data.sender .. " te enviou pedido de amizade.", 
                function() 
                    db_friends[data.senderId] = {username = data.sender}
                    SaveData("friends", db_friends)
                    sendWS({type = "friend_accept", targetId = data.senderId, senderId = tostring(LocalPlayer.UserId), sender = LocalPlayer.Name})
                end,
                function() sendWS({type = "friend_decline", targetId = data.senderId}) end
            )
            
        elseif data.type == "friend_accept" then
            db_friends[data.senderId] = {username = data.sender}
            SaveData("friends", db_friends)
            receiveNotif(data.sender .. " aceitou sua amizade!", nil, nil)
            
        elseif data.type == "chat_invite" then
            receiveNotif("Convite de bate-papo de " .. data.sender, 
                function()
                    activeChatId = data.senderId
                    activeGroupId = nil
                    SwitchTab("chat")
                    loadChatHistory(activeChatId)
                    addChatMessage("Sistema", "Você se conectou ao bate-papo de " .. data.sender, true)
                end
            )
            
        elseif data.type == "group_sys_msg" then
            addChatMessage("Grupo", data.msg, true)
            
        elseif data.type == "clone_invite" then
            receiveNotif("Convite de Clone de " .. data.senderId, 
                function()
                    activeClone = data.senderId
                    ActionsBtn.Visible = true
                    BuildCloneRig(data.senderId)
                end
            )
            
        elseif data.type == "sync_clone" and clonedRig then
            local cf = data.cframe
            -- Interpolação suave (Tween) para as posições do clone
            TweenService:Create(clonedRig.PrimaryPart, TweenInfo.new(0.1), {CFrame = CFrame.new(cf.x, cf.y, cf.z) * CFrame.Angles(math.rad(cf.rx), math.rad(cf.ry), math.rad(cf.rz))}):Play()
        end
    end)
    
    sendWS({ type = "register", userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name })
end

print("Delta Universal carregado. Diretório de Dados Local: " .. folderName)
