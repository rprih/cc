package.path = package.path .. ";/?.lua;/?/init.lua"

local reactor = peripheral.find("fissionReactorLogicAdapter")
local communication = require("common.communication")

peripheral.find("modem", rednet.open)

if not rednet.isOpen() then
    error("Network is not available")
end
if not reactor then
    error("Reactor is not found")
end
if not reactor.isFormed() then
    error("Reactor is not formed")
end

while true do
    local id, packet = communication.getMatrixTelemetry(2)
    if not id or not packet then
        error("Matrix telemetry is not available")
    end

    print("Current charge is: " .. packet.currentEnergyLevel)

    sleep(1)
end