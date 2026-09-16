-- ==========================================
-- CHAT-UNIVERSAL V5 (Atualizado com Bios, Sincronização, Edição, Figurinhas)
-- Autor: techno_milgrau (modificações UI / API integradas)
-- ==========================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local SERVER_URL = "https://chat-universal-gb22.onrender.com"

-- ==========================================
-- SISTEMA DE PASTAS E ARQUIVOS (JSON)
-- ==========================================
local BaseFolder = "ChatUniversal_Data"
local FriendsFile = BaseFolder .. "/Amigos.json"
local StickersFolder = BaseFolder .. "/Stickers"
local RecentStickersFile = BaseFolder .. "/Recents.json"

pcall(function()
    if isfolder and not isfolder(BaseFolder) then makefolder(BaseFolder) end
    if isfolder and not isfolder(StickersFolder) then makefolder(StickersFolder) end
end)

local LocalData = { Friends = {}, RecentStickers = {} }

local function SaveFriends()
    pcall(function() writefile(FriendsFile, HttpService:JSONEncode(LocalData.Friends)) end)
end

local function LoadFriends()
    pcall(function()
        if isfile and isfile(FriendsFile) then
            local decoded = HttpService:JSONDecode(readfile(FriendsFile))
            if decoded then LocalData.Friends = decoded end
        end
    end)
end
LoadFriends()

local function SaveRecentStickers()
    pcall(function() writefile(RecentStickersFile, HttpService:JSONEncode(LocalData.RecentStickers)) end)
end

local function LoadRecentStickers()
    pcall(function()
        if isfile and isfile(RecentStickersFile) then
            local decoded = HttpService:JSONDecode(readfile(RecentStickersFile))
            if decoded then LocalData.RecentStickers = decoded end
        end
    end)
end
LoadRecentStickers()

local function GetChatFilePath(friendName) return BaseFolder .. "/Chat_" .. friendName .. ".json" end

local function SaveChat(friendName, chatHistory)
    pcall(function() writefile(GetChatFilePath(friendName), HttpService:JSONEncode(chatHistory)) end)
end

local function LoadChat(friendName)
    local history = {}
    pcall(function()
        if isfile and isfile(GetChatFilePath(friendName)) then
            local decoded = HttpService:JSONDecode(readfile(GetChatFilePath(friendName)))
            if decoded then history = decoded end
        end
    end)
    return history
end

local function GenerateMsgId()
    return tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- ==========================================
-- GITHUB STICKER FETCHER
-- ==========================================
task.spawn(function()
    local success, res = pcall(function()
        return HttpService:RequestAsync({Url = "https://api.github.com/repos/technomilgrau/Chat-universal/contents/Stickers", Method = "GET"})
    end)
    if success and res.Success then
        local files = HttpService:JSONDecode(res.Body)
        for _, file in ipairs(files) do
            if file.type == "file" and (string.match(file.name:lower(), "%.png$") or string.match(file.name:lower(), "%.jpg$")) then
                if not isfile(StickersFolder .. "/" .. file.name) then
                    local imgRes = HttpService:RequestAsync({Url = file.download_url, Method = "GET"})
                    if imgRes.Success then writefile(StickersFolder .. "/" .. file.name, imgRes.Body) end
                end
            end
        end
    end
end)

local function GetAvailableStickers()
    local stickers = {}
    if listfiles then
        pcall(function()
            local files = listfiles(StickersFolder)
            for _, path in ipairs(files) do
                if string.match(path:lower(), "%.png$") or string.match(path:lower(), "%.jpg$") then table.insert(stickers, path) end
            end
        end)
    end
    return stickers
end

-- ==========================================
-- REGISTRO AUTOMÁTICO
-- ==========================================
task.spawn(function()
    pcall(function()
        HttpService:RequestAsync({
            Url = SERVER_URL .. "/register", Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({ username = player.Name, displayName = player.DisplayName, userId = player.UserId })
        })
    end)
end)

-- ==========================================
-- INTERFACE PRINCIPAL
-- ==========================================
if CoreGui:FindFirstChild("ChatUniversalHub") then CoreGui.ChatUniversalHub:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatUniversalHub"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrameWrapper = Instance.new("Frame", ScreenGui)
MainFrameWrapper.Size = UDim2.new(0, 300, 0, 500)
MainFrameWrapper.Position = UDim2.new(0.5, -150, 0.5, -250)
MainFrameWrapper.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrameWrapper.BorderSizePixel = 0
MainFrameWrapper.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrameWrapper)
MainCorner.CornerRadius = UDim.new(0, 10)

local function MakeDraggable(dragHandle, frameToMove)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true dragInput = input dragStart = input.Position startPos = frameToMove.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frameToMove.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then dragging = false dragInput = nil end
    end)
end

local TitleBar = Instance.new("Frame", MainFrameWrapper)
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundTransparency = 1
TitleBar.ZIndex = 50
MakeDraggable(TitleBar, MainFrameWrapper)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -80, 0, 20) Title.Position = UDim2.new(0, 10, 0, 5) Title.BackgroundTransparency = 1
Title.Text = "Chat-universal" Title.TextColor3 = Color3.fromRGB(255, 255, 255) Title.Font = Enum.Font.GothamBold Title.TextSize = 18 Title.TextXAlignment = Enum.TextXAlignment.Left

local Subtitle = Instance.new("TextLabel", TitleBar)
Subtitle.Size = UDim2.new(1, -80, 0, 12) Subtitle.Position = UDim2.new(0, 10, 0, 24) Subtitle.BackgroundTransparency = 1
Subtitle.Text = "techno_milgrau" Subtitle.TextColor3 = Color3.fromRGB(150, 150, 150) Subtitle.Font = Enum.Font.Gotham Subtitle.TextSize = 10 Subtitle.TextXAlignment = Enum.TextXAlignment.Left

local NotifyBtn = Instance.new("TextButton", TitleBar)
NotifyBtn.Size = UDim2.new(0, 30, 0, 30) NotifyBtn.Position = UDim2.new(1, -65, 0, 5) NotifyBtn.BackgroundTransparency = 1
NotifyBtn.Text = "🔔" NotifyBtn.TextColor3 = Color3.fromRGB(200, 200, 200) NotifyBtn.Font = Enum.Font.GothamBold NotifyBtn.TextSize = 16

