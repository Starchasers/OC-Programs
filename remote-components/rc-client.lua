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

local function send(packet,actionTypeSend,actionTypeRecive,addresstoSend)
    local cId = tID
    tID=tID+1
    local id = nil
    local response = nil
    local i = 0
    local tempAddress 
    if addresstoSend==nil then
        modem.broadcast(port,cId,actionTypeSend,utils.serialize(packet))
    else
        modem.send(addresstoSend,port,cId,actionTypeSend,utils.serialize(packet))
    end
    
    while id ~=cId and i<retry do
        local typ,receiverAddress,senderAddress,reciverPort,distance,idr,action,data = event.pull(timeout,"modem_message",nil,nil,port,nil,cId,actionTypeRecive)
        if(data~=nil)then
          response = utils.unserialize(data)
          tempAddress = senderAddress
        end
        id=idr
        i=i+1
    end  
    if response~=nil then
      return response.data,response.status,tempAddress
    else
      return nil
    end
end

local function createPacket(address,data,stat)
    local packet = {}
    packet.data = data
    packet.status= stat
    packet.address = address
    return packet
end

function tableMerge(t1, t2)
    for k,v in pairs(t2) do
      if type(v) == "table" then
        if type(t1[k] or false) == "table" then
          tableMerge(t1[k] or {}, t2[k] or {})
        else
          t1[k] = v
        end
      else
        t1[k] = v
      end
    end
    return t1
end

-----------------

function rc.proxy(address)
    local packet = createPacket(address,nil,true)
    local response,stat,sender = send(packet,"proxy","component_wrap")
    if response == nil then return end
    local result = {}
    result.address = response.address
    result.type = response.type
    if response.functions == nil then return result end
    
    for _,name in pairs(response.functions) do
        result[name] = function(...) 
                                    local p = createPacket(address,nil,true)
                                    p.func = name
                                    p.arg = {...}
                                    local resp,stat = send(p,"invoke","component_response",sender)
                                    if stat then
                                        return resp,true
                                    else
                                        return nil,false
                                    end
                        end
    end
    return result
end

function rc.list()
  local component_list = {}
  local id= tID
  tID=tID+1
  modem.broadcast(port,id,"list")
  while true do
    local typ,receiverAddress,senderAddress,reciverPort,distance,idr,action,data = event.pull(timeout+2,"modem_message",nil,nil,port,nil,id,"component_list")
    if typ==nil then break end
    local response = utils.unserialize(data)
    if response~=nil and response.data~=nil then
      tableMerge(component_list, response.data)
    end
  end
  return component_list
end

return rc