local component = require("component")
local sides = require("sides")
local utils = require("utils")
local function get_component_array(component_list)
    local result = {}
    for addr, _ in pairs(component_list) do
        table.insert(result, component.proxy(addr))
    end
    return result
end
local function select_component(component_array, name)
    if #component_array == 0 then
        error(string.format("Can't find any %s component", name))
    end

    print(string.format("--- %s list ---", name))
    for index, _component in ipairs(component_array) do
        print(string.format("   [%d] Address: %s", index, _component.address))
    end

    local prompt = string.format("Choose %s Index (1-%d)", name, #component_array)
    local select_index = tonumber(utils.input_filter(prompt, function(input)
        input = tonumber(input)
        return input and input > 0 and input <= #component_array
    end))

    return component_array[select_index], select_index
end

local gt_machine_array = get_component_array(component.list("gt_machine"))
local transposer_array = get_component_array(component.list("transposer"))
local configs = {}
if #gt_machine_array == 0 then
    print("Can't find any gt machine")
    return
end
if #transposer_array == 0 then
    print("Can't find any transposer")
    return
end
for _, transposer in pairs(transposer_array) do
    print(string.format("Transposer (Addr: %s)", transposer.address))
    local continue_flag = utils.input_filter("0=Skip/1=Config", { "0", "1" })
    if continue_flag == "1" then
        local result = { ["transposer_address"] = transposer.address }
        do
            local side = utils.input_filter("Side of buffer relative to transposer: ", function(input)
                return sides[input] ~= nil
            end)
            result["buffer_side"] = side
        end
        do
            local gt_machines = {}
            while true do
                local gt_machine = {}
                local selected_gt_machine, index = select_component(gt_machine_array, "gt_machine")
                table.remove(gt_machine_array, index)
                gt_machine["address"] = selected_gt_machine.address

                local side = utils.input_filter("Side relative to transposer: ", function(input)
                    return sides[input] ~= nil
                end)
                gt_machine["side_relative_transposer"] = side
                table.insert(gt_machines, gt_machine)
                local exit_flag = utils.input_filter("0=Exit/1=Continue", { "0", "1" })
                if exit_flag == "0" then
                    goto exit
                end
            end
            ::exit::
            result["gt_machines"] = gt_machines
        end
        table.insert(configs, result)
    end
end
utils.write_to_file(configs, "configs.lua")