local MinimizeBtn = Instance.new("TextButton", TitleBar)
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30) MinimizeBtn.Position = UDim2.new(1, -35, 0, 5) MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Text = "−" MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200) MinimizeBtn.Font = Enum.Font.GothamBold MinimizeBtn.TextSize = 20

local MinimizedIcon = Instance.new("TextButton", MainFrameWrapper)
MinimizedIcon.Size = UDim2.new(1, 0, 1, 0) MinimizedIcon.BackgroundTransparency = 1 MinimizedIcon.Text = "C" MinimizedIcon.TextColor3 = Color3.fromRGB(255, 255, 255) MinimizedIcon.Font = Enum.Font.GothamBold MinimizedIcon.TextSize = 24 MinimizedIcon.Visible = false

local isMinimized = false
local originalSize = UDim2.new(0, 300, 0, 500)
local minimizedSize = UDim2.new(0, 50, 0, 50)

MinimizeBtn.MouseButton1Click:Connect(function()
    if not isMinimized then
        isMinimized = true TitleBar.Visible = false
        if MainFrameWrapper:FindFirstChild("SettingsPanel") then MainFrameWrapper.SettingsPanel.Visible = false end
        MainFrameWrapper.Size = minimizedSize MinimizedIcon.Visible = true
    end
end)

MinimizedIcon.MouseButton1Click:Connect(function()
    if isMinimized then
        isMinimized = false MinimizedIcon.Visible = false TitleBar.Visible = true
        if MainFrameWrapper:FindFirstChild("SettingsPanel") then MainFrameWrapper.SettingsPanel.Visible = true end
        MainFrameWrapper.Size = originalSize
    end
end)

-- ==========================================
-- GERENCIADOR DE ABAS & MODAIS
-- ==========================================
local SettingsPanel = Instance.new("Frame", MainFrameWrapper)
SettingsPanel.Name = "SettingsPanel" SettingsPanel.Size = UDim2.new(1, 0, 1, -40) SettingsPanel.Position = UDim2.new(0, 0, 0, 40) SettingsPanel.BackgroundTransparency = 1

local MainMenu = Instance.new("Frame", SettingsPanel) MainMenu.Size = UDim2.new(1, 0, 1, 0) MainMenu.BackgroundTransparency = 1
local SearchMenu = Instance.new("Frame", SettingsPanel) SearchMenu.Size = UDim2.new(1, 0, 1, 0) SearchMenu.Position = UDim2.new(1, 0, 0, 0) SearchMenu.BackgroundTransparency = 1
local FriendsMenu = Instance.new("Frame", SettingsPanel) FriendsMenu.Size = UDim2.new(1, 0, 1, 0) FriendsMenu.Position = UDim2.new(1, 0, 0, 0) FriendsMenu.BackgroundTransparency = 1
local PrivateChatMenu = Instance.new("Frame", SettingsPanel) PrivateChatMenu.Size = UDim2.new(1, 0, 1, 0) PrivateChatMenu.Position = UDim2.new(1, 0, 0, 0) PrivateChatMenu.BackgroundTransparency = 1
local NotificationsMenu = Instance.new("Frame", SettingsPanel) NotificationsMenu.Size = UDim2.new(1, 0, 1, 0) NotificationsMenu.Position = UDim2.new(1, 0, 0, 0) NotificationsMenu.BackgroundTransparency = 1
local ProfileMenu = Instance.new("Frame", SettingsPanel) ProfileMenu.Size = UDim2.new(1, 0, 1, 0) ProfileMenu.Position = UDim2.new(1, 0, 0, 0) ProfileMenu.BackgroundTransparency = 1

local MenuStack = {MainMenu}
local CurrentMenu = MainMenu

local function OpenMenu(newMenu)
    if CurrentMenu == newMenu then return end
    CurrentMenu.Position = UDim2.new(-1, 0, 0, 0)
    newMenu.Position = UDim2.new(0, 0, 0, 0)
    table.insert(MenuStack, newMenu)
    CurrentMenu = newMenu
end

