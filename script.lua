local RENDER_WEBSOCKET_URL = "https://chat-universal-k9at.onrender.com/" -- COLOQUE SEU LINK AQUI

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- === BANCO DE DADOS LOCAL (JSON) ===
local folderName = "Mbchat_dados"
if isfolder and not isfolder(folderName) then makefolder(folderName) end

local function saveData(fileName, data)
    if writefile then
        writefile(folderName .. "/" .. fileName .. ".json", HttpService:JSONEncode(data))
    end
end

local function loadData(fileName)
    if isfile and isfile(folderName .. "/" .. fileName .. ".json") then
        local success, result = pcall(function() return HttpService:JSONDecode(readfile(folderName .. "/" .. fileName .. ".json")) end)
        if success then return result end
    end
    return {}
end

local chatHistory = loadData("history")
local friendsData = loadData("friends")
local settingsData = loadData("settings") or { uiScale = 1 }
local recentStickers = loadData("stickers")

-- === CONFIGURAÇÕES DE ASSETS (Coloque seus links do GitHub aqui) ===
local StickersList = {
    "rbxassetid://12345678", -- Exemplo: Troque por URLs ou IDs reais
    "rbxassetid://87654321"
}
local BackgroundsList = {
    "rbxassetid://111222333",
    "rbxassetid://444555666"
}

-- === CRIAÇÃO DA INTERFACE ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPairingAdvanced"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local UIScale = Instance.new("UIScale")
UIScale.Scale = settingsData.uiScale
UIScale.Parent = ScreenGui

-- Ícone Minimizador
local MinimizedBtn = Instance.new("TextButton")
MinimizedBtn.Size = UDim2.new(0, 50, 0, 50)
MinimizedBtn.Position = UDim2.new(0, 10, 0, 10)
MinimizedBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MinimizedBtn.Text = "D"
MinimizedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizedBtn.Font = Enum.Font.GothamBold
MinimizedBtn.TextSize = 24
MinimizedBtn.Visible = false
MinimizedBtn.Draggable = true
MinimizedBtn.Parent = ScreenGui
Instance.new("UICorner", MinimizedBtn).CornerRadius = UDim.new(1, 0)

-- Janela Principal
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 380)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Topbar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA ADVANCED CHAT"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Botão Configuração (Engrenagem)
local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Size = UDim2.new(0, 30, 0, 30)
SettingsBtn.Position = UDim2.new(1, -75, 0, 5)
SettingsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SettingsBtn.Text = "⚙"
SettingsBtn.TextColor3 = Color3.fromRGB(255,255,255)
SettingsBtn.Parent = Header
Instance.new("UICorner", SettingsBtn).CornerRadius = UDim.new(0,6)

-- Botão Minimizar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
CloseBtn.Text = "-"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,6)

-- Lógica Minimizar
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinimizedBtn.Visible = true
    MinimizedBtn.Position = UDim2.new(0, MainFrame.AbsolutePosition.X, 0, MainFrame.AbsolutePosition.Y)
end)
MinimizedBtn.MouseButton1Click:Connect(function()
    MinimizedBtn.Visible = false
    MainFrame.Visible = true
    MainFrame.Position = UDim2.new(0, MinimizedBtn.AbsolutePosition.X, 0, MinimizedBtn.AbsolutePosition.Y)
end)

-- Abas
local TabHolder = Instance.new("Frame")
TabHolder.Size = UDim2.new(1, -20, 0, 30)
TabHolder.Position = UDim2.new(0, 10, 0, 48)
TabHolder.BackgroundTransparency = 1
TabHolder.Parent = MainFrame

