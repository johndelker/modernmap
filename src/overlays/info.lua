local info_overlay = {}

local imgui = require('imgui')
local utils = require('src.utils')
local map = require('src.map')

-- Draw compact location and coordinate badges to the right of the map controls.
function info_overlay.draw(windowPosX, windowPosY, contentMinX, contentMinY, mapData)
    local zoneText = nil
    if boussole.config.showMapZoneInfo[1] then
        local zoneId = mapData and mapData.entry and mapData.entry.ZoneId or map.get_player_zone()
        local floorId = mapData and mapData.entry and mapData.entry.FloorId
        local resMgr = AshitaCore:GetResourceManager()
        local zoneName = resMgr and zoneId and resMgr:GetString('zones.names', zoneId) or nil
        local regionId = zoneId and utils.getRegionIDByZoneID(zoneId) or nil
        local regionName = regionId and utils.getRegionNameById(regionId) or nil

        if zoneName and zoneName ~= '' then
            zoneText = regionName and string.format('%s (%s)', zoneName, regionName) or zoneName

            if mapData and mapData.entry and mapData.entry._isCustomMap and
                mapData.entry._customData and mapData.entry._customData.subZoneName then
                zoneText = zoneText .. string.format(' (%s)', mapData.entry._customData.subZoneName)
            elseif floorId and floorId > 0 then
                zoneText = zoneText .. string.format(' (Floor %d)', floorId)
            end
        end
    end

    local coordinateText = nil
    if boussole.config.showMapCoordinates[1] then
        local gridX, gridY = map.get_player_grid_position()
        if gridX and gridY then
            coordinateText = string.format('(%s-%d)', gridX, gridY)
        end
    end

    if not zoneText and not coordinateText then return end

    local fontScale = boussole.config.infoPanelFontSize[1] / 13.0
    imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * fontScale)

    local zoneWidth, zoneHeight = 0, 0
    local coordinateWidth, coordinateHeight = 0, 0
    if zoneText then zoneWidth, zoneHeight = imgui.CalcTextSize(zoneText) end
    if coordinateText then coordinateWidth, coordinateHeight = imgui.CalcTextSize(coordinateText) end

    local rowHeight = 28
    local paddingX = 8
    local rowY = windowPosY + imgui.GetWindowHeight() - 8 - rowHeight
    local nextX = windowPosX + contentMinX + 8 + (4 * 28) + (3 * 4) + 8
    local drawList = imgui.GetWindowDrawList()
    local bgColor = utils.rgb_to_abgr(boussole.config.colorInfoPanelBg)
    local textColor = utils.rgb_to_abgr(boussole.config.colorInfoPanelText)

    if coordinateText then
        local boxWidth = coordinateWidth + paddingX * 2
        drawList:AddRectFilled({ nextX, rowY }, { nextX + boxWidth, rowY + rowHeight }, bgColor, 3.0)
        drawList:AddText({ nextX + paddingX, rowY + (rowHeight - coordinateHeight) / 2 }, textColor, coordinateText)
        nextX = nextX + boxWidth + 6
    end

    if zoneText then
        local boxWidth = zoneWidth + paddingX * 2
        drawList:AddRectFilled({ nextX, rowY }, { nextX + boxWidth, rowY + rowHeight }, bgColor, 3.0)
        drawList:AddText({ nextX + paddingX, rowY + (rowHeight - zoneHeight) / 2 }, textColor, zoneText)
    end

    imgui.PopFont()
end

return info_overlay