local function CloseMenu()
    if #MenuStack <= 1 then return end
    local menuToClose = table.remove(MenuStack)
    local previousMenu = MenuStack[#MenuStack]
    menuToClose.Position = UDim2.new(1, 0, 0, 0)
    previousMenu.Position = UDim2.new(0, 0, 0, 0)
    CurrentMenu = previousMenu
end

local function createTopBar(parent, titleText, backAction)
    local bar = Instance.new("Frame", parent) bar.Size = UDim2.new(1, 0, 0, 40) bar.BackgroundTransparency = 1
    local title = Instance.new("TextLabel", bar) title.Size = UDim2.new(1, -70, 1, 0) title.Position = UDim2.new(0, 40, 0, 0) title.BackgroundTransparency = 1 title.Text = titleText title.TextColor3 = Color3.fromRGB(255, 255, 255) title.Font = Enum.Font.GothamBold title.TextSize = 16 title.TextXAlignment = Enum.TextXAlignment.Left
    local backBtn = Instance.new("TextButton", bar) backBtn.Size = UDim2.new(0, 30, 0, 30) backBtn.Position = UDim2.new(0, 5, 0, 5) backBtn.BackgroundTransparency = 1 backBtn.Text = "◀" backBtn.TextColor3 = Color3.fromRGB(200, 200, 200) backBtn.Font = Enum.Font.GothamBold backBtn.TextSize = 18
    backBtn.MouseButton1Click:Connect(backAction or CloseMenu)
    return title, bar
end

-- OVERLAYS E POPUPS
local ModalContainer = Instance.new("Frame", MainFrameWrapper)
ModalContainer.Size = UDim2.new(1,0,1,0) ModalContainer.BackgroundColor3 = Color3.fromRGB(0,0,0) ModalContainer.BackgroundTransparency = 0.5 ModalContainer.Visible = false ModalContainer.ZIndex = 100

local function ShowPopup(title, text, btn1Text, btn2Text, callback1, callback2)
    for _,c in pairs(ModalContainer:GetChildren()) do c:Destroy() end
    ModalContainer.Visible = true
    local box = Instance.new("Frame", ModalContainer) box.Size = UDim2.new(0,240,0,120) box.Position = UDim2.new(0.5,-120,0.5,-60) box.BackgroundColor3 = Color3.fromRGB(35,35,40) Instance.new("UICorner",box).CornerRadius = UDim.new(0,10)
    local ttl = Instance.new("TextLabel", box) ttl.Size=UDim2.new(1,0,0,30) ttl.BackgroundTransparency=1 ttl.Text=title ttl.TextColor3=Color3.fromRGB(255,255,255) ttl.Font=Enum.Font.GothamBold ttl.TextSize=14
    local txt = Instance.new("TextLabel", box) txt.Size=UDim2.new(1,-20,0,40) txt.Position=UDim2.new(0,10,0,30) txt.BackgroundTransparency=1 txt.Text=text txt.TextColor3=Color3.fromRGB(200,200,200) txt.Font=Enum.Font.Gotham txt.TextSize=12 txt.TextWrapped=true
    local b1 = Instance.new("TextButton", box) b1.Size=UDim2.new(0.4,0,0,30) b1.Position=UDim2.new(0.05,0,1,-40) b1.BackgroundColor3=Color3.fromRGB(200,50,50) b1.Text=btn1Text b1.TextColor3=Color3.fromRGB(255,255,255) b1.Font=Enum.Font.GothamBold Instance.new("UICorner",b1).CornerRadius=UDim.new(0,6)
    local b2 = Instance.new("TextButton", box) b2.Size=UDim2.new(0.4,0,0,30) b2.Position=UDim2.new(0.55,0,1,-40) b2.BackgroundColor3=Color3.fromRGB(50,50,55) b2.Text=btn2Text b2.TextColor3=Color3.fromRGB(255,255,255) b2.Font=Enum.Font.GothamBold Instance.new("UICorner",b2).CornerRadius=UDim.new(0,6)
    b1.MouseButton1Click:Connect(function() ModalContainer.Visible=false if callback1 then callback1() end end)
    b2.MouseButton1Click:Connect(function() ModalContainer.Visible=false if callback2 then callback2() end end)
end

local function OpenBioEditor(oldBio)
    for _,c in pairs(ModalContainer:GetChildren()) do c:Destroy() end
    ModalContainer.Visible = true
    local box = Instance.new("Frame", ModalContainer) box.Size = UDim2.new(0,260,0,160) box.Position = UDim2.new(0.5,-130,0.5,-80) box.BackgroundColor3 = Color3.fromRGB(35,35,40) Instance.new("UICorner",box).CornerRadius = UDim.new(0,10)
    local ttl = Instance.new("TextLabel", box) ttl.Size=UDim2.new(1,0,0,30) ttl.BackgroundTransparency=1 ttl.Text="Editar Biografia" ttl.TextColor3=Color3.fromRGB(255,255,255) ttl.Font=Enum.Font.GothamBold ttl.TextSize=14
    local input = Instance.new("TextBox", box) input.Size=UDim2.new(1,-20,0,60) input.Position=UDim2.new(0,10,0,40) input.BackgroundColor3=Color3.fromRGB(20,20,25) input.TextColor3=Color3.fromRGB(255,255,255) input.Text=oldBio or "" input.MultiLine=true input.TextWrapped=true input.Font=Enum.Font.Gotham input.TextSize=12 input.TextYAlignment=Enum.TextYAlignment.Top input.ClearTextOnFocus=false Instance.new("UICorner",input).CornerRadius=UDim.new(0,6)
    local b1 = Instance.new("TextButton", box) b1.Size=UDim2.new(0.4,0,0,30) b1.Position=UDim2.new(0.05,0,1,-40) b1.BackgroundColor3=Color3.fromRGB(46,204,113) b1.Text="Salvar" b1.TextColor3=Color3.fromRGB(255,255,255) b1.Font=Enum.Font.GothamBold Instance.new("UICorner",b1).CornerRadius=UDim.new(0,6)
    local b2 = Instance.new("TextButton", box) b2.Size=UDim2.new(0.4,0,0,30) b2.Position=UDim2.new(0.55,0,1,-40) b2.BackgroundColor3=Color3.fromRGB(50,50,55) b2.Text="Cancelar" b2.TextColor3=Color3.fromRGB(255,255,255) b2.Font=Enum.Font.GothamBold Instance.new("UICorner",b2).CornerRadius=UDim.new(0,6)
    
    b1.MouseButton1Click:Connect(function()
        ModalContainer.Visible=false
        local newBio = string.sub(input.Text, 1, 80)
        pcall(function()
            HttpService:RequestAsync({ Url = SERVER_URL .. "/update_bio", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({username=player.Name, bio=newBio}) })
        end)
        if CurrentMenu == ProfileMenu then OpenProfileUI(player.Name) end -- Reload profile
    end)
    b2.MouseButton1Click:Connect(function() ModalContainer.Visible=false end)
end

-- ==========================================
-- MENU PRINCIPAL
-- ==========================================
local ProfileBtn = Instance.new("TextButton", MainMenu)
ProfileBtn.Size = UDim2.new(0, 240, 0, 45) ProfileBtn.Position = UDim2.new(0.5, -120, 0, 20)
ProfileBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) ProfileBtn.Text = "👤 Meu Perfil" ProfileBtn.TextColor3 = Color3.fromRGB(255, 255, 255) ProfileBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", ProfileBtn).CornerRadius = UDim.new(0, 6)
ProfileBtn.MouseButton1Click:Connect(function() OpenProfileUI(player.Name) end)

local SearchBtn = Instance.new("TextButton", MainMenu)
SearchBtn.Size = UDim2.new(0, 240, 0, 45) SearchBtn.Position = UDim2.new(0.5, -120, 0, 75)
SearchBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) SearchBtn.Text = "🔍 Procurar Amigos" SearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SearchBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 6)
SearchBtn.MouseButton1Click:Connect(function() OpenMenu(SearchMenu) end)

local MessagesBtn = Instance.new("TextButton", MainMenu)
MessagesBtn.Size = UDim2.new(0, 240, 0, 45) MessagesBtn.Position = UDim2.new(0.5, -120, 0, 130)
MessagesBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) MessagesBtn.Text = "💬 Mensagens" MessagesBtn.TextColor3 = Color3.fromRGB(255, 255, 255) MessagesBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", MessagesBtn).CornerRadius = UDim.new(0, 6)
MessagesBtn.MouseButton1Click:Connect(function() OpenMenu(FriendsMenu) LoadFriendsUI() end)

NotifyBtn.MouseButton1Click:Connect(function() if CurrentMenu ~= NotificationsMenu then OpenMenu(NotificationsMenu) LoadNotificationsUI() end end)

