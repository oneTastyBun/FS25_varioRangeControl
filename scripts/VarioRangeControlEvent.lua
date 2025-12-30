-- scripts/VarioRangeControlEvent.lua

VarioRangeControlEvent = {}

-- Event for attaching
local VarioRangeControlEvent_mt = Class(VarioRangeControlEvent, Event)

InitEventClass(VarioRangeControlEvent, "VarioRangeControlEvent")

-- Create instance of Event class
function VarioRangeControlEvent.emptyNew()
    return Event.new(VarioRangeControlEvent_mt)
end

-- Create new instance of event
function VarioRangeControlEvent.new(vehicle, rangeIndex)
    local self = VarioRangeControlEvent.emptyNew()
    self.vehicle = vehicle
    self.rangeIndex = rangeIndex
    return self
end

-- Called on client side on join
function VarioRangeControlEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.rangeIndex = streamReadUIntN(streamId, 2)  -- 1..2 fits in 2 bits
    self:run(connection)
end

-- Called on server side on join
function VarioRangeControlEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.rangeIndex, 2)
end

-- Run action on receiving side
function VarioRangeControlEvent:run(connection)
    if self.vehicle == nil or self.vehicle.spec_varioRangeControl == nil then
        return
    end

    -- Apply on server and/or on clients when broadcast
    self.vehicle:setVarioRange(self.rangeIndex)

    -- If we received this from a client, rebroadcast from server to everyone
    if not connection:getIsServer() then
        g_server:broadcastEvent(VarioRangeControlEvent.new(self.vehicle, self.rangeIndex), nil, connection, self.vehicle)
    end
end
