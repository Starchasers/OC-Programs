local component = require "component"
local event = require "event"
local utils = require "serialization"
local remote = {}
local port = 123
local modem = component.modem
------------------ [ SERVER ] -----------------
local function addPeripheral(comp)
    local peripheral = {}
    peripheral.address = comp.address
    peripheral.type = comp.type
    peripheral.functions = {}
    for _,tab in pairs(comp) do
        if type(tab) == "table" and tab.name ~= nil then 
            table.insert(peripheral.functions,tab.name)
        end
    end
    remote[comp.address] = peripheral
end

local function wrapComponents()
    remote = {}
    local it = component.list()
    while true do
      local element = it()
      if element == nil then break end
      addPeripheral(component.proxy(element))
    end
end

local function onAdd(...)
    local arg = {...}
    local comp = component.proxy(arg[2])
    if comp == nil then return end
    addPeripheral(comp)
    print("add: "..arg[2])
end

local function onRemove(...)
    local arg = {...}
    if remote[arg[2]] ==nil then return end
    remote[arg[2]]=nil
    print("remove: "..arg[2])
end

local function createPacket(action,id,data,stat)
    local packet = {}
    packet.id = id
    packet.action = action
    packet.data = data
    packet.status= stat
    return utils.serialize(packet)
end

local function onPacket(...)
    local arg = {...}
    if arg[4]~=123 then return end
    local packet = utils.unserialize(arg[6])
    if packet ~=nil and packet.action~=nil and packet.id~=nil then 
        if packet.action == "proxy" and packet.address ~= nil and remote[packet.address]~=nil then
            local data = createPacket("component_wrap",packet.id,remote[packet.address],true)
            modem.send(arg[3],port,data)
        end
        
        local status
        local response
        if packet.action == "invoke" and packet.address ~= nil and packet.func ~= nil and remote[packet.address]~=nil then
            if packet.arg~=nil then
                status, response = pcall(function() return component.invoke(packet.address,packet.func,table.unpack(packet.arg))end)
            else
                status, response = pcall(function() return component.invoke(packet.address,packet.func)end)
            end
                modem.send(arg[3],port,createPacket("component_response",packet.id,response,status))
        end
        
    end

end



component.modem.open(port)
wrapComponents()
event.listen("component_added",onAdd)
event.listen("component_removed",onRemove)
event.listen("modem_message",onPacket)
-----------------------------------------------