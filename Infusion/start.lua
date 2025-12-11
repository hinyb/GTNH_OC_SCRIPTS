local component = require("component")
local sides = require("sides")
local computer = require("computer")
local redstone_sides = {
    placer = sides.up,
    exporter = sides.east
}
local max_time = 12

local redstone = component.redstone
local database = component.database

local function wrap_side(target_table, target_side, extra_table)
    local table = { side = target_side }
    if extra_table then
        for k, v in pairs(extra_table) do
            table[k] = v
        end
    end
    return setmetatable(table, { __index = target_table })
end

local redstone_extra_table = {
    trigger_pulse = function(wrapped_redstone)
        wrapped_redstone.setOutput(wrapped_redstone.side, 15)
        os.sleep(0.05)
        wrapped_redstone.setOutput(wrapped_redstone.side, 0)
    end
}

local pedestal = {}
local placer = { redstone = wrap_side(redstone, redstone_sides.placer, redstone_extra_table) }
local exporter = { redstone = wrap_side(redstone, redstone_sides.exporter, redstone_extra_table) }

for address, _ in pairs(component.list("transposer")) do
    local transposer = component.proxy(address)
    for i = 0, 5 do
        local name = transposer.getInventoryName(i)
        if name == "tile.blockStoneDevice" then
            pedestal.transposer = wrap_side(transposer, i)
        end
        -- 感觉这部分有点糟糕
        if name == "tile.projectred.expansion.machine2" then
            local transposer = wrap_side(transposer, i)
            for index = 1, 9 do
                local item = transposer.getStackInSlot(transposer.side, index)
                if item then
                    if item.name == "Thaumcraft:WandCasting" then
                        print(string.format("Find Wand at slot %d", index))
                        transposer.wand_slot = index
                    elseif item.name == "ThaumicTinkerer:shareBook" then
                        print(string.format("Find Share Book at slot %d", index))
                        transposer.share_book_slot = index
                    end
                else
                    transposer.tmp_slot = index
                end
            end
            if transposer.wand_slot and transposer.share_book_slot then
                local function swap_wand()
                    transposer.transferItem(transposer.side, transposer.side, 1, transposer.wand_slot,
                        transposer.tmp_slot)
                    transposer.transferItem(transposer.side, transposer.side, 1, transposer.share_book_slot,
                        transposer.wand_slot)
                    transposer.transferItem(transposer.side, transposer.side, 1, transposer.tmp_slot,
                        transposer.share_book_slot)
                    local tmp = transposer.wand_slot
                    transposer.wand_slot = transposer.share_book_slot
                    transposer.share_book_slot = tmp
                end
                transposer.ensure_wand_first = function()
                    if transposer.wand_slot < transposer.share_book_slot then
                        swap_wand()
                    end
                end
                transposer.ensure_share_book_first = function()
                    if transposer.wand_slot > transposer.share_book_slot then
                        swap_wand()
                    end
                end
                placer.transposer = transposer
            end
        end
    end
end

if not pedestal.transposer then
    print("transposer need next to pedestal")
    return
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
    if flag == true and placer.transposer then
        placer.transposer.ensure_share_book_first()
        placer.redstone:trigger_pulse()
        placer.transposer.ensure_wand_first()
    end
    for _, accelerator in pairs(accelerator_list) do
        accelerator.setWorkAllowed(flag)
    end
    accelerator_flag = flag
end
set_accelerator(false)

while true do
    if pedestal.transposer.getStackInSlot(pedestal.transposer.side, 1) then
        while true do
            local ok = pedestal.transposer.store(pedestal.transposer.side, 1, database.address, 1)
            if not ok then
                set_accelerator(false)
                break
            end
            print("Start Infusion")
            set_accelerator(true)
            local start_time = computer.uptime()
            placer.redstone:trigger_pulse()
            while pedestal.transposer.compareStackToDatabase(pedestal.transposer.side, 1, database.address, 1, true) do
                if computer.uptime() - start_time > max_time and max_time ~= -1 then
                    set_accelerator(false)
                    exporter.redstone:trigger_pulse()
                    print(string.format("Infusion Timeout: Failed to infuse %s", database.get(1).label))
                    os.exit(-1)
                    break
                end
            end
            exporter.redstone:trigger_pulse()
            print("Finish Infusion")
        end
    end
end
