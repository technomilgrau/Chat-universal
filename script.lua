local RENDER_WEBSOCKET_URL = "wss://chat-universal-online.onrender.com"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SISTEMA DE ARQUIVOS (PERSISTÊNCIA)
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
    return {}
end

local chatHistories = {}
local activeChatId = nil
local activeGroupId = nil
local allUsersCache = {}

-- ==========================================
-- INTERFACE GRÁFICA PRINCIPAL
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPairingMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 520, 0, 400)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Header & Controles de Janela
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
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

local function createTabButton(name, width)
    local btn = Instance.new("TextButton", TabHolder)
    btn.Size = UDim2.new(0, width, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SearchTabBtn = createTabButton("Procurar Amigos", 115)
local ChatTabBtn = createTabButton("Bate-Papo", 85)
local GroupTabBtn = createTabButton("Grupo", 70)
local NotifTabBtn = createTabButton("Notificações", 95)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1

-- ==========================================
-- CONTEÚDO DAS ABAS
-- ==========================================

-- 1. Procurar Amigos
local SearchFrame = Instance.new("Frame", ContentArea)
SearchFrame.Size = UDim2.new(1, 0, 1, 0)
SearchFrame.BackgroundTransparency = 1

local SearchBar = Instance.new("TextBox", SearchFrame)
SearchBar.Size = UDim2.new(1, 0, 0, 30)
SearchBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
SearchBar.PlaceholderText = " Pesquisar usuário (Ex: @lucas)..."
SearchBar.TextColor3 = Color3.new(1,1,1)
SearchBar.TextXAlignment = Enum.TextXAlignment.Left
SearchBar.ClearTextOnFocus = false
Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(0, 6)

local UsersScroll = Instance.new("ScrollingFrame", SearchFrame)
UsersScroll.Size = UDim2.new(1, 0, 1, -40)
UsersScroll.Position = UDim2.new(0, 0, 0, 40)
UsersScroll.BackgroundTransparency = 1
UsersScroll.ScrollBarThickness = 4
local UsersLayout = Instance.new("UIListLayout", UsersScroll)
UsersLayout.Padding = UDim.new(0, 6)

-- 2. Bate-Papo & Comandos
local ChatFrame = Instance.new("Frame", ContentArea)
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false

local ChatLog = Instance.new("ScrollingFrame", ChatFrame)
ChatLog.Size = UDim2.new(1, 0, 1, -40)
ChatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ChatLog.ScrollBarThickness = 4
Instance.new("UICorner", ChatLog).CornerRadius = UDim.new(0, 6)
local ChatLayout = Instance.new("UIListLayout", ChatLog)
ChatLayout.Padding = UDim.new(0, 4)

local ChatInputBox = Instance.new("Frame", ChatFrame)
ChatInputBox.Size = UDim2.new(1, 0, 0, 35)
ChatInputBox.Position = UDim2.new(0, 0, 1, -35)
ChatInputBox.BackgroundTransparency = 1

local ChatInput = Instance.new("TextBox", ChatInputBox)
ChatInput.Size = UDim2.new(1, -40, 1, 0)
ChatInput.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInput.PlaceholderText = "Digite uma mensagem ou /invite @nick..."
ChatInput.TextColor3 = Color3.new(1,1,1)
ChatInput.ClearTextOnFocus = false -- IMPEDE APAGAR AO FECHAR TECLADO
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 6)

local StickerBtn = Instance.new("TextButton", ChatInputBox)
StickerBtn.Size = UDim2.new(0, 35, 0, 35)
StickerBtn.Position = UDim2.new(1, -35, 0, 0)
StickerBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
StickerBtn.Text = "🙂"
Instance.new("UICorner", StickerBtn).CornerRadius = UDim.new(0, 6)

-- 3. Notificações
local NotifFrame = Instance.new("ScrollingFrame", ContentArea)
NotifFrame.Size = UDim2.new(1, 0, 1, 0)
NotifFrame.BackgroundTransparency = 1
NotifFrame.Visible = false
local NotifLayout = Instance.new("UIListLayout", NotifFrame)
NotifLayout.Padding = UDim.new(0, 6)

-- Navegação Visual
local function switchTab(tab)
    SearchFrame.Visible = (tab == "search")
    ChatFrame.Visible = (tab == "chat")
    NotifFrame.Visible = (tab == "notif")
end

SearchTabBtn.MouseButton1Click:Connect(function() switchTab("search") end)
ChatTabBtn.MouseButton1Click:Connect(function() switchTab("chat") end)
GroupTabBtn.MouseButton1Click:Connect(function() switchTab("chat") end) -- Usando mesma UI base para grupo
NotifTabBtn.MouseButton1Click:Connect(function() switchTab("notif") end)

