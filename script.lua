-- ==========================================
-- CHAT-UNIVERSAL V5 (Atualizado)
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

local getasset = getsynasset or getcustomasset or function() return "" end

-- ==========================================
-- SISTEMA DE PASTAS E ARQUIVOS (JSON)
-- ==========================================
local BaseFolder = "ChatUniversal_Data"
local FriendsFile = BaseFolder .. "/Amigos.json"
local StickersFolder = BaseFolder .. "/Stickers"

pcall(function()
    if isfolder and not isfolder(BaseFolder) then makefolder(BaseFolder) end
    if isfolder and not isfolder(StickersFolder) then makefolder(StickersFolder) end
end)

local LocalData = { Friends = {}, RecentStickers = {} }
local LocalStickers = {}

local function SaveFriends()
    pcall(function()
        if writefile then
            writefile(FriendsFile, HttpService:JSONEncode(LocalData))
        end
    end)
end

local function LoadFriends()
    pcall(function()
        if isfile and isfile(FriendsFile) then
            local decoded = HttpService:JSONDecode(readfile(FriendsFile))
            if decoded then
                if decoded.Friends then LocalData.Friends = decoded.Friends else LocalData.Friends = decoded end
                if decoded.RecentStickers then LocalData.RecentStickers = decoded.RecentStickers end
            end
        end
    end)
end
LoadFriends()

local function GetChatFilePath(friendName)
    return BaseFolder .. "/Chat_" .. friendName .. ".json"
end

local function SaveChat(friendName, chatHistory)
    pcall(function() if writefile then writefile(GetChatFilePath(friendName), HttpService:JSONEncode(chatHistory)) end end)
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

local function LoadRemoteStickers()
    task.spawn(function()
        pcall(function()
            local res = HttpService:RequestAsync({Url = "https://api.github.com/repos/technomilgrau/Chat-universal/contents/Stickers", Method = "GET"})
            if res.Success then
                local files = HttpService:JSONDecode(res.Body)
                for _, file in ipairs(files) do
                    if file.name:match("%.png$") or file.name:match("%.jpg$") then
                        local localPath = StickersFolder .. "/" .. file.name
                        if not isfile(localPath) then
                            local imgRes = HttpService:RequestAsync({Url = file.download_url, Method = "GET"})
                            if imgRes.Success then writefile(localPath, imgRes.Body) end
                        end
                        if isfile(localPath) then
                            table.insert(LocalStickers, {name = file.name, path = localPath, asset = getasset(localPath)})
                        end
                    end
                end
            end
        end)
    end)
end
LoadRemoteStickers()

task.spawn(function()
    pcall(function()
        HttpService:RequestAsync({
            Url = SERVER_URL .. "/register", Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({username = player.Name, displayName = player.DisplayName, userId = player.UserId})
        })
    end)
end)

-- ==========================================
-- CRIANDO A INTERFACE (GUI)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatUniversalHub"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrameWrapper = Instance.new("Frame", ScreenGui)
MainFrameWrapper.Size = UDim2.new(0, 280, 0, 480) MainFrameWrapper.Position = UDim2.new(0.5, -140, 0.5, -240) MainFrameWrapper.BackgroundColor3 = Color3.fromRGB(30, 30, 35) MainFrameWrapper.BorderSizePixel = 0 MainFrameWrapper.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrameWrapper) MainCorner.CornerRadius = UDim.new(0, 10)

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
    UserInputService.InputEnded:Connect(function(input) if input == dragInput then dragging = false dragInput = nil end end)
end

local TitleBar = Instance.new("Frame", MainFrameWrapper)
TitleBar.Size = UDim2.new(1, 0, 0, 40) TitleBar.BackgroundTransparency = 1 TitleBar.ZIndex = 10
MakeDraggable(TitleBar, MainFrameWrapper)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -80, 0, 20) Title.Position = UDim2.new(0, 10, 0, 5) Title.BackgroundTransparency = 1 Title.Text = "Chat-universal" Title.TextColor3 = Color3.fromRGB(255, 255, 255) Title.Font = Enum.Font.GothamBold Title.TextSize = 18 Title.TextXAlignment = Enum.TextXAlignment.Left

local Subtitle = Instance.new("TextLabel", TitleBar)
Subtitle.Size = UDim2.new(1, -80, 0, 12) Subtitle.Position = UDim2.new(0, 10, 0, 24) Subtitle.BackgroundTransparency = 1 Subtitle.Text = "techno_milgrau" Subtitle.TextColor3 = Color3.fromRGB(150, 150, 150) Subtitle.Font = Enum.Font.Gotham Subtitle.TextSize = 10 Subtitle.TextXAlignment = Enum.TextXAlignment.Left

local NotifyBtn = Instance.new("TextButton", TitleBar)
NotifyBtn.Size = UDim2.new(0, 30, 0, 30) NotifyBtn.Position = UDim2.new(1, -65, 0, 5) NotifyBtn.BackgroundTransparency = 1 NotifyBtn.Text = "🔔" NotifyBtn.TextColor3 = Color3.fromRGB(200, 200, 200) NotifyBtn.Font = Enum.Font.GothamBold NotifyBtn.TextSize = 16

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
    CurrentMenu:TweenPosition(UDim2.new(-1, 0, 0, 0), "Out", "Quad", 0.2, true)
    newMenu.Position = UDim2.new(1, 0, 0, 0)
    newMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    table.insert(MenuStack, newMenu)
    CurrentMenu = newMenu
end

