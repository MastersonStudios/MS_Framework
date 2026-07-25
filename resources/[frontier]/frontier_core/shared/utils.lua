Frontier = Frontier or {}

function Frontier.Trim(value)
    if type(value) ~= 'string' then return value end
    return value:match('^%s*(.-)%s*$')
end

function Frontier.IsInteger(value)
    return type(value) == 'number' and value >= 0 and value % 1 == 0
end

function Frontier.ValidName(value)
    if type(value) ~= 'string' then return false end
    value = Frontier.Trim(value)
    return #value >= 2 and #value <= 32 and value:match("^[%aÀ-ÿ'%- ]+$") ~= nil
end
