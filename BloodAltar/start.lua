-- 感觉写的很糟糕，但是没想好怎么优化
local thread = require("thread")
local utils = require("utils")
local event = require("event")
local config = require("config")
event.onError = function(msg)
    print("ERROR: ", msg)
end

local input_slot = 1
local suffering_cost = 200

local altar = require("component/altar").init(config.altar)
local sacrifice_accelerator_list, altar_accelerator_list = require("component/accelerator").init()
local sacrifice_amount_per_operation = 100 * 10 * (1 + altar.sacrifice_efficiency_multiplier)
local sacrifice_amount_per_cycle = math.min(altar.capacity, sacrifice_amount_per_operation *
    (1 + sacrifice_accelerator_list.speed * #sacrifice_accelerator_list))
local calculate = require("calculate").init(config.max_craft_time_when_back, altar_accelerator_list.speed,
    #altar_accelerator_list, sacrifice_amount_per_cycle, altar)
local transposer = require("component/transposer").init()
if transposer.getInventoryName(config.IO.input):find("Drawers") then
    input_slot = 2
end

local function set_all_work_allowed(table, allowed)
    local n = #table
    for i = 1, n do
        table[i].setWorkAllowed(allowed)
    end
end

local orb_store_side = config.IO.orb
local orb = {}
orb.update_orb = function()
    local item = transposer.getStackInSlot(orb_store_side, 1)
    orb.max_network_essence = item.maxNetworkEssence
    orb.network_essence = item.networkEssence
end
orb.wait_min_blood = function(max_missing)
    orb.update_orb()
    if orb.network_essence + max_missing > orb.max_network_essence then
        return
    end
    orb.transferOrb(true)
    set_all_work_allowed(altar_accelerator_list, true)
    repeat
        utils.synchronize_to_tick(25, -3)
        orb.update_orb()
        altar.update_current_blood()
    until orb.network_essence + max_missing > orb.max_network_essence
    set_all_work_allowed(altar_accelerator_list, false)
    orb.transferOrb(false)
end
orb.transferOrb = function(is_charge)
    local current_side = orb_store_side
    local target_side = is_charge and config.IO.altar or config.IO.orb
    local source_side = is_charge and config.IO.orb or config.IO.altar
    if target_side == current_side then
        return
    end
    transposer.ensureTransferItem(source_side, target_side, 1)
    orb_store_side = target_side
end
orb.wait_for = function(target)
    if target then
        if orb.capacity < target then
            error("Not enough orb capacity!")
        end
        orb.wait_min_blood(orb.capacity - target)
    else
        orb.wait_min_blood(suffering_cost)
    end
end
local blood_network = require("blood_network").init(config.network_port, orb)
thread.create(function()
    while true do
        utils.synchronize_to_tick(25, -1)
        local num = (altar.capacity - altar.current_blood) / sacrifice_amount_per_operation - 1
        num = math.ceil(num / sacrifice_accelerator_list.speed)
        local actived_count = math.min(num, #sacrifice_accelerator_list)
        for i = 1, actived_count do
            sacrifice_accelerator_list[i].setWorkAllowed(true)
        end
        local current_time = utils.get_world_time()
        if (current_time + 1) % 25 ~= 0 then
            print("Sacrifice Accelerator sync failed.", current_time + 1, (current_time + 1) % 25)
        end
        os.sleep(0.05)
        altar.current_blood = altar.clamp_blood(altar.current_blood +
            (actived_count * sacrifice_accelerator_list.speed + 1) * sacrifice_amount_per_operation)
        set_all_work_allowed(sacrifice_accelerator_list, false)
    end
end)

local altar_accel_schedule = {}
local sleep_ticks = 0
local function safe_sleep()
    if sleep_ticks == 25 then
        return true
    end
    sleep_ticks = sleep_ticks + 1
    os.sleep(0.05)
    return false
end
local function start_altar_accel()
    thread.create(function()
        while true do
            sleep_ticks = 0
            if altar_accel_schedule[1] == math.huge then
                set_all_work_allowed(altar_accelerator_list, true)
                while altar_accel_schedule[1] == math.huge do
                    os.sleep(0.05)
                end
                set_all_work_allowed(altar_accelerator_list, false)
                return
            end
            local accel_ticks = table.remove(altar_accel_schedule, 1)
            if accel_ticks then
                local current_time = utils.get_world_time()
                local dead_line = current_time + accel_ticks
                while current_time < dead_line do
                    local n = #altar_accelerator_list
                    for i = 1, n do
                        altar_accelerator_list[i].setWorkAllowed(i <= accel_ticks)
                    end
                    accel_ticks = accel_ticks - n
                    if safe_sleep() then
                        print("WARN: Incorrect sleep time calculated!")
                        break
                    end
                    current_time = utils.get_world_time()
                end
            end
            set_all_work_allowed(altar_accelerator_list, false)
            utils.synchronize_to_tick(25, -1)
        end
    end)
end

local cached_recipe = utils.create_auto_cache_table("cached_recipe.lua")

local sleep_time = 0
local input_item
local function start_craft(batch_size)                            -- 2t
    transposer.ensureTransferItem(config.IO.input, config.IO.altar, batch_size, input_slot)
    transposer.transferFluid(config.IO.fluid, config.IO.altar, 1) -- 1.7.10的血魔法转移流体可以强制开始判断合成, 可惜转运器会强控对应电脑1t
    print("Try to craft", input_item.label)
    start_altar_accel()
end
while true do
    blood_network.process_task()
    orb.wait_for()
    input_item = transposer.getStackInSlot(config.IO.input, input_slot)
    if input_item then
        sleep_time = 0
        local recipe = cached_recipe[input_item.label]
        if not recipe then
            altar.wait_min_blood(suffering_cost)
            start_craft(1)
            do
                local max_progress = 0
                local diff_progress
                local last_progress
                while true do
                    local progress = altar.getProgress() -- 没深入研究, 但是这里似乎是必定在祭坛tick之后执行, 大概是不是同一种tick类型
                    if last_progress and not diff_progress then
                        diff_progress = progress - last_progress
                    end
                    max_progress = math.max(progress, max_progress)
                    if progress == 0 then
                        if max_progress == 0 then
                            max_progress = 20 * (1 + altar.consumption_multiplier) * 2 -- 1t或者2t(罕见)就合成完的, 不太好处理a.a
                        end
                        recipe = {
                            consumption_rate = diff_progress / (1 + altar.consumption_multiplier),
                            liquid_required = max_progress + diff_progress -- 可能会稍大一点, 一般可以接受
                        }
                        recipe.drain_rate = recipe.consumption_rate        -- 几乎没有配方例外，所以懒得写了
                        cached_recipe[input_item.label] = recipe
                        print(string.format("%s consumption_rate: %.1f liquid_required: %.1f", input_item.label,
                            recipe.consumption_rate, recipe.liquid_required))
                        break
                    end
                    last_progress = progress
                    altar.current_blood = altar.current_blood - (progress - last_progress)
                    -- 这里为了尽可能保证结果准确, 没有真正的更新数据, 其实感觉使用俩个电脑来实时更新会更好更简单一点(
                end
                cached_recipe.save_if_dirty()
            end
            transposer.ensureTransferItem(config.IO.altar, config.IO.output, 1)
        else
            altar.wait_min_blood(sacrifice_amount_per_cycle)
            local consumption_rate = recipe.consumption_rate * (1 + altar.consumption_multiplier)
            local batch_size, accel_table = calculate.calculate_amount(altar.current_blood, altar.capacity,
                consumption_rate,
                recipe.liquid_required, recipe.drain_rate, 2) -- 因为转运需要2t
            batch_size = math.min(batch_size, input_item.size)
            altar_accel_schedule = accel_table or {}
            start_craft(batch_size)
            local output_item
            while true do
                local current_tick = utils.get_world_time()
                if current_tick % 25 == 24 then
                    altar.update_current_blood()
                elseif current_tick % config.update_time == 0 then
                    altar.update_current_blood()
                    output_item = transposer.getStackInSlot(config.IO.altar, 1)
                    if output_item.label ~= input_item.label then
                        break
                    end
                else
                    os.sleep(0.05)
                end
            end
            altar_accel_schedule = {}
            transposer.ensureTransferItem(config.IO.altar, config.IO.output, batch_size)
            print("Finish craft", output_item.label)
        end
    else
        sleep_time = math.min(config.max_sleep_time, sleep_time + config.sleep_increase_time) * 0.05
    end
    os.sleep(sleep_time)
end