local function CloseMenu()
    if #MenuStack <= 1 then return end
    local menuToClose = table.remove(MenuStack)
    local previousMenu = MenuStack[#MenuStack]
    menuToClose:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Quad", 0.2, true)
    previousMenu.Position = UDim2.new(-1, 0, 0, 0)
    previousMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    CurrentMenu = previousMenu
end

local function createTopBar(parent, titleText, backAction)
    local bar = Instance.new("Frame", parent) bar.Size = UDim2.new(1, 0, 0, 40) bar.BackgroundTransparency = 1
    local title = Instance.new("TextLabel", bar) title.Size = UDim2.new(1, -40, 1, 0) title.Position = UDim2.new(0, 40, 0, 0) title.BackgroundTransparency = 1 title.Text = titleText title.TextColor3 = Color3.fromRGB(255, 255, 255) title.Font = Enum.Font.GothamBold title.TextSize = 16 title.TextXAlignment = Enum.TextXAlignment.Left
    local backBtn = Instance.new("TextButton", bar) backBtn.Size = UDim2.new(0, 30, 0, 30) backBtn.Position = UDim2.new(0, 5, 0, 5) backBtn.BackgroundTransparency = 1 backBtn.Text = "◀" backBtn.TextColor3 = Color3.fromRGB(200, 200, 200) backBtn.Font = Enum.Font.GothamBold backBtn.TextSize = 18
    backBtn.MouseButton1Click:Connect(backAction or CloseMenu)
    return title
end

-- ==========================================
-- POPUP GENÉRICO (Confirmar/Input)
-- ==========================================
local PopupLayer = Instance.new("Frame", ScreenGui)
PopupLayer.Size = UDim2.new(1,0,1,0) PopupLayer.BackgroundColor3 = Color3.fromRGB(0,0,0) PopupLayer.BackgroundTransparency = 0.5 PopupLayer.Visible = false PopupLayer.ZIndex = 100

local PopupBox = Instance.new("Frame", PopupLayer)
PopupBox.Size = UDim2.new(0, 220, 0, 150) PopupBox.Position = UDim2.new(0.5, -110, 0.5, -75) PopupBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", PopupBox).CornerRadius = UDim.new(0, 8)

local PopupTitle = Instance.new("TextLabel", PopupBox)
PopupTitle.Size = UDim2.new(1,0,0,30) PopupTitle.BackgroundTransparency = 1 PopupTitle.TextColor3 = Color3.fromRGB(255,255,255) PopupTitle.Font = Enum.Font.GothamBold PopupTitle.TextSize = 14

local PopupInput = Instance.new("TextBox", PopupBox)
PopupInput.Size = UDim2.new(1,-20, 0, 60) PopupInput.Position = UDim2.new(0,10,0,35) PopupInput.BackgroundColor3 = Color3.fromRGB(40,40,45) PopupInput.TextColor3 = Color3.fromRGB(255,255,255) PopupInput.Font = Enum.Font.Gotham PopupInput.TextSize = 12 PopupInput.TextWrapped = true PopupInput.MultiLine = true PopupInput.ClearTextOnFocus = false
Instance.new("UICorner", PopupInput).CornerRadius = UDim.new(0, 6)

local PopupBtnYes = Instance.new("TextButton", PopupBox)
PopupBtnYes.Size = UDim2.new(0.5, -15, 0, 30) PopupBtnYes.Position = UDim2.new(0, 10, 1, -40) PopupBtnYes.BackgroundColor3 = Color3.fromRGB(46, 204, 113) PopupBtnYes.TextColor3 = Color3.fromRGB(255,255,255) PopupBtnYes.Font = Enum.Font.GothamBold
Instance.new("UICorner", PopupBtnYes).CornerRadius = UDim.new(0, 6)

local PopupBtnNo = Instance.new("TextButton", PopupBox)
PopupBtnNo.Size = UDim2.new(0.5, -15, 0, 30) PopupBtnNo.Position = UDim2.new(0.5, 5, 1, -40) PopupBtnNo.BackgroundColor3 = Color3.fromRGB(231, 76, 60) PopupBtnNo.Text = "Não" PopupBtnNo.TextColor3 = Color3.fromRGB(255,255,255) PopupBtnNo.Font = Enum.Font.GothamBold
Instance.new("UICorner", PopupBtnNo).CornerRadius = UDim.new(0, 6)

local currentPopupCallback = nil
PopupBtnNo.MouseButton1Click:Connect(function() PopupLayer.Visible = false end)
PopupBtnYes.MouseButton1Click:Connect(function()
    PopupLayer.Visible = false
    if currentPopupCallback then currentPopupCallback(PopupInput.Text) end
end)

local function ShowPopup(title, btnYesText, showInput, inputText, callback)
    PopupTitle.Text = title
    PopupBtnYes.Text = btnYesText
    PopupBtnNo.Text = "Não"
    PopupBtnNo.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    PopupBtnYes.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    PopupInput.Visible = showInput
    if showInput then PopupInput.Text = inputText or "" end
    currentPopupCallback = callback
    PopupLayer.Visible = true
end

-- ==========================================
-- MENU PRINCIPAL E NAVEGAÇÃO
-- ==========================================
local SearchBtn = Instance.new("TextButton", MainMenu)
SearchBtn.Size = UDim2.new(0, 240, 0, 45) SearchBtn.Position = UDim2.new(0.5, -120, 0, 20) SearchBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) SearchBtn.Text = "🔍 Procurar Amigos" SearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SearchBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 6)
SearchBtn.MouseButton1Click:Connect(function() OpenMenu(SearchMenu) end)

local MessagesBtn = Instance.new("TextButton", MainMenu)
MessagesBtn.Size = UDim2.new(0, 240, 0, 45) MessagesBtn.Position = UDim2.new(0.5, -120, 0, 75) MessagesBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) MessagesBtn.Text = "💬 Mensagens" MessagesBtn.TextColor3 = Color3.fromRGB(255, 255, 255) MessagesBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", MessagesBtn).CornerRadius = UDim.new(0, 6)
MessagesBtn.MouseButton1Click:Connect(function() OpenMenu(FriendsMenu) LoadFriendsUI() end)

