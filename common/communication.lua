---@class MatrixTelemetryPacket
---@field currentEnergyLevel number Current stored energy in Joules.
---@field maximumEnergyLevel number Total energy capacity in Joules.
---@field filledLevelNormalized number Fill percentage represented as 0.0 to 1.0.
---@field energyNeeded number Remaining energy needed to reach full capacity in Joules.
---@field timestamp integer Epoch timestamp in milliseconds (UTC).

local M = {}

M.PROTOCOL = "matrix_telemetry"

---Sends current matrix telemetry over Rednet.
---@param packet MatrixTelemetryPacket The wrapped Induction Port peripheral.
---@param targetId? integer Optional computer ID to send to. If nil, broadcasts to all.
---@return boolean success True if sent, false if unformed or battery missing.
function M.sendMatrixTelemetry(packet, targetId)
    if targetId then
        rednet.send(targetId, packet, M.PROTOCOL)
    else
        rednet.broadcast(packet, M.PROTOCOL)
    end

    return true
end

---Listens for incoming matrix telemetry packets.
---@param timeout? number Optional timeout in seconds.
---@return integer|nil senderId The sender's computer ID, or nil if timed out.
---@return MatrixTelemetryPacket|nil packet The telemetry packet, or nil if timed out.
function M.getMatrixTelemetry(timeout)
    local senderId, message = rednet.receive(M.PROTOCOL, timeout)

    if not senderId or type(message) ~= "table" then
        return nil, nil
    end

    ---@type MatrixTelemetryPacket
    local packet = message

    return senderId, packet
end

return M