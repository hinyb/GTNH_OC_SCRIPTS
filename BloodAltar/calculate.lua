local module = {}
module.init = function(max_craft_time_when_back, altar_accelerator_speed, altar_accelerator_count, sacrifice_amount_per_cycle, altar)
    local function can_reach_next_cycle(current_blood, consumption_rate, current_tick, progress, drain_rate)
        current_tick = current_tick or 0
        local remaining_ticks = 25 - current_tick
        local run_ticks = math.floor(current_blood / consumption_rate)
        if run_ticks >= remaining_ticks then
            return true
        end
        if progress and drain_rate then
            local stop_ticks = remaining_ticks - run_ticks
            return progress - stop_ticks * drain_rate > 0, stop_ticks
        end
        return false
    end

    local function calculate_amount_simple(current_blood, consumption_rate, liquid_required, current_tick)
        if current_blood < liquid_required then
            return 0
        end
        local batch_size = math.floor(current_blood / liquid_required)
        local accel_table = {} -- 用于存储每个周期内需要加速开启加速器多少tick
        table.insert(accel_table, math.huge)
        return batch_size, accel_table
    end

    local function calculate_amount_complex(current_blood, capacity, consumption_rate, liquid_required, drain_rate,
                                            current_tick)
        local consumption_per_cycle = consumption_rate * 25
        local rate_inc_per_accel = consumption_rate * altar_accelerator_speed
        local theoretical_max_rate = math.min((consumption_rate + rate_inc_per_accel * altar_accelerator_count) * 25,
            sacrifice_amount_per_cycle)
        local actual_max_rate = consumption_per_cycle +
            math.floor((theoretical_max_rate - consumption_per_cycle) / rate_inc_per_accel) * rate_inc_per_accel
        local require_cycles = math.ceil((liquid_required - current_blood) / actual_max_rate)
        local require_amount_table = { 0 }
        for i = 1, require_cycles do
            local require_amount_current_cycle = require_amount_table[i]
            local require_amount_last_cycle = math.max(
                consumption_per_cycle + require_amount_current_cycle - actual_max_rate, 0)
            if require_amount_last_cycle > capacity then
                return 0
            end
            require_amount_table[i + 1] = require_amount_last_cycle
        end
        if require_amount_table[require_cycles + 1] > current_blood then
            return 0
        end
        local accel_table = {}
        local rest_fluid = current_blood
        for i = require_cycles + 1, 2, -1 do
            rest_fluid = rest_fluid - require_amount_table[i] - consumption_per_cycle
            local accel_ticks = math.floor(math.floor(rest_fluid / consumption_rate) / altar_accelerator_speed)
            table.insert(accel_table, accel_ticks)
            rest_fluid = rest_fluid - accel_ticks * rate_inc_per_accel
            rest_fluid = altar.clamp_blood(rest_fluid + sacrifice_amount_per_cycle)
        end
        table.insert(accel_table, math.huge)
        return 1, accel_table
    end

    local function calculate_amount_internal(current_blood, capacity, consumption_rate, liquid_required, drain_rate,
                                             current_tick)
        -- 当前可合成
        local batch_size, accel_table = calculate_amount_simple(current_blood, consumption_rate, liquid_required,
            current_tick)
        if batch_size > 0 then
            return batch_size, accel_table
        end
        -- 当前不可合成，考虑多个周期
        batch_size, accel_table = calculate_amount_complex(current_blood, capacity, consumption_rate, liquid_required,
            drain_rate, current_tick)
        return batch_size, accel_table
    end

    local function calculate_amount(current_blood, capacity, consumption_rate, liquid_required, drain_rate, current_tick)
        local batch_size, accel_table = calculate_amount_internal(current_blood, capacity, consumption_rate,
            liquid_required, drain_rate, current_tick)
        if batch_size > 0 then
            return batch_size, accel_table
        end

        altar.wait_to_next_cycle()
        current_blood = altar.current_blood

        batch_size, accel_table = calculate_amount_internal(current_blood, capacity, consumption_rate, liquid_required,
            drain_rate, current_tick)
        if batch_size > 0 then
            return batch_size, accel_table
        end

        local require_cycles = math.ceil((liquid_required - current_blood) / sacrifice_amount_per_cycle)
        if require_cycles < max_craft_time_when_back then
            local progress = 0
            for _ = 1, require_cycles do
                local flag, stop_ticks = can_reach_next_cycle(current_blood, consumption_rate, current_tick,
                    progress, drain_rate)
                if not flag then
                    break
                end
                stop_ticks = stop_ticks or 0
                local add_amount = consumption_rate * (25 - stop_ticks) - stop_ticks * drain_rate
                progress = progress + add_amount
                current_blood = current_blood - add_amount + sacrifice_amount_per_cycle
            end
            accel_table = {}
            accel_table[require_cycles] = math.huge
            print("Trigger drain")
            return 1, accel_table
        end
        error("Can't craft this item")
        os.exit()
    end

    return {
        calculate_amount = calculate_amount
    }
end
return module
