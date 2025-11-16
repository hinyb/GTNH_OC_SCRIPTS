local utils = require("utils")
local serialization = require("serialization")
local component = require("component")
local sides = require("sides")
local thread = require("thread")
local event = require("event")
local cache = utils.create_auto_cache_table("cache.lua")
local configs = utils.read_from_file("configs.lua")
if configs == nil then
    error("Need a configs.lua to work")
end
local id = 0
local input_queue = {}
local function get_circuit(inv)
    local key = utils.create_digest(inv)
    if key == "" then
        return 0
    end
    local circuit = cache[key]
    if circuit == nil then
        local _id = tostring(id)
        id = id + 1
        if not utils.table_contain(input_queue, key) then
            table.insert(input_queue, { key = key, id = _id })
        end
        event.push("input_request")
        print("waiting for input")
        local _, result = event.pull(nil, _id)
        print("get input", result)
        cache[key] = result
        cache.save_if_dirty()
        return result
    end
    return circuit
end
local threads = {}
table.insert(threads, thread.create(function()
    while true do
        event.pull(nil, "input_request")
        local t = table.remove(input_queue, 1)
        if t then
            local result = tonumber(utils.input_filter(
                string.format("please input target circuit number %s(1-24 or -1)", t.key), function(input)
                    input = tonumber(input)
                    return input == -1 or (input >= 1 and input <= 24)
                end))
            event.push(t.id, result)
        end
        if #input_queue > 0 then
            event.push("input_request")
        end
    end
end))
local function has_item(slot)
    return not utils.table_is_empty(slot) and slot.name ~= "gregtech:gt.integrated_circuit"
end
local function get_free_machine(transposer, gt_machines)
    while true do
        for _, gt_machine in ipairs(gt_machines) do
            if not gt_machine.isMachineActive() then
                local inv = transposer.getAllStacks(sides[gt_machine.side_relative_transposer]):getAll()
                for _, slot in pairs(inv) do
                    if has_item(slot) then
                        goto continue
                    end
                end
                if true then
                    return gt_machine
                end
            end
            ::continue::
        end
        os.sleep(1)
    end
end
local function transfer_all(transposer, source_side, target_side, inv)
    if not inv then
        inv = transposer.getAllStacks(source_side):getAll()
    end
    local fluid_amount = transposer.getTankLevel(source_side)
    if fluid_amount ~= 0 then
        local detail_table = transposer.getFluidInTank(source_side)
        local flag = false
        while true do
            local ok, amount = transposer.transferFluid(source_side, target_side, fluid_amount)
            if ok and amount == fluid_amount then
                local fluid_list = {}
                for _, detail in pairs(detail_table) do
                    table.insert(fluid_list, detail.label)
                end
                print(string.format("transfer fluid %s to %s side", table.concat(fluid_list, " | "), utils.table_find_value(sides, target_side)))
                goto continue
            end
            fluid_amount = fluid_amount - amount
            if not flag then
                print("Failed to transfer fluid. Retrying... ", transposer.getTankLevel(target_side))
                flag = true
            end
        end
    end
    ::continue::
    for _, slot in pairs(inv) do
        if has_item(slot) then
            transposer.transferItem(source_side, target_side)
            print(string.format("transfer %s to %s side", slot.label, utils.table_find_value(sides, target_side)))
        end
    end
end
for _, config in pairs(configs) do
    table.insert(threads, thread.create(function()
        local transposer = component.proxy(config.transposer_address)
        local gt_machines = {}
        for _, t in pairs(config.gt_machines) do
            local gt_machine = { side_relative_transposer = t.side_relative_transposer }
            table.insert(gt_machines,
                setmetatable(gt_machine, { __index = component.proxy(t.address) }))
        end
        while true do
            os.sleep(0.25)
            local inv = transposer.getAllStacks(sides[config.buffer_side]):getAll()
            local circuit = get_circuit(inv)
            if circuit ~= 0 then
                local gt_machine = get_free_machine(transposer, gt_machines)
                gt_machine.setCircuitConfiguration(-1)
                gt_machine.setWorkAllowed(false)
                transfer_all(transposer, sides[config.buffer_side], sides[gt_machine.side_relative_transposer], inv)
                gt_machine.setCircuitConfiguration(circuit)
                gt_machine.setWorkAllowed(true)
            end
        end
    end))
end
table.insert(threads, thread.create(function()
    event.pull(nil, "interrupted")
end))
thread.waitForAny(threads)
os.exit(0)
