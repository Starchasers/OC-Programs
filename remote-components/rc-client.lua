local component = require "component"
local event = require "event"
local utils = require "serialization"
local port = 123
local modem = component.modem
local tID=1
local timeout = 3
local retry = 3
local rc ={}

modem.open(port)

local function send(packet,t)
    local cId = packet.id
    local id = nil
    local response = nil
    local i = 0
    modem.broadcast(port,utils.serialize(packet))
    while id ~=cId and i<retry do
        local _,_,_,p,_,pack = event.pull(3,"modem_message")
        if p~=port then return end
        response = utils.unserialize(pack)
        if response~=nil and response.action==t then
            id = response.id
        end
        i=i+1
    end
    
    return response.data,response.status
end

local function createPacket(action,id,address,data,stat)
    tID=tID+1
    local packet = {}
    packet.id = id
    packet.action = action
    packet.data = data
    packet.status= stat
    packet.address = address
    return packet
end

-----------------

function rc.proxy(address)
    local packet = createPacket("proxy",tID,address,true)
    local response = send(packet,"component_wrap")
    if response == nil then return end
    local result = {}
    result.address = response.address
    result.type = response.type
    if response.functions == nil then return result end
    
    for _,name in pairs(response.functions) do
        result[name] = function(...) 
                                    local p = createPacket("invoke",tID,address,nil,true)
                                    p.func = name
                                    p.arg = {...}
                                    local resp,stat = send(p,"component_response")
                                    if stat then
                                        return true,resp
                                    else
                                        return false
                                    end
                        end
    end
    return result
end

return rc