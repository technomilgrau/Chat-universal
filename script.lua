local RENDER_WEBSOCKET_URL = "wss://chat-universal-k9at.onrender.com"

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SISTEMA DE ARQUIVOS LOCAL (Mbchat_dados)
-- ==========================================
local folderName = "Mbchat_dados"
if not isfolder(folderName) then makefolder(folderName) end
if not isfolder(folderName .. "/stickers") then makefolder(folderName .. "/stickers") end
if not isfolder(folderName .. "/backgrounds") then makefolder(folderName .. "/backgrounds") end

local function saveData(file, data) writefile(folderName .. "/" .. file, HttpService:JSONEncode(data)) end
local function loadData(file, default)
    if isfile(folderName .. "/" .. file) then
        local s, r = pcall(function() return HttpService:JSONDecode(readfile(folderName .. "/" .. file)) end)
        if s then return r end
    end
    return default
end

local db = {
    friends = loadData("friends.json", {}),
    chats = loadData("chats.json", {}),
    settings = loadData("settings.json", { scale = 1, bg = "nenhuma", pos = {0.5, -240, 0.5, -165} }),
    recentStickers = loadData("recentStickers.json", {})
}

-- ==========================================
-- UI CORE
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaChatSystem"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

local UIScale = Instance.new("UIScale", ScreenGui)
UIScale.Scale = db.settings.scale

-- Botão Bolinha "D" (Minimizado)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 50, 0, 50)
MinBtn.Position = UDim2.new(db.settings.pos[1], db.settings.pos[2], db.settings.pos[3], db.settings.pos[4])
MinBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MinBtn.Text = "D"
MinBtn.TextColor3 = Color3.fromRGB(0, 130, 210)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 24
MinBtn.Visible = false
MinBtn.Active = true
MinBtn.Draggable = true
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)
MinBtn.Parent = ScreenGui

-- Main Menu
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 330)
MainFrame.Position = MinBtn.Position
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
MainFrame.Parent = ScreenGui

-- Background
local BgImage = Instance.new("ImageLabel", MainFrame)
BgImage.Size = UDim2.new(1, 0, 1, 0)
BgImage.BackgroundTransparency = 1
BgImage.ImageTransparency = 0.7
BgImage.ZIndex = 0
if db.settings.bg ~= "nenhuma" and isfile(folderName .. "/backgrounds/" .. db.settings.bg) then
    BgImage.Image = getcustomasset(folderName .. "/backgrounds/" .. db.settings.bg)
end

-- Topbar
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Header.ZIndex = 2
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA CHAT V3"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local BtnConfig = Instance.new("TextButton", Header)
BtnConfig.Size = UDim2.new(0, 30, 0, 30)
BtnConfig.Position = UDim2.new(1, -75, 0, 5)
BtnConfig.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BtnConfig.Text = "⚙"
BtnConfig.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", BtnConfig).CornerRadius = UDim.new(0, 5)

local BtnMinimize = Instance.new("TextButton", Header)
BtnMinimize.Size = UDim2.new(0, 30, 0, 30)
BtnMinimize.Position = UDim2.new(1, -40, 0, 5)
BtnMinimize.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BtnMinimize.Text = "-"
BtnMinimize.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", BtnMinimize).CornerRadius = UDim.new(0, 5)

-- Lógica de Minimizar
BtnMinimize.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinBtn.Visible = true
    db.settings.pos = {MainFrame.Position.X.Scale, MainFrame.Position.X.Offset, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset}
    saveData("settings.json", db.settings)
end)
MinBtn.MouseButton1Click:Connect(function()
    MinBtn.Visible = false
    MainFrame.Position = MinBtn.Position
    MainFrame.Visible = true
end)

-- Abas
local TabHolder = Instance.new("Frame", MainFrame)
TabHolder.Size = UDim2.new(1, -20, 0, 30)
TabHolder.Position = UDim2.new(0, 10, 0, 48)
TabHolder.BackgroundTransparency = 1
local UIListLayoutTabs = Instance.new("UIListLayout", TabHolder)
UIListLayoutTabs.FillDirection = Enum.FillDirection.Horizontal
UIListLayoutTabs.Padding = UDim.new(0, 8)