-- ==========================================
-- ABA 5: PERFIL E BIO (NOVO)
-- ==========================================
createTopBar(ProfileMenu, "Perfil")
local ProfAvatar = Instance.new("ImageLabel", ProfileMenu) ProfAvatar.Size = UDim2.new(0, 90, 0, 90) ProfAvatar.Position = UDim2.new(0.5, -45, 0, 50) ProfAvatar.BackgroundColor3 = Color3.fromRGB(40,40,45) Instance.new("UICorner", ProfAvatar).CornerRadius = UDim.new(1,0)
local ProfDName = Instance.new("TextLabel", ProfileMenu) ProfDName.Size = UDim2.new(1,0,0,20) ProfDName.Position = UDim2.new(0,0,0,150) ProfDName.BackgroundTransparency=1 ProfDName.TextColor3=Color3.fromRGB(255,255,255) ProfDName.Font=Enum.Font.GothamBold ProfDName.TextSize=18
local ProfUName = Instance.new("TextLabel", ProfileMenu) ProfUName.Size = UDim2.new(1,0,0,15) ProfUName.Position = UDim2.new(0,0,0,170) ProfUName.BackgroundTransparency=1 ProfUName.TextColor3=Color3.fromRGB(150,150,150) ProfUName.Font=Enum.Font.Gotham ProfUName.TextSize=12
local ProfStats = Instance.new("TextLabel", ProfileMenu) ProfStats.Size = UDim2.new(1,0,0,15) ProfStats.Position = UDim2.new(0,0,0,195) ProfStats.BackgroundTransparency=1 ProfStats.TextColor3=Color3.fromRGB(200,200,200) ProfStats.Font=Enum.Font.GothamBold ProfStats.TextSize=14
local ProfBtn = Instance.new("TextButton", ProfileMenu) ProfBtn.Size = UDim2.new(0, 140, 0, 35) ProfBtn.Position = UDim2.new(0.5, -70, 0, 220) ProfBtn.Font = Enum.Font.GothamBold ProfBtn.TextSize = 14 ProfBtn.TextColor3 = Color3.fromRGB(255,255,255) Instance.new("UICorner", ProfBtn).CornerRadius = UDim.new(0,8)
local ProfBio = Instance.new("TextButton", ProfileMenu) ProfBio.Size = UDim2.new(1, -40, 0, 60) ProfBio.Position = UDim2.new(0, 20, 0, 270) ProfBio.BackgroundTransparency=1 ProfBio.TextColor3=Color3.fromRGB(220,220,220) ProfBio.Font=Enum.Font.Gotham ProfBio.TextSize=12 ProfBio.TextWrapped=true ProfBio.TextYAlignment=Enum.TextYAlignment.Top

function OpenProfileUI(targetUsername)
    OpenMenu(ProfileMenu)
    ProfDName.Text = "Carregando..." ProfUName.Text = "" ProfStats.Text = "amigos 0" ProfBio.Text = "" ProfBtn.Visible = false
    task.spawn(function()
        local s, r = pcall(function() return HttpService:RequestAsync({Url=SERVER_URL.."/get_profile?username="..targetUsername, Method="GET"}) end)
        if s and r.Success then
            local data = HttpService:JSONDecode(r.Body)
            if not data then return end
            pcall(function() ProfAvatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(data.userId or 1).."&w=150&h=150" end)
            ProfDName.Text = data.displayName
            ProfUName.Text = "@" .. data.username
            ProfStats.Text = "amigos " .. tostring(data.friendCount or 0)
            
            local isMe = (targetUsername == player.Name)
            local isFriend = table.find(LocalData.Friends, targetUsername) ~= nil
            
            if isMe then
                ProfBtn.Visible = false
                if data.bio == "" then ProfBio.Text = "adicionar bio+" ProfBio.TextColor3 = Color3.fromRGB(255,255,255) ProfBio.Font = Enum.Font.GothamBold
                else ProfBio.Text = data.bio ProfBio.TextColor3 = Color3.fromRGB(220,220,220) ProfBio.Font = Enum.Font.Gotham end
                
                ProfBio.MouseButton1Click:Connect(function()
                    if data.bio == "" then OpenBioEditor("") else ShowPopup("Editar biografia?", "", "Sim", "Não", function() OpenBioEditor(data.bio) end) end
                end)
            else
                ProfBtn.Visible = true
                ProfBio.Text = data.bio == "" and "Sem biografia." or data.bio
                ProfBio.TextColor3 = Color3.fromRGB(220,220,220) ProfBio.Font = Enum.Font.Gotham
                ProfBio.MouseButton1Click:Connect(function() end) -- Do nothing for others
                
                if isFriend then
                    ProfBtn.Text = "Mensagem" ProfBtn.BackgroundColor3 = Color3.fromRGB(50,50,55)
                    ProfBtn.MouseButton1Click:Connect(function() OpenPrivateChat(data.username, data.displayName, data.userId) end)
                else
                    ProfBtn.Text = "Adicionar" ProfBtn.BackgroundColor3 = Color3.fromRGB(233,30,99) -- Rosa estilo tiktok/instagram
                    ProfBtn.MouseButton1Click:Connect(function()
                        if ProfBtn.Text == "Adicionar" then
                            ProfBtn.Text = "Enviado" ProfBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
                            pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = targetUsername}) }) end)
                        end
                    end)
                end
            end
        end
    end)
end

