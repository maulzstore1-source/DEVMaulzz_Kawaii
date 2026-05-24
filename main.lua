--!nonstrict
--[[

The majority of this code is an interface designed to make it easy for you to
work with TopbarPlus (most methods for instance reference :modifyTheme()).
The processing overhead mainly consists of applying themes and calculating 
appearance (such as size and width of labels) which is handled in about
200 lines of code here and the Widget UI module. This has been achieved
in v3 by outsourcing a majority of previous calculations to inbuilt Roblox
features like UIListLayouts.
 
 
v3 provides inbuilt support for controllers (simply press DPadUp),
touch devices (phones, tablets , etc), localization (automatic resizing
of widgets, autolocalize for relevant labels), backwards compatability
with the old topbar, and more.
 
 
My primary goals for the v3 re-write have been to:

1. Improve code readability and organisation (reduced lines of code within
Icon+IconController from 3200 to ~950, separated UI elements, etc)

2. Improve ease-of-use (themes now actually make sense and can account
for any modifications you want, converted to a package for
    quick installation and easy-comparisons of new updates, etc)
    
    3. Provide support for all key features of the new Roblox topbar
    while improving performance of the module (deferring and collecting
        changes then calling as a singular, utilizing inbuilt Roblox features
        such as UILIstLayouts, etc)
 
        --]]
 
 
 
        -- SERVICES
        local UserInputService = game:GetService("UserInputService")
        local ContentProvider = game:GetService("ContentProvider")
        local StarterGui = game:GetService("StarterGui")
        local Players = game:GetService("Players")
        local Types = require(script.Types)
 
 
 
        -- TYPES
        export type Icon = Types.Icon
 
 
 
        -- REFERENCE HANDLER
        -- Multiple Icons packages may exist at runtime (for instance if the developer additionally uses HD Admin)
        -- therefore this ensures that the first required package becomes the dominant and only functioning module
        local iconModule = script
        local Reference = require(iconModule.Reference)
        local referenceObject = Reference.getObject()
        local leadPackage = referenceObject and referenceObject.Value
        if leadPackage and leadPackage ~= iconModule then
            return require(leadPackage) :: Types.StaticIcon
        end
        if not referenceObject then
            Reference.addToReplicatedStorage()
        end
 
 
 
        -- MODULES
        local Signal = require(iconModule.Packages.GoodSignal)
        local Janitor = require(iconModule.Packages.Janitor)
        local Utility = require(iconModule.Utility)
        local Themes = require(iconModule.Features.Themes)
        local Gamepad = require(iconModule.Features.Gamepad)
        local Overflow = require(iconModule.Features.Overflow)
        local Icon = {}
        Icon.__index = Icon
 
 
 
        --- LOCAL
        local localPlayer = Players.LocalPlayer
        local themes = iconModule.Features.Themes
        local iconsDict = {}
        local anyIconSelected = Signal.new()
        local elements = iconModule.Elements
        local totalCreatedIcons = 0
        local preferredInput = {
        mobile = Enum.PreferredInput.Touch,
        desktop = Enum.PreferredInput.KeyboardAndMouse,
        console = Enum.PreferredInput.Gamepad
        }
 
 
 
        -- PUBLIC VARIABLES
        Icon.baseDisplayOrderChanged = Signal.new()
        Icon.baseDisplayOrder = 10
        Icon.baseTheme = require(themes.Default)
        Icon.isOldTopbar = false -- Logic has been moved to Container
        Icon.iconsDictionary = iconsDict
        Icon.insetHeightChanged = Signal.new()
        Icon.container = require(elements.Container)(Icon)
        Icon.topbarEnabled = true
        Icon.iconAdded = Signal.new()
        Icon.iconRemoved = Signal.new()
        Icon.iconChanged = Signal.new()
 
 
 
        -- PUBLIC FUNCTIONS
        function Icon.getIcons()
            return Icon.iconsDictionary
        end
 
        function Icon.getIconByUID(UID)
            local match = Icon.iconsDictionary[UID]
            if match then
                return match
            end
            return nil
        end
 
        function Icon.getIcon(nameOrUID)
            local match = Icon.getIconByUID(nameOrUID)
            if match then
                return match
            end
            for _, icon in pairs(iconsDict) do
                if icon.name == nameOrUID then
                    return icon
                end
            end
            return nil
        end
 
        function Icon.setTopbarEnabled(bool, isInternal)
            if typeof(bool) ~= "boolean" then
                bool = Icon.topbarEnabled
            end
            if not isInternal then
                Icon.topbarEnabled = bool
            end
            for _, screenGui in pairs(Icon.container) do
                screenGui.Enabled = bool
            end
        end
 
        function Icon.modifyBaseTheme(modifications)
            modifications = Themes.getModifications(modifications)
            for _, modification in pairs(modifications) do
                for _, detail in pairs(Icon.baseTheme) do
                    Themes.merge(detail, modification)
                end
            end
            for _, icon in pairs(iconsDict) do
                icon:setTheme(Icon.baseTheme)
            end
        end
 
        function Icon.setDisplayOrder(int)
            Icon.baseDisplayOrder = int
            Icon.baseDisplayOrderChanged:Fire(int)
        end
 
 
 
        -- SETUP
        task.defer(Gamepad.start, Icon)
        task.defer(Overflow.start, Icon)
        task.defer(function()
            local playerGui = localPlayer:WaitForChild("PlayerGui")
            for _, screenGui in pairs(Icon.container) do
                screenGui.Parent = playerGui
            end
            require(iconModule.Attribute)
        end)
 
 
 
        -- CONSTRUCTOR
        function Icon.new()
            local self = {}
            setmetatable(self, Icon)
 
            --- Janitors (for cleanup)
            local janitor = Janitor.new()
            self.janitor = janitor
            self.themesJanitor = janitor:add(Janitor.new())
            self.singleClickJanitor = janitor:add(Janitor.new())
            self.captionJanitor = janitor:add(Janitor.new())
            self.joinJanitor = janitor:add(Janitor.new())
            self.menuJanitor = janitor:add(Janitor.new())
            self.dropdownJanitor = janitor:add(Janitor.new())
 
            -- Register
            local iconUID = Utility.generateUID()
            iconsDict[iconUID] = self
            janitor:add(function()
                iconsDict[iconUID] = nil
            end)
 
            -- Signals (events)
            self.selected = janitor:add(Signal.new())
            self.deselected = janitor:add(Signal.new())
            self.toggled = janitor:add(Signal.new())
            self.viewingStarted = janitor:add(Signal.new())
            self.viewingEnded = janitor:add(Signal.new())
            self.stateChanged = janitor:add(Signal.new())
            self.notified = janitor:add(Signal.new())
            self.noticeStarted = janitor:add(Signal.new())
            self.noticeChanged = janitor:add(Signal.new())
            self.endNotices = janitor:add(Signal.new())
            self.toggleKeyAdded = janitor:add(Signal.new())
            self.fakeToggleKeyChanged = janitor:add(Signal.new())
            self.alignmentChanged = janitor:add(Signal.new())
            self.updateSize = janitor:add(Signal.new())
            self.resizingComplete = janitor:add(Signal.new())
            self.joinedParent = janitor:add(Signal.new())
            self.menuSet = janitor:add(Signal.new())
            self.dropdownSet = janitor:add(Signal.new())
            self.updateMenu = janitor:add(Signal.new())
            self.startMenuUpdate = janitor:add(Signal.new())
            self.childThemeModified = janitor:add(Signal.new())
            self.indicatorSet = janitor:add(Signal.new())
            self.dropdownChildAdded = janitor:add(Signal.new())
            self.menuChildAdded = janitor:add(Signal.new())
 
            -- Properties
            self.iconModule = iconModule
            self.UID = iconUID
            self.isEnabled = true
            self.enabled = self.isEnabled -- Backwards compatability
            self.isSelected = false
            self.isViewing = false
            self.joinedFrame = false
            self.parentIconUID = false
            self.deselectWhenOtherIconSelected = true
            self.totalNotices = 0
            self.activeState = "Deselected"
            self.alignment = ""
            self.originalAlignment = ""
            self.appliedTheme = {}
            self.appearance = {}
            self.cachedInstances = {}
            self.cachedNamesToInstances = {}
            self.cachedCollectives = {}
            self.bindedToggleKeys = {}
            self.customBehaviours = {}
            self.toggleItems = {}
            self.bindedEvents = {}
            self.notices = {}
            self.menuIcons = {}
            self.dropdownIcons = {}
            self.childIconsDict = {}
            self.creationTime = os.clock()
 
            -- Widget is the new name for an icon
            local widget = janitor:add(require(elements.Widget)(self, Icon))
            self.widget = widget
            self:setAlignment()
            
            -- It's important we set an order otherwise icons will not align
            -- correctly within menus
            totalCreatedIcons += 1
            local ourOrder = 1+(totalCreatedIcons*0.01)
            self:setOrder(ourOrder, "deselected")
            self:setOrder(ourOrder, "selected")
 
            -- This applies the default them
            self:setTheme(Icon.baseTheme)
 
            -- Button Clicked (for states "Selected" and "Deselected")
            local clickRegion = self:getInstance("ClickRegion")
            local hasUsedMouseButton1Click = false
            local lastToggleTime = 0
            local DEBOUNCE_TIME = 0.1 -- 100ms debounce to prevent rapid toggles
 
            local function handleToggle()
                if self.locked then
                    return
                end
 
                -- Debounce logic to prevent rapid toggling
                local currentTime = tick()
                if currentTime - lastToggleTime < DEBOUNCE_TIME then
                    return
                end
                lastToggleTime = currentTime
 
                if self.isSelected then
                    self:deselect("User", self)
                else
                    self:select("User", self)
                end
            end
 
            clickRegion.MouseButton1Click:Connect(function()
                hasUsedMouseButton1Click = true
                handleToggle()
            end)
 
            clickRegion.TouchTap:Connect(function()
                -- This resolves the bug report by @28Pixels:
                -- https://devforum.roblox.com/t/topbarplus/1017485/1104
                -- Only use TouchTap if MouseButton1Click has never fired
                -- This handles edge cases where ONLY TouchTap works
                -- Also prevents double-toggle bug with multi-touch on mobile
                -- Credit to @sayer80 for this fix
                if not hasUsedMouseButton1Click then
                    handleToggle()
                end
            end)
 
            -- Keys can be bound to toggle between Selected and Deselected
            janitor:add(UserInputService.InputBegan:Connect(function(input, touchingAnObject)
                if self.locked then
                    return
                end
                if self.bindedToggleKeys[input.KeyCode] and not touchingAnObject then
                    handleToggle()
                end
            end))
 
            -- Button Hovering (for state "Viewing")
            -- Hovering is a state only for devices with keyboards
            -- and controllers (not touchpads)
            local function viewingStarted(dontSetState)
                if self.locked then
                    return
                end
                self.isViewing = true
                self.viewingStarted:Fire(true)
                if not dontSetState then
                    self:setState("Viewing", "User", self)
                end
            end
            local function viewingEnded()
                if self.locked then
                    return
                end
                self.isViewing = false
                self.viewingEnded:Fire(true)
                self:setState(nil, "User", self)
            end
            self.joinedParent:Connect(function()
                if self.isViewing then
                    viewingEnded()
                end
            end)
            clickRegion.MouseEnter:Connect(function()
                local dontSetState = UserInputService.PreferredInput ~= preferredInput.desktop
                viewingStarted(dontSetState)
            end)
            local touchCount = 0
            janitor:add(UserInputService.TouchEnded:Connect(viewingEnded))
            clickRegion.MouseLeave:Connect(viewingEnded)
            clickRegion.SelectionGained:Connect(viewingStarted)
            clickRegion.SelectionLost:Connect(viewingEnded)
            clickRegion.MouseButton1Down:Connect(function()
                if not self.locked and UserInputService.PreferredInput == preferredInput.mobile then
                    touchCount += 1
                    local myTouchCount = touchCount
                    task.delay(0.2, function()
                        if myTouchCount == touchCount then
                            viewingStarted()
                        end
                    end)
                end
            end)
            clickRegion.MouseButton1Up:Connect(function()
                touchCount += 1
            end)
 
            -- Handle overlay on viewing
            local iconOverlay = self:getInstance("IconOverlay")
            self.viewingStarted:Connect(function()
                iconOverlay.Visible = not self.overlayDisabled
            end)
            self.viewingEnded:Connect(function()
                iconOverlay.Visible = false
            end)
 
            -- Deselect when another icon is selected
            janitor:add(anyIconSelected:Connect(function(incomingIcon)
                if incomingIcon ~= self and self.deselectWhenOtherIconSelected and incomingIcon.deselectWhenOtherIconSelected then
                    self:deselect("AutoDeselect", incomingIcon)
                end
            end))
 
            -- This checks if the script calling this module is a descendant of a ScreenGui
            -- with 'ResetOnSpawn' set to true. If it is, then we destroy the icon the
            -- client respawns. This solves one of the most asked about questions on the post
            -- The only caveat this may not work if the player doesn't uniquely name their ScreenGui and the frames
            -- the LocalScript rests within
            local source =  debug.info(2, "s")
            local sourcePath = string.split(source, ".")
            local origin = game
            local originsScreenGui
            for i, sourceName in pairs(sourcePath) do
                origin = origin:FindFirstChild(sourceName)
                if not origin then
                    break
                end
                if origin:IsA("ScreenGui") then
                    originsScreenGui = origin
                end
            end
            if origin and originsScreenGui and originsScreenGui.ResetOnSpawn == true then
                self.originsScreenGui = originsScreenGui
                Utility.localPlayerRespawned(function()
                    self:destroy()
                end)
            end
 
            -- Additional children behaviour when toggled (mostly notices)
            self.toggled:Connect(function(isSelected)
                self.noticeChanged:Fire(self.totalNotices)
                for childIconUID, _ in pairs(self.childIconsDict) do
                    local childIcon = Icon.getIconByUID(childIconUID)
                    childIcon.noticeChanged:Fire(childIcon.totalNotices)
                    if not isSelected and childIcon.isSelected then
                        -- If an icon within a menu or dropdown is also
                        -- a dropdown or menu, then close it
                        for _, _ in pairs(childIcon.childIconsDict) do
                            childIcon:deselect("HideParentFeature", self)
                        end
                    end
                end
            end)
            
            -- This closes/reopens the chat or playerlist if the icon is a dropdown
            -- In the future I'd prefer to use the position+size of the chat
            -- to determine whether to close dropdown (instead of non-right-set)
            -- but for reasons mentioned here it's unreliable at the time of
            -- writing this: https://devforum.roblox.com/t/here/2794915
            -- I could also make this better by accounting for multiple
            -- dropdowns being open (not just this one) but this will work
            -- fine for almost every use case for now.
            self.selected:Connect(function()
                local isDropdown = #self.dropdownIcons > 0
                if isDropdown then
                    if StarterGui:GetCore("ChatActive") and self.alignment ~= "Right" then
                        self.chatWasPreviouslyActive = true
                        StarterGui:SetCore("ChatActive", false)
                    end
                    if StarterGui:GetCoreGuiEnabled("PlayerList") and self.alignment ~= "Left" then
                        self.playerlistWasPreviouslyActive = true
                        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
                    end
                end
            end)
            self.deselected:Connect(function()
                if self.chatWasPreviouslyActive then
                    self.chatWasPreviouslyActive = nil
                    StarterGui:SetCore("ChatActive", true)
                end
                if self.playerlistWasPreviouslyActive then
                    self.playerlistWasPreviouslyActive = nil
                    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
                end
            end)
            
            -- There's a rare occassion where the appearance is not
            -- fully set to deselected so this ensures the icons
            -- appearance is fully as it should be
            task.delay(0.1, function()
                if self.activeState == "Deselected" then
                    self.stateChanged:Fire("Deselected")
                    self:refresh()
                end
            end)
            
            -- Call icon added
            Icon.iconAdded:Fire(self)
 
            return self
        end
 
 
 
        -- METHODS
        function Icon:setName(name)
            self.widget.Name = name
            self.name = name
            return self
        end
 
        function Icon:setState(incomingStateName, fromSource, sourceIcon)
            -- This is responsible for acknowleding a change in stage (such as from "Deselected" to "Viewing" when
            -- a users mouse enters the widget), then informing other systems of this state change to then act upon
            -- (such as the theme handler applying the theme which corresponds to that state).
            if not incomingStateName then
                incomingStateName = (self.isSelected and "Selected") or "Deselected"
            end
            local stateName = Utility.formatStateName(incomingStateName)
            local previousStateName = self.activeState
            if previousStateName == stateName then
                return
            end
            local currentIsSelected = self.isSelected
            self.activeState = stateName
            if stateName == "Deselected" then
                self.isSelected = false
                if currentIsSelected then
                    self.toggled:Fire(false, fromSource, sourceIcon)
                    self.deselected:Fire(fromSource, sourceIcon)
                end
                self:_setToggleItemsVisible(false, fromSource, sourceIcon)
            elseif stateName == "Selected" then
                self.isSelected = true
                if not currentIsSelected then
                    self.toggled:Fire(true, fromSource, sourceIcon)
                    self.selected:Fire(fromSource, sourceIcon)
                    anyIconSelected:Fire(self, fromSource, sourceIcon)
                end
                self:_setToggleItemsVisible(true, fromSource, sourceIcon)
            end
            self.stateChanged:Fire(stateName, fromSource, sourceIcon)
        end
 
        function Icon:getInstance(name)
            -- This enables us to easily retrieve instances located within the icon simply by passing its name.
            -- Every important/significant instance is named uniquely therefore this is no worry of overlap.
            -- We cache the result for more performant retrieval in the future.
            local instance = self.cachedNamesToInstances[name]
            if instance then
                return instance
            end
            local function cacheInstance(childName, child)
                local currentCache = self.cachedInstances[child]
                if not currentCache then
                    local collectiveName = child:GetAttribute("Collective")
                    local cachedCollective = collectiveName and self.cachedCollectives[collectiveName]
                    if cachedCollective then
                        table.insert(cachedCollective, child)
                    end
                    self.cachedNamesToInstances[childName] = child
                    self.cachedInstances[child] = true
                    child.Destroying:Once(function()
                        self.cachedNamesToInstances[childName] = nil
                        self.cachedInstances[child] = nil
                    end)
                end
            end
            local widget = self.widget
            cacheInstance("Widget", widget)
            if name == "Widget" then
                return widget
            end
 
            local returnChild
            local function scanChildren(parentInstance)
                for _, child in pairs(parentInstance:GetChildren()) do
                    local widgetUID = child:GetAttribute("WidgetUID")
                    if widgetUID and widgetUID ~= self.UID then
                        -- This prevents instances within other icons from being recorded
                        -- (for instance when other icons are added to this icons menu)
                        continue
                    end
                    -- If the child is a fake placeholder instance (such as dropdowns, notices, etc)
                    -- then its important we scan the real original instance instead of this clone
                    local realChild = Themes.getRealInstance(child)
                    if realChild then
                        child = realChild
                    end
                    -- Finally scan its children
                    scanChildren(child)
                    if child:IsA("GuiBase") or child:IsA("UIBase") or child:IsA("ValueBase") then
                        local childName = child.Name
                        cacheInstance(childName, child)
                        if childName == name then
                            returnChild = child
                        end
                    end
                end
            end
            scanChildren(widget)
            return returnChild
        end
 
        function Icon:getCollective(name)
            -- A collective is an array of instances within the Widget that have been
            -- grouped together based on a given name. This just makes it easy
            -- to act on multiple instances at once which share similar behaviours.
            -- For instance, if we want to change the icons corner size, all corner instances
            -- with the attribute "Collective" and value "WidgetCorner" could be updated
            -- instantly by doing Themes.apply(icon, "WidgetCorner", newSize)
            local collective = self.cachedCollectives[name]
            if collective then
                return collective
            end
            collective = {}
            for instance, _ in pairs(self.cachedInstances) do
                if instance:GetAttribute("Collective") == name then
                    table.insert(collective, instance)
                end
            end
            self.cachedCollectives[name] = collective
            return collective
        end
 
        function Icon:getInstanceOrCollective(collectiveOrInstanceName)
            -- Similar to :getInstance but also accounts for 'Collectives', such as UICorners and returns
            -- an array of instances instead of a single instance
            local instances = {}
            local instance = self:getInstance(collectiveOrInstanceName)
            if instance then
                table.insert(instances, instance)
            end
            if #instances == 0 then
                instances = self:getCollective(collectiveOrInstanceName)
            end
            return instances
        end
 
        function Icon:getStateGroup(iconState)
            local chosenState = iconState or self.activeState
            local stateGroup = self.appearance[chosenState]
            if not stateGroup then
                stateGroup = {}
                self.appearance[chosenState] = stateGroup
            end
            return stateGroup
        end
 
        function Icon:refreshAppearance(instance, specificProperty)
            Themes.refresh(self, instance, specificProperty)
            return self
        end
 
        function Icon:refresh()
            self:refreshAppearance(self.widget)
            self.updateSize:Fire()
            return self
        end
 
        function Icon:updateParent()
            local parentIcon = Icon.getIconByUID(self.parentIconUID)
            if parentIcon then
                parentIcon.updateSize:Fire()
            end
        end
 
        function Icon:setBehaviour(collectiveOrInstanceName, property, callback, refreshAppearance)
            -- You can specify your own custom callback to handle custom logic just before
            -- an instances property is changed by using :setBehaviour()
            local key = collectiveOrInstanceName.."-"..property
            self.customBehaviours[key] = callback
            if refreshAppearance then
                local instances = self:getInstanceOrCollective(collectiveOrInstanceName)
                for _, instance in pairs(instances) do
                    self:refreshAppearance(instance, property)
                end
            end
        end
 
        function Icon:modifyTheme(modifications, customModificationUID)
            local modificationUID = Themes.modify(self, modifications, customModificationUID)
            return self, modificationUID
        end
 
        function Icon:modifyChildTheme(modifications, modificationUID)
            -- Same as modifyTheme except for its children (i.e. icons
            -- within its dropdown or menu)
            self.childModifications = modifications
            self.childModificationsUID = modificationUID
            for childIconUID, _ in pairs(self.childIconsDict) do
                local childIcon = Icon.getIconByUID(childIconUID)
                childIcon:modifyTheme(modifications, modificationUID)
            end
            self.childThemeModified:Fire()
            return self
        end
 
        function Icon:removeModification(modificationUID)
            Themes.remove(self, modificationUID)
            return self
        end
 
        function Icon:removeModificationWith(instanceName, property, state)
            Themes.removeWith(self, instanceName, property, state)
            return self
        end
 
        function Icon:setTheme(theme)
            Themes.set(self, theme)
            return self
        end
 
        function Icon:setEnabled(bool)
            self.isEnabled = bool
            self.enabled = self.isEnabled
            self.widget.Visible = bool
            self:updateParent()
            return self
        end
 
        function Icon:select(fromSource, sourceIcon)
            self:setState("Selected", fromSource, sourceIcon)
            return self
        end
 
        function Icon:deselect(fromSource, sourceIcon)
            self:setState("Deselected", fromSource, sourceIcon)
            return self
        end
 
        function Icon:notify(customClearSignal, noticeId)
            -- Generates a notification which appears in the top right of the icon. Useful for example for prompting
            -- users of changes/updates within your UI such as a Catalog
            -- 'customClearSignal' is a signal object (e.g. icon.deselected) or
            -- Roblox event (e.g. Instance.new("BindableEvent").Event)
            local notice = self.notice
            if not notice then
                notice = require(elements.Notice)(self, Icon)
                self.notice = notice
            end
            self.noticeStarted:Fire(customClearSignal, noticeId)
            return self
        end
 
        function Icon:clearNotices()
            self.endNotices:Fire()
            return self
        end
 
        function Icon:disableOverlay(bool)
            self.overlayDisabled = bool
            return self
        end
        Icon.disableStateOverlay = Icon.disableOverlay
 
        function Icon:setImage(imageId, iconState)
            self:modifyTheme({"IconImage", "Image", imageId, iconState})
            
            -- This code ensures icon images are preloaded if they haven't been fetched yet
            task.spawn(function()
                local newIdContent = if tonumber(imageId) then `rbxassetid://{imageId}` else imageId
                local initialAssetFetchStatus = ContentProvider:GetAssetFetchStatus(newIdContent)
                
                if initialAssetFetchStatus ~= Enum.AssetFetchStatus.Success then
                    pcall(ContentProvider.PreloadAsync, ContentProvider, { newIdContent })
                end
            end)
            
            return self
        end
 
        function Icon:setLabel(text, iconState)
            self:modifyTheme({"IconLabel", "Text", text, iconState})
            return self
        end
 
        function Icon:setOrder(int, iconState)
            -- We multiply by 100 to allow for custom increments inbetween
            -- (.01, .02, etc) as LayoutOrders only support integers
            local newInt = int*100
            self:modifyTheme({"IconSpot", "LayoutOrder", newInt, iconState})
            self:modifyTheme({"Widget", "LayoutOrder", newInt, iconState})
            return self
        end
 
        function Icon:setCornerRadius(udim, iconState)
            self:modifyTheme({"IconCorners", "CornerRadius", udim, iconState})
            return self
        end
 
        function Icon:align(leftCenterOrRight, isFromParentIcon)
            -- Determines the side of the screen the icon will be ordered
            local direction = tostring(leftCenterOrRight):lower()
            if direction == "mid" or direction == "centre" then
                direction = "center"
            end
            if direction ~= "left" and direction ~= "center" and direction ~= "right" then
                direction = "left"
            end
            local screenGui = (direction == "center" and Icon.container.TopbarCentered) or Icon.container.TopbarStandard
            local holders = screenGui.Holders
            local finalDirection = string.upper(string.sub(direction, 1, 1))..string.sub(direction, 2)
            if not isFromParentIcon then
                self.originalAlignment = finalDirection
            end
            local joinedFrame = self.joinedFrame
            local alignmentHolder = holders[finalDirection]
            self.screenGui = screenGui
            self.alignmentHolder = alignmentHolder
            if not self.isDestroyed then
                self.widget.Parent = joinedFrame or alignmentHolder
            end
            self.alignment = finalDirection
            self.alignmentChanged:Fire(finalDirection)
            Icon.iconChanged:Fire(self)
            return self
        end
        Icon.setAlignment = Icon.align
 
        function Icon:setLeft()
            self:setAlignment("Left")
            return self
        end
 
        function Icon:setMid()
            self:setAlignment("Center")
            return self
        end
 
        function Icon:setRight()
            self:setAlignment("Right")
            return self
        end
 
        function Icon:setWidth(offsetMinimum, iconState)
            -- This sets a minimum X offset size for the widget, useful
            -- for example if you're constantly changing the label
            -- but don't want the icon to resize every time
            self:modifyTheme({"Widget", "DesiredWidth", offsetMinimum, iconState})
            return self
        end
 
        function Icon:setImageScale(number, iconState)
            self:modifyTheme({"IconImageScale", "Value", number, iconState})
            return self
        end
 
        function Icon:setImageRatio(number, iconState)
            self:modifyTheme({"IconImageRatio", "AspectRatio", number, iconState})
            return self
        end
 
        function Icon:setTextSize(number, iconState)
            self:modifyTheme({"IconLabel", "TextSize", number, iconState})
            return self
        end
 
        function Icon:setTextFont(font, fontWeight, fontStyle, iconState)
            fontWeight = fontWeight or Enum.FontWeight.Regular
            fontStyle = fontStyle or Enum.FontStyle.Normal
            local fontFace
            local fontType = typeof(font)
            if fontType == "number" then
                fontFace = Font.fromId(font, fontWeight, fontStyle)
            elseif fontType == "EnumItem" then
                fontFace = Font.fromEnum(font)
            elseif fontType == "string" then
                if not font:match("rbxasset") then
                    fontFace = Font.fromName(font, fontWeight, fontStyle)
                end
            end
            if not fontFace then
                fontFace = Font.new(font, fontWeight, fontStyle)
            end
            self:modifyTheme({"IconLabel", "FontFace", fontFace, iconState})
            return self
        end
 
        function Icon:setTextColor(Color, iconState)
            if Color == nil or Color == "" or (type(Color) ~= "userdata" or typeof(Color) ~= "Color3") then
                if Color ~= nil and Color ~= "" then
                    warn("setTextColor item must be a Color3 value! Changed the color to white.")
                end
                Color = Color3.fromRGB(255, 255, 255)
            end
 
            self:modifyTheme({"IconLabel", "TextColor3", Color, iconState})
            return self
        end
 
        function Icon:bindToggleItem(guiObjectOrLayerCollector)
            if not guiObjectOrLayerCollector:IsA("GuiObject") and not guiObjectOrLayerCollector:IsA("LayerCollector") then
                error("Toggle item must be a GuiObject or LayerCollector!")
            end
            self.toggleItems[guiObjectOrLayerCollector] = true
            self:_updateSelectionInstances()
            return self
        end
 
        function Icon:unbindToggleItem(guiObjectOrLayerCollector)
            self.toggleItems[guiObjectOrLayerCollector] = nil
            self:_updateSelectionInstances()
            return self
        end
 
        function Icon:_updateSelectionInstances()
            -- This is to assist with controller navigation and selection
            -- It converts the value true to an array
            for guiObjectOrLayerCollector, _ in pairs(self.toggleItems) do
                local buttonInstancesArray = {}
                for _, instance in pairs(guiObjectOrLayerCollector:GetDescendants()) do
                    if (instance:IsA("TextButton") or instance:IsA("ImageButton")) and instance.Active then
                        table.insert(buttonInstancesArray, instance)
                    end
                end
                self.toggleItems[guiObjectOrLayerCollector] = buttonInstancesArray
            end
        end
 
        function Icon:_setToggleItemsVisible(bool, fromSource, sourceIcon)
            for toggleItem, _ in pairs(self.toggleItems) do
                if not sourceIcon or sourceIcon == self or sourceIcon.toggleItems[toggleItem] == nil then
                    local property = "Visible"
                    if toggleItem:IsA("LayerCollector") then
                        property = "Enabled"
                    end
                    toggleItem[property] = bool
                end
            end
        end
 
        function Icon:bindEvent(iconEventName, eventFunction)
            local event = self[iconEventName]
            assert(event and typeof(event) == "table" and event.Connect, "argument[1] must be a valid topbarplus icon event name!")
            assert(typeof(eventFunction) == "function", "argument[2] must be a function!")
                self.bindedEvents[iconEventName] = event:Connect(function(...)
                    eventFunction(self, ...)
                end)
                return self
            end
 
            function Icon:unbindEvent(iconEventName)
                local eventConnection = self.bindedEvents[iconEventName]
                if eventConnection then
                    eventConnection:Disconnect()
                    self.bindedEvents[iconEventName] = nil
                end
                return self
            end
 
            function Icon:bindToggleKey(keyCodeEnum)
                assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
                self.bindedToggleKeys[keyCodeEnum] = true
                self.toggleKeyAdded:Fire(keyCodeEnum)
                self:setCaption("_hotkey_")
                return self
            end
 
            function Icon:unbindToggleKey(keyCodeEnum)
                assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
                self.bindedToggleKeys[keyCodeEnum] = nil
                return self
            end
 
            function Icon:call(callback, ...)
                local packedArgs = table.pack(...)
                task.spawn(function()
                    callback(self, table.unpack(packedArgs))
                end)
                return self
            end
 
            function Icon:addToJanitor(callback, methodName, index)
                self.janitor:add(callback, methodName, index)
                return self
            end
 
            function Icon:lock()
                -- This disables all user inputs related to the icon (such as clicking buttons, pressing keys, etc)
                local clickRegion = self:getInstance("ClickRegion")
                clickRegion.Visible = false
                self.locked = true
                return self
            end
 
            function Icon:unlock()
                local clickRegion = self:getInstance("ClickRegion")
                clickRegion.Visible = true
                self.locked = false
                return self
            end
 
            function Icon:debounce(seconds)
                self:lock()
                task.wait(seconds)
                self:unlock()
                return self
            end
 
            function Icon:autoDeselect(bool)
                -- When set to true the icon will deselect itself automatically whenever
                -- another icon is selected
                if bool == nil then
                    bool = true
                end
                self.deselectWhenOtherIconSelected = bool
                return self
            end
 
            function Icon:oneClick(bool)
                -- When set to true the icon will automatically deselect when selected, this creates
                -- the effect of a single click button
                local singleClickJanitor = self.singleClickJanitor
                singleClickJanitor:clean()
                if bool or bool == nil then
                    singleClickJanitor:add(self.selected:Connect(function()
                        self:deselect("OneClick", self)
                    end))
                end
                self.oneClickEnabled = true
                return self
            end
 
            function Icon:setCaption(text)
                if text == "_hotkey_" and (self.captionText) then
                    return self
                end
                local captionJanitor = self.captionJanitor
                self.captionJanitor:clean()
                if not text or text == "" then
                    self.caption = nil
                    self.captionText = nil
                    return self
                end
                local caption = captionJanitor:add(require(elements.Caption)(self))
                caption:SetAttribute("CaptionText", text)
                self.caption = caption
                self.captionText = text
                return self
            end
 
            function Icon:setCaptionHint(keyCodeEnum)
                assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
                self.fakeToggleKey = keyCodeEnum
                self.fakeToggleKeyChanged:Fire(keyCodeEnum)
                self:setCaption("_hotkey_")
                return self
            end
 
            function Icon:leave()
                local joinJanitor = self.joinJanitor
                joinJanitor:clean()
                return self
            end
 
            function Icon:joinMenu(parentIcon)
                Utility.joinFeature(self, parentIcon, parentIcon.menuIcons, parentIcon:getInstance("Menu"))
                parentIcon.menuChildAdded:Fire(self)
                return self
            end
 
            function Icon:setMenu(arrayOfIcons)
                self.menuSet:Fire(arrayOfIcons)
                return self
            end
 
            function Icon:setFixedMenu(arrayOfIcons)
                self:freezeMenu(arrayOfIcons)
                self:setMenu(arrayOfIcons)
            end
            Icon.setFrozenMenu = Icon.setFixedMenu
 
            function Icon:freezeMenu()
                -- A frozen menu is a menu which is permanently locked in the
                -- the selected state (with its toggle hidden)
                self:select("FrozenMenu", self)
                self:bindEvent("deselected", function(icon)
                    icon:select("FrozenMenu", self)
                end)
                self:modifyTheme({"IconSpot", "Visible", false})
            end
 
            function Icon:joinDropdown(parentIcon)
                parentIcon:getDropdown()
                Utility.joinFeature(self, parentIcon, parentIcon.dropdownIcons, parentIcon:getInstance("DropdownScroller"))
                parentIcon.dropdownChildAdded:Fire(self)
                return self
            end
 
            function Icon:getDropdown()
                local dropdown = self.dropdown
                if not dropdown then
                    dropdown = require(elements.Dropdown)(self)
                    self.dropdown = dropdown
                    self:clipOutside(dropdown)
                end
                return dropdown
            end
 
            function Icon:setDropdown(arrayOfIcons)
                self:getDropdown()
                self.dropdownSet:Fire(arrayOfIcons)
                return self
            end
 
            function Icon:clipOutside(instance)
                -- This is essential for items such as notices and dropdowns which will exceed the bounds of the widget. This is an issue
                -- because the widget must have ClipsDescendents enabled to hide items for instance when the menu is closing or opening.
                -- This creates an invisible frame which matches the size and position of the instance, then the instance is parented outside of
                -- the widget and tracks the clone to match its size and position. In order for themes, etc to work the applying system checks
                -- to see if an instance is a clone, then if it is, it applies it to the original instance instead of the clone.
                local instanceClone = Utility.clipOutside(self, instance)
                self:refreshAppearance(instance)
                return self, instanceClone
            end
 
            function Icon:setIndicator(keyCode)
                -- An indicator is a direction button prompt with an image of the given keycode. This is useful for instance
                -- with controllers to show the user what button to press to highlight the topbar. You don't need
                -- to set an indicator for controllers as this is handled internally within the Gamepad module
                local indicator = self.indicator
                if not indicator then
                    indicator = self.janitor:add(require(elements.Indicator)(self, Icon))
                    self.indicator = indicator
                end
                self.indicatorSet:Fire(keyCode)
            end
 
            function Icon:convertLabelToNumberSpinner(numberSpinner, callback)
                task.defer(function()
                    
                    local label = self:getInstance("IconLabel")
                    label.Transparency = 1
                    numberSpinner.Parent = label.Parent
                    numberSpinner.Size = UDim2.fromScale(1, 1)
                    numberSpinner.AnchorPoint = Vector2.new(0.5, 0.5)
                    numberSpinner.Position = UDim2.new(0.5, 0, 0.5, 0)
                    numberSpinner.TextXAlignment = Enum.TextXAlignment.Center
                    numberSpinner.ClipsDescendants = false
 
                    local propertiesToChangeLabel = {
                    "FontFace",
                    "BorderSizePixel",
                    "BorderColor3",
                    "Rotation",
                    "TextStrokeTransparency",
                    "TextStrokeColor3",
                    "TextStrokeTransparency",
                    "TextColor3",
                    }
                    for _, property in ipairs(propertiesToChangeLabel) do
                        numberSpinner[property] = label[property]
                        self:addToJanitor(label:GetPropertyChangedSignal(property):Connect(function()
                            numberSpinner[property] = label[property]
                        end))
                    end
 
                    local minDigits = 0
                    local maxDigits = 8
                    local function getSpinnerSizeAndDigitCount()
                        local TotalSize = 0
                        local numOfDigits = 0
                        for i, child in numberSpinner.Frame:GetChildren() do
                            local name = string.lower(child.Name)
                            if name == "digit" then
                                TotalSize += child.AbsoluteSize.X
                                numOfDigits += 1
                            elseif name == "prefix" or name == "suffix" or name == "comma" then
                                if child.Text ~= "" then
                                    TotalSize += child.AbsoluteSize.X
                                    numOfDigits += 1
                                end
                            end
                        end
                        return TotalSize, numOfDigits
                    end
                    
                    local function getLabelParentContainerXSize()
                        local firstParent = label.Parent
                        local nextParent = firstParent and firstParent.Parent
                        if nextParent == nil then
                            return 0
                        end
                        if nextParent.IconImage.Visible == true then
                            return numberSpinner.Frame.AbsoluteSize.X + label.Parent.Parent.IconImage.AbsoluteSize.X
                        else
                            return nextParent.AbsoluteSize.X
                        end
                    end
                    local function getNumberSpinnerXSize()
                        return numberSpinner.Frame.AbsoluteSize.X
                    end
 
                    local function adjustSize()
                        local totalDigitXSize, numOfDigits = getSpinnerSizeAndDigitCount()
                        if numOfDigits < 18 then
                            self:setLabel(numberSpinner.Value)
                        end
 
                        local NumberSpinnerXSize = getNumberSpinnerXSize()
 
                        while totalDigitXSize < NumberSpinnerXSize and self.isDestroyed ~= true do
                            task.wait(0.05)
                            if numOfDigits > minDigits and numOfDigits < maxDigits then
                                numberSpinner.TextSize = label.TextSize
                                break
                            else
                                numberSpinner.TextSize += 1
                            end
 
                            NumberSpinnerXSize = getNumberSpinnerXSize()
                            totalDigitXSize, numOfDigits = getSpinnerSizeAndDigitCount()
                        end
 
                        local labelParentContainerXSize = getLabelParentContainerXSize()
                        while totalDigitXSize > labelParentContainerXSize and self.isDestroyed ~= true do
                            task.wait(0.05)
                            if numOfDigits < maxDigits and numOfDigits > minDigits then
                                numberSpinner.TextSize = label.TextSize
                                break
                            else
                                numberSpinner.TextSize -= 1
                            end
 
                            labelParentContainerXSize = getLabelParentContainerXSize()
                            totalDigitXSize, numOfDigits = getSpinnerSizeAndDigitCount()
                        end
                    end
 
                    self:addToJanitor(numberSpinner.Frame.ChildAdded:Connect(adjustSize))
                    self:addToJanitor(numberSpinner.Frame.ChildRemoved:Connect(adjustSize))
                    self:addToJanitor(self.iconAdded:Connect(function()
                        task.wait(1)
                        adjustSize()
                    end))
 
                    self:updateParent()
 
                    -- This corrects text to the size of a normal label
                    numberSpinner.Name = "LabelSpinner"
                    numberSpinner.Prefix = "$"
                    numberSpinner.Commas = true
                    numberSpinner.Decimals = 0
                    numberSpinner.Duration = 0.25
                    numberSpinner.Value = 10
                    task.wait(0.2)
                    
                    if typeof(callback) == "function" then
                        callback()
                    end
                    
                end)
                return self
            end
 
 
 
            -- DESTROY/CLEANUP
            function Icon:destroy()
                if self.isDestroyed then
                    return
                end
                self:clearNotices()
                if self.parentIconUID then
                    self:leave()
                end
                self.isDestroyed = true
                self.janitor:clean()
                Icon.iconRemoved:Fire(self)
            end
            Icon.Destroy = Icon.destroy
 
            return Icon :: Types.StaticIcon