local function createTabBtn(name)
    local b = Instance.new("TextButton", TabHolder)
    b.Size = UDim2.new(0, 105, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    b.Text = name
    b.TextColor3 = Color3.fromRGB(200, 200, 210)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local FriendsTabBtn = createTabBtn("Procurar Amigos")
local NotifsTabBtn = createTabBtn("Notificações")
local ChatTabBtn = createTabBtn("Bate-Papo")

-- Containers
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1

local FriendsFrame = Instance.new("Frame", ContentArea)
FriendsFrame.Size = UDim2.new(1, 0, 1, 0)
FriendsFrame.BackgroundTransparency = 1

local SearchBar = Instance.new("TextBox", FriendsFrame)
SearchBar.Size = UDim2.new(1, 0, 0, 30)
SearchBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
SearchBar.PlaceholderText = " Pesquisar usuário..."
SearchBar.Text = ""
SearchBar.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(0, 6)

local CreateGroupBtn = Instance.new("TextButton", FriendsFrame)
CreateGroupBtn.Size = UDim2.new(1, 0, 0, 30)
CreateGroupBtn.Position = UDim2.new(0, 0, 1, -30)
CreateGroupBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 210)
CreateGroupBtn.Text = "Criar Grupo"
CreateGroupBtn.TextColor3 = Color3.new(1,1,1)
CreateGroupBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", CreateGroupBtn).CornerRadius = UDim.new(0, 6)

local UsersList = Instance.new("ScrollingFrame", FriendsFrame)
UsersList.Size = UDim2.new(1, 0, 1, -70)
UsersList.Position = UDim2.new(0, 0, 0, 35)
UsersList.BackgroundTransparency = 1
UsersList.ScrollBarThickness = 4
local UsersLayout = Instance.new("UIListLayout", UsersList)
UsersLayout.Padding = UDim.new(0, 6)

local NotifsFrame = Instance.new("ScrollingFrame", ContentArea)
NotifsFrame.Size = UDim2.new(1, 0, 1, 0)
NotifsFrame.BackgroundTransparency = 1
NotifsFrame.Visible = false
NotifsFrame.ScrollBarThickness = 4
local NotifsLayout = Instance.new("UIListLayout", NotifsFrame)
NotifsLayout.Padding = UDim.new(0, 6)

local ChatFrame = Instance.new("Frame", ContentArea)
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false

local ChatLog = Instance.new("ScrollingFrame", ChatFrame)
ChatLog.Size = UDim2.new(1, 0, 1, -35)
ChatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ChatLog.BackgroundTransparency = 0.4
ChatLog.BorderSizePixel = 0
ChatLog.ScrollBarThickness = 4
Instance.new("UICorner", ChatLog).CornerRadius = UDim.new(0, 6)
local ChatLayout = Instance.new("UIListLayout", ChatLog)
ChatLayout.Padding = UDim.new(0, 4)

local ChatInputArea = Instance.new("Frame", ChatFrame)
ChatInputArea.Size = UDim2.new(1, 0, 0, 30)
ChatInputArea.Position = UDim2.new(0, 0, 1, -30)
ChatInputArea.BackgroundTransparency = 1

local ChatInput = Instance.new("TextBox", ChatInputArea)
ChatInput.Size = UDim2.new(1, -75, 1, 0)
ChatInput.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInput.PlaceholderText = " /invite, //leave, //invitegp..."
ChatInput.Text = ""
ChatInput.TextColor3 = Color3.new(1,1,1)
ChatInput.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 6)

local StickerBtn = Instance.new("TextButton", ChatInputArea)
StickerBtn.Size = UDim2.new(0, 30, 0, 30)
StickerBtn.Position = UDim2.new(1, -70, 0, 0)
StickerBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
StickerBtn.Text = "🙂"
Instance.new("UICorner", StickerBtn).CornerRadius = UDim.new(0, 6)

local CloneBtn = Instance.new("TextButton", ChatInputArea)
CloneBtn.Size = UDim2.new(0, 35, 0, 30)
CloneBtn.Position = UDim2.new(1, -35, 0, 0)
CloneBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 180)
CloneBtn.Text = "Clone"
CloneBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", CloneBtn).CornerRadius = UDim.new(0, 6)

