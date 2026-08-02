MSUtils = MSUtils or {}

function MSUtils.Trim(value)
    if type(value) ~= 'string' then return '' end
    return value:match('^%s*(.-)%s*$') or ''
end

function MSUtils.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

function MSUtils.RoundMoney(value)
    value = tonumber(value) or 0
    return math.floor(value * 100 + 0.5) / 100
end

function MSUtils.IsFiniteNumber(value)
    value = tonumber(value)
    return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
end

function MSUtils.ValidName(value)
    value = MSUtils.Trim(value)
    local limits = Config.Limits or {}
    local minimum = math.max(1, math.floor(tonumber(limits.NameMinLength) or 2))
    local maximum = math.max(minimum, math.floor(tonumber(limits.NameMaxLength) or 32))
    local length = #value
    if type(utf8) == 'table' and type(utf8.len) == 'function' then
        local ok, utf8Length = pcall(utf8.len, value)
        if ok and utf8Length then length = utf8Length end
    end
    if length < minimum or length > maximum then return false end
    if value:find('[%c%d]') then return false end
    -- Lua patterns are byte based. Printable UTF-8 bytes are accepted while
    -- punctuation that does not belong in a person name is rejected.
    return value:find("[^%a%s'%-\128-\255]") == nil
end

function MSUtils.SafeDecode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback or {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
    return fallback or {}
end

function MSUtils.SafeEncode(value)
    local ok, encoded = pcall(json.encode, type(value) == 'table' and value or {})
    return ok and encoded or '{}'
end

function MSUtils.Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        copy[MSUtils.Copy(key, seen)] = MSUtils.Copy(entry, seen)
    end
    return copy
end
