
local Lr = {}
local meta = {}

meta.__index = function(table, key)
    
    key = string.sub(key, 1, 1):upper() .. string.sub(key, 2)
    Lr[key] = import('Lr' .. key)
    return Lr[key]

end

setmetatable(Lr, meta)

return Lr