local MyProfileBtn = Instance.new("TextButton", MainMenu)
MyProfileBtn.Size = UDim2.new(0, 240, 0, 45) MyProfileBtn.Position = UDim2.new(0.5, -120, 0, 130) MyProfileBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) MyProfileBtn.Text = "👤 Meu Perfil" MyProfileBtn.TextColor3 = Color3.fromRGB(255, 255, 255) MyProfileBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", MyProfileBtn).CornerRadius = UDim.new(0, 6)
MyProfileBtn.MouseButton1Click:Connect(function() LoadProfile(player.Name) end)

NotifyBtn.MouseButton1Click:Connect(function() if CurrentMenu ~= NotificationsMenu then OpenMenu(NotificationsMenu) LoadNotificationsUI() end end)

-- ==========================================
-- LÓGICA DE PERFIL E AMIGOS (User Entry)
-- ==========================================
local function CreateUserEntry(parent, displayName, username, userId, mode, onClickOrAdd, statusText)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -20, 0, 60) frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45) frame.Position = UDim2.new(0,10,0,0)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local avatar = Instance.new("ImageLabel", frame)
    avatar.Size = UDim2.new(0, 45, 0, 45) avatar.Position = UDim2.new(0, 8, 0, 7) avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 6)
    pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..userId.."&w=150&h=150" end)
    
    local avatarBtn = Instance.new("TextButton", avatar)
    avatarBtn.Size = UDim2.new(1,0,1,0) avatarBtn.BackgroundTransparency = 1 avatarBtn.Text = ""
    avatarBtn.MouseButton1Click:Connect(function() LoadProfile(username) end)
    
    local dName = Instance.new("TextLabel", frame)
    dName.Size = UDim2.new(0, 100, 0, 20) dName.Position = UDim2.new(0, 60, 0, 8) dName.BackgroundTransparency = 1 dName.Text = displayName dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left dName.TextScaled = true
    
    local userBox = Instance.new("Frame", frame)
    userBox.Size = UDim2.new(0, 90, 0, 16) userBox.Position = UDim2.new(0, 60, 0, 32) userBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30) Instance.new("UICorner", userBox).CornerRadius = UDim.new(0, 4)
    local uName = Instance.new("TextLabel", userBox)
    uName.Size = UDim2.new(1, -10, 1, 0) uName.Position = UDim2.new(0, 5, 0, 0) uName.BackgroundTransparency = 1 uName.Text = "@" .. username uName.TextColor3 = Color3.fromRGB(180, 180, 180) uName.Font = Enum.Font.Gotham uName.TextSize = 10 uName.TextXAlignment = Enum.TextXAlignment.Left
    
    if mode == "Search" then
        local actionBtn = Instance.new("TextButton", frame)
        actionBtn.Size = UDim2.new(0, 70, 0, 26) actionBtn.Position = UDim2.new(1, -78, 0.5, -13) actionBtn.Font = Enum.Font.GothamBold actionBtn.TextSize = 11 actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)
        
        local isFriend = false
        for _, f in ipairs(LocalData.Friends) do if f == username then isFriend = true break end end
        
        if isFriend then
            actionBtn.Text = "Amigos" actionBtn.BackgroundColor3 = Color3.fromRGB(50,50,55)
            actionBtn.MouseButton1Click:Connect(function()
                ShowPopup("Desfazer amizade?", "Sim", false, "", function()
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/remove_friend", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = username})}) end)
                    for i, f in ipairs(LocalData.Friends) do if f == username then table.remove(LocalData.Friends, i) break end end
                    SaveFriends() actionBtn.Text = "Adicionar" actionBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
                end)
            end)
        else
            actionBtn.Text = "Adicionar" actionBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
            actionBtn.MouseButton1Click:Connect(function()
                if actionBtn.Text == "Adicionar" then
                    actionBtn.Text = "Enviado" actionBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                    onClickOrAdd(username)
                end
            end)
        end
    elseif mode == "Friend" then
        local statusLabel = Instance.new("TextLabel", frame)
        statusLabel.Size = UDim2.new(0, 70, 0, 16) statusLabel.Position = UDim2.new(1, -78, 0.5, -8) statusLabel.BackgroundTransparency = 1 statusLabel.Font = Enum.Font.Gotham statusLabel.TextSize = 10 statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusText = statusText or "Offline" statusLabel.Text = statusText
        if statusText == "Online" then statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113) elseif statusText == "Digitando..." then statusLabel.TextColor3 = Color3.fromRGB(241, 196, 15) else statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150) end

        local hitBox = Instance.new("TextButton", frame)
        hitBox.Size = UDim2.new(1, -70, 1, 0) hitBox.Position = UDim2.new(0, 70, 0, 0) hitBox.BackgroundTransparency = 1 hitBox.Text = ""
        hitBox.MouseButton1Click:Connect(function() onClickOrAdd(username, displayName, userId) end)
    end
    return frame
end

-- ==========================================
-- PROCURAR AMIGOS
-- ==========================================
createTopBar(SearchMenu, "Procurar")
local SearchBoxFrame = Instance.new("Frame", SearchMenu) SearchBoxFrame.Size = UDim2.new(1, -20, 0, 35) SearchBoxFrame.Position = UDim2.new(0, 10, 0, 45) SearchBoxFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", SearchBoxFrame).CornerRadius = UDim.new(0, 6)
local SearchInput = Instance.new("TextBox", SearchBoxFrame) SearchInput.Size = UDim2.new(1, -20, 1, 0) SearchInput.Position = UDim2.new(0, 10, 0, 0) SearchInput.BackgroundTransparency = 1 SearchInput.PlaceholderText = "Pesquisar nick..." SearchInput.Text = "" SearchInput.TextColor3 = Color3.fromRGB(255, 255, 255) SearchInput.Font = Enum.Font.Gotham SearchInput.TextSize = 13 SearchInput.TextXAlignment = Enum.TextXAlignment.Left

