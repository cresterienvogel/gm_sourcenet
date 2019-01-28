if CLIENT then
	include("incoming.new.lua")
else
	include("outgoing.new.lua")
end

local manager = IGameEventManager2()
local function FilterGameEvent(netchan, streamname, read, write, hookname)
	local bits = read:ReadUInt(11)
	local data = read:ReadBits(bits)

	SourceNetMsg(string.format("svc_GameEvent on %s stream: bits=%i\n", streamname, bits))

	if not read:IsOverflowed() then
		local buffer = sn_bf_read(data)
		local event = manager:UnserializeEvent(buffer)

		local result = hook.Call(hookname, nil, netchan, event)

		if result ~= false then
			write:WriteUInt(svc_GameEvent, NET_MESSAGE_BITS)

			if type(result) == "IGameEvent" then
				local serialized_data = UCHARPTR(2048)
				local serialized_buffer = sn_bf_write(serialized_data)

				manager:SerializeEvent(event, serialized_buffer)

				write:WriteUInt(serialized_buffer:GetNumBitsWritten(), 11)
				write:WriteBits(serialized_buffer:GetBasePointer())
			else
				write:WriteUInt(bits, 11)
				write:WriteBits(data)
			end
		end
	end
end

if CLIENT then
	FilterIncomingMessage(svc_GameEvent, function(netchan, streamname, read, write)
		FilterGameEvent(netchan, streamname, read, write, "ProcessGameEvent")
	end)
else
	FilterOutgoingMessage(svc_GameEvent, function(netchan, streamname, read, write)
		FilterGameEvent(netchan, streamname, read, write, "SendGameEvent")
	end)
end