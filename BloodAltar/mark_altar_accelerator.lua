local utils = require("utils")
local accelerator_list = utils.list_component("accelerator")
local result = {}
for _, machine in pairs(accelerator_list) do
    result[machine.address] = "altar_accelerator"
end
utils.write_to_file(result, "altar_accelerator_list.lua")
