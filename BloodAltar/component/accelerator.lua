local utils = require("utils")

local module = {}
module.init = function()
    local sacrifice_accelerator_list = {}
    local altar_accelerator_list = {}

    local accelerator_list = utils.list_component("accelerator")
    utils.table_each(accelerator_list, function(accelerator)
        accelerator.speed = 2 ^ accelerator.tier
    end)
    local altar_list = utils.read_from_file("altar_accelerator_list.lua")
    if not altar_list then
        print("WARN: Altar accelerator list is empty.")
        altar_list = {}
    end
    for _, machine in pairs(accelerator_list) do
        if altar_list[machine.address] then
            table.insert(altar_accelerator_list, machine)
            print("Find Altar Accelerator Address: ", machine.address)
        else
            table.insert(sacrifice_accelerator_list, machine)
            print("Find Sacrifice Accelerator Address: ", machine.address)
        end
    end
    sacrifice_accelerator_list.speed = sacrifice_accelerator_list[1] and sacrifice_accelerator_list[1].speed or 1
    altar_accelerator_list.speed = altar_accelerator_list[1] and altar_accelerator_list[1].speed or 1
    return sacrifice_accelerator_list, altar_accelerator_list
end

return module