-- Avatar Changer Server - RGB Animation FORCE RESTART FIXED
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")

-- Create RemoteEvents
local changeAvatarEvent = Instance.new("RemoteEvent")
changeAvatarEvent.Name = "ChangeAvatarEvent"
changeAvatarEvent.Parent = ReplicatedStorage

local resetAvatarEvent = Instance.new("RemoteEvent")
resetAvatarEvent.Name = "ResetAvatarEvent"
resetAvatarEvent.Parent = ReplicatedStorage

local addAccessoryEvent = Instance.new("RemoteEvent")
addAccessoryEvent.Name = "AddAccessoryEvent"
addAccessoryEvent.Parent = ReplicatedStorage

local removeAccessoryEvent = Instance.new("RemoteEvent")
removeAccessoryEvent.Name = "RemoveAccessoryEvent"
removeAccessoryEvent.Parent = ReplicatedStorage

-- NEW: Remote untuk restart RGB animation dari client
local restartRGBEvent = Instance.new("RemoteEvent")
restartRGBEvent.Name = "RestartRGBEvent"
restartRGBEvent.Parent = ReplicatedStorage

-- Store player data
local playerData = {}
local savedHeadGUIs = {}

-- SIMPAN HEADGUI DENGAN SEMUA SCRIPTS NYA!
local function saveHeadGUI(player)
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            -- Cari BillboardGui
            for _, child in pairs(head:GetChildren()) do
                if child:IsA("BillboardGui") then
                    -- CLONE LENGKAP DENGAN SEMUA SCRIPTS!
                    local clonedGui = child:Clone()
                    
                    -- Pastikan semua LocalScript enabled
                    for _, script in pairs(clonedGui:GetDescendants()) do
                        if script:IsA("LocalScript") or script:IsA("Script") then
                            script.Disabled = false
                            script.Enabled = true
                        end
                    end
                    
                    savedHeadGUIs[player.UserId] = clonedGui
                    print("💾 HeadGUI saved for " .. player.Name .. " (with RGB scripts)")
                    return
                end
            end
        end
    end
