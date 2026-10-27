local party_overlay = {}

local imgui = require('imgui')
local map = require('src.map')
local tooltip = require('src.overlays.tooltip')
local utils = require('src.utils')
local party_positions = require('src.party_positions')

function party_overlay.draw(contextConfig, mapData, windowPosX, windowPosY, contentMinX, contentMinY, mapOffsetX, mapOffsetY, mapZoom, textureWidth, contextAlpha, contextLabels)
    contextConfig = contextConfig or boussole.config
    contextAlpha = contextAlpha or 1.0
    local showLabels
    if contextLabels ~= nil then
        showLabels = contextLabels
    else
        showLabels = contextConfig.showLabels[1]
    end
    showLabels = showLabels and (contextConfig.showPartyLabels == nil or contextConfig.showPartyLabels[1])
    if not mapData then return end

    if not contextConfig.showParty or not contextConfig.showParty[1] then return end

    -- Only show party on the map matching the player's current zone
    local playerZone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if (mapData.entry and mapData.entry.ZoneId ~= playerZone and not (mapData.entry._redirected and mapData.entry._originalZone == playerZone)) then return end

    local partyMgr = AshitaCore:GetMemoryManager():GetParty()
    if not partyMgr then return end
    local playerEntity = GetPlayerEntity()
    local playerPosition = playerEntity and playerEntity.Movement.LocalPosition or nil

    local drawList = imgui.GetWindowDrawList()
    local mousePosX, mousePosY = imgui.GetMousePos()

    local markerRadius = (contextConfig.iconSizeParty[1] or 20.0) / 2

    for i = 1, 5 do
        if partyMgr:GetMemberIsActive(i) == 1 then
            local serverId = partyMgr:GetMemberServerId(i)
            local entityIndex = partyMgr:GetMemberTargetIndex(i)
            local entity = (entityIndex and entityIndex > 0) and GetEntity(entityIndex) or nil
            if entity and entity.Render.Flags0 == 0 then entity = nil end

            local position = party_positions.get_marker_position(serverId, playerZone, entity, playerPosition)

            if position then
                    local memberX = position.x
                    local memberY = position.y
                    local memberZ = position.z

                    local mapX, mapY = map.world_to_map_coords(mapData.entry, memberX, memberY, memberZ)

                    if mapX then
                        local texX, texY
                        if mapData.entry._isCustomMap then
                            texX = (mapX - mapData.entry.OffsetX) * (textureWidth / mapData.entry._customData.referenceSize)
                            texY = (mapY - mapData.entry.OffsetY) * (textureWidth / mapData.entry._customData.referenceSize)
                        else
                            texX = (mapX - mapData.entry.OffsetX) * (textureWidth / 512.0)
                            texY = (mapY - mapData.entry.OffsetY) * (textureWidth / 512.0)
                        end

                        local screenX = windowPosX + contentMinX + mapOffsetX + texX * mapZoom
                        local screenY = windowPosY + contentMinY + mapOffsetY + texY * mapZoom

                        local partyColor = contextConfig.colorParty or { 0.349, 0.639, 1.0, 1.0 }
                        local markerColor = utils.mul_alpha(utils.rgb_to_abgr(partyColor), contextAlpha)
                        local outlineColor = utils.mul_alpha(utils.rgb_to_abgr({ 0.0, 0.0, 0.0, 1.0 }), contextAlpha)

                        -- Draw label above party member if showLabels is enabled
                        if showLabels then
                            local memberName = (entity and entity.Name) or partyMgr:GetMemberName(i) or ('Party ' .. i)
                            utils.draw_label(drawList, memberName, screenX, screenY, markerRadius, markerColor, contextAlpha)
                        end

                        local dx = mousePosX - screenX
                        local dy = mousePosY - screenY
                        local distance = math.sqrt(dx * dx + dy * dy)

                        if distance <= markerRadius + 5 then
                            local memberName = (entity and entity.Name) or partyMgr:GetMemberName(i)
                            if memberName and memberName ~= '' then
                                local color = utils.rgb_to_abgr(partyColor)
                                tooltip.add_line(string.format('%s (Party)', memberName), color)
                            end
                        end

                        if not utils.draw_configured_marker(drawList, contextConfig.markerIconParty and contextConfig.markerIconParty[1], screenX, screenY, markerRadius, markerColor, outlineColor, 1.5) then
                            utils.draw_circle_marker(drawList, screenX, screenY, markerRadius, markerColor, outlineColor, 1.5)
                        end
                    end
            end
        end
    end
end

return party_overlay
