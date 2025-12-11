local utils = require("utils")

local module = {}
module.init = function()
    local transposer = utils.require_component("transposer")
    utils.proxy_component_for_yield(transposer)
    transposer.ensureTransferItem = function(source_side, target_side, amount, ...)
        if not amount or amount <= 0 then
            transposer.transferItem(source_side, target_side, amount, ...)
            return
        end
        repeat
            local num = transposer.transferItem(source_side, target_side, amount, ...)
            amount = amount - num
        until amount <= 0
    end
    return transposer
end

return module