end

-- RESTORE HEADGUI DENGAN RGB ANIMATION!
local function restoreHeadGUI(player)
    if not savedHeadGUIs[player.UserId] then 
        print("⚠️ No saved HeadGUI for " .. player.Name)
        return 
    end
    
    task.wait(0.3) -- Wait for character to fully load
    
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            -- Hapus semua BillboardGui yang ada
            for _, child in pairs(head:GetChildren()) do
                if child:IsA("BillboardGui") then
                    child:Destroy()
                end
            end
            
            task.wait(0.1)
            
            -- Clone GUI yang udah disimpan
            local restoredGui = savedHeadGUIs[player.UserId]:Clone()
            restoredGui.Parent = head
            
            -- RESTART SEMUA LOCALSCRIPT BIAR RGB JALAN!
            task.wait(0.1)
            
            for _, script in pairs(restoredGui:GetDescendants()) do
                if script:IsA("LocalScript") then
                    -- Method 1: Disable then enable
                    script.Disabled = true
                    script.Enabled = false
                    task.wait(0.05)
                    script.Disabled = false
                    script.Enabled = true
                    print("🔄 Restarted RGB LocalScript: " .. script.Name)
                elseif script:IsA("Script") then
                    -- If it's a regular script
                    script.Disabled = true
                    task.wait(0.05)
                    script.Disabled = false
                    print("🔄 Restarted RGB Script: " .. script.Name)
                end
            end
            
            -- EXTRA: Fire event ke client buat restart dari sisi client juga
            task.wait(0.2)
            restartRGBEvent:FireClient(player)
            
            print("✅ HeadGUI restored with RGB for " .. player.Name)
        end
    end
end

-- Save original avatar
local function saveOriginalAvatar(player)
    if not playerData[player.UserId] then
        playerData[player.UserId] = {
        currentAvatarId = nil,
        accessories = {},
        accessoryObjects = {}
        }
    end
end

-- Smooth avatar change
local function changeAvatarSmooth(player, targetUserId)
    if not player.Character then return end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then return end
    
    saveOriginalAvatar(player)
    
    -- SAVE HEADGUI SEBELUM GANTI!
    saveHeadGUI(player)
    
    playerData[player.UserId].currentAvatarId = targetUserId
    
    -- SMOOTH EFFECTS
    for i = 1, 25 do
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.4, 0.4, 0.4)
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(88, 101, 242)
        part.CanCollide = false
        part.Anchored = true
        part.Transparency = 0.2
        
        local angle = (i / 25) * math.pi * 2
        local radius = 3
        part.Position = rootPart.Position + Vector3.new(
        math.cos(angle) * radius,
        math.random(0, 4),
        math.sin(angle) * radius
        )
        part.Parent = workspace
        
        local targetPos = rootPart.Position + Vector3.new(0, math.random(1, 3), 0)
        TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
        Position = targetPos,
        Transparency = 1,
        Size = Vector3.new(0, 0, 0)
        }):Play()
        
        task.delay(0.7, function() part:Destroy() end)
        end
            
            local beam = Instance.new("Part")
            beam.Size = Vector3.new(5, 0.5, 5)
            beam.Shape = Enum.PartType.Cylinder
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromRGB(88, 101, 242)
            beam.CanCollide = false
            beam.Anchored = true
            beam.Transparency = 0.3
            beam.Position = rootPart.Position
            beam.Orientation = Vector3.new(0, 0, 90)
            beam.Parent = workspace
            
            TweenService:Create(beam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
            Size = Vector3.new(8, 0.5, 8),
            Transparency = 1
            }):Play()
            task.delay(0.6, function() beam:Destroy() end)
                
                for i = 1, 3 do
                    task.wait(0.1)
                    local ring = Instance.new("Part")
                    ring.Size = Vector3.new(0.5, 0.2, 0.5)
                    ring.Shape = Enum.PartType.Cylinder
                    ring.Material = Enum.Material.Neon
                    ring.Color = Color3.fromRGB(120, 130, 255)
                    ring.CanCollide = false
                    ring.Anchored = true
                    ring.Transparency = 0.4
                    ring.Position = rootPart.Position + Vector3.new(0, i * 0.5, 0)
                    ring.Orientation = Vector3.new(0, 0, 90)
                    ring.Parent = workspace
                    
                    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
                    Size = Vector3.new(12, 0.2, 12),
                    Transparency = 1
                    }):Play()
                    task.delay(0.5, function() ring:Destroy() end)
                    end
                        
                        -- Fade out
                        for _, part in pairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") or part:IsA("Decal") then
                                TweenService:Create(part, TweenInfo.new(0.3), {Transparency = 1}):Play()
                            end
                        end
                        
                        task.wait(0.4)
                        
                        -- Remove old accessories (NOT HEADGUI!)
                        for _, item in pairs(player.Character:GetChildren()) do
                            if item:IsA("Accessory") or item:IsA("Hat") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                                item:Destroy()
                            end
                        end
                        
                        -- Apply new avatar
                        local success, description = pcall(function()
                            return Players:GetHumanoidDescriptionFromUserId(targetUserId)
                        end)
                        
                        if success and description then
                            humanoid:ApplyDescription(description)
                            
                            -- WAIT FOR CHARACTER TO FULLY LOAD
                            task.wait(0.8)
                            
                            -- RESTORE HEADGUI DENGAN RGB!
                            restoreHeadGUI(player)
                            
                            -- EXTRA WAIT BUAT MASTIIN RGB JALAN
                            task.wait(0.3)
                            
                            -- RESTART RGB LAGI KALO PERLU
                            if player.Character then
                                local head = player.Character:FindFirstChild("Head")
                                if head then
                                    for _, gui in pairs(head:GetChildren()) do
                                        if gui:IsA("BillboardGui") then
                                            for _, script in pairs(gui:GetDescendants()) do
                                                if script:IsA("LocalScript") then
                                                    -- Force restart again!
                                                    script.Disabled = true
                                                    task.wait(0.1)
                                                    script.Disabled = false
                                                    print("🔄 FORCE RESTARTED RGB: " .. script.Name)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        task.wait(0.2)
                        
                        -- Fade in
                        for _, part in pairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                local original = 0
                                if part.Name == "HumanoidRootPart" then
                                    original = 1
                                end
                                TweenService:Create(part, TweenInfo.new(0.4), {Transparency = original}):Play()
                            elseif part:IsA("Decal") then
                                TweenService:Create(part, TweenInfo.new(0.4), {Transparency = 0}):Play()
                            end
                        end
                        
                        -- Burst effect
                        local burst = Instance.new("Part")
                        burst.Size = Vector3.new(1, 1, 1)
                        burst.Shape = Enum.PartType.Ball
                        burst.Material = Enum.Material.Neon
                        burst.Color = Color3.fromRGB(88, 101, 242)
                        burst.CanCollide = false
                        burst.Anchored = true
                        burst.Transparency = 0.3
                        burst.Position = rootPart.Position + Vector3.new(0, 1, 0)
                        burst.Parent = workspace
                        
                        TweenService:Create(burst, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
                        Size = Vector3.new(10, 10, 10),
                        Transparency = 1
                        }):Play()
                        task.delay(0.5, function() burst:Destroy() end)
                            
                            -- Re-add custom accessories
                            if playerData[player.UserId] and playerData[player.UserId].accessories then
                                task.wait(0.3)
                                for assetId, _ in pairs(playerData[player.UserId].accessories) do
                                    addAccessory(player, assetId)
                                end
                            end
                            
                            print("✨ Avatar changed - HeadGUI RGB FORCE RESTARTED!")
                        end
                        
                        -- Add Accessory
                        function addAccessory(player, assetId)
                            if player.Character then
                                local humanoid = player.Character:FindFirstChild("Humanoid")
                                if humanoid then
                                    local success, model = pcall(function()
                                        return InsertService:LoadAsset(assetId)
                                    end)
                                    
                                    if success and model then
                                        local accessory = model:FindFirstChildOfClass("Accessory")
                                        
                                        if accessory then
                                            local clonedAccessory = accessory:Clone()
                                            humanoid:AddAccessory(clonedAccessory)
                                            
                                            if not playerData[player.UserId] then
                                                saveOriginalAvatar(player)
                                            end
                                            playerData[player.UserId].accessories[assetId] = true
                                            
                                            if not playerData[player.UserId].accessoryObjects[assetId] then
                                                playerData[player.UserId].accessoryObjects[assetId] = {}
                                            end
                                            table.insert(playerData[player.UserId].accessoryObjects[assetId], clonedAccessory)
                                            
                                            print("✅ Added accessory " .. assetId .. " (" .. accessory.Name .. ")")
                                        else
                                            warn("❌ No Accessory found in asset " .. assetId)
                                        end
                                        
                                        model:Destroy()
                                    else
                                        warn("❌ Failed to load asset: " .. assetId)
                                    end
                                end
                            end
                        end
                        
                        -- Remove Accessory
                        function removeAccessory(player, assetId)
                            if player.Character then
                                if playerData[player.UserId] and playerData[player.UserId].accessoryObjects[assetId] then
                                    for _, accessory in pairs(playerData[player.UserId].accessoryObjects[assetId]) do
                                        if accessory and accessory.Parent then
                                            accessory:Destroy()
                                            print("✅ Removed accessory from saved objects: " .. assetId)
                                        end
                                    end
                                    playerData[player.UserId].accessoryObjects[assetId] = {}
                                end
                                
                                for _, item in pairs(player.Character:GetChildren()) do
                                    if item:IsA("Accessory") then
                                        local handle = item:FindFirstChild("Handle")
                                        if handle then
                                            for _, mesh in pairs(handle:GetDescendants()) do
                                                if mesh:IsA("SpecialMesh") or mesh:IsA("MeshPart") then
                                                    local meshId = mesh:IsA("SpecialMesh") and mesh.MeshId or mesh.MeshId
                                                    if meshId and (meshId:find(tostring(assetId)) or meshId:find("rbxassetid://" .. assetId)) then
                                                        item:Destroy()
                                                        print("✅ Removed accessory by mesh check: " .. item.Name)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                if playerData[player.UserId] and playerData[player.UserId].accessories then
                                    playerData[player.UserId].accessories[assetId] = nil
                                end
                                
                                print("✅ Accessory removal complete for " .. assetId)
                            end
                        end
                        
                        -- Reset avatar
                        local function resetAvatar(player)
                            if not player.Character then return end
                            
                            local humanoid = player.Character:FindFirstChild("Humanoid")
                            if humanoid and playerData[player.UserId] then
                                
                                playerData[player.UserId].currentAvatarId = nil
                                playerData[player.UserId].accessories = {}
                                playerData[player.UserId].accessoryObjects = {}
                                
                                local success, description = pcall(function()
                                    return Players:GetHumanoidDescriptionFromUserId(player.UserId)
                                end)
                                
                                if success and description then
                                    humanoid:ApplyDescription(description)
                                    
                                    task.wait(0.8)
                                    restoreHeadGUI(player)
                                    
                                    -- RESTART RGB LAGI
                                    task.wait(0.3)
                                    if player.Character then
                                        local head = player.Character:FindFirstChild("Head")
                                        if head then
                                            for _, gui in pairs(head:GetChildren()) do
                                                if gui:IsA("BillboardGui") then
                                                    for _, script in pairs(gui:GetDescendants()) do
                                                        if script:IsA("LocalScript") then
                                                            script.Disabled = true
                                                            task.wait(0.1)
                                                            script.Disabled = false
                                                            print("🔄 RESET - RGB RESTARTED!")
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    print("✅ Avatar reset - HeadGUI RGB restored!")
                                end
                            end
                        end
                        
                        -- Player joined
                        Players.PlayerAdded:Connect(function(player)
                            saveOriginalAvatar(player)
                            
                            player.CharacterAdded:Connect(function(character)
                                -- Save HeadGUI on spawn
                                task.wait(2.5) -- Tunggu character & HeadGUI load
                                saveHeadGUI(player)
                                
                                task.wait(0.5)
                                
                                -- Reapply avatar if needed
                                if playerData[player.UserId] and playerData[player.UserId].currentAvatarId then
                                    local humanoid = character:WaitForChild("Humanoid", 5)
                                    if humanoid then
                                        task.wait(0.3)
                                        changeAvatarSmooth(player, playerData[player.UserId].currentAvatarId)
                                    end
                                else
                                    if playerData[player.UserId] and playerData[player.UserId].accessories then
                                        task.wait(0.5)
                                        for assetId, _ in pairs(playerData[player.UserId].accessories) do
                                            addAccessory(player, assetId)
                                        end
                                    end
                                end
                            end)
                        end)
                        
                        -- Event handlers
                        changeAvatarEvent.OnServerEvent:Connect(function(player, targetUserId)
                            if typeof(targetUserId) == "number" then
                                changeAvatarSmooth(player, targetUserId)
                            end
                        end)
                        
                        resetAvatarEvent.OnServerEvent:Connect(function(player)
                            resetAvatar(player)
                        end)
                        
                        addAccessoryEvent.OnServerEvent:Connect(function(player, assetId)
                            if typeof(assetId) == "number" then
                                addAccessory(player, assetId)
                            end
                        end)
                        
                        removeAccessoryEvent.OnServerEvent:Connect(function(player, assetId)
                            if typeof(assetId) == "number" then
                                removeAccessory(player, assetId)
                            end
                        end)
                        
                        -- Cleanup
                        Players.PlayerRemoving:Connect(function(player)
                            playerData[player.UserId] = nil
                            savedHeadGUIs[player.UserId] = nil
                        end)
                        
                        print("✅ Avatar Changer FULLY WORKING - RGB FORCE RESTART!")
