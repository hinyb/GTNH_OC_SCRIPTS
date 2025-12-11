local component = require("component")
local event = require("event")
local module = {}
local queue = {}
module.init = function(port, orb)
    if not component.modem then
        print("WARN: Can't find a modem!")
        return function()

        end
    end
    local modem = component.modem
    modem.open(port)
    event.listen("modem_message", function(_, _, from, _, _, message, amount)
        if message == "require_blood" then
            table.insert(queue, { from = from, amount = amount })
        end
    end)
    local process_task = function()
        local task = table.remove(queue, 1)
        if not task then
            return
        end
        orb.wait_for_amount(task.amount)
        modem.send(task.from, port, "require_blood_finished")
    end
    return { process_task = process_task }
end
return module