-- ==========================================
-- LOGICA DE JANELA & CONFIGURAÇÕES
-- ==========================================
local isMinimized = false
local lastSize, lastPos

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        lastSize = MainFrame.Size
        lastPos = MainFrame.Position
        MainFrame.Size = UDim2.new(0, 50, 0, 50)
        Header.BackgroundTransparency = 1
        Title.Visible = false
        ConfigBtn.Visible = false
        TabHolder.Visible = false
        ContentArea.Visible = false
        MinBtn.Size = UDim2.new(1, 0, 1, 0)
        MinBtn.Position = UDim2.new(0, 0, 0, 0)
        MinBtn.Text = "D"
        MinBtn.TextSize = 24
        MainFrame:FindFirstChild("UICorner").CornerRadius = UDim.new(1, 0)
    else
        MainFrame.Size = lastSize
        MainFrame.Position = lastPos
        Header.BackgroundTransparency = 0
        Title.Visible = true
        ConfigBtn.Visible = true
        TabHolder.Visible = true
        ContentArea.Visible = true
        MinBtn.Size = UDim2.new(0, 30, 0, 30)
        MinBtn.Position = UDim2.new(1, -40, 0, 5)
        MinBtn.Text = "-"
        MinBtn.TextSize = 14
        MainFrame:FindFirstChild("UICorner").CornerRadius = UDim.new(0, 10)
    end
end)

-- ==========================================
-- WEBSOCKET & ROTEAMENTO DE MENSAGENS
-- ==========================================
local ws = nil
local activeClone = nil
local cloneConnection = nil

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function renderMessage(sender, text, isHistory)
    local msg = Instance.new("TextLabel", ChatLog)
    msg.Size = UDim2.new(1, -10, 0, 24)
    msg.BackgroundTransparency = 1
    msg.Text = "  ["..sender.."]: "..text
    msg.TextColor3 = isHistory and Color3.fromRGB(150, 150, 160) or Color3.new(1,1,1)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 13
    msg.TextXAlignment = Enum.TextXAlignment.Left
    
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
end

local function findUserIdByPartialName(partialName)
    local lowerPartial = string.lower(partialName)
    for _, u in ipairs(allUsersCache) do
        if string.find(string.lower(u.username), lowerPartial) then
            return u.userId
        end
    end
    return nil
end

-- Processador de Comandos
ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and ChatInput.Text ~= "" then
        local text = ChatInput.Text
        local args = string.split(text, " ")
        local cmd = args[1]:lower()

        if cmd == "/invite" and args[2] then
            local targetNick = string.gsub(args[2], "@", "")
            local id = findUserIdByPartialName(targetNick)
            if id then
                sendWS({ type = "chat_invite", targetId = id })
                renderMessage("Sistema", "Convite enviado para "..targetNick, false)
            else
                renderMessage("Sistema", "Usuário não encontrado online.", false)
            end

        elseif cmd == "//leave" then
            sendWS({ type = "leave_chat" })

        elseif cmd == "//invitegp" and args[2] then
            local targetNick = string.gsub(args[2], "@", "")
            local id = findUserIdByPartialName(targetNick)
            if id then sendWS({ type = "invite_group", targetId = id }) end

        elseif cmd == "//ban" or cmd == "//kick" then
            if args[2] then
                local id = findUserIdByPartialName(string.gsub(args[2], "@", ""))
                if id then sendWS({ type = "group_command", action = string.gsub(cmd, "//", ""), targetId = id }) end
            end
        else
            if activeChatId then
                sendWS({ type = "chat_message", message = text })
                if not chatHistories[activeChatId] then chatHistories[activeChatId] = {} end
                table.insert(chatHistories[activeChatId], {sender = LocalPlayer.Name, msg = text})
                saveJSON("chat_"..activeChatId, chatHistories[activeChatId])
            end
        end
        ChatInput.Text = "" -- Limpa APENAS após o envio bem-sucedido
    end
end)

local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "user_list" then
            allUsersCache = data.users
            -- Atualiza Search UI
            for _, c in ipairs(UsersScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for _, u in ipairs(data.users) do
                if u.userId ~= tostring(LocalPlayer.UserId) then
                    local card = Instance.new("Frame", UsersScroll)
                    card.Size = UDim2.new(1, -6, 0, 50)
                    card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
                    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
                    
                    local avatar = Instance.new("ImageLabel", card)
                    avatar.Size = UDim2.new(0, 40, 0, 40)
                    avatar.Position = UDim2.new(0, 5, 0, 5)
                    avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..u.userId.."&w=150&h=150"
                    avatar.BackgroundTransparency = 1
                    Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 8)
                    
                    local nameL = Instance.new("TextLabel", card)
                    nameL.Size = UDim2.new(1, -140, 1, 0)
                    nameL.Position = UDim2.new(0, 55, 0, 0)
                    nameL.BackgroundTransparency = 1
                    nameL.Text = u.username
                    nameL.TextColor3 = Color3.new(1,1,1)
                    nameL.TextXAlignment = Enum.TextXAlignment.Left
                    
                    local addBtn = Instance.new("TextButton", card)
                    addBtn.Size = UDim2.new(0, 75, 0, 30)
                    addBtn.Position = UDim2.new(1, -85, 0, 10)
                    addBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                    addBtn.Text = "Adicionar"
                    addBtn.TextColor3 = Color3.new(1,1,1)
                    Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
                    
                    addBtn.MouseButton1Click:Connect(function()
                        sendWS({ type = "friend_request", targetId = u.userId })
                        addBtn.Text = "Enviado"
                        addBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    end)
                end
            end
            
        elseif data.type == "friend_notification" or data.type == "chat_notification" then
            local nCard = Instance.new("Frame", NotifFrame)
            nCard.Size = UDim2.new(1, -6, 0, 45)
            nCard.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
            local l = Instance.new("TextLabel", nCard)
            l.Size = UDim2.new(1, -110, 1, 0)
            l.Position = UDim2.new(0, 10, 0, 0)
            l.Text = data.fromName .. (data.type == "friend_notification" and " enviou pedido de amizade" or " convidou pro chat")
            l.TextColor3 = Color3.new(1,1,1)
            l.BackgroundTransparency = 1
            l.TextXAlignment = Enum.TextXAlignment.Left
            
            local accBtn = Instance.new("TextButton", nCard)
            accBtn.Size = UDim2.new(0, 40, 0, 30)
            accBtn.Position = UDim2.new(1, -95, 0, 7)
            accBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
            accBtn.Text = "Sim"
            Instance.new("UICorner", accBtn).CornerRadius = UDim.new(0, 6)
            
            local recBtn = Instance.new("TextButton", nCard)
            recBtn.Size = UDim2.new(0, 40, 0, 30)
            recBtn.Position = UDim2.new(1, -50, 0, 7)
            recBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
            recBtn.Text = "Não"
            Instance.new("UICorner", recBtn).CornerRadius = UDim.new(0, 6)
            
            accBtn.MouseButton1Click:Connect(function()
                if data.type == "friend_notification" then
                    sendWS({ type = "friend_accept", targetId = data.fromId })
                else
                    sendWS({ type = "chat_accept", targetId = data.fromId })
                end
                nCard:Destroy()
            end)
            recBtn.MouseButton1Click:Connect(function() nCard:Destroy() end)
            
        elseif data.type == "chat_connected" then
            activeChatId = data.targetId
            switchTab("chat")
            renderMessage("Sistema", "Conectado ao bate-papo! Digite //leave para sair.", false)
            
            local hist = loadJSON("chat_"..activeChatId)
            for _, m in ipairs(hist) do renderMessage(m.sender, m.msg, true) end
            
        elseif data.type == "chat_receive" or data.type == "group_message" then
            renderMessage(data.sender, data.message, false)
            
        elseif data.type == "clone_start" then
            -- Sistema básico de Clonagem Rig. Sincroniza a CFrame via Heartbeat.
            if activeClone then activeClone:Destroy() end
            activeClone = Instance.new("Model", workspace)
            activeClone.Name = "Clone_"..data.targetId
            local root = Instance.new("Part", activeClone)
            root.Name = "HumanoidRootPart"
            root.Anchored = true
            root.Size = Vector3.new(2,2,1)
            root.Transparency = 0.5
            Instance.new("Humanoid", activeClone)
            
            if cloneConnection then cloneConnection:Disconnect() end
            cloneConnection = RunService.Heartbeat:Connect(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local pos = LocalPlayer.Character.HumanoidRootPart.CFrame
                    sendWS({ type = "clone_sync", targetId = data.targetId, cframe = {pos.X, pos.Y, pos.Z} })
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

-- Lógica de Pesquisa de Usuários
SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local text = string.lower(SearchBar.Text)
    for _, child in ipairs(UsersScroll:GetChildren()) do
        if child:IsA("Frame") then
            local nameLabel = child:FindFirstChildOfClass("TextLabel")
            if nameLabel then
                if text == "" or string.find(string.lower(nameLabel.Text), text) then
                    child.Visible = true
                else
                    child.Visible = false
                end
            end
        end
    end
end)
