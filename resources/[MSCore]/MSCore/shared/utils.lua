MSCore = MSCore or {}

function MSCore.Trim(value)
    if type(value) ~= 'string' then return value end
    return value:match('^%s*(.-)%s*$')
end

function MSCore.IsInteger(value)
    return type(value) == 'number' and value >= 0 and value % 1 == 0
end

function MSCore.ValidName(value)
    if type(value) ~= 'string' then return false end
    value = MSCore.Trim(value)
    return #value >= 2 and #value <= 32 and value:match("^[%aÀ-ÿ'%- ]+$") ~= nil
end