-- ==========================================
-- DESIGN DE ENTRADAS (USUÁRIOS/AMIGOS)
-- ==========================================
local function CreateUserEntry(parent, displayName, username, userId, mode, statusText)
    local frame = Instance.new("Frame", parent) frame.Size = UDim2.new(1, -20, 0, 60) frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local avatarBtn = Instance.new("ImageButton", frame) avatarBtn.Size = UDim2.new(0, 45, 0, 45) avatarBtn.Position = UDim2.new(0, 8, 0, 7) avatarBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", avatarBtn).CornerRadius = UDim.new(0, 6)
    pcall(function() avatarBtn.Image = "rbxthumb://type=AvatarHeadShot&id="..userId.."&w=150&h=150" end)
    avatarBtn.MouseButton1Click:Connect(function() OpenProfileUI(username) end) -- Somente a foto abre o perfil
    
    local dName = Instance.new("TextLabel", frame) dName.Size = UDim2.new(0, 100, 0, 20) dName.Position = UDim2.new(0, 60, 0, 8) dName.BackgroundTransparency = 1 dName.Text = displayName dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left
    local uName = Instance.new("TextLabel", frame) uName.Size = UDim2.new(0, 90, 0, 16) uName.Position = UDim2.new(0, 60, 0, 32) uName.BackgroundTransparency = 1 uName.Text = "@" .. username uName.TextColor3 = Color3.fromRGB(180, 180, 180) uName.Font = Enum.Font.Gotham uName.TextSize = 10 uName.TextXAlignment = Enum.TextXAlignment.Left
    
    if mode == "Search" then
        local actionBtn = Instance.new("TextButton", frame) actionBtn.Size = UDim2.new(0, 75, 0, 26) actionBtn.Position = UDim2.new(1, -85, 0.5, -13) actionBtn.Font = Enum.Font.GothamBold actionBtn.TextSize = 11 Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)
        local isFriend = table.find(LocalData.Friends, username) ~= nil
        if isFriend then
            actionBtn.Text = "Amigos" actionBtn.BackgroundColor3 = Color3.fromRGB(80,80,90) actionBtn.TextColor3 = Color3.fromRGB(255,255,255)
            actionBtn.MouseButton1Click:Connect(function()
                ShowPopup("Desfazer amizade?", "Você não poderá mais trocar mensagens com " .. displayName .. ".", "Sim", "Não", function()
                    pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/unfriend", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({user=player.Name, friend=username}) }) end)
                    local idx = table.find(LocalData.Friends, username)
                    if idx then table.remove(LocalData.Friends, idx) SaveFriends() end
                    frame:Destroy()
                end)
            end)
        else
            actionBtn.Text = "Adicionar" actionBtn.BackgroundColor3 = Color3.fromRGB(233,30,99) actionBtn.TextColor3 = Color3.fromRGB(255,255,255)
            actionBtn.MouseButton1Click:Connect(function()
                if actionBtn.Text == "Adicionar" then
                    actionBtn.Text = "Enviado" actionBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
                    pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = username}) }) end)
                end
            end)
        end
    elseif mode == "Friend" then
        local statusLabel = Instance.new("TextLabel", frame) statusLabel.Size = UDim2.new(0, 70, 0, 16) statusLabel.Position = UDim2.new(1, -78, 0.5, -8) statusLabel.BackgroundTransparency = 1 statusLabel.Font = Enum.Font.Gotham statusLabel.TextSize = 10 statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusText = statusText or "Offline" statusLabel.Text = statusText
        if statusText == "Online" then statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113) elseif statusText == "Digitando..." then statusLabel.TextColor3 = Color3.fromRGB(241, 196, 15) else statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150) end
        
        local hitBox = Instance.new("TextButton", frame) hitBox.Size = UDim2.new(1, -60, 1, 0) hitBox.Position = UDim2.new(0,60,0,0) hitBox.BackgroundTransparency = 1 hitBox.Text = ""
        hitBox.MouseButton1Click:Connect(function() OpenPrivateChat(username, displayName, userId) end) -- Resto do frame abre chat
    end
    return frame
end

-- ABA 1: PROCURAR AMIGOS
createTopBar(SearchMenu, "Procurar Amigos")
local SearchBoxFrame = Instance.new("Frame", SearchMenu) SearchBoxFrame.Size = UDim2.new(1, -20, 0, 35) SearchBoxFrame.Position = UDim2.new(0, 10, 0, 45) SearchBoxFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", SearchBoxFrame).CornerRadius = UDim.new(0, 6)
local SearchInput = Instance.new("TextBox", SearchBoxFrame) SearchInput.Size = UDim2.new(1, -20, 1, 0) SearchInput.Position = UDim2.new(0, 10, 0, 0) SearchInput.BackgroundTransparency = 1 SearchInput.PlaceholderText = "Pesquisar nick..." SearchInput.Text = "" SearchInput.TextColor3 = Color3.fromRGB(255, 255, 255) SearchInput.Font = Enum.Font.Gotham SearchInput.TextSize = 13 SearchInput.TextXAlignment = Enum.TextXAlignment.Left
local SearchResults = Instance.new("ScrollingFrame", SearchMenu) SearchResults.Size = UDim2.new(1, 0, 1, -90) SearchResults.Position = UDim2.new(0, 0, 0, 90) SearchResults.BackgroundTransparency = 1 SearchResults.ScrollBarThickness = 3
local SearchLayout = Instance.new("UIListLayout", SearchResults) SearchLayout.Padding = UDim.new(0, 8) SearchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SearchLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SearchResults.CanvasSize = UDim2.new(0, 0, 0, SearchLayout.AbsoluteContentSize.Y + 10) end)

local searchTick = 0
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text
    for _, c in pairs(SearchResults:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    if query == "" then return end
    searchTick = searchTick + 1 local currentTick = searchTick
    task.delay(0.5, function()
        if currentTick ~= searchTick then return end
        task.spawn(function()
            local s, r = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL .. "/users?query=" .. HttpService:UrlEncode(query), Method = "GET"}) end)
            if s and r.Success then
                local users = HttpService:JSONDecode(r.Body)
                for _, u in ipairs(users) do
                    if u.username ~= player.Name then CreateUserEntry(SearchResults, u.displayName, u.username, u.userId, "Search") end
                end
            end
        end)
    end)
end)

-- ABA 2: NOTIFICAÇÕES
createTopBar(NotificationsMenu, "Notificações")
local RequestsList = Instance.new("ScrollingFrame", NotificationsMenu) RequestsList.Size = UDim2.new(1, 0, 1, -50) RequestsList.Position = UDim2.new(0, 0, 0, 50) RequestsList.BackgroundTransparency = 1 RequestsList.ScrollBarThickness = 3
local ReqLayout = Instance.new("UIListLayout", RequestsList) ReqLayout.Padding = UDim.new(0, 8) ReqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ReqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RequestsList.CanvasSize = UDim2.new(0, 0, 0, ReqLayout.AbsoluteContentSize.Y + 10) end)