local SearchResults = Instance.new("ScrollingFrame", SearchMenu) SearchResults.Size = UDim2.new(1, 0, 1, -90) SearchResults.Position = UDim2.new(0, 0, 0, 90) SearchResults.BackgroundTransparency = 1 SearchResults.ScrollBarThickness = 3
local SearchLayout = Instance.new("UIListLayout", SearchResults) SearchLayout.Padding = UDim.new(0, 8) SearchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SearchLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SearchResults.CanvasSize = UDim2.new(0, 0, 0, SearchLayout.AbsoluteContentSize.Y + 10) end)

local searchTick = 0
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text
    for _, child in pairs(SearchResults:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    if query == "" then return end
    
    searchTick = searchTick + 1
    local currentTick = searchTick
    task.delay(0.5, function()
        if currentTick ~= searchTick then return end
        task.spawn(function()
            local res = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL .. "/users?query=" .. HttpService:UrlEncode(query), Method = "GET"}) end)
            if res and res.Success then
                local users = HttpService:JSONDecode(res.Body)
                for _, u in ipairs(users) do
                    if u.username ~= player.Name then
                        CreateUserEntry(SearchResults, u.displayName, u.username, u.userId or 1, "Search", function(targetUser)
                            task.spawn(function() pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = targetUser})}) end) end)
                        end)
                    end
                end
            end
        end)
    end)
end)

-- ==========================================
-- PERFIL
-- ==========================================
createTopBar(ProfileMenu, "Perfil")
local ProfAvatar = Instance.new("ImageLabel", ProfileMenu) ProfAvatar.Size = UDim2.new(0, 80, 0, 80) ProfAvatar.Position = UDim2.new(0.5, -40, 0, 50) ProfAvatar.BackgroundColor3 = Color3.fromRGB(40,40,45) Instance.new("UICorner", ProfAvatar).CornerRadius = UDim.new(1, 0)
local ProfDisplay = Instance.new("TextLabel", ProfileMenu) ProfDisplay.Size = UDim2.new(1, 0, 0, 20) ProfDisplay.Position = UDim2.new(0, 0, 0, 140) ProfDisplay.BackgroundTransparency = 1 ProfDisplay.Font = Enum.Font.GothamBold ProfDisplay.TextSize = 16 ProfDisplay.TextColor3 = Color3.fromRGB(255,255,255)
local ProfUser = Instance.new("TextLabel", ProfileMenu) ProfUser.Size = UDim2.new(1, 0, 0, 15) ProfUser.Position = UDim2.new(0, 0, 0, 160) ProfUser.BackgroundTransparency = 1 ProfUser.Font = Enum.Font.Gotham ProfUser.TextSize = 12 ProfUser.TextColor3 = Color3.fromRGB(150,150,150)
local ProfFriendsCount = Instance.new("TextLabel", ProfileMenu) ProfFriendsCount.Size = UDim2.new(1, 0, 0, 15) ProfFriendsCount.Position = UDim2.new(0, 0, 0, 185) ProfFriendsCount.BackgroundTransparency = 1 ProfFriendsCount.Font = Enum.Font.GothamBold ProfFriendsCount.TextSize = 14 ProfFriendsCount.TextColor3 = Color3.fromRGB(255,255,255)
local ProfFriendsLabel = Instance.new("TextLabel", ProfileMenu) ProfFriendsLabel.Size = UDim2.new(1, 0, 0, 15) ProfFriendsLabel.Position = UDim2.new(0, 0, 0, 200) ProfFriendsLabel.BackgroundTransparency = 1 ProfFriendsLabel.Font = Enum.Font.Gotham ProfFriendsLabel.TextSize = 10 ProfFriendsLabel.TextColor3 = Color3.fromRGB(150,150,150) ProfFriendsLabel.Text = "amigos"

local ProfActionBtn = Instance.new("TextButton", ProfileMenu) ProfActionBtn.Size = UDim2.new(0, 120, 0, 35) ProfActionBtn.Position = UDim2.new(0.5, -60, 0, 230) ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 90) ProfActionBtn.Font = Enum.Font.GothamBold ProfActionBtn.TextColor3 = Color3.fromRGB(255,255,255) ProfActionBtn.TextSize = 14 Instance.new("UICorner", ProfActionBtn).CornerRadius = UDim.new(0, 8)
local ProfBioBtn = Instance.new("TextButton", ProfileMenu) ProfBioBtn.Size = UDim2.new(1, -40, 0, 60) ProfBioBtn.Position = UDim2.new(0, 20, 0, 280) ProfBioBtn.BackgroundTransparency = 1 ProfBioBtn.Font = Enum.Font.Gotham ProfBioBtn.TextSize = 12 ProfBioBtn.TextColor3 = Color3.fromRGB(220,220,220) ProfBioBtn.TextWrapped = true ProfBioBtn.TextYAlignment = Enum.TextYAlignment.Top

local CurrentProfileUser = ""
function LoadProfile(username)
    OpenMenu(ProfileMenu)
    ProfDisplay.Text = "Carregando..." ProfUser.Text = "@" .. username ProfFriendsCount.Text = "-" ProfBioBtn.Text = "" ProfActionBtn.Visible = false
    CurrentProfileUser = username
    task.spawn(function()
        local res = HttpService:RequestAsync({Url = SERVER_URL .. "/profile?username=" .. username, Method = "GET"})
        if res.Success then
            local data = HttpService:JSONDecode(res.Body)
            ProfDisplay.Text = data.displayName ProfFriendsCount.Text = tostring(data.friendCount)
            pcall(function() ProfAvatar.Image = "rbxthumb://type=AvatarHeadShot&id="..data.userId.."&w=150&h=150" end)
            if username == player.Name then
                ProfActionBtn.Visible = false
                if not data.bio or data.bio == "" then ProfBioBtn.Text = "adicionar bio+" ProfBioBtn.TextColor3 = Color3.fromRGB(255,255,255) ProfBioBtn.Font = Enum.Font.GothamBold
                else ProfBioBtn.Text = data.bio ProfBioBtn.TextColor3 = Color3.fromRGB(220,220,220) ProfBioBtn.Font = Enum.Font.Gotham end
            else
                ProfActionBtn.Visible = true
                ProfBioBtn.Text = (not data.bio or data.bio == "") and "" or data.bio
                local friendRes = HttpService:RequestAsync({Url = SERVER_URL .. "/check_friendship?user=" .. player.Name .. "&friend=" .. username, Method = "GET"})
                if friendRes.Success then
                    local fStatus = HttpService:JSONDecode(friendRes.Body).status
                    if fStatus == "friends" then ProfActionBtn.Text = "Mensagem" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(50,50,55)
                    elseif fStatus == "pending_sent" then ProfActionBtn.Text = "Enviado" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(150,150,150)
                    else ProfActionBtn.Text = "Adicionar" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 90) end
                end
            end
        end
    end)
end

ProfActionBtn.MouseButton1Click:Connect(function()
    if ProfActionBtn.Text == "Adicionar" then
        ProfActionBtn.Text = "Enviado" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(150,150,150)
        pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = CurrentProfileUser})}) end)
    elseif ProfActionBtn.Text == "Mensagem" then
        OpenPrivateChat(CurrentProfileUser, ProfDisplay.Text, 1)
    end
end)

ProfBioBtn.MouseButton1Click:Connect(function()
    if CurrentProfileUser == player.Name then
        if ProfBioBtn.Text == "adicionar bio+" then
            ShowPopup("Escrever biografia", "Salvar", true, "", function(newBio)
                if newBio then
                    ProfBioBtn.Text = newBio ProfBioBtn.TextColor3 = Color3.fromRGB(220,220,220) ProfBioBtn.Font = Enum.Font.Gotham
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/update_bio", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({username = player.Name, bio = newBio})}) end)
                end
            end)
        else
            ShowPopup("Editar biografia?", "Sim", true, ProfBioBtn.Text, function(newBio)
                if newBio then
                    ProfBioBtn.Text = newBio
                    if newBio == "" then ProfBioBtn.Text = "adicionar bio+" ProfBioBtn.TextColor3 = Color3.fromRGB(255,255,255) ProfBioBtn.Font = Enum.Font.GothamBold end
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/update_bio", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({username = player.Name, bio = newBio})}) end)
                end
            end)
        end
    end
end)

-- ==========================================
-- NOTIFICAÇÕES (Concertado avatar UserId)
-- ==========================================
createTopBar(NotificationsMenu, "Notificações")
local RequestsList = Instance.new("ScrollingFrame", NotificationsMenu) RequestsList.Size = UDim2.new(1, 0, 1, -50) RequestsList.Position = UDim2.new(0, 0, 0, 50) RequestsList.BackgroundTransparency = 1 RequestsList.ScrollBarThickness = 3
local ReqLayout = Instance.new("UIListLayout", RequestsList) ReqLayout.Padding = UDim.new(0, 8) ReqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ReqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RequestsList.CanvasSize = UDim2.new(0, 0, 0, ReqLayout.AbsoluteContentSize.Y + 10) end)

function LoadNotificationsUI()
    for _, child in pairs(RequestsList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    task.spawn(function()
        local res = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL .. "/get_requests?username=" .. player.Name, Method = "GET"}) end)
        if res and res.Success then
            local requests = HttpService:JSONDecode(res.Body)
            for _, req in ipairs(requests) do
                local card = Instance.new("Frame", RequestsList) card.Size = UDim2.new(1, -20, 0, 60) card.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                local avatar = Instance.new("ImageLabel", card) avatar.Size = UDim2.new(0, 45, 0, 45) avatar.Position = UDim2.new(0, 8, 0, 7) avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 8)
                pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(req.fromId or 1).."&w=150&h=150" end)
                local dName = Instance.new("TextLabel", card) dName.Size = UDim2.new(0, 100, 0, 18) dName.Position = UDim2.new(0, 60, 0, 10) dName.BackgroundTransparency = 1 dName.Text = req.fromDisplay or req.from dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left dName.TextSize = 12
                local uName = Instance.new("TextLabel", card) uName.Size = UDim2.new(0, 100, 0, 14) uName.Position = UDim2.new(0, 60, 0, 30) uName.BackgroundTransparency = 1 uName.Text = "@" .. req.from uName.TextColor3 = Color3.fromRGB(150, 150, 150) uName.Font = Enum.Font.Gotham uName.TextXAlignment = Enum.TextXAlignment.Left uName.TextSize = 10
                
                local acceptBtn = Instance.new("TextButton", card) acceptBtn.Size = UDim2.new(0, 28, 0, 28) acceptBtn.Position = UDim2.new(1, -65, 0.5, -14) acceptBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113) acceptBtn.Text = "✓" acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255) acceptBtn.Font = Enum.Font.GothamBold acceptBtn.TextSize = 14 Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)
                local declineBtn = Instance.new("TextButton", card) declineBtn.Size = UDim2.new(0, 28, 0, 28) declineBtn.Position = UDim2.new(1, -32, 0.5, -14) declineBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) declineBtn.Text = "✕" declineBtn.TextColor3 = Color3.fromRGB(255, 255, 255) declineBtn.Font = Enum.Font.GothamBold declineBtn.TextSize = 14 Instance.new("UICorner", declineBtn).CornerRadius = UDim.new(0, 6)
                
                acceptBtn.MouseButton1Click:Connect(function()
                    if not table.find(LocalData.Friends, req.from) then table.insert(LocalData.Friends, req.from) SaveFriends() end
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/accept_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from})}) end)
                    card:Destroy()
                end)
                declineBtn.MouseButton1Click:Connect(function()
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/decline_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from})}) end)
                    card:Destroy()
                end)
            end
        end
    end)
end

