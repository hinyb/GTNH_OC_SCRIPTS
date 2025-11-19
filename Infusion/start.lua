local component = require("component")
local sides = require("sides")
local computer = require("computer")
local redstone_sides = {
    placer = sides.up,
    exporter = sides.north
}
local max_time = 12

local transposer = component.transposer
local redstone = component.redstone
local database = component.database

local pedestal_side = -1
for i = 0, 5 do
    local name = transposer.getInventoryName(i)
    if name == "tile.blockStoneDevice" then
        pedestal_side = i
    end
end
if pedestal_side == -1 then
    print("transposer need next to pedestal")
end

local accelerator_list = {}
for address in pairs(component.list("gt_machine")) do
    table.insert(accelerator_list, component.proxy(address))
end

local accelerator_flag = true
local function set_accelerator(flag)
    if accelerator_flag == flag then
        return
    end
    for _, accelerator in pairs(accelerator_list) do
        accelerator.setWorkAllowed(flag)
    end
    accelerator_flag = flag
end
set_accelerator(false)

local function set_redstone(component, side)
    component.setOutput(side, 15)
    os.sleep(0.05)
    component.setOutput(side, 0)
end
while true do
    local ok = transposer.store(pedestal_side, 1, database.address, 1)
    if ok then
        print("Start Infusion")
        set_accelerator(true)
        local start_time = computer.uptime()
        set_redstone(redstone, redstone_sides.placer)
        while transposer.compareStackToDatabase(pedestal_side, 1, database.address, 1, true) do
            if computer.uptime() - start_time > max_time and max_time ~= -1 then
                set_accelerator(false)
                set_redstone(redstone, redstone_sides.exporter)
                print(string.format("Infusion Timeout: Failed to infuse %s", database.get(1).label))
                os.exit(-1)
                break
            end
        end
        set_redstone(redstone, redstone_sides.exporter)
        print("Finish Infusion")
    else
        set_accelerator(false)
    end
end