function LoadNotificationsUI()
    for _, c in pairs(RequestsList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    task.spawn(function()
        local s, r = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL .. "/get_requests?username=" .. player.Name, Method = "GET"}) end)
        if s and r.Success then
            local reqs = HttpService:JSONDecode(r.Body)
            for _, req in ipairs(reqs) do
                local card = Instance.new("Frame", RequestsList) card.Size = UDim2.new(1, -20, 0, 60) card.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                local avatar = Instance.new("ImageLabel", card) avatar.Size = UDim2.new(0, 45, 0, 45) avatar.Position = UDim2.new(0, 8, 0, 7) avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 8)
                pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(req.fromId or 1).."&w=150&h=150" end)
                local dName = Instance.new("TextLabel", card) dName.Size = UDim2.new(0, 100, 0, 18) dName.Position = UDim2.new(0, 60, 0, 10) dName.BackgroundTransparency = 1 dName.Text = req.fromDisplay or req.from dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left dName.TextSize = 12
                local uName = Instance.new("TextLabel", card) uName.Size = UDim2.new(0, 100, 0, 14) uName.Position = UDim2.new(0, 60, 0, 30) uName.BackgroundTransparency = 1 uName.Text = "@" .. req.from uName.TextColor3 = Color3.fromRGB(150, 150, 150) uName.Font = Enum.Font.Gotham uName.TextXAlignment = Enum.TextXAlignment.Left uName.TextSize = 10
                
                local acceptBtn = Instance.new("TextButton", card) acceptBtn.Size = UDim2.new(0, 28, 0, 28) acceptBtn.Position = UDim2.new(1, -65, 0.5, -14) acceptBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113) acceptBtn.Text = "✓" acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255) acceptBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)
                local declineBtn = Instance.new("TextButton", card) declineBtn.Size = UDim2.new(0, 28, 0, 28) declineBtn.Position = UDim2.new(1, -32, 0.5, -14) declineBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) declineBtn.Text = "✕" declineBtn.TextColor3 = Color3.fromRGB(255, 255, 255) declineBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", declineBtn).CornerRadius = UDim.new(0, 6)
                
                acceptBtn.MouseButton1Click:Connect(function()
                    if not table.find(LocalData.Friends, req.from) then table.insert(LocalData.Friends, req.from) SaveFriends() end
                    pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/accept_request", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from}) }) end)
                    card:Destroy()
                end)
                declineBtn.MouseButton1Click:Connect(function()
                    pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/decline_request", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from}) }) end)
                    card:Destroy()
                end)
            end
        end
    end)
end

-- ABA 3: MENSAGENS (AMIGOS)
createTopBar(FriendsMenu, "Mensagens")
local FriendsList = Instance.new("ScrollingFrame", FriendsMenu) FriendsList.Size = UDim2.new(1, 0, 1, -50) FriendsList.Position = UDim2.new(0, 0, 0, 50) FriendsList.BackgroundTransparency = 1 FriendsList.ScrollBarThickness = 3
local FriendsLayout = Instance.new("UIListLayout", FriendsList) FriendsLayout.Padding = UDim.new(0, 8) FriendsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
FriendsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() FriendsList.CanvasSize = UDim2.new(0, 0, 0, FriendsLayout.AbsoluteContentSize.Y + 10) end)

local ActiveChatTarget = "" local ActiveChatTargetDisplay = "" local ActiveChatTargetId = 1

local _, ChatBarObj = createTopBar(PrivateChatMenu, "Chat", function() CloseMenu() ActiveChatTarget = "" end)
local ChatTitle = ChatBarObj:FindFirstChildOfClass("TextLabel")
local SyncBtn = Instance.new("TextButton", ChatBarObj) SyncBtn.Size = UDim2.new(0,30,0,30) SyncBtn.Position = UDim2.new(1,-40,0,5) SyncBtn.BackgroundTransparency=1 SyncBtn.Text="🔄" SyncBtn.TextColor3=Color3.fromRGB(200,200,200) SyncBtn.Font=Enum.Font.GothamBold SyncBtn.TextSize=14
SyncBtn.MouseButton1Click:Connect(function()
    if ActiveChatTarget ~= "" then pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/request_sync", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget}) }) end) end
end)

function OpenPrivateChat(username, displayName, userId)
    ActiveChatTarget = username ActiveChatTargetDisplay = displayName or username ActiveChatTargetId = userId or 1 ChatTitle.Text = ActiveChatTargetDisplay
    OpenMenu(PrivateChatMenu) RefreshChatUI(LoadChat(username))
end

function LoadFriendsUI()
    for _, c in pairs(FriendsList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for _, friendName in ipairs(LocalData.Friends) do
        task.spawn(function()
            local targetId = 1 pcall(function() targetId = Players:GetUserIdFromNameAsync(friendName) end)
            local statusText = "Offline" pcall(function() local r = HttpService:RequestAsync({Url = SERVER_URL .. "/get_status?username=" .. friendName, Method = "GET"}) if r.Success then statusText = HttpService:JSONDecode(r.Body).status end end)
            CreateUserEntry(FriendsList, friendName, friendName, targetId, "Friend", statusText)
        end)
    end
end

-- ==========================================
-- ABA 4: CHAT PRIVADO & FIGURINHAS
-- ==========================================
local ChatScroll = Instance.new("ScrollingFrame", PrivateChatMenu) ChatScroll.Size = UDim2.new(1, -20, 1, -100) ChatScroll.Position = UDim2.new(0, 10, 0, 45) ChatScroll.BackgroundTransparency = 1 ChatScroll.ScrollBarThickness = 4
local ChatLayout = Instance.new("UIListLayout", ChatScroll) ChatLayout.Padding = UDim.new(0, 8)
ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ChatScroll.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10) end)

local ChatInputFrame = Instance.new("Frame", PrivateChatMenu) ChatInputFrame.Size = UDim2.new(1, -20, 0, 40) ChatInputFrame.Position = UDim2.new(0, 10, 1, -50) ChatInputFrame.BackgroundTransparency = 1
local ChatBox = Instance.new("TextBox", ChatInputFrame) ChatBox.Size = UDim2.new(1, -100, 1, 0) ChatBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45) ChatBox.TextColor3 = Color3.fromRGB(255, 255, 255) ChatBox.Font = Enum.Font.Gotham ChatBox.TextSize = 13 ChatBox.PlaceholderText = "Mensagem..." ChatBox.Text = "" ChatBox.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", ChatBox).CornerRadius = UDim.new(0, 6) local UIPaddingBox = Instance.new("UIPadding", ChatBox) UIPaddingBox.PaddingLeft = UDim.new(0, 10) UIPaddingBox.PaddingRight = UDim.new(0, 10)
local StickerBtn = Instance.new("TextButton", ChatInputFrame) StickerBtn.Size = UDim2.new(0, 30, 1, 0) StickerBtn.Position = UDim2.new(1, -95, 0, 0) StickerBtn.BackgroundTransparency=1 StickerBtn.Text = "🙂" StickerBtn.TextSize = 18
local SendBtn = Instance.new("TextButton", ChatInputFrame) SendBtn.Size = UDim2.new(0, 60, 1, 0) SendBtn.Position = UDim2.new(1, -60, 0, 0) SendBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180) SendBtn.Text = "Enviar" SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SendBtn.Font = Enum.Font.GothamBold SendBtn.TextSize = 12 Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 6)

