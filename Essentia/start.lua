local component = require("component")
local sides = require("sides")
local thread = require("thread")
local event = require("event")
local utils = require("utils")

local essentia_amount = 6400

local redstone_sides =
{
    tablet = sides.east,
    breaker = sides.north,
    bee = sides.west
}
local transposer_sides =
{
    cache = sides.down,
    tablet = sides.up
}

local me_interface = component.me_interface
local transposer = component.transposer
local redstone = component.redstone

local essentia_map = {}
local threads = {}
table.insert(threads, thread.create(function()
    while true do
        essentia_map = {}
        local essentia_list = me_interface.getEssentiaInNetwork()
        for _, essentia in pairs(essentia_list) do
            essentia_map[essentia.name] = essentia.amount
        end
        os.sleep(5)
    end
end))
local name_map = {
    aequalitas = "custom1",
    vesania = "custom2",
    primordium = "custom3",
    astrum = "custom4",
    gloria = "custom5",
}
local function get_essentia_amount_by_name(name)
    name = string.format("gaseous%sessentia", name_map[name] or name)
    return essentia_map[name] or 0
end
table.insert(threads, thread.create(function()
    while true do
        os.sleep(5)
        local inventory = transposer.getAllStacks(transposer_sides.cache)
        local slot = 0
        while true do
            local item = inventory()
            slot = slot + 1
            if utils.table_is_empty(item) then
                break
            end
            local aspect_name = item.aspects[1].name:lower()
            if get_essentia_amount_by_name(aspect_name) < essentia_amount then
                print("try to increase", aspect_name)
                if redstone_sides.bee then
                    redstone.setOutput(redstone_sides.bee, 15)
                end
                transposer.transferItem(transposer_sides.cache, transposer_sides.tablet, 1, slot)
                redstone.setOutput(redstone_sides.tablet, 15)
                os.sleep(1)
                redstone.setOutput(redstone_sides.tablet, 0)
                transposer.transferItem(transposer_sides.tablet, transposer_sides.cache)
                while true do
                    os.sleep(5)
                    local amount = get_essentia_amount_by_name(aspect_name) or 0
                    print(string.format("%s Amount: %d", aspect_name, amount))
                    if amount >= essentia_amount then
                        break
                    end
                end
                redstone.setOutput(redstone_sides.breaker, 15)
                os.sleep(1)
                redstone.setOutput(redstone_sides.breaker, 0)
                if redstone_sides.bee then
                    redstone.setOutput(redstone_sides.bee, 0)
                end
                print("Finish to increase", aspect_name)
            end
        end
    end
end))
table.insert(threads, thread.create(function()
    event.pull(nil, "interrupted")
    if redstone_sides.bee then
        redstone.setOutput(redstone_sides.bee, 0)
    end
end))
thread.waitForAny(threads)
os.exit(0)