-- Avatar Catalog - With Accessories Shop
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
 
-- Import Topbar+
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))
 
-- RemoteEvents
local changeAvatarEvent = ReplicatedStorage:WaitForChild("ChangeAvatarEvent")
local resetAvatarEvent = ReplicatedStorage:WaitForChild("ResetAvatarEvent")
local addAccessoryEvent = ReplicatedStorage:WaitForChild("AddAccessoryEvent")
local removeAccessoryEvent = ReplicatedStorage:WaitForChild("RemoveAccessoryEvent")
 
-- ============================================
-- AVATAR DATA
-- ============================================
local AVATARS = {
Boys = {
{name = "Boys 1", id = 9101259798},
{name = "Boys 2", id = 8912185225},
{name = "Boys 3", id = 8935877365},
{name = "Boys 4", id = 8352609716},
{name = "Boys 5", id = 8976748119},
{name = "Boys 6", id = 8968308984},
{name = "Boys 7", id = 4832303740},
{name = "Boys 8", id = 9220382005},
{name = "Boys 9", id = 9046030552},
{name = "Boys 10", id = 9000844254},
{name = "Boys 11", id = 8966687266},
{name = "Boys 12", id = 9112933446}
},
Girls = {
{name = "Girls 1", id = 9181935703},
{name = "Girls 2", id = 7843828496},
{name = "Girls 3", id = 3226668321},
{name = "Girls 4", id = 7260068521},
{name = "Girls 5", id = 8592887007},
{name = "Girls 6", id = 9093398365},
{name = "Girls 7", id = 8918025774},
{name = "Girls 8", id = 8935328065},
{name = "Girls 9", id = 8891975253},
{name = "Girls 10", id = 8486540814},
{name = "Girls 11", id = 9101275612},
{name = "Girls 12", id = 9084296513}
}
}
-- ============================================
-- ACCESSORIES DATA
-- ============================================
local ACCESSORIES = {
{name = "Crown 8 Bit", id = 10159600649},
{name = "8-Bit Extra Life", id = 10159606132},
{name = "8-Bit HP Bar", id = 10159610478},
{name = "8-Bit Roblox Coin", id = 10159622004},
{name = "8-Bit Tabby Cat", id = 10159617728},
{name = "8-Bit Exstra Life", id = 10159606132}
}
 
-- Topbar Icon
local avatarIcon = Icon.new()
avatarIcon:setLabel("Avatars")
avatarIcon:setOrder(1)
 
-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AvatarCatalog"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui
 
-- Overlay
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = gui
 
-- Main Frame
local main = Instance.new("Frame")
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Size = UDim2.new(0, 650, 0, 380)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
main.BorderSizePixel = 0
main.Visible = false
main.Parent = gui
 
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main
 
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 45, 50)
mainStroke.Thickness = 1.5
mainStroke.Parent = main
 
-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(26, 26, 29)
header.BorderSizePixel = 0
header.Parent = main
 
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header
 
local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 15)
headerFix.Position = UDim2.new(0, 0, 1, -15)
headerFix.BackgroundColor3 = Color3.fromRGB(26, 26, 29)
headerFix.BorderSizePixel = 0
headerFix.Parent = header
 
-- Title with gradient
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 150, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Avatar Catalog"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header
 
-- Close
local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 35, 0, 35)
close.Position = UDim2.new(1, -43, 0, 8)
close.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(200, 200, 205)
close.TextSize = 18
close.Font = Enum.Font.GothamBold
close.AutoButtonColor = false
close.Parent = header
 
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = close
 
-- Tabs Container
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(0, 200, 0, 36)
tabs.Position = UDim2.new(0, 20, 0, 62)
tabs.BackgroundTransparency = 1
tabs.Parent = main
 
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabs
 
-- LEFT SIDE - Content Container
local leftSide = Instance.new("Frame")
leftSide.Size = UDim2.new(0, 300, 1, -155)
leftSide.Position = UDim2.new(0, 20, 0, 105)
leftSide.BackgroundTransparency = 1
leftSide.Parent = main
 
-- Avatar Grid
local avatarContent = Instance.new("ScrollingFrame")
avatarContent.Name = "AvatarContent"
avatarContent.Size = UDim2.new(1, 0, 1, 0)
avatarContent.BackgroundTransparency = 1
avatarContent.BorderSizePixel = 0
avatarContent.ScrollBarThickness = 4
avatarContent.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
avatarContent.CanvasSize = UDim2.new(0, 0, 0, 0)
avatarContent.Visible = true
avatarContent.Parent = leftSide
 
local avatarGrid = Instance.new("UIGridLayout")
avatarGrid.CellSize = UDim2.new(0, 68, 0, 88)
avatarGrid.CellPadding = UDim2.new(0, 6, 0, 6)
avatarGrid.Parent = avatarContent
 
local avatarPad = Instance.new("UIPadding")
avatarPad.PaddingTop = UDim.new(0, 3)
avatarPad.PaddingLeft = UDim.new(0, 3)
avatarPad.PaddingRight = UDim.new(0, 3)
avatarPad.Parent = avatarContent
 
-- Accessories Grid
local accessoryContent = Instance.new("ScrollingFrame")
accessoryContent.Name = "AccessoryContent"
accessoryContent.Size = UDim2.new(1, 0, 1, 0)
accessoryContent.BackgroundTransparency = 1
accessoryContent.BorderSizePixel = 0
accessoryContent.ScrollBarThickness = 4
accessoryContent.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
accessoryContent.CanvasSize = UDim2.new(0, 0, 0, 0)
accessoryContent.Visible = false
accessoryContent.Parent = leftSide
 
local accessoryGrid = Instance.new("UIGridLayout")
accessoryGrid.CellSize = UDim2.new(0, 68, 0, 88)
accessoryGrid.CellPadding = UDim2.new(0, 6, 0, 6)
accessoryGrid.Parent = accessoryContent
 
local accessoryPad = Instance.new("UIPadding")
accessoryPad.PaddingTop = UDim.new(0, 3)
accessoryPad.PaddingLeft = UDim.new(0, 3)
accessoryPad.PaddingRight = UDim.new(0, 3)
accessoryPad.Parent = accessoryContent
 
-- RIGHT SIDE - 3D PREVIEW
local rightSide = Instance.new("Frame")
rightSide.Size = UDim2.new(0, 295, 1, -155)
rightSide.Position = UDim2.new(1, -315, 0, 105)
rightSide.BackgroundColor3 = Color3.fromRGB(26, 26, 29)
rightSide.BorderSizePixel = 0
rightSide.Parent = main
 
local rightCorner = Instance.new("UICorner")
rightCorner.CornerRadius = UDim.new(0, 12)
rightCorner.Parent = rightSide
 
local rightStroke = Instance.new("UIStroke")
rightStroke.Color = Color3.fromRGB(40, 40, 45)
rightStroke.Thickness = 1
rightStroke.Parent = rightSide
 
-- Preview Title
local previewTitle = Instance.new("TextLabel")
previewTitle.Size = UDim2.new(1, 0, 0, 24)
previewTitle.BackgroundTransparency = 1
previewTitle.Text = "PREVIEW"
previewTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
previewTitle.TextSize = 11
previewTitle.Font = Enum.Font.GothamBold
previewTitle.Parent = rightSide
 
-- ViewportFrame
local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, -8, 1, -28)
viewport.Position = UDim2.new(0, 4, 0, 26)
viewport.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
viewport.BorderSizePixel = 0
viewport.Parent = rightSide
 
local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 10)
viewportCorner.Parent = viewport
 
local camera = Instance.new("Camera")
camera.Parent = viewport
viewport.CurrentCamera = camera
 
local worldModel = Instance.new("WorldModel")
worldModel.Parent = viewport
 
local previewCharacter = nil
local rotationConnection = nil
 
-- Bottom Bar
local bottom = Instance.new("Frame")
bottom.Size = UDim2.new(1, -40, 0, 45)
bottom.Position = UDim2.new(0, 20, 1, -55)
bottom.BackgroundColor3 = Color3.fromRGB(26, 26, 29)
bottom.BorderSizePixel = 0
bottom.Parent = main
 
local bottomCorner = Instance.new("UICorner")
bottomCorner.CornerRadius = UDim.new(0, 10)
bottomCorner.Parent = bottom
 
local bottomStroke = Instance.new("UIStroke")
bottomStroke.Color = Color3.fromRGB(40, 40, 45)
bottomStroke.Thickness = 1
bottomStroke.Parent = bottom
 
-- Selected Name
local selectedName = Instance.new("TextLabel")
selectedName.Size = UDim2.new(0, 280, 1, 0)
selectedName.Position = UDim2.new(0, 15, 0, 0)
selectedName.BackgroundTransparency = 1
selectedName.Text = "Select an avatar"
selectedName.TextColor3 = Color3.fromRGB(180, 180, 190)
selectedName.TextSize = 12
selectedName.Font = Enum.Font.GothamMedium
selectedName.TextXAlignment = Enum.TextXAlignment.Left
selectedName.TextTruncate = Enum.TextTruncate.AtEnd
selectedName.Parent = bottom
 
-- Use/Add Button
local actionBtn = Instance.new("TextButton")
actionBtn.Size = UDim2.new(0, 90, 0, 32)
actionBtn.Position = UDim2.new(1, -195, 0.5, -16)
actionBtn.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
actionBtn.BorderSizePixel = 0
actionBtn.Text = "Use"
actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
actionBtn.TextSize = 13
actionBtn.Font = Enum.Font.GothamBold
actionBtn.AutoButtonColor = false
actionBtn.Parent = bottom
 
local actionBtnCorner = Instance.new("UICorner")
actionBtnCorner.CornerRadius = UDim.new(0, 8)
actionBtnCorner.Parent = actionBtn
 
-- Reset Button
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(0, 90, 0, 32)
resetBtn.Position = UDim2.new(1, -95, 0.5, -16)
resetBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "Reset"
resetBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
resetBtn.TextSize = 13
resetBtn.Font = Enum.Font.GothamMedium
resetBtn.AutoButtonColor = false
resetBtn.Parent = bottom
 
local resetBtnCorner = Instance.new("UICorner")
resetBtnCorner.CornerRadius = UDim.new(0, 8)
resetBtnCorner.Parent = resetBtn
 
-- Variables
local currentMainTab = "Avatars"
local currentCategory = "Boys"
local selected = nil
local selectedAccessory = nil
local tabButtons = {}
local equippedAccessories = {}
 
-- Tween
local function tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad), props):Play()
end
 
-- Clear Preview
local function clearPreview()
    if rotationConnection then
        rotationConnection:Disconnect()
        rotationConnection = nil
    end
 
    if previewCharacter then
        previewCharacter:Destroy()
        previewCharacter = nil
    end
 
    worldModel:ClearAllChildren()
end
 
-- Load Preview (FIXED VERSION)
local function loadPreviewCharacter(userId)
    clearPreview()
    selectedName.Text = "Loading preview..."
 
    task.spawn(function()
        local success, character = pcall(function()
            return Players:CreateHumanoidModelFromUserId(userId)
        end)
 
        if success and character then
            character.Parent = worldModel
            previewCharacter = character
 
            -- Apply description
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local descSuccess, description = pcall(function()
                    return Players:GetHumanoidDescriptionFromUserId(userId)
                end)
 
                if descSuccess and description then
                    pcall(function()
                        humanoid:ApplyDescription(description)
                    end)
                end
            end
 
            -- Wait for character to fully load
            task.wait(0.5)
 
            -- Setup camera
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Parent then
                hrp.Anchored = true
 
                local charSize = character:GetExtentsSize()
                local distance = math.max(charSize.X, charSize.Y, charSize.Z) * 1.2
 
                camera.CFrame = CFrame.new(
                Vector3.new(0, charSize.Y / 2.5, distance),
                Vector3.new(0, charSize.Y / 2.5, 0)
                )
 
                -- Rotation animation
                local angle = 0
                rotationConnection = RunService.RenderStepped:Connect(function(dt)
                    if previewCharacter and previewCharacter.Parent and hrp and hrp.Parent then
                        angle = angle + (dt * 40)
                        hrp.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(angle), 0)
                    else
                        if rotationConnection then
                            rotationConnection:Disconnect()
                            rotationConnection = nil
                        end
                    end
                end)
 
                selectedName.Text = "Preview loaded!"
            else
                selectedName.Text = "Preview loaded"
            end
        else
            selectedName.Text = "Failed to load preview"
            warn("Failed to create character model for userId:", userId)
        end
    end)
end
 
-- Create Main Tab
local function createMainTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 92, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.BorderSizePixel = 0
    btn.Text = icon .. " " .. name
    btn.TextColor3 = Color3.fromRGB(140, 140, 150)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.AutoButtonColor = false
    btn.Parent = tabs
 
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
 
    tabButtons[name] = btn
 
    btn.MouseButton1Click:Connect(function()
        switchMainTab(name)
    end)
 
    return btn
end
 
-- Create Category Tab (Boys/Girls)
local categoryTabs = Instance.new("Frame")
categoryTabs.Size = UDim2.new(0, 150, 0, 34)
categoryTabs.Position = UDim2.new(0, 220, 0, 62)
categoryTabs.BackgroundTransparency = 1
categoryTabs.Visible = false
categoryTabs.Parent = main
 
local categoryLayout = Instance.new("UIListLayout")
categoryLayout.FillDirection = Enum.FillDirection.Horizontal
categoryLayout.Padding = UDim.new(0, 8)
categoryLayout.Parent = categoryTabs
 
local categoryButtons = {}
 
local function createCategoryTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(140, 140, 150)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.AutoButtonColor = false
    btn.Parent = categoryTabs
 
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
 
    categoryButtons[name] = btn
 
    btn.MouseButton1Click:Connect(function()
        loadCategory(name)
    end)
 
    return btn
end
 
-- Switch Main Tab
function switchMainTab(tab)
    currentMainTab = tab
 
    for name, btn in pairs(tabButtons) do
        if name == tab then
            tween(btn, {BackgroundColor3 = Color3.fromRGB(114, 137, 218), TextColor3 = Color3.fromRGB(255, 255, 255)})
        else
            tween(btn, {BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(140, 140, 150)})
        end
    end
 
    if tab == "Avatars" then
        avatarContent.Visible = true
        accessoryContent.Visible = false
        categoryTabs.Visible = true
        actionBtn.Text = "Use"
        selectedName.Text = "Select an avatar"
    elseif tab == "Items" then
        avatarContent.Visible = false
        accessoryContent.Visible = true
        categoryTabs.Visible = false
        actionBtn.Text = "Add"
        selectedName.Text = "Select an item"
        loadAccessories()
    end
 
    clearPreview()
    selected = nil
    selectedAccessory = nil