-- Painel de Figurinhas
local StickerPanel = Instance.new("ScrollingFrame", PrivateChatMenu) StickerPanel.Size = UDim2.new(1,0,0,200) StickerPanel.Position = UDim2.new(0,0,1,-250) StickerPanel.BackgroundColor3 = Color3.fromRGB(30,30,35) StickerPanel.Visible = false StickerPanel.ZIndex = 20
local StickerGrid = Instance.new("UIGridLayout", StickerPanel) StickerGrid.CellSize = UDim2.new(0,60,0,60) StickerGrid.CellPadding = UDim2.new(0,10,0,10) StickerGrid.SortOrder = Enum.SortOrder.LayoutOrder

StickerBtn.MouseButton1Click:Connect(function()
    StickerPanel.Visible = not StickerPanel.Visible
    if StickerPanel.Visible then
        for _,c in pairs(StickerPanel:GetChildren()) do if c:IsA("ImageButton") then c:Destroy() end end
        local stickers = GetAvailableStickers()
        
        -- Carrega recentes
        for i = #LocalData.RecentStickers, 1, -1 do
            local path = LocalData.RecentStickers[i]
            pcall(function()
                local b = Instance.new("ImageButton", StickerPanel) b.LayoutOrder = -i
                if getcustomasset then b.Image = getcustomasset(path) end
                b.MouseButton1Click:Connect(function() SendPrivateMessage("sticker", string.match(path, "([^/\\]+)$")) StickerPanel.Visible = false end)
            end)
        end
        -- Carrega todos
        for i, path in ipairs(stickers) do
            if not table.find(LocalData.RecentStickers, path) then
                pcall(function()
                    local b = Instance.new("ImageButton", StickerPanel) b.LayoutOrder = i
                    if getcustomasset then b.Image = getcustomasset(path) end
                    b.MouseButton1Click:Connect(function()
                        table.insert(LocalData.RecentStickers, 1, path)
                        if #LocalData.RecentStickers > 5 then table.remove(LocalData.RecentStickers, 6) end
                        SaveRecentStickers()
                        SendPrivateMessage("sticker", string.match(path, "([^/\\]+)$"))
                        StickerPanel.Visible = false
                    end)
                end)
            end
        end
    end
end)

local function FormatMessageTime(t) return os.date("%H:%M", t) end

function RenderMessageItem(msg)
    local msgFrame = Instance.new("Frame", ChatScroll) msgFrame.BackgroundTransparency = 1
    local avatar = Instance.new("ImageLabel", msgFrame) avatar.Size = UDim2.new(0, 32, 0, 32) avatar.Position = UDim2.new(0, 0, 0, 2) avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
    pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(msg.userId or 1).."&w=150&h=150" end)
    
    local header = Instance.new("TextLabel", msgFrame) header.Size = UDim2.new(1, -42, 0, 16) header.Position = UDim2.new(0, 40, 0, 0) header.BackgroundTransparency = 1 header.TextXAlignment = Enum.TextXAlignment.Left header.Font = Enum.Font.GothamBold header.TextSize = 12 header.TextColor3 = Color3.fromRGB(255, 255, 255) header.RichText = true
    header.Text = (msg.displayName or msg.sender) .. "  <font color=\"rgb(150,150,150)\">" .. FormatMessageTime(msg.timestamp or os.time()) .. "</font>"
    
    local contentHeight = 20
    if msg.isDeleted then
        local body = Instance.new("TextLabel", msgFrame) body.Size = UDim2.new(1, -42, 0, 20) body.Position = UDim2.new(0, 40, 0, 18) body.BackgroundTransparency = 1 body.TextXAlignment = Enum.TextXAlignment.Left body.Font = Enum.Font.Gotham body.TextSize = 12 body.TextColor3 = Color3.fromRGB(150,150,150) body.Text = "🚫 Mensagem apagada"
    elseif msg.type == "sticker" then
        local img = Instance.new("ImageLabel", msgFrame) img.Size = UDim2.new(0, 100, 0, 100) img.Position = UDim2.new(0, 40, 0, 18) img.BackgroundTransparency = 1
        pcall(function() if getcustomasset then img.Image = getcustomasset(StickersFolder .. "/" .. msg.text) end end)
        contentHeight = 100
    else
        local body = Instance.new("TextLabel", msgFrame) body.Position = UDim2.new(0, 40, 0, 18) body.BackgroundTransparency = 1 body.TextXAlignment = Enum.TextXAlignment.Left body.TextYAlignment = Enum.TextYAlignment.Top body.Font = Enum.Font.Gotham body.TextSize = 12 body.TextColor3 = Color3.fromRGB(220, 220, 220) body.TextWrapped = true body.RichText = true
        body.Text = msg.text .. (msg.isEdited and " <font color=\"rgb(150,150,150)\">editado</font>" or "")
        local bounds = TextService:GetTextSize(body.Text, 12, Enum.Font.Gotham, Vector2.new(190, 10000)) -- 190 para evitar sair da tela
        body.Size = UDim2.new(0, 190, 0, bounds.Y)
        contentHeight = bounds.Y
    end
    msgFrame.Size = UDim2.new(1, 0, 0, contentHeight + 22)
    
    -- Editar/Apagar interatividade
    if msg.sender == player.Name and not msg.isDeleted then
        local btn = Instance.new("TextButton", msgFrame) btn.Size = UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text=""
        btn.MouseButton1Click:Connect(function()
            ShowPopup("Opções da mensagem", "", msg.type == "text" and "Editar" or "Ok", "Apagar", 
            function() -- Editar
                if msg.type == "text" then
                    for _,c in pairs(ModalContainer:GetChildren()) do c:Destroy() end ModalContainer.Visible=true
                    local box = Instance.new("Frame", ModalContainer) box.Size = UDim2.new(0,240,0,140) box.Position = UDim2.new(0.5,-120,0.5,-70) box.BackgroundColor3 = Color3.fromRGB(35,35,40) Instance.new("UICorner",box).CornerRadius = UDim.new(0,10)
                    local input = Instance.new("TextBox", box) input.Size=UDim2.new(1,-20,0,60) input.Position=UDim2.new(0,10,0,20) input.BackgroundColor3=Color3.fromRGB(20,20,25) input.TextColor3=Color3.fromRGB(255,255,255) input.Text=msg.text input.MultiLine=true input.TextWrapped=true input.Font=Enum.Font.Gotham input.TextSize=12
                    local bSave = Instance.new("TextButton", box) bSave.Size=UDim2.new(1,-20,0,30) bSave.Position=UDim2.new(0,10,1,-40) bSave.BackgroundColor3=Color3.fromRGB(70,130,180) bSave.Text="Salvar Edição" bSave.TextColor3=Color3.fromRGB(255,255,255) bSave.Font=Enum.Font.GothamBold
                    bSave.MouseButton1Click:Connect(function()
                        ModalContainer.Visible=false local newTxt = input.Text
                        msg.text = newTxt msg.isEdited = true
                        local h = LoadChat(ActiveChatTarget) for _,m in ipairs(h) do if m.id == msg.id then m.text=newTxt m.isEdited=true break end end SaveChat(ActiveChatTarget, h) RefreshChatUI(h)
                        pcall(function() HttpService:RequestAsync({ Url=SERVER_URL.."/edit_message", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({from=player.Name, to=ActiveChatTarget, msgId=msg.id, newText=newTxt}) }) end)
                    end)
                end
            end,
            function() -- Apagar
                msg.isDeleted = true
                local h = LoadChat(ActiveChatTarget) for _,m in ipairs(h) do if m.id == msg.id then m.isDeleted=true break end end SaveChat(ActiveChatTarget, h) RefreshChatUI(h)
                pcall(function() HttpService:RequestAsync({ Url=SERVER_URL.."/delete_message", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({from=player.Name, to=ActiveChatTarget, msgId=msg.id}) }) end)
            end)
        end)
    end
