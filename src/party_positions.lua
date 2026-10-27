local party_positions = {}

local positions = {}
local last_request_time = nil
local last_request_interval = 1
local MAX_COORDINATE = 100000

local function valid_coordinate(value)
    return value and value == value and value ~= math.huge and value ~= -math.huge and
        math.abs(value) <= MAX_COORDINATE
end

local function distance_between(a, b)
    if not a or not b then return nil end
    if not valid_coordinate(a.x) or not valid_coordinate(a.y) or not valid_coordinate(a.z) or
        not valid_coordinate(b.X) or not valid_coordinate(b.Y) or not valid_coordinate(b.Z) then
        return nil
    end
    local dx = a.x - b.X
    local dy = a.y - b.Y
    local dz = a.z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function get_member_name(party, serverId, index)
    if index then
        local name = party:GetMemberName(index)
        if name and name ~= '' then return name end
    end
    for i = 0, 17 do
        if party:GetMemberServerId(i) == serverId then
            local name = party:GetMemberName(i)
            if name and name ~= '' then return name end
            break
        end
    end
    return string.format('server ID %X', serverId)
end

local function get_packet_position(serverId, zoneId, now)
    local position = positions[serverId]
    if not position or position.zone ~= zoneId then return nil end

    local elapsed = now - position.updatedAt
    if elapsed > last_request_interval + 3 then return nil end

    return {
        -- Prediction disabled; use the most recently received packet coordinates.
        x = position.x,
        y = position.y,
        z = position.z,
        updatedAt = position.updatedAt,
    }
end

function party_positions.clear()
    positions = {}
    last_request_time = nil
    last_request_interval = 1
end

function party_positions.update_requests(zoneId, fullMapOpen, minimapRadius)
    if not zoneId or zoneId == 0 or (not fullMapOpen and not minimapRadius) then return end

    local memory = AshitaCore:GetMemoryManager()
    local party = memory and memory:GetParty()
    local player = GetPlayerEntity()
    if not party or not player then return end

    local playerPosition = player.Movement.LocalPosition
    local now = os.clock()
    local outOfRangeMembers = {}

    for i = 1, 17 do
        if party:GetMemberIsActive(i) == 1 and party:GetMemberZone(i) == zoneId then
            local serverId = party:GetMemberServerId(i)
            local entityIndex = party:GetMemberTargetIndex(i)
            local entity = (entityIndex and entityIndex > 0) and GetEntity(entityIndex) or nil
            if entity and entity.Render.Flags0 == 0 then entity = nil end

            local entityPosition
            if entity then
                local p = entity.Movement.LastPosition
                entityPosition = { x = p.X, y = p.Y, z = p.Z }
            end

            local packetPosition = get_packet_position(serverId, zoneId, now)
            local currentPosition = entityPosition
            if entityPosition and distance_between(entityPosition, playerPosition) <= 50 then
                currentPosition = entityPosition
            elseif packetPosition then
                currentPosition = packetPosition
            end

            local distance = distance_between(currentPosition, playerPosition)
            if not distance or distance > 50 then
                outOfRangeMembers[#outOfRangeMembers + 1] = {
                    id = serverId,
                    name = get_member_name(party, serverId, i),
                    distance = distance,
                }
            end
        end
    end

    if #outOfRangeMembers == 0 then return end

    local interval
    if fullMapOpen then
        interval = 1
    else
        local nearestDistance
        for _, member in ipairs(outOfRangeMembers) do
            if member.distance and (not nearestDistance or member.distance < nearestDistance) then
                nearestDistance = member.distance
            end
        end

        if nearestDistance and minimapRadius and nearestDistance <= minimapRadius then
            interval = 1
        elseif nearestDistance and minimapRadius and nearestDistance <= minimapRadius * 2 then
            interval = 5
        else
            interval = 15
        end
    end

    local elapsedSinceRequest = last_request_time and (now - last_request_time) or nil
    if elapsedSinceRequest and elapsedSinceRequest < interval then return end

    AshitaCore:GetPacketManager():AddOutgoingPacket(0x0D2, {
        0, 0, 0, 0,
        bit.band(zoneId, 0xFF), bit.band(bit.rshift(zoneId, 8), 0xFF), 0, 0,
    })
    last_request_time = now
    last_request_interval = interval

    -- local memberDetails = {}
    -- for _, member in ipairs(outOfRangeMembers) do
    --     local distanceText = member.distance and string.format('%.1f yalms', member.distance) or 'unknown distance (>50 yalms)'
    --     memberDetails[#memberDetails + 1] = string.format('%s: %s', member.name, distanceText)
    -- end
    -- print(string.format('Boussole party marker request sent (%s since previous request): %s',
    --     elapsedSinceRequest and string.format('%.1f seconds', elapsedSinceRequest) or 'first request',
    --     table.concat(memberDetails, ', ')))
end

function party_positions.handle_packet(e)
    if not e or e.id ~= 0x00A0 then return end

    local ok, serverId, zoneId, x, z, y = pcall(function ()
        local parsedServerId = struct.unpack('L', e.data, 0x04 + 1)
        local parsedZoneId = struct.unpack('H', e.data, 0x08 + 1)
        -- 0x0A-0x0B is an unknown 16-bit field; coordinates begin at 0x0C.
        local parsedX = struct.unpack('f', e.data, 0x0C + 1)
        local parsedZ = struct.unpack('f', e.data, 0x10 + 1)
        local parsedY = struct.unpack('f', e.data, 0x14 + 1)
        return parsedServerId, parsedZoneId, parsedX, parsedZ, parsedY
    end)
    if not ok or not serverId or serverId == 0 or not zoneId or zoneId == 0 or
        not valid_coordinate(x) or not valid_coordinate(y) or not valid_coordinate(z) then
        return
    end

    local now = os.clock()
    positions[serverId] = {
        zone = zoneId,
        x = x,
        y = y,
        z = z,
        updatedAt = now,
    }
end

function party_positions.get_marker_position(serverId, zoneId, entity, playerPosition)
    local packetPosition = get_packet_position(serverId, zoneId, os.clock())
    local entityPosition

    if entity then
        local p = entity.Movement.LastPosition
        entityPosition = { x = p.X, y = p.Y, z = p.Z }
    end

    if entityPosition then
        local entityDistance = distance_between(entityPosition, playerPosition)
        if entityDistance and entityDistance <= 50 then
            return entityPosition
        end
    end

    return packetPosition
end

return party_positions
