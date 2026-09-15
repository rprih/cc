local communication = require("common.communication")

-- 1. Open rednet on any attached wireless/ender modem
peripheral.find("modem", rednet.open)

if not rednet.isOpen() then
    error("Network is not available! Attach and activate a modem.")
end

-- 2. Find the Induction Port with fallback across versions
local battery = peripheral.find("inductionPort")

if not battery then
    error("Induction Matrix port not found! Check wiring and modems.")
end

term.clear()

while true do
    term.setCursorPos(1, 1)

    if not battery.isFormed() then
        print("Status: Matrix Not Formed!             ")
    else
        local energyJ = battery.getEnergy()
        local maxEnergyJ = battery.getMaxEnergy()
        local fillRatio = battery.getEnergyFilledPercentage()
        local neededJ = battery.getEnergyNeeded()

        ---@type MatrixTelemetryPacket
        local infoPackage = {
            currentEnergyLevel = energyJ,
            maximumEnergyLevel = maxEnergyJ,
            filledLevelNormalized = fillRatio,
            energyNeeded = neededJ,
            timestamp = os.epoch("utc")
        }

        communication.sendMatrixTelemetry(infoPackage)

        -- On-screen heartbeat display
        print("=== MATRIX TELEMETRY SENDER ===")
        print(string.format("Charge:   %.1f%%", fillRatio * 100))
        print(string.format("Stored:   %.2f / %.2f MFE", (energyJ / 2.5) / 1e6, (maxEnergyJ / 2.5) / 1e6))
        print(string.format("Packets:  Broadcasting on 'matrix_telemetry'"))
        print(string.format("Time:     %s", os.date("%T")))
        print("================================")
    end

    sleep(2)
end