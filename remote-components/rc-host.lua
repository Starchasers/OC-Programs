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

local function createPacketData(data,stat)
    local packet = {}
    packet.data = data
    packet.status= stat
    return utils.serialize(packet)
end

local function onPacket(...)
    local typ,receiverAddress,senderAddress,reciverPort,distance,id,action,data = table.unpack({...})
    if reciverPort~=123 then return end
    local packet  
    if data~=nil then
      packet = utils.unserialize(data)
    end
    if  action~=nil and id~=nil then 
        ------------------- ACTION PROXY ----------------------------
        if action == "proxy" and packet ~=nil and packet.address ~= nil and remote[packet.address]~=nil then
            local data = createPacketData(remote[packet.address],true)
            modem.send(senderAddress,port,id,"component_wrap",data)
        end
        ------------------- ACTION INVOKE ----------------------------
        local status
        local response
        if action == "invoke" and packet ~=nil and packet.address ~= nil and packet.func ~= nil and remote[packet.address]~=nil then
            if packet.arg~=nil then
                status, response = pcall(function() return component.invoke(packet.address,packet.func,table.unpack(packet.arg))end)
            else
                status, response = pcall(function() return component.invoke(packet.address,packet.func)end)
            end
                modem.send(senderAddress,port,id,"component_response",createPacketData(response,status))
        end
        ------------------- ACTION LIST ----------------------------
        if action == "list" then
          modem.send(senderAddress,port,id,"component_list",createPacketData(remote,true))  
        end     
        ------------------------------------------------------------
    end

end



component.modem.open(port)
wrapComponents()
event.listen("component_added",onAdd)
event.listen("component_removed",onRemove)
event.listen("modem_message",onPacket)
