MSRestrictedAreasGeometry = {}

local Geometry = MSRestrictedAreasGeometry
local Config = MSRestrictedAreasConfig

local function number(value)
    return tonumber(value)
end

local function validPoint(point)
    return point and number(point.x) and number(point.y)
end

local function withinHeight(coords, zone)
    local z = number(coords and coords.z)
    if not z then return false end
    local minimum = number(zone.MinZ)
    local maximum = number(zone.MaxZ)
    if minimum and z < minimum then return false end
    if maximum and z > maximum then return false end
    return true
end

local function pointOnSegment(x, y, first, second)
    local ax, ay = number(first.x), number(first.y)
    local bx, by = number(second.x), number(second.y)
    if not ax or not ay or not bx or not by then return false end

    local cross = (x - ax) * (by - ay) - (y - ay) * (bx - ax)
    if math.abs(cross) > 0.01 then return false end
    local dot = (x - ax) * (bx - ax) + (y - ay) * (by - ay)
    if dot < 0.0 then return false end
    local lengthSquared = (bx - ax) ^ 2 + (by - ay) ^ 2
    return dot <= lengthSquared
end

local function insidePolygon(coords, zone)
    local points = zone.Points
    if type(points) ~= 'table' or #points < 3 then return false end

    local x, y = number(coords.x), number(coords.y)
    if not x or not y then return false end
    local inside = false
    local previous = points[#points]

    for _, current in ipairs(points) do
        if not validPoint(current) or not validPoint(previous) then return false end
        if pointOnSegment(x, y, previous, current) then return true end

        local currentY, previousY = number(current.y), number(previous.y)
        local crosses = (currentY > y) ~= (previousY > y)
        if crosses then
            local boundaryX = (number(previous.x) - number(current.x))
                * (y - currentY)
                / (previousY - currentY)
                + number(current.x)
            if x < boundaryX then inside = not inside end
        end
        previous = current
    end
    return inside
end

local function insideCircle(coords, zone)
    local center = zone.Center
    local radius = math.max(0.1, number(zone.Radius) or 0.0)
    if not validPoint(center) then return false end

    local dx = number(coords.x) - number(center.x)
    local dy = number(coords.y) - number(center.y)
    return dx * dx + dy * dy <= radius * radius
end

function Geometry.IsInside(coords, zone)
    if type(zone) ~= 'table' or zone.Enabled ~= true or not withinHeight(coords, zone) then
        return false
    end

    local shape = tostring(zone.Shape or 'circle'):lower()
    if shape == 'polygon' then return insidePolygon(coords, zone) end
    if shape == 'circle' then return insideCircle(coords, zone) end
    return false
end

function Geometry.FindZone(coords)
    local selected
    local selectedPriority = -math.huge
    for _, zone in ipairs(Config.Zones or {}) do
        local priority = number(zone.Priority) or 0
        if priority > selectedPriority and Geometry.IsInside(coords, zone) then
            selected = zone
            selectedPriority = priority
        end
    end
    return selected
end

function Geometry.GetZone(zoneId)
    if type(zoneId) ~= 'string' then return nil end
    for _, zone in ipairs(Config.Zones or {}) do
        if zone.Id == zoneId then return zone end
    end
end

local function explicitExit(zone)
    local exit = zone.Exit
    if not exit or not number(exit.x) or not number(exit.y) or not number(exit.z) then return nil end
    return {
        x = number(exit.x),
        y = number(exit.y),
        z = number(exit.z),
        w = number(exit.w) or number(exit.heading)
    }
end

local function circleExit(coords, zone, buffer)
    local center = zone.Center
    if not validPoint(center) then return nil end

    local dx = number(coords.x) - number(center.x)
    local dy = number(coords.y) - number(center.y)
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.001 then dx, dy, length = 1.0, 0.0, 1.0 end
    local radius = math.max(0.1, number(zone.Radius) or 0.1) + buffer
    return {
        x = number(center.x) + dx / length * radius,
        y = number(center.y) + dy / length * radius,
        z = number(coords.z),
        w = number(coords.w)
    }
end

local function polygonOrientation(points)
    local area = 0.0
    local previous = points[#points]
    for _, current in ipairs(points) do
        area = area + number(previous.x) * number(current.y)
            - number(current.x) * number(previous.y)
        previous = current
    end
    return area >= 0.0 and 1.0 or -1.0
end

local function polygonExit(coords, zone, buffer)
    local points = zone.Points
    if type(points) ~= 'table' or #points < 3 then return nil end

    local x, y = number(coords.x), number(coords.y)
    local nearest
    local nearestDistance = math.huge
    local previous = points[#points]
    local orientation = polygonOrientation(points)

    for _, current in ipairs(points) do
        if not validPoint(current) or not validPoint(previous) then return nil end
        local ax, ay = number(previous.x), number(previous.y)
        local bx, by = number(current.x), number(current.y)
        local edgeX, edgeY = bx - ax, by - ay
        local lengthSquared = edgeX * edgeX + edgeY * edgeY
        if lengthSquared > 0.0 then
            local amount = ((x - ax) * edgeX + (y - ay) * edgeY) / lengthSquared
            amount = math.max(0.0, math.min(1.0, amount))
            local pointX, pointY = ax + edgeX * amount, ay + edgeY * amount
            local dx, dy = x - pointX, y - pointY
            local distance = dx * dx + dy * dy
            if distance < nearestDistance then
                local edgeLength = math.sqrt(lengthSquared)
                local normalX = orientation > 0.0 and edgeY / edgeLength or -edgeY / edgeLength
                local normalY = orientation > 0.0 and -edgeX / edgeLength or edgeX / edgeLength
                nearestDistance = distance
                nearest = {
                    x = pointX + normalX * buffer,
                    y = pointY + normalY * buffer,
                    z = number(coords.z),
                    w = number(coords.w)
                }
            end
        end
        previous = current
    end
    return nearest
end

function Geometry.ExitPoint(coords, zone, fallback)
    if type(zone) ~= 'table' then return fallback end
    local configured = explicitExit(zone)
    if configured then return configured end

    local buffer = math.max(1.0, number(Config.ExitBuffer) or 6.0)
    local shape = tostring(zone.Shape or 'circle'):lower()
    if shape == 'circle' then return circleExit(coords, zone, buffer) or fallback end
    if shape == 'polygon' then return polygonExit(coords, zone, buffer) or fallback end
    return fallback
end
