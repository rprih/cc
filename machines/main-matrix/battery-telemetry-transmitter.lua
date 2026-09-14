peripheral.find("modem", rednet.open)
local battery = peripheral.find("inductionPort")

if not rednet.isOpen() then
    error("Network is not available")
end

if not battery then
    error("Induction matrix is not found")
end

term.clear()
term.setCursorPos(1, 1)

while true do
    local infoPackage = {
        currentEnergyLevel = battery.getEnergy(),
        maximumEnergyLevel = battery.getMaxEnergy(),
        filledLevelNormalized = battery.getEnergyFilledPercentage(),
        energyNeeded = battery.getEnergyNeeded()
    }

    rednet.broadcast(infoPackage, "matrix_telemetry")
    sleep(2)
end