-- ==========================================
-- CHAT PRIVADO
-- ==========================================
createTopBar(FriendsMenu, "Mensagens")
local FriendsList = Instance.new("ScrollingFrame", FriendsMenu) FriendsList.Size = UDim2.new(1, 0, 1, -50) FriendsList.Position = UDim2.new(0, 0, 0, 50) FriendsList.BackgroundTransparency = 1 FriendsList.ScrollBarThickness = 3
local FriendsLayout = Instance.new("UIListLayout", FriendsList) FriendsLayout.Padding = UDim.new(0, 8) FriendsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
FriendsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() FriendsList.CanvasSize = UDim2.new(0, 0, 0, FriendsLayout.AbsoluteContentSize.Y + 10) end)

local ActiveChatTarget = ""
local ActiveChatTargetDisplay = ""
local ActiveChatTargetId = 1

local ChatTitle = createTopBar(PrivateChatMenu, "Chat", function() CloseMenu() ActiveChatTarget = "" end)
local SyncBtn = Instance.new("TextButton", ChatTitle.Parent)
SyncBtn.Size = UDim2.new(0, 30, 0, 30) SyncBtn.Position = UDim2.new(1, -35, 0, 5) SyncBtn.BackgroundTransparency = 1 SyncBtn.Text = "🔄" SyncBtn.TextColor3 = Color3.fromRGB(200,200,200) SyncBtn.TextSize = 16
SyncBtn.MouseButton1Click:Connect(function()
    if ActiveChatTarget ~= "" then
        pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/request_sync", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget})}) end)
        SyncBtn.Text = "✔" task.wait(2) SyncBtn.Text = "🔄"
    end
end)

function OpenPrivateChat(username, displayName, userId)
    ActiveChatTarget = username ActiveChatTargetDisplay = displayName or username ActiveChatTargetId = userId or 1
    ChatTitle.Text = ActiveChatTargetDisplay
    OpenMenu(PrivateChatMenu)
    RefreshChatUI(LoadChat(username))
end

function LoadFriendsUI()
    for _, child in pairs(FriendsList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, friendName in ipairs(LocalData.Friends) do
        local targetId = 1 pcall(function() targetId = Players:GetUserIdFromNameAsync(friendName) end)
        local statusText = "Offline"
        pcall(function() local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_status?username=" .. friendName, Method = "GET"}) if res.Success then statusText = HttpService:JSONDecode(res.Body).status end end)
        CreateUserEntry(FriendsList, friendName, friendName, targetId, "Friend", OpenPrivateChat, statusText)
    end
end

local ChatScroll = Instance.new("ScrollingFrame", PrivateChatMenu) ChatScroll.Size = UDim2.new(1, -20, 1, -100) ChatScroll.Position = UDim2.new(0, 10, 0, 45) ChatScroll.BackgroundTransparency = 1 ChatScroll.ScrollBarThickness = 4
local ChatLayout = Instance.new("UIListLayout", ChatScroll) ChatLayout.Padding = UDim.new(0, 8)
ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ChatScroll.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10) end)

local ChatInputFrame = Instance.new("Frame", PrivateChatMenu) ChatInputFrame.Size = UDim2.new(1, -20, 0, 40) ChatInputFrame.Position = UDim2.new(0, 10, 1, -50) ChatInputFrame.BackgroundTransparency = 1
local StickerBtn = Instance.new("TextButton", ChatInputFrame) StickerBtn.Size = UDim2.new(0, 30, 0, 30) StickerBtn.Position = UDim2.new(0, 5, 0, 5) StickerBtn.BackgroundTransparency = 1 StickerBtn.Text = "☺" StickerBtn.TextColor3 = Color3.fromRGB(200,200,200) StickerBtn.Font = Enum.Font.GothamBold StickerBtn.TextSize = 20
local ChatBox = Instance.new("TextBox", ChatInputFrame) ChatBox.Size = UDim2.new(1, -110, 1, 0) ChatBox.Position = UDim2.new(0, 40, 0, 0) ChatBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45) ChatBox.TextColor3 = Color3.fromRGB(255, 255, 255) ChatBox.Font = Enum.Font.Gotham ChatBox.TextSize = 13 ChatBox.PlaceholderText = "Mensagem..." ChatBox.Text = "" ChatBox.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", ChatBox).CornerRadius = UDim.new(0, 6)
local UIPaddingBox = Instance.new("UIPadding", ChatBox) UIPaddingBox.PaddingLeft = UDim.new(0, 10) UIPaddingBox.PaddingRight = UDim.new(0, 10)
local SendBtn = Instance.new("TextButton", ChatInputFrame) SendBtn.Size = UDim2.new(0, 60, 1, 0) SendBtn.Position = UDim2.new(1, -60, 0, 0) SendBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180) SendBtn.Text = "Enviar" SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SendBtn.Font = Enum.Font.GothamBold SendBtn.TextSize = 12 Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 6)

-- Painel de Stickers
local StickerPanel = Instance.new("Frame", PrivateChatMenu) StickerPanel.Size = UDim2.new(1, 0, 0, 200) StickerPanel.Position = UDim2.new(0, 0, 1, 0) StickerPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 40) StickerPanel.ZIndex = 5
local StickerScroll = Instance.new("ScrollingFrame", StickerPanel) StickerScroll.Size = UDim2.new(1, 0, 1, -10) StickerScroll.Position = UDim2.new(0, 0, 0, 10) StickerScroll.BackgroundTransparency = 1 StickerScroll.ScrollBarThickness = 2
local StickerLayoutGrid = Instance.new("UIGridLayout", StickerScroll) StickerLayoutGrid.CellSize = UDim2.new(0, 60, 0, 60) StickerLayoutGrid.CellPadding = UDim2.new(0, 5, 0, 5) StickerLayoutGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center StickerLayoutGrid.SortOrder = Enum.SortOrder.LayoutOrder

local isStickerPanelOpen = false
StickerBtn.MouseButton1Click:Connect(function()
    isStickerPanelOpen = not isStickerPanelOpen
    if isStickerPanelOpen then
        StickerPanel:TweenPosition(UDim2.new(0, 0, 1, -200), "Out", "Quad", 0.2, true)
        ChatScroll.Size = UDim2.new(1, -20, 1, -300) ChatInputFrame.Position = UDim2.new(0, 10, 1, -250)
        RenderStickerPanel()
    else
        StickerPanel:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.2, true)
        ChatScroll.Size = UDim2.new(1, -20, 1, -100) ChatInputFrame.Position = UDim2.new(0, 10, 1, -50)
    end