local UIListLayoutTabs = Instance.new("UIListLayout")
UIListLayoutTabs.FillDirection = Enum.FillDirection.Horizontal
UIListLayoutTabs.Padding = UDim.new(0, 5)
UIListLayoutTabs.Parent = TabHolder

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabHolder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SearchTabBtn = createTab("Procurar amigos")
local NotifTabBtn = createTab("Notificações")
local ChatTabBtn = createTab("Bate-papo")
local GroupTabBtn = createTab("Grupos")

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Painéis
local SearchFrame = Instance.new("Frame", ContentArea)
SearchFrame.Size = UDim2.new(1,0,1,0); SearchFrame.BackgroundTransparency = 1
local NotifFrame = Instance.new("ScrollingFrame", ContentArea)
NotifFrame.Size = UDim2.new(1,0,1,0); NotifFrame.BackgroundTransparency = 1; NotifFrame.Visible = false
local ChatFrame = Instance.new("Frame", ContentArea)
ChatFrame.Size = UDim2.new(1,0,1,0); ChatFrame.BackgroundTransparency = 1; ChatFrame.Visible = false
local GroupFrame = Instance.new("Frame", ContentArea)
GroupFrame.Size = UDim2.new(1,0,1,0); GroupFrame.BackgroundTransparency = 1; GroupFrame.Visible = false

local function switchTab(tab)
    SearchFrame.Visible = (tab == "search")
    NotifFrame.Visible = (tab == "notif")
    ChatFrame.Visible = (tab == "chat")
    GroupFrame.Visible = (tab == "group")
end
SearchTabBtn.MouseButton1Click:Connect(function() switchTab("search") end)
NotifTabBtn.MouseButton1Click:Connect(function() switchTab("notif") end)
ChatTabBtn.MouseButton1Click:Connect(function() switchTab("chat") end)
GroupTabBtn.MouseButton1Click:Connect(function() switchTab("group") end)

-- === ABA PROCURAR AMIGOS ===
local SearchBar = Instance.new("TextBox", SearchFrame)
SearchBar.Size = UDim2.new(1, 0, 0, 30)
SearchBar.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
SearchBar.PlaceholderText = "Pesquisar usuário..."
SearchBar.TextColor3 = Color3.fromRGB(255,255,255)
SearchBar.Text = ""
Instance.new("UICorner", SearchBar)

local UsersList = Instance.new("ScrollingFrame", SearchFrame)
UsersList.Size = UDim2.new(1, 0, 1, -35)
UsersList.Position = UDim2.new(0, 0, 0, 35)
UsersList.BackgroundTransparency = 1
local UsersLayout = Instance.new("UIListLayout", UsersList)
UsersLayout.Padding = UDim.new(0, 5)

-- === ABA BATE-PAPO ===
local ChatLog = Instance.new("ScrollingFrame", ChatFrame)
ChatLog.Size = UDim2.new(1, 0, 1, -40)
ChatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
local ChatLayout = Instance.new("UIListLayout", ChatLog)
ChatLayout.Padding = UDim.new(0, 4)

local ChatInputContainer = Instance.new("Frame", ChatFrame)
ChatInputContainer.Size = UDim2.new(1, 0, 0, 35)
ChatInputContainer.Position = UDim2.new(0, 0, 1, -35)
ChatInputContainer.BackgroundTransparency = 1

local ChatInput = Instance.new("TextBox", ChatInputContainer)
ChatInput.Size = UDim2.new(1, -40, 1, 0)
ChatInput.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInput.PlaceholderText = "Digite sua mensagem... (/invite @nick)"
ChatInput.TextColor3 = Color3.fromRGB(255,255,255)
ChatInput.Text = "" -- FIXED: Empty by default
Instance.new("UICorner", ChatInput)

local StickerBtn = Instance.new("TextButton", ChatInputContainer)
StickerBtn.Size = UDim2.new(0, 35, 0, 35)
StickerBtn.Position = UDim2.new(1, -35, 0, 0)
StickerBtn.BackgroundColor3 = Color3.fromRGB(40,40,50)
StickerBtn.Text = "🙂"
Instance.new("UICorner", StickerBtn)

-- Autocomplete UI
local AutoCompleteFrame = Instance.new("Frame", ChatFrame)
AutoCompleteFrame.Size = UDim2.new(0, 150, 0, 100)
AutoCompleteFrame.Position = UDim2.new(0, 5, 1, -140)
AutoCompleteFrame.BackgroundColor3 = Color3.fromRGB(40,40,50)
AutoCompleteFrame.Visible = false
Instance.new("UICorner", AutoCompleteFrame)
local AutoCompleteLayout = Instance.new("UIListLayout", AutoCompleteFrame)

