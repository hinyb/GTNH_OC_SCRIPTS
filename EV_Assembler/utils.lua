local component = require("component")
local serialization = require("serialization")
local filesystem = require("filesystem")
local function table_is_empty(t)
    return next(t) == nil
end
local function table_contain(t, value)
    for _, v in pairs(t) do
        if value == v then
            return true
        end
    end
    return false
end
local function table_find_value(t, value)
    for k, v in pairs(t) do
        if v == value then
            return k
        end
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
local function create_digest(inv)
    local result = {}
    for _, item in pairs(inv) do
        if item.label and item.size then
            table.insert(result, string.format("[%s] x%d", item.label, item.size))
        end
    end
    return table.concat(result, " + ")
end
local function input_filter(prompt, filter)
    print(prompt)
    local validator
    if type(filter) == 'function' then
        validator = filter
    elseif type(filter) == 'table' then
        validator = function(input)
            return table_contain(filter, input)
        end
    else
        error("unsupported filter")
    end

    local input = io.read()
    while not validator(input) do
        print("invalid input, please retry")
        print(prompt)
        input = io.read()
    end
    return input
end
return {
    table_is_empty = table_is_empty,
    table_contain = table_contain,
    table_find_value = table_find_value,
    write_to_file = write_to_file,
    read_from_file = read_from_file,
    create_auto_cache_table = create_auto_cache_table,
    create_digest = create_digest,
    input_filter = input_filter
}
