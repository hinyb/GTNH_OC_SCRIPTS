local utils = require("utils")
return {
    -- 注意如果是二级祭坛，四个角的符文不生效
    altar = {
        speed_count = 3,
        sacrifice_count = 0
    },
    IO = utils.proxy_side({
        orb = "north",
        input = "up",
        fluid = "up",
        output = "south",
        altar = "west"
    }),
    max_sleep_time = 5 * 20,
    sleep_increase_time = 5,
    update_time = 5,
    max_craft_time_when_back = 46,
    network_port = 4
}