end)

function RenderStickerPanel()
    for _, child in pairs(StickerScroll:GetChildren()) do if child:IsA("ImageButton") or child:IsA("TextLabel") then child:Destroy() end end
    local function CreateLabel(text, order)
        local lbl = Instance.new("TextLabel", StickerScroll) lbl.Size = UDim2.new(1, 0, 0, 20) lbl.BackgroundTransparency = 1 lbl.Text = text lbl.TextColor3 = Color3.fromRGB(150,150,150) lbl.Font = Enum.Font.GothamBold lbl.TextSize = 10 lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.LayoutOrder = order
    end
    
    CreateLabel("RECENTES", 1)
    local idx = 2
    for _, rName in ipairs(LocalData.RecentStickers) do
        for _, s in ipairs(LocalStickers) do
            if s.name == rName then
                local btn = Instance.new("ImageButton", StickerScroll) btn.Size = UDim2.new(0,60,0,60) btn.BackgroundColor3 = Color3.fromRGB(45,45,50) btn.Image = s.asset btn.LayoutOrder = idx Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                idx = idx + 1
                btn.MouseButton1Click:Connect(function() SendPrivateMessage(true, s.name); AddSticker(s.name) end)
            end
        end
    end
    
    CreateLabel("TODAS", idx) idx = idx + 1
    for _, s in ipairs(LocalStickers) do
        local btn = Instance.new("ImageButton", StickerScroll) btn.Size = UDim2.new(0,60,0,60) btn.BackgroundColor3 = Color3.fromRGB(45,45,50) btn.Image = s.asset btn.LayoutOrder = idx Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        idx = idx + 1
        btn.MouseButton1Click:Connect(function() SendPrivateMessage(true, s.name); AddSticker(s.name) end)
    end
end

function AddSticker(name)
    for i, v in ipairs(LocalData.RecentStickers) do if v == name then table.remove(LocalData.RecentStickers, i) break end end
    table.insert(LocalData.RecentStickers, 1, name)
    if #LocalData.RecentStickers > 5 then table.remove(LocalData.RecentStickers, 6) end
    SaveFriends() RenderStickerPanel()
end

local function SendMsgAction(msgId, action, newText)
    local history = LoadChat(ActiveChatTarget)
    for _, m in ipairs(history) do if m.msgId == msgId then if action == "delete" then m.deleted = true elseif action == "edit" then m.text = newText m.edited = true end end end
    SaveChat(ActiveChatTarget, history) RefreshChatUI(history)
    task.spawn(function() pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/message_action", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget, msgId = msgId, action = action, newText = newText})}) end) end)
end

local function RenderMessageItem(msg)
    local msgFrame = Instance.new("Frame", ChatScroll) msgFrame.BackgroundTransparency = 1
    local avatar = Instance.new("ImageLabel", msgFrame) avatar.Size = UDim2.new(0, 32, 0, 32) avatar.Position = UDim2.new(0, 0, 0, 2) avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
    pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(msg.userId or 1).."&w=150&h=150" end)
    
    local headerLabel = Instance.new("TextLabel", msgFrame) headerLabel.Size = UDim2.new(1, -42, 0, 16) headerLabel.Position = UDim2.new(0, 40, 0, 0) headerLabel.BackgroundTransparency = 1 headerLabel.TextXAlignment = Enum.TextXAlignment.Left headerLabel.Font = Enum.Font.GothamBold headerLabel.TextSize = 12 headerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) headerLabel.RichText = true
    headerLabel.Text = (msg.displayName or msg.sender)
    
    local contentHeight = 0
    if msg.deleted then
        local bodyElement = Instance.new("TextLabel", msgFrame) bodyElement.Size = UDim2.new(1, -42, 0, 16) bodyElement.Position = UDim2.new(0, 40, 0, 18) bodyElement.BackgroundTransparency = 1 bodyElement.TextXAlignment = Enum.TextXAlignment.Left bodyElement.TextYAlignment = Enum.TextYAlignment.Top bodyElement.Font = Enum.Font.GothamItalic bodyElement.TextSize = 12 bodyElement.TextColor3 = Color3.fromRGB(150, 150, 150) bodyElement.Text = "🚫 Mensagem apagada"
        contentHeight = 16
    elseif msg.type == "sticker" then
        local bodyElement = Instance.new("ImageLabel", msgFrame) bodyElement.Size = UDim2.new(0, 100, 0, 100) bodyElement.Position = UDim2.new(0, 40, 0, 18) bodyElement.BackgroundTransparency = 1 
        for _, s in ipairs(LocalStickers) do if s.name == msg.text then bodyElement.Image = s.asset break end end
        contentHeight = 100
    else
        local bodyElement = Instance.new("TextLabel", msgFrame) bodyElement.Position = UDim2.new(0, 40, 0, 18) bodyElement.BackgroundTransparency = 1 bodyElement.TextXAlignment = Enum.TextXAlignment.Left bodyElement.TextYAlignment = Enum.TextYAlignment.Top bodyElement.Font = Enum.Font.Gotham bodyElement.TextSize = 12 bodyElement.TextColor3 = Color3.fromRGB(220, 220, 220) bodyElement.TextWrapped = true bodyElement.RichText = true
        local displayTxt = msg.text if msg.edited then displayTxt = displayTxt .. " <font color=\"rgb(120,120,120)\" size=\"10\">editado</font>" end
        bodyElement.Text = displayTxt
        local textBounds = TextService:GetTextSize(displayTxt, 12, Enum.Font.Gotham, Vector2.new(200, 10000))
        bodyElement.Size = UDim2.new(0, textBounds.X + 10, 0, textBounds.Y)
        contentHeight = textBounds.Y
    end
    msgFrame.Size = UDim2.new(1, 0, 0, contentHeight + 22)
    
    if msg.sender == player.Name and not msg.deleted then
        local hitBox = Instance.new("TextButton", msgFrame) hitBox.Size = UDim2.new(1, -40, 0, contentHeight) hitBox.Position = UDim2.new(0, 40, 0, 18) hitBox.BackgroundTransparency = 1 hitBox.Text = ""
        hitBox.MouseButton1Click:Connect(function()
            if msg.type == "text" then
                PopupTitle.Text = "Mensagem" PopupInput.Visible = false PopupBtnYes.Text = "Editar" PopupBtnNo.Text = "Apagar" PopupBtnNo.BackgroundColor3 = Color3.fromRGB(231, 76, 60) PopupBtnYes.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
                local conY, conN
                conY = PopupBtnYes.MouseButton1Click:Connect(function() conY:Disconnect() conN:Disconnect() ShowPopup("Editar Mensagem", "Salvar", true, msg.text, function(nt) if nt and nt ~= "" then SendMsgAction(msg.msgId, "edit", nt) end end) end)
                conN = PopupBtnNo.MouseButton1Click:Connect(function() conY:Disconnect() conN:Disconnect() PopupLayer.Visible = false SendMsgAction(msg.msgId, "delete", "") end)
                PopupLayer.Visible = true
            elseif msg.type == "sticker" then
                PopupTitle.Text = "Sticker" PopupInput.Visible = false PopupBtnYes.Text = "Apagar" PopupBtnYes.BackgroundColor3 = Color3.fromRGB(231, 76, 60) PopupBtnNo.Text = "Cancelar" PopupBtnNo.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
                local conY, conN
                conY = PopupBtnYes.MouseButton1Click:Connect(function() conY:Disconnect() conN:Disconnect() PopupLayer.Visible = false SendMsgAction(msg.msgId, "delete", "") end)
                conN = PopupBtnNo.MouseButton1Click:Connect(function() conY:Disconnect() conN:Disconnect() PopupLayer.Visible = false end)
                PopupLayer.Visible = true
            end
        end)
    end
