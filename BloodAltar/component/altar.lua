local utils = require("utils")

local module = {}
module.init = function(config)
    local altar = utils.require_component("blood_altar")
    utils.proxy_component_for_yield(altar)
    altar.capacity = altar.getCapacity()
    altar.buffer_capacity = altar.capacity / 10
    altar.sacrifice_efficiency_multiplier = 0.12 * config.sacrifice_count
    altar.consumption_multiplier = 0.25 * config.speed_count
    altar.update_current_blood = function()
        altar.current_blood = altar.getCurrentBlood()
    end
    altar.update_current_blood()
    altar.clamp_blood = function(number)
        return math.max(0, math.min(altar.capacity, number))
    end
    altar.wait_to_next_cycle = function()
        utils.synchronize_to_tick(25, -1)
        altar.update_current_blood()
    end
    altar.wait_min_blood = function(max_missing)
        altar.update_current_blood()
        while altar.current_blood <= math.max(0, altar.capacity - max_missing) do
            altar.wait_to_next_cycle()
        end
    end
    return altar
end
return module