-- === FUNÇÕES WEBSOCKET ===
local ws = nil
local activeContext = "private"
local hostRoomId = nil

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function addNotification(text, onAccept, onDecline)
    local card = Instance.new("Frame", NotifFrame)
    card.Size = UDim2.new(1, 0, 0, 50)
    card.BackgroundColor3 = Color3.fromRGB(28,28,34)
    Instance.new("UICorner", card)
    
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -90, 1, 0); lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextWrapped = true
    
    local accBtn = Instance.new("TextButton", card)
    accBtn.Size = UDim2.new(0, 40, 0, 30); accBtn.Position = UDim2.new(1, -85, 0, 10)
    accBtn.BackgroundColor3 = Color3.fromRGB(40,160,80); accBtn.Text = "V"
    accBtn.MouseButton1Click:Connect(function() onAccept() card:Destroy() end)
    
    local decBtn = Instance.new("TextButton", card)
    decBtn.Size = UDim2.new(0, 40, 0, 30); decBtn.Position = UDim2.new(1, -45, 0, 10)
    decBtn.BackgroundColor3 = Color3.fromRGB(190,40,40); decBtn.Text = "X"
    decBtn.MouseButton1Click:Connect(function() if onDecline then onDecline() end card:Destroy() end)
end

local function appendChat(sender, text)
    local msg = Instance.new("TextLabel", ChatLog)
    msg.Size = UDim2.new(1, -10, 0, 24)
    msg.BackgroundTransparency = 1
    msg.Text = "["..sender.."]: " .. text
    msg.TextColor3 = Color3.fromRGB(230, 230, 240)
    msg.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Salvar localmente
    if hostRoomId then
        if not chatHistory[hostRoomId] then chatHistory[hostRoomId] = {} end
        table.insert(chatHistory[hostRoomId], {s = sender, t = text})
        saveData("history", chatHistory)
    end
end

-- Lógica de Pesquisa de Usuários
local allOnlineUsers = {}
local function renderUsers(filter)
    for _, c in ipairs(UsersList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    for _, u in ipairs(allOnlineUsers) do
        if u.userId ~= tostring(LocalPlayer.UserId) then
            if filter == "" or string.find(string.lower(u.username), string.lower(filter)) then
                local card = Instance.new("Frame", UsersList)
                card.Size = UDim2.new(1, 0, 0, 50)
                card.BackgroundColor3 = Color3.fromRGB(40,40,48) -- Quadrado mais claro
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                
                local av = Instance.new("ImageLabel", card)
                av.Size = UDim2.new(0, 40, 0, 40); av.Position = UDim2.new(0, 5, 0, 5)
                av.Image = "rbxthumb://type=AvatarHeadShot&id="..u.userId.."&w=150&h=150"
                Instance.new("UICorner", av).CornerRadius = UDim.new(0, 8) -- Quadrado com borda arredondada
                
                local name = Instance.new("TextLabel", card)
                name.Size = UDim2.new(1, -130, 1, 0); name.Position = UDim2.new(0, 55, 0, 0)
                name.BackgroundTransparency = 1; name.Text = u.username; name.TextColor3 = Color3.fromRGB(255,255,255)
                name.TextXAlignment = Enum.TextXAlignment.Left
                
                local addBtn = Instance.new("TextButton", card)
                addBtn.Size = UDim2.new(0, 70, 0, 30); addBtn.Position = UDim2.new(1, -75, 0, 10)
                addBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                addBtn.Text = "Adicionar"
                addBtn.TextColor3 = Color3.fromRGB(255,255,255)
                Instance.new("UICorner", addBtn)
                
                addBtn.MouseButton1Click:Connect(function()
                    sendWS({type = "friend_request", targetId = u.userId})
                    addBtn.Text = "Enviado"
                end)
            end
        end
    end
end

SearchBar:GetPropertyChangedSignal("Text"):Connect(function() renderUsers(SearchBar.Text) end)

-- Lógica Autocomplete Chat
ChatInput:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = ChatInput.Text
    if string.match(txt, "^/invite @") or string.match(txt, "^//invitegp @") then
        local search = string.gsub(txt, "^/?/inviteg?p? @", "")
        AutoCompleteFrame.Visible = true
        for _, c in ipairs(AutoCompleteFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        
        for friendId, friendName in pairs(friendsData) do
            if string.find(string.lower(friendName), string.lower(search)) then
                local b = Instance.new("TextButton", AutoCompleteFrame)
                b.Size = UDim2.new(1, 0, 0, 25); b.Text = friendName
                b.BackgroundColor3 = Color3.fromRGB(50,50,60); b.TextColor3 = Color3.fromRGB(200,200,255)
                b.MouseButton1Click:Connect(function()
                    ChatInput.Text = string.match(txt, "^/?/inviteg?p?") .. " @" .. friendName
                    AutoCompleteFrame.Visible = false
                end)
            end
        end
    else
        AutoCompleteFrame.Visible = false
    end
end)

-- FIXED: Chat Input losing focus fix
ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and ChatInput.Text ~= "" then
        local txt = ChatInput.Text
        
        if string.match(txt, "^/invite @") then
            local targetName = string.gsub(txt, "/invite @", "")
            local targetId = nil
            for id, name in pairs(friendsData) do if name == targetName then targetId = id break end end
            if targetId then sendWS({type = "chat_invite", targetId = targetId}) end
            
        elseif txt == "//leave" then
            sendWS({type = "chat_leave"})
            hostRoomId = nil
            appendChat("Sistema", "Você saiu do chat.")
            
        else
            sendWS({type = "send_message", context = activeContext, content = txt})
        end
        ChatInput.Text = ""
    end
    -- Se enterPressed for false (fechou teclado), o texto CONTINUA LÁ.
end)