end

function RefreshChatUI(history)
    for _, child in pairs(ChatScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, msg in ipairs(history) do RenderMessageItem(msg) end
    ChatScroll.CanvasPosition = Vector2.new(0, 99999)
end

function SendPrivateMessage(isSticker, stickerName)
    local text = ChatBox.Text
    if not isSticker and (text == "" or ActiveChatTarget == "") then return end
    if isSticker and ActiveChatTarget == "" then return end
    ChatBox.Text = ""
    local msgData = { msgId = HttpService:GenerateGUID(false), sender = player.Name, displayName = player.DisplayName, userId = player.UserId, text = isSticker and stickerName or text, type = isSticker and "sticker" or "text", timestamp = os.time(), edited = false, deleted = false }
    local history = LoadChat(ActiveChatTarget) table.insert(history, msgData) SaveChat(ActiveChatTarget, history)
    RefreshChatUI(history)
    task.spawn(function() pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_message", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget, msg = msgData})}) end) end)
end

SendBtn.MouseButton1Click:Connect(function() SendPrivateMessage(false) end)
ChatBox.FocusLost:Connect(function(e) if e then SendPrivateMessage(false) end end)

-- Loop Mestre de Sincronização (Amigos, Mensagens e Histórico)
local function MergeHistory(localHist, remoteHist)
    local merged = {} local seen = {}
    for _, m in ipairs(localHist) do if not seen[m.msgId] then table.insert(merged, m) seen[m.msgId] = true end end
    for _, m in ipairs(remoteHist) do
        if not seen[m.msgId] then table.insert(merged, m) seen[m.msgId] = true
        else for _, ex in ipairs(merged) do if ex.msgId == m.msgId then if m.edited then ex.text = m.text ex.edited = true end if m.deleted then ex.deleted = true end end end end
    end
    table.sort(merged, function(a,b) return a.timestamp < b.timestamp end)
    return merged
end

task.spawn(function()
    while task.wait(3) do
        pcall(function()
            local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_messages?to=" .. player.Name, Method = "GET"})
            if res.Success then
                local msgs = HttpService:JSONDecode(res.Body)
                if msgs and #msgs > 0 then
                    local grouped = {}
                    for _, m in ipairs(msgs) do
                        local fName = m.from if m.isSync and m.from == player.Name then fName = m.to end
                        if not grouped[fName] then grouped[fName] = {} end table.insert(grouped[fName], m)
                    end
                    for fName, fMsgs in pairs(grouped) do
                        local history = LoadChat(fName) local changed = false
                        for _, m in ipairs(fMsgs) do
                            if m.isSync then history = MergeHistory(history, m.history) changed = true
                            elseif m.isAction then
                                for _, hMsg in ipairs(history) do if hMsg.msgId == m.msgId then if m.action == "delete" then hMsg.deleted = true elseif m.action == "edit" then hMsg.text = m.newText hMsg.edited = true end changed = true end end
                            else table.insert(history, m) changed = true end
                        end
                        if changed then SaveChat(fName, history) if ActiveChatTarget == fName then RefreshChatUI(history) end end
                    end
                end
            end
            
            local syncRes = HttpService:RequestAsync({Url = SERVER_URL .. "/get_sync_requests?user=" .. player.Name, Method = "GET"})
            if syncRes.Success then
                for _, r in ipairs(HttpService:JSONDecode(syncRes.Body)) do
                    HttpService:RequestAsync({Url = SERVER_URL .. "/send_sync_data", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = r.from, history = LoadChat(r.from)})})
                end
            end
            
            local profRes = HttpService:RequestAsync({Url = SERVER_URL .. "/profile?username=" .. player.Name, Method = "GET"})
            if profRes.Success then
                local profData = HttpService:JSONDecode(profRes.Body)
                if profData.friends then LocalData.Friends = profData.friends SaveFriends() end
            end
        end)
    end
end)
