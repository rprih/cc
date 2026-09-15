package.path = package.path .. ";/?.lua;/?/init.lua"

local terminalUtils = require("common.terminal")
local turbine = peripheral.find("turbineValve")

terminalUtils.reset()

if not turbine then
    error("Device is not connected to the turbine")
end

if not turbine.isFormed then
    error("Turbine is not formed")
end

-- The logic is quite simple 
-- When stored energy level is < 75%
-- Turn the resistive load (heaters) off
-- When stored energy level is > 75% & < 80%
-- Turn one resistive loads
-- When stored energy level is higher than 80%
-- Turn both resistive loads
-- First resistive load is at the left side of the terminal
-- Second load is at the right side of the terminal

-- Initially both redstone signals should be turned on
-- It's made for safety 
-- Heaters works in inverted mode
-- Signal on means turn off the heater
-- In case of some bug etc both heaters must be activated by default
 
local function getEnergyPercent()
  local cur = turbine.getEnergy()
  local max = turbine.getMaxEnergy()
  
  return cur * 100 / max
end
 
local function changeMode(mode) 
  -- There are 3 modes
  -- 0 - both resistors are off (redstone signals on)
  -- 1 - one resistor is on (redstone signal at left side)
  -- 2 - both resistors are on (redstone signals from left and right)
 
  if mode == 0 then
    redstone.setOutput("left", true)
    redstone.setOutput("right", true)
  elseif mode == 1 then
    redstone.setOutput("left", false)
    redstone.setOutput("right", true)
  else
    redstone.setOutput("left", false)
    redstone.setOutput("right", false)
  end
end
 
local currMode = -1
 
while true do  
  local curr = getEnergyPercent() 
  local newMode = -1
  
  if curr < 75 then
    newMode = 0  
  elseif curr > 75 and curr < 80 then
    newMode = 1
  else 
    newMode = 2
  end 
  
 
  if newMode ~= currMode then
    changeMode(newMode)
    print("Operating mode changed from " .. currMode .. " to " .. newMode)
    print("Current energy level: " .. getEnergyPercent() .. "% \n")
    
    currMode = newMode
  end
 
  sleep(1)
end