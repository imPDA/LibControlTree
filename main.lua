--local df = function(...) end

local CONTROL_TYPE_NAMES = {
    --[[-1]] [-1] = 'Invalid',
    --[[ 0]] [0] = 'Control',
    --[[ 1]] 'Label',
    --[[ 2]] 'DebugText',
    --[[ 3]] 'Texture',
    --[[ 4]] 'TopLevelControl',
    --[[ 5]] 'RootWindow',
    --[[ 6]] 'TextBuffer',
    --[[ 7]] 'Button',
    --[[ 8]] 'StatusBar',
    --[[ 9]] 'EditBox',
    --[[10]] 'Cooldown',
    --[[11]] 'Tooltip',
    --[[12]] 'Scroll',
    --[[13]] 'Slider',
    --[[14]] 'Backdrop',
    --[[15]] 'MapDisplay',
    --[[16]] 'ColorSelect',
    --[[17]] 'Line',
    --[[18]] 'Compass',
    --[[19]] 'TextureComposite',
    --[[20]] 'Polygon',
    --[[21]] 'Vector',
    --[[22]] 'Canvas',
}

local addonName = 'LibControlTree'
local EVENT_NAMESPACE = addonName


local HIGHLIGHT_CONTROL = LibControlTreeHighlight
local CONTROL_HIGHLIGHT_CONTROL = LibControlTreeControlHighlight
local CONTROLNAME_CONTROL = LibControlTree_TLCControlName


local registry = {}
local function _setKeybind(labelText, source)
    LibControlTree_TLCKeybind:SetHidden(false)
    -- LibControlTree_TLCKeybindLabel:SetText(('Build tree for %s'):format(control:GetName()))
    LibControlTree_TLCKeybindLabel:SetText(labelText)
    registry[source] = true
end

local function _hideKeybind(source)
    if not registry[source] then return end

    LibControlTree_TLCKeybind:SetHidden(true)
    registry[source] = nil
end


local function followTheMouse(control)
    control:SetAnchorOffsets(GetUIMousePosition())
end

local function _startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local function _getNameWithoutParentPrefix(control)
    local parentName = control:GetParent():GetName()
    local controlName = control:GetName()

    if _startsWith(controlName, parentName) then
        return controlName:sub(#parentName+1, -1)
    else
        return controlName
    end
end

local CURRENT_TREE
local function BuildTree(control)
    if not control then return end

    if control == HIGHLIGHT_CONTROL then
        return nil  -- TODO: can cause problems in the future with continuous counting!
    end

    local branch = {
        _name = _getNameWithoutParentPrefix(control),
        _control = control,
    }

    local numChildren = control:GetNumChildren()

    if numChildren > 0 then
        branch.children = {}
        for i = 1, numChildren do
            branch.children[i] = BuildTree(control:GetChild(i))
        end
    end

    return branch
end

local WHITELIST = {
    ['ZgooFrame'] = true,
    ['ZgooEventTracker'] = true,
    ['tbugTabWindow1'] = true,
    ['LibControlTree_TLC'] = true,
}

-- ----------------------------------------------------------------------------

local LIST_CONTROL = LibControlTree_TLCListingScrollableList

local function Update()
    -- if self:IsHidden() then
    --     self.dirty = true
    --     return
    -- end

    local tree = CURRENT_TREE

    local updateStart = GetGameTimeSeconds()

    local control = LIST_CONTROL
    local dataList = ZO_ScrollList_GetDataList(control)

    ZO_ScrollList_Clear(control)

    local function CreateAndAddDataEntry(node, level, last)
        local value = {node, level, last}
        local entry = ZO_ScrollList_CreateDataEntry(1, value)

        dataList[#dataList+1] = entry
    end

    local function traverse(node, level, last)
        level = level or 1
        CreateAndAddDataEntry(node, level, last)

        if level == 1 and node.children then
            node.opened = true
        end

        if node.children and node.opened then
            local numChildren = #node.children
            for i = 1, numChildren do
                traverse(node.children[i], level+1, i == numChildren)
            end
        end
    end

    traverse(tree)

    -- table.sort(dataList, function(l, r) return compareRecursive(l, r, sortingKeys, ascending, 1) end)

    local updateDuration = GetGameTimeSeconds() - updateStart
    df('Updated in %.2f ms', updateDuration * 1000)

    ZO_ScrollList_Commit(control)
end

local function CreateScrollListDataType()
    -- local function ShowRMBMenu(control, button)
    --     if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

    --     local data = control.dataEntry.data

    --     ClearMenu()

    --     local categories = ImpressiveStatsPlayersSV.categories
    --     local players = ImpressiveStatsPlayersSV.playerCategories

    --     for categoryIndex, categoryData in ipairs(categories) do
    --         local text = ('|c%s|t13:13:/art/fx/texture/whitesquare.dds:inheritcolor|t|r %s'):format(categoryData.color, categoryData.name)
    --         AddCustomMenuItem(text, function()
    --             local playerDisplayName = data[2]
    --             players[playerDisplayName] = categoryIndex

    --             -- GetControl(control, 'Mark'):SetHidden(false)
    --             -- GetControl(control, 'Mark'):SetColor(hex2rgb(categoryData.color))

    --             self:Update()
    --         end)
    --     end

    --     AddCustomMenuItem('Clear category', function()
    --         local playerDisplayName = data[2]
    --         players[playerDisplayName] = nil

    --         -- GetControl(control, 'Mark'):SetHidden(true)

    --         self:Update()
    --     end)

    --     ShowMenu()
    -- end

    local PLUS_TEXTURE = '/esoui/art/buttons/gamepad/switchpro/nav_switchpro_rs_plus.dds'
    local MINUS_TEXTURE = '/esoui/art/buttons/gamepad/switchpro/nav_switchpro_minus.dds'

    local function toggleLevel(control, button, ctrl, alt, shift, command)
        local node = control:GetParent().dataEntry.data[1]
        node.opened = not node.opened
        Update()
    end

    local function highlight(rowControl)
        local control = rowControl.dataEntry.data[1]._control

        CONTROL_HIGHLIGHT_CONTROL:SetParent(control)  -- TODO: do I need this?
        CONTROL_HIGHLIGHT_CONTROL:SetAnchorFill(control)
        CONTROL_HIGHLIGHT_CONTROL:SetHidden(false)
    end

    local function removeHighlight()
        -- HIGHLIGHT_CONTROL:SetParent(control)  -- TODO: do I need this?
        -- HIGHLIGHT_CONTROL:SetAnchorFill(control)
        CONTROL_HIGHLIGHT_CONTROL:SetHidden(true)
    end

    local function onMouseEnter(rowControl)
        highlight(rowControl)
        local control = rowControl.dataEntry.data[1]._control
        _setKeybind(control:GetName(), 'onmouseover')
    end

    local function onMouseExit()
        removeHighlight()
        _hideKeybind('onmouseover')
    end

    local function LayoutRow(rowControl, data, scrollList)
        local node = data[1]
        local isHidden = node._control:IsHidden()

        local label = GetControl(rowControl, 'Label')
        local name, color
        if isHidden then
            name = ('HIDDEN || %s'):format(node._name)
            color = {0.6, 0.6, 0.6}  -- TODO: define colors
        else
            name = ('%s'):format(node._name)
            color = {1, 1, 1}  -- TODO: define colors
        end
        label:SetText(name)
        label:SetColor(unpack(color))
        label:SetAnchorOffsets(data[2] * 25, 0)

        GetControl(rowControl, 'Type'):SetText(CONTROL_TYPE_NAMES[node._control:GetType()] or 'Unknown')

        local navigation = GetControl(rowControl, 'Navigation')
        if node.children and #node.children > 0 then
            if node.opened then
                navigation:SetTexture(MINUS_TEXTURE)
            else
                navigation:SetTexture(PLUS_TEXTURE)
            end
            navigation:SetHidden(false)
        else
            navigation:SetHidden(true)
        end

        -- do I need this? Rewriting handler probably fast anyway
        -- if not navigation:GetHandler('OnMouseDown') then
        -- end
        -- Ideally TODO: add handler on row creation, default ZOs function does not support it
        navigation:SetHandler('OnMouseDown', toggleLevel)

        -- if data[3] then
        --     navigation:SetTexture('LibControlTree/nav3.dds')
        -- else
        --     navigation:SetTexture('LibControlTree/nav2.dds')
        -- end

        local dataList = ZO_ScrollList_GetDataList(scrollList)
        local index = rowControl.index

        -- d(dataList)
        -- d(index)

        rowControl:SetHandler('OnMouseDown', function(control, button, ctrl, alt, shift, command)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                if not ctrl then return end

                -- Zgoo:Main(nil, 1, node._control)

                TBUG.doOpenNewInspector = false
                TBUG.inspectResults('MOC', {}, nil, node._control, true, node._control)

            else
            --     -- rowControl:SetHandler('OnMouseDown', ShowRMBMenu)
            --     ShowRMBMenu(control, button)
            end
        end)

        rowControl:SetHandler('OnMouseEnter', onMouseEnter)
        rowControl:SetHandler('OnMouseExit', onMouseExit)
    end

	local control = LIST_CONTROL
	local typeId = 1
	local templateName = 'LibControlTree_RowTemplate'
	local height = 32
	local setupFunction = LayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)

    -- local function foo(previouslySelectedData, selectedData, selectingDuringRebuild)
	-- end

	-- ZO_ScrollList_EnableSelection(control, 'ZO_ThinListHighlight', foo)
	-- ZO_ScrollList_SetDeselectOnReselect(control, true)
end

-- ----------------------------------------------------------------------------

local function OnAddonLoaded(_, addonName_)
    if addonName_ ~= addonName then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

    local previousMOCTLC
    local controlToOpen

    local function MouseClick(_, button, ctrl, alt, shift, command)
        -- df('MB: %s, ctrl: %s', tostring(button), tostring(ctrl))
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not ctrl then return end

        if controlToOpen then
            local tree = BuildTree(controlToOpen)

            -- Zgoo:Main(nil, 1, tree)

            CURRENT_TREE = tree

            Update()
        end
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_GLOBAL_MOUSE_UP, MouseClick)

    EVENT_MANAGER:RegisterForUpdate(EVENT_NAMESPACE, 0, function()
        local controlTLC = WINDOW_MANAGER:GetMouseOverControl()

        -- followTheMouse(CONTROLNAME_CONTROL)

        -- TODO: !!! REFACTOR LOGIC

        if controlTLC == GuiRoot then
            previousMOCTLC = GuiRoot
            HIGHLIGHT_CONTROL:SetHidden(true)

            -- CONTROLNAME_CONTROL:SetHidden(true)
            _hideKeybind('update')

            controlToOpen = nil
            return
        end

        if controlTLC == previousMOCTLC then return end
        previousMOCTLC = controlTLC

        while controlTLC:GetType() ~= CT_TOPLEVELCONTROL do
            controlTLC = controlTLC:GetParent()
        end

        if WHITELIST[controlTLC:GetName()] then
            HIGHLIGHT_CONTROL:SetHidden(true)

            -- CONTROLNAME_CONTROL:SetHidden(true)
            _hideKeybind('update')

            controlToOpen = nil
            return
        end

        controlToOpen = controlTLC
        HIGHLIGHT_CONTROL:SetParent(controlTLC)  -- TODO: do I need this?
        HIGHLIGHT_CONTROL:SetAnchorFill(controlTLC)
        HIGHLIGHT_CONTROL:SetHidden(false)

        -- CONTROLNAME_CONTROL:SetText(control:GetName())
        -- CONTROLNAME_CONTROL:SetHidden(false)
        _setKeybind(controlTLC:GetName(), 'update')
    end)

    CreateScrollListDataType()
end


EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- TODO: update if control got update (hidden -> visible)
-- TODO: draw tree
