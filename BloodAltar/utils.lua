local serialization = require("serialization")
local component = require("component")
local sides = require("sides")

local function table_is_empty(t)
    return next(t) == nil
end
local function table_find_value(t, value)
    for k, v in pairs(t) do
        if v == value then
            return k, v
        end
    end
end
local function table_contain(t, value)
    local k = table_find_value(t, value)
    return k ~= nil
end
local function table_find_if(t, predicate)
    for k, v in pairs(t) do
        if predicate(v) then
            return k, v
        end
    end
end
local function create_validator(filter)
    if type(filter) == 'function' then
        return filter
    elseif type(filter) == 'table' then
        return function(v, k)
            return table_contain(filter, v)
        end
    else
        error("unsupported filter", 2)
    end
end
local function table_filter(t, filter)
    local validator = create_validator(filter)
    local result = {}
    for k, v in pairs(t) do
        if validator(v, k) then
            table.insert(result, v)
        end
    end
    return result
end
local function table_each(t, fn)
    for _, v in pairs(t) do
        fn(v)
    end
end
local function write_to_file(value, path)
    local ori_mt = nil
    if type(value) == 'table' then
        ori_mt = getmetatable(value)
        setmetatable(value, nil)
    end
    local ok, content = pcall(serialization.serialize, value)
    if ori_mt then
        setmetatable(value, ori_mt)
    end
    if not ok then
        print(content)
    else
        local handle = io.open(path, "w")
        handle:write("return " .. content)
        handle:close()
    end
end
local function read_from_file(path)
    local ok, context = pcall(dofile, path)
    if ok then
        return context
    else
        print(context)
        return nil
    end
end
local function create_auto_cache_table(path)
    local table = read_from_file(path) or {}
    local dirty = false
    local mt = {}
    mt.__newindex = function(t, key, value)
        rawset(t, key, value)
        dirty = true
    end
    mt.__index = mt
    setmetatable(table, mt)
    mt.save_if_dirty = function()
        if dirty then
            write_to_file(table, path)
            dirty = false
        end
    end
    return table
end
local function input_filter(prompt, filter)
    print(prompt)
    local validator = create_validator(filter)
    local input = io.read()
    while not validator(input) do
        print("invalid input, please retry")
        print(prompt)
        input = io.read()
    end
    return input
end
local function list_component(filter)
    local result = {}
    for address, name in pairs(component.list()) do
        if name == filter then
            table.insert(result, setmetatable({}, { __index = component.proxy(address) }))
        elseif name == "gt_machine" then
            local machine = component.proxy(address)
            local name = machine.getName()
            if name:find(filter) then
                local tier = tonumber(name:match("%.tier%.(%d+)"))
                table.insert(result, setmetatable({ tier = tier }, { __index = component.proxy(address) }))
            end
        end
    end
    return result
end
local function require_component(filter)
    local component = list_component(filter)[1]
    if not component then
        error(string.format("Error: Can't find %s", filter))
    end
    return component
end
local function get_world_time()
    return os.time() * 1000 / 60 / 60 - 6000
end
local function synchronize_to_tick_internal(tick_interval, offset)
    local sleep_duration = tick_interval - get_world_time() % tick_interval + offset
    os.sleep(sleep_duration * 0.05 - 0.025)
end
local function synchronize_to_tick(tick_interval, offset)
    offset = offset or 0
    for i = -2, 0 do
        synchronize_to_tick_internal(tick_interval, offset + i)
    end
end
local function proxy_component_for_yield(t)
    local mt = getmetatable(t)
    local origin_proxy = mt.__index
    mt.__index = function(t, k)
        os.sleep(0)
        return origin_proxy[k]
    end
    setmetatable(t, mt)
end
local function proxy_side(mt)
    mt.__index = function (t, k)
        local side = rawget(mt, k)
        if type(side) == "number" then
            rawset(t, k, side)
            return side
        elseif type(side) == "string" then
            side = sides[side]
            rawset(t, k, side)
            return side
        end
    end
    return setmetatable({}, mt)
end
return {
    table_is_empty = table_is_empty,
    table_contain = table_contain,
    table_find_value = table_find_value,
    table_find_if = table_find_if,
    table_filter = table_filter,
    table_each = table_each,
    write_to_file = write_to_file,
    read_from_file = read_from_file,
    create_auto_cache_table = create_auto_cache_table,
    input_filter = input_filter,
    list_component = list_component,
    require_component = require_component,
    get_world_time = get_world_time,
    synchronize_to_tick = synchronize_to_tick,
    proxy_component_for_yield = proxy_component_for_yield,
    proxy_side = proxy_side
}