end

function RefreshChatUI(history)
    for _, c in pairs(ChatScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for _, msg in ipairs(history) do RenderMessageItem(msg) end
    ChatScroll.CanvasPosition = Vector2.new(0, 99999)
end

function SendPrivateMessage(msgType, content)
    local text = content or ChatBox.Text
    if text == "" or ActiveChatTarget == "" then return end
    ChatBox.Text = ""
    local msgData = { id = GenerateMsgId(), sender = player.Name, displayName = player.DisplayName, userId = player.UserId, type = msgType or "text", text = text, timestamp = os.time(), isEdited = false, isDeleted = false }
    
    local history = LoadChat(ActiveChatTarget) table.insert(history, msgData) SaveChat(ActiveChatTarget, history)
    RefreshChatUI(history)
    
    task.spawn(function()
        pcall(function() HttpService:RequestAsync({ Url = SERVER_URL .. "/send_message", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget, msg = msgData}) }) end)
    end)
end

SendBtn.MouseButton1Click:Connect(function() SendPrivateMessage("text") end)
ChatBox.FocusLost:Connect(function(ep) if ep then SendPrivateMessage("text") end end)

-- ==========================================
-- LOOPS DE SINCRONIZAÇÃO EM TEMPO REAL
-- ==========================================
-- Loop de Mensagens Privadas (apenas para o chat aberto)
task.spawn(function()
    while task.wait(2) do
        if ActiveChatTarget ~= "" then
            pcall(function()
                local r = HttpService:RequestAsync({Url = SERVER_URL .. "/get_messages?from=" .. ActiveChatTarget .. "&to=" .. player.Name, Method = "GET"})
                if r.Success then
                    local data = HttpService:JSONDecode(r.Body)
                    if (data.msgs and #data.msgs > 0) or (data.edits and #data.edits > 0) or (data.deletes and #data.deletes > 0) then
                        local h = LoadChat(ActiveChatTarget)
                        for _,m in ipairs(data.msgs) do table.insert(h, m) end
                        for _,ed in ipairs(data.edits) do for _,m in ipairs(h) do if m.id == ed.msgId then m.text=ed.newText m.isEdited=true break end end end
                        for _,delId in ipairs(data.deletes) do for _,m in ipairs(h) do if m.id == delId then m.isDeleted=true break end end end
                        SaveChat(ActiveChatTarget, h) RefreshChatUI(h)
                    end
                end
            end)
        end
    end
end)

-- Loop Global (Amizades e Pedidos de Sincronização)
task.spawn(function()
    while task.wait(3.5) do
        -- Busca eventos globais
        pcall(function()
            local r = HttpService:RequestAsync({Url = SERVER_URL .. "/get_global_events?username=" .. player.Name, Method = "GET"})
            if r.Success then
                local events = HttpService:JSONDecode(r.Body)
                for _, ev in ipairs(events) do
                    if ev.type == "friend_accept" then
                        if not table.find(LocalData.Friends, ev.username) then table.insert(LocalData.Friends, ev.username) SaveFriends() if CurrentMenu == FriendsMenu then LoadFriendsUI() end end
                    elseif ev.type == "unfriend" then
                        local idx = table.find(LocalData.Friends, ev.username) if idx then table.remove(LocalData.Friends, idx) SaveFriends() if CurrentMenu == FriendsMenu then LoadFriendsUI() end end
                    elseif ev.type == "sync_request" then
                        -- Outro usuário pediu seu histórico local
                        local h = LoadChat(ev.username)
                        HttpService:RequestAsync({Url = SERVER_URL .. "/provide_sync", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ev.username, history = h})})
                    end
                end
            end
        end)
        -- Verifica se alguém respondeu nosso request_sync
        pcall(function()
            local r = HttpService:RequestAsync({Url = SERVER_URL .. "/get_sync?username=" .. player.Name, Method = "GET"})
            if r.Success then
                local data = HttpService:JSONDecode(r.Body)
                for friend, remoteHist in pairs(data) do
                    local localHist = LoadChat(friend)
                    local map = {} for _,m in ipairs(localHist) do map[m.id]=true end
                    for _,m in ipairs(remoteHist) do if not map[m.id] then table.insert(localHist, m) end end
                    table.sort(localHist, function(a,b) return (a.timestamp or 0) < (b.timestamp or 0) end)
                    SaveChat(friend, localHist)
                    if ActiveChatTarget == friend then RefreshChatUI(localHist) end
                end
            end
        end)
    end
end)