-- Painel de Configurações
local ConfigPanel = Instance.new("Frame", MainFrame)
ConfigPanel.Size = UDim2.new(1, 0, 1, 0)
ConfigPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
ConfigPanel.Visible = false
ConfigPanel.ZIndex = 10

local CfgTitle = Instance.new("TextLabel", ConfigPanel)
CfgTitle.Size = UDim2.new(1, 0, 0, 40)
CfgTitle.Text = "Configurações"
CfgTitle.TextColor3 = Color3.new(1,1,1)
CfgTitle.BackgroundTransparency = 1
CfgTitle.Font = Enum.Font.GothamBold

local function createCfgBtn(txt, pos, cb)
    local b = Instance.new("TextButton", ConfigPanel)
    b.Size = UDim2.new(0, 100, 0, 30)
    b.Position = pos
    b.Text = txt
    b.BackgroundColor3 = Color3.fromRGB(40,40,50)
    b.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
end
createCfgBtn("Aumentar UI", UDim2.new(0.5, 10, 0.3, 0), function() UIScale.Scale = UIScale.Scale + 0.1 db.settings.scale = UIScale.Scale saveData("settings.json", db.settings) end)
createCfgBtn("Diminuir UI", UDim2.new(0.5, -110, 0.3, 0), function() UIScale.Scale = math.max(0.5, UIScale.Scale - 0.1) db.settings.scale = UIScale.Scale saveData("settings.json", db.settings) end)
createCfgBtn("Voltar", UDim2.new(0.5, -50, 0.8, 0), function() ConfigPanel.Visible = false end)

BtnConfig.MouseButton1Click:Connect(function() ConfigPanel.Visible = true end)

local function switchTab(tab)
    FriendsFrame.Visible = (tab == "friends")
    NotifsFrame.Visible = (tab == "notifs")
    ChatFrame.Visible = (tab == "chat")
end
FriendsTabBtn.MouseButton1Click:Connect(function() switchTab("friends") end)
NotifsTabBtn.MouseButton1Click:Connect(function() switchTab("notifs") end)
ChatTabBtn.MouseButton1Click:Connect(function() switchTab("chat") end)

-- ==========================================
-- GERENCIAMENTO WEBSOCKET E LÓGICA
-- ==========================================
local ws = nil
local currentChatId = nil
local currentGroupId = nil
local isGroupHost = false

-- Variáveis Clone
local cloneActive = false
local cloneTargetId = nil
local cloneModel = nil

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function appendChat(sender, text, isSystem)
    local msgLabel = Instance.new("TextLabel", ChatLog)
    msgLabel.Size = UDim2.new(1, -10, 0, 24)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = "  " .. (isSystem and "⚙ " or sender .. ": ") .. text
    msgLabel.TextColor3 = isSystem and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(230, 230, 240)
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.Font = isSystem and Enum.Font.GothamBold or Enum.Font.Gotham
    msgLabel.TextSize = 13
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
    
    if cloneActive and cloneTargetId and sender == LocalPlayer.Name then
        sendWS({type = "sync_transform", targetId = cloneTargetId, chatBubble = text})
    end
end

-- Fix Mobile: Texto só some se apertar enviar (enterPressed)
ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and ChatInput.Text ~= "" then
        local msg = ChatInput.Text
        local isCmd = false
        
        -- COMANDOS DE CHAT E GRUPO
        if string.sub(msg, 1, 8) == "/invite " then
            isCmd = true
            -- AQUI ENTRA A LOGICA DE BUSCAR ID PELO NOME E ENVIAR chat_invite
            appendChat("Sistema", "Convite enviado. (Precisa do ID na lógica real)", true)
        elseif msg == "//leave" then
            isCmd = true
            if isGroupHost then
                appendChat("Sistema", "Você é o anfitrião. Use //deletegp para apagar.", true)
            else
                sendWS({ type = "chat_leave" })
                currentChatId = nil
                currentGroupId = nil
                appendChat("Sistema", "Você saiu do chat/grupo.", true)
            end
        elseif string.sub(msg, 1, 10) == "//invitegp" then
            isCmd = true
            appendChat("Sistema", "Comando de invite de grupo detectado.", true)
        elseif msg == "//deletegp" then
            isCmd = true
            if currentGroupId and isGroupHost then
                sendWS({ type = "delete_group", groupId = currentGroupId })
            end
        end

        if not isCmd then
            sendWS({ type = "chat_msg", message = msg })
            appendChat(LocalPlayer.Name, msg, false)
            table.insert(db.chats, {sender = LocalPlayer.Name, text = msg})
            saveData("chats.json", db.chats)
        end
        ChatInput.Text = "" 
    end
end)

-- Sistema de Convite de Clone
CloneBtn.MouseButton1Click:Connect(function()
    if currentChatId then
        sendWS({type = "clone_invite", targetId = currentChatId})
        appendChat("Sistema", "Convite de clone enviado!", true)
    else
        appendChat("Sistema", "Você precisa estar em um chat 1v1 para usar o clone.", true)
    end
end)

local function buildCloneModel(userId)
    -- Cria um Dummy básico (Em um script completo, usar GetHumanoidDescription)
    local dummy = Instance.new("Model")
    dummy.Name = "DeltaClone_"..userId
    local hrp = Instance.new("Part", dummy)
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2,2,1)
    hrp.Transparency = 0.5
    hrp.Color = Color3.new(0,0,1)
    hrp.Anchored = true
    hrp.CanCollide = false
    dummy.PrimaryPart = hrp
    
    local head = Instance.new("Part", dummy)
    head.Name = "Head"
    head.Size = Vector3.new(1,1,1)
    head.Position = hrp.Position + Vector3.new(0, 1.5, 0)
    head.Anchored = true
    head.CanCollide = false
    local weld = Instance.new("WeldConstraint", dummy)
    weld.Part0 = hrp weld.Part1 = head
    
    dummy.Parent = workspace
    return dummy
end

local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "user_list" then
            -- Atualiza interface de usuários...
        elseif data.type == "chat_connected" then
            currentChatId = data.targetId
            switchTab("chat")
            appendChat("Sistema", "Você conectou com " .. data.targetName, true)
            
            -- Carrega histórico
            for _, c in ipairs(db.chats) do
                appendChat(c.sender, c.text, false)
            end
            
        elseif data.type == "chat_msg" or data.type == "group_msg" then
            appendChat(data.sender, data.message, false)
            table.insert(db.chats, {sender = data.sender, text = data.message})
            saveData("chats.json", db.chats)
            
        elseif data.type == "chat_ended" then
            appendChat("Sistema", data.reason, true)
            currentChatId = nil
            
        -- Lógica de Clones
        elseif data.type == "clone_invite" then
            -- Auto-aceita para testar a lógica (Na ui real teria o botão Sim/Não)
            sendWS({type = "clone_accept", targetId = data.fromId})
            appendChat("Sistema", data.fromName .. " convidou para clone. Aceito!", true)
            
        elseif data.type == "clone_accepted" then
            cloneActive = true
            cloneTargetId = data.fromId
            cloneModel = buildCloneModel(data.fromId)
            appendChat("Sistema", data.targetName .. " aceitou o clone!", true)
            
        elseif data.type == "sync_update" then
            if cloneModel and cloneModel.PrimaryPart then
                -- Atualiza a posição do boneco clone
                cloneModel.PrimaryPart.CFrame = CFrame.new(unpack(data.cframe))
                if data.chatBubble then
                    Chat:Chat(cloneModel:FindFirstChild("Head") or cloneModel.PrimaryPart, data.chatBubble, Enum.ChatColor.White)
                end
            end
        end
    end)
    
    sendWS({ type = "register", userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name })
end

-- Loop de Sincronização de Movimento (Heartbeat)
RunService.Heartbeat:Connect(function()
    if cloneActive and cloneTargetId and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local cf = LocalPlayer.Character.HumanoidRootPart.CFrame
        -- Envia um Array X,Y,Z para economizar banda no WebSocket
        sendWS({
            type = "sync_transform",
            targetId = cloneTargetId,
            cframe = {cf.X, cf.Y, cf.Z} 
        })
    end
end)