-- Conexão e Handlers WebSocket
local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "users_list" then
            allOnlineUsers = data.users
            renderUsers(SearchBar.Text)
            
        elseif data.type == "notification" then
            if data.notifType == "friend_request" then
                addNotification(data.senderName.." enviou um pedido de amizade", 
                    function() sendWS({type="friend_accept", targetId=data.senderId, targetName=data.senderName}) end)
            elseif data.notifType == "chat_invite" then
                addNotification("Sua amizade "..data.senderName.." enviou um pedido de chat",
                    function() sendWS({type="chat_accept", hostId=data.senderId}) end)
            end
            
        elseif data.type == "friend_added" then
            friendsData[tostring(data.friendId)] = data.friendName
            saveData("friends", friendsData)
            
        elseif data.type == "chat_connected" or data.type == "chat_joined" then
            hostRoomId = data.hostId or tostring(LocalPlayer.UserId)
            activeContext = "private"
            switchTab("chat")
            appendChat("Sistema", "Conectado ao bate-papo de " .. (data.hostName or data.userName))
            
            -- Carregar Histórico Local
            if chatHistory[hostRoomId] then
                for _, m in ipairs(chatHistory[hostRoomId]) do
                    appendChat(m.s, m.t)
                end
            end
            
        elseif data.type == "message" or data.type == "system_message" then
            appendChat(data.senderName or "Sistema", data.content or data.text)
            
        elseif data.type == "clone_start" then
            -- SISTEMA DE CLONE INICIADO
            appendChat("Clone", "Sincronização de clone iniciada!")
            local targetPlayerId = data.targetId
            -- Criaria um Rig local aqui e começaria o loop de CFrame (Simplificado para caber no limite)
            RunService.RenderStepped:Connect(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local pos = LocalPlayer.Character.HumanoidRootPart.CFrame
                    sendWS({type="clone_sync", targetId = targetPlayerId, cframe = {pos.X, pos.Y, pos.Z}})
                end
            end)
            
        elseif data.type == "clone_update" then
            -- Moveria o Rig criado com os dados data.cframe
        end
    end)
    
    sendWS({ type = "register", userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name })
end

-- === BOTÃO CLONE ===
local CloneBtn = Instance.new("TextButton", Header)
CloneBtn.Size = UDim2.new(0, 100, 0, 30); CloneBtn.Position = UDim2.new(1, -185, 0, 5)
CloneBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
CloneBtn.Text = "Convite Clone"
CloneBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", CloneBtn).CornerRadius = UDim.new(0,6)
CloneBtn.MouseButton1Click:Connect(function()
    -- Dispara para a pessoa que está no hostRoomId atual
    if hostRoomId and hostRoomId ~= tostring(LocalPlayer.UserId) then
        sendWS({type = "clone_request", targetId = hostRoomId})
    end
end)