end
 
-- Create Avatar Card
local function createAvatarCard(data)
    local card = Instance.new("TextButton")
    card.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.Parent = avatarContent
 
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card
 
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 45)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = card
 
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, -8, 0, 58)
    img.Position = UDim2.new(0, 4, 0, 4)
    img.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    img.BorderSizePixel = 0
    img.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. data.id .. "&width=150&height=150&format=png"
    img.ScaleType = Enum.ScaleType.Crop
    img.Parent = card
 
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(0, 8)
    imgCorner.Parent = img
 
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -6, 0, 24)
    name.Position = UDim2.new(0, 3, 0, 64)
    name.BackgroundTransparency = 1
    name.Text = data.name
    name.TextColor3 = Color3.fromRGB(210, 210, 220)
    name.TextSize = 10
    name.Font = Enum.Font.GothamMedium
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.TextWrapped = true
    name.Parent = card
 
    card.MouseEnter:Connect(function()
        if selected ~= data then
            tween(card, {BackgroundColor3 = Color3.fromRGB(35, 35, 40)})
            tween(stroke, {Transparency = 0})
        end
    end)
 
    card.MouseLeave:Connect(function()
        if selected ~= data then
            tween(card, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)})
            tween(stroke, {Transparency = 0.5})
        end
    end)
 
    card.MouseButton1Click:Connect(function()
        selected = data
        selectedAccessory = nil
        selectedName.Text = data.name
 
        loadPreviewCharacter(data.id)
 
        for _, c in pairs(avatarContent:GetChildren()) do
            if c:IsA("TextButton") then
                local s = c:FindFirstChildOfClass("UIStroke")
                tween(c, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)})
                if s then s.Color = Color3.fromRGB(40, 40, 45) end
            end
        end
        tween(card, {BackgroundColor3 = Color3.fromRGB(114, 137, 218)})
        stroke.Color = Color3.fromRGB(114, 137, 218)
    end)
end
 
-- Create Accessory Card
local function createAccessoryCard(data)
    local card = Instance.new("TextButton")
    card.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.Parent = accessoryContent
 
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card
 
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 45)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = card
 
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, -8, 0, 58)
    img.Position = UDim2.new(0, 4, 0, 4)
    img.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    img.BorderSizePixel = 0
    img.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    img.ScaleType = Enum.ScaleType.Fit
    img.Parent = card
 
    task.spawn(function()
        local success, result = pcall(function()
            return "https://www.roblox.com/asset-thumbnail/image?assetId=" .. data.id .. "&width=150&height=150&format=png"
        end)
        if success then img.Image = result end
    end)
 
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(0, 8)
    imgCorner.Parent = img
 
    local equipped = Instance.new("TextLabel")
    equipped.Size = UDim2.new(1, -8, 0, 16)
    equipped.Position = UDim2.new(0, 4, 0, 4)
    equipped.BackgroundColor3 = Color3.fromRGB(67, 181, 129)
    equipped.BorderSizePixel = 0
    equipped.Text = "✓ EQUIPPED"
    equipped.TextColor3 = Color3.fromRGB(255, 255, 255)
    equipped.TextSize = 9
    equipped.Font = Enum.Font.GothamBold
    equipped.Visible = false
    equipped.Parent = card
 
    local equippedCorner = Instance.new("UICorner")
    equippedCorner.CornerRadius = UDim.new(0, 8)
    equippedCorner.Parent = equipped
 
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -6, 0, 24)
    name.Position = UDim2.new(0, 3, 0, 64)
    name.BackgroundTransparency = 1
    name.Text = data.name
    name.TextColor3 = Color3.fromRGB(210, 210, 220)
    name.TextSize = 9
    name.Font = Enum.Font.GothamMedium
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.TextWrapped = true
    name.Parent = card
 
    if equippedAccessories[data.id] then
        equipped.Visible = true
    end
 
    card.MouseEnter:Connect(function()
        if selectedAccessory ~= data then
            tween(card, {BackgroundColor3 = Color3.fromRGB(35, 35, 40)})
            tween(stroke, {Transparency = 0})
        end
    end)
 
    card.MouseLeave:Connect(function()
        if selectedAccessory ~= data then
            tween(card, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)})
            tween(stroke, {Transparency = 0.5})
        end
    end)
 
    card.MouseButton1Click:Connect(function()
        selectedAccessory = data
        selected = nil
        selectedName.Text = data.name
 
        for _, c in pairs(accessoryContent:GetChildren()) do
            if c:IsA("TextButton") then
                local s = c:FindFirstChildOfClass("UIStroke")
                tween(c, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)})
                if s then s.Color = Color3.fromRGB(40, 40, 45) end
            end
        end
        tween(card, {BackgroundColor3 = Color3.fromRGB(114, 137, 218)})
        stroke.Color = Color3.fromRGB(114, 137, 218)
 
        if equippedAccessories[data.id] then
            actionBtn.Text = "Remove"
            actionBtn.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
        else
            actionBtn.Text = "Add"
            actionBtn.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
        end
    end)
 
    return card
end
 
-- Load Category
function loadCategory(cat)
    currentCategory = cat
 
    for name, btn in pairs(categoryButtons) do
        if name == cat then
            tween(btn, {BackgroundColor3 = Color3.fromRGB(114, 137, 218), TextColor3 = Color3.fromRGB(255, 255, 255)})
        else
            tween(btn, {BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(140, 140, 150)})
        end
    end
 
    for _, c in pairs(avatarContent:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
 
    for _, data in ipairs(AVATARS[cat] or {}) do
        createAvatarCard(data)
    end
 
    avatarContent.CanvasSize = UDim2.new(0, 0, 0, avatarGrid.AbsoluteContentSize.Y + 6)
    selected = nil
    selectedName.Text = "Select an avatar"
    clearPreview()
end
 
-- Load Accessories
function loadAccessories()
    for _, c in pairs(accessoryContent:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
 
    for _, data in ipairs(ACCESSORIES) do
        createAccessoryCard(data)
    end
 
    accessoryContent.CanvasSize = UDim2.new(0, 0, 0, accessoryGrid.AbsoluteContentSize.Y + 6)
end
 
-- Init
createMainTab("Avatars", "👤")
createMainTab("Items", "🎩")
 
createCategoryTab("Boys")
createCategoryTab("Girls")
 
categoryTabs.Visible = true
loadCategory("Boys")
switchMainTab("Avatars")
 
-- Canvas update
avatarGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    avatarContent.CanvasSize = UDim2.new(0, 0, 0, avatarGrid.AbsoluteContentSize.Y + 6)
end)
 
accessoryGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    accessoryContent.CanvasSize = UDim2.new(0, 0, 0, accessoryGrid.AbsoluteContentSize.Y + 6)
end)
 
-- Open/Close (TANPA ANIMASI)
avatarIcon:bindEvent("selected", function()
    overlay.Visible = true
    overlay.BackgroundTransparency = 0.55
    main.Visible = true
end)
 
avatarIcon:bindEvent("deselected", function()
    overlay.Visible = false
    main.Visible = false
    clearPreview()
end)
 
close.MouseButton1Click:Connect(function()
    avatarIcon:deselect()
end)
 
close.MouseEnter:Connect(function()
    tween(close, {BackgroundColor3 = Color3.fromRGB(237, 66, 69), TextColor3 = Color3.fromRGB(255, 255, 255)})
end)
 
close.MouseLeave:Connect(function()
    tween(close, {BackgroundColor3 = Color3.fromRGB(35, 35, 40), TextColor3 = Color3.fromRGB(200, 200, 205)})
end)
 
-- Action Button
actionBtn.MouseButton1Click:Connect(function()
    if currentMainTab == "Avatars" and selected then
        changeAvatarEvent:FireServer(selected.id)
        actionBtn.Text = "✓"
        tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(67, 181, 129)})
 
        task.wait(0.5)
        avatarIcon:deselect()
 
        task.wait(0.3)
        actionBtn.Text = "Use"
        tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(114, 137, 218)})
 
    elseif currentMainTab == "Items" and selectedAccessory then
        if equippedAccessories[selectedAccessory.id] then
            removeAccessoryEvent:FireServer(selectedAccessory.id)
            equippedAccessories[selectedAccessory.id] = nil
            actionBtn.Text = "Add"
            tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(114, 137, 218)})
        else
            addAccessoryEvent:FireServer(selectedAccessory.id)
            equippedAccessories[selectedAccessory.id] = true
            actionBtn.Text = "Remove"
            tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(237, 66, 69)})
        end
        loadAccessories()
    end
end)
 
actionBtn.MouseEnter:Connect(function()
    if actionBtn.Text == "Use" or actionBtn.Text == "Add" then
        tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(124, 147, 228)})
    elseif actionBtn.Text == "Remove" then
        tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(247, 76, 79)})
    end
end)
 
actionBtn.MouseLeave:Connect(function()
    if actionBtn.Text == "Use" or actionBtn.Text == "Add" then
        tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(114, 137, 218)})
    elseif actionBtn.Text == "Remove" then
        tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(237, 66, 69)})
    end
end)
 
-- Reset Button
resetBtn.MouseButton1Click:Connect(function()
    resetAvatarEvent:FireServer()
    equippedAccessories = {}
    selected = nil
    selectedAccessory = nil
    selectedName.Text = "Avatar reset!"
 
    for _, c in pairs(avatarContent:GetChildren()) do
        if c:IsA("TextButton") then
            local s = c:FindFirstChildOfClass("UIStroke")
            tween(c, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)})
            if s then s.Color = Color3.fromRGB(40, 40, 45) end
        end
    end
 
    if currentMainTab == "Items" then loadAccessories() end
    clearPreview()
 
    task.wait(0.8)
    selectedName.Text = "Select an avatar"
end)
 
resetBtn.MouseEnter:Connect(function()
    tween(resetBtn, {BackgroundColor3 = Color3.fromRGB(45, 45, 52)})
end)
 
resetBtn.MouseLeave:Connect(function()
    tween(resetBtn, {BackgroundColor3 = Color3.fromRGB(35, 35, 40)})
end)
 
print("✨ Avatar Catalog - Ready!")
