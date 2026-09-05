-- Shows AE2 ME network storage status (item types + item count) on a monitor.
-- Requires an ME Bridge peripheral (Advanced Peripherals) connected to an AE2 ME network.

local mon = peripheral.find("monitor")
local me = peripheral.find("me_bridge")

if not me then
  error("No ME Bridge peripheral found. Attach an ME Bridge to this computer.", 0)
end

local out = mon or term

-- ME Bridge only reports item-type capacity via storage cell info, not a
-- single "types total" call, so we derive it by summing each item cell's
-- (totalBytes / bytesPerType).
local function getTypeCapacity()
  local cells, err = me.listCells()
  if not cells then
    return nil, err
  end

  local capacity = 0
  for _, cell in ipairs(cells) do
    if cell.cellType == "item" and cell.bytesPerType and cell.bytesPerType > 0 then
      capacity = capacity + math.floor(cell.totalBytes / cell.bytesPerType)
    end
  end
  return capacity
end

-- Item type count (used) and total item count come from the same item list.
local function getItemStats()
  local items, err = me.listItems()
  if not items then
    return nil, nil, err
  end

  local typesUsed, itemsTotal = 0, 0
  for _, item in ipairs(items) do
    typesUsed = typesUsed + 1
    itemsTotal = itemsTotal + (item.amount or 0)
  end
  return typesUsed, itemsTotal
end

local function draw()
  out.setBackgroundColor(colors.black)
  out.setTextColor(colors.white)
  out.clear()

  if out.setTextScale then
    out.setTextScale(1)
  end

  local typesUsed, itemsTotal, itemErr = getItemStats()
  local typesCapacity, capErr = getTypeCapacity()
  local storageUsed = me.getUsedItemStorage()
  local storageTotal = me.getTotalItemStorage()
  local storageAvailable = me.getAvailableItemStorage()

  out.setCursorPos(1, 1)
  out.write("=== AE2 ME Network Status ===")

  if itemErr or capErr then
    out.setCursorPos(1, 3)
    out.write("Error reading ME network:")
    out.setCursorPos(1, 4)
    out.write(tostring(itemErr or capErr))
    return
  end

  local typesAvailable = math.max(typesCapacity - typesUsed, 0)

  out.setCursorPos(1, 3)
  out.write(string.format(
    "Item Types: %d used / %d free / %d total",
    typesUsed, typesAvailable, typesCapacity
  ))

  out.setCursorPos(1, 4)
  out.write(string.format("Items Total: %d", itemsTotal))

  out.setCursorPos(1, 6)
  out.write(string.format(
    "Storage: %d used / %d free / %d total bytes",
    storageUsed, storageAvailable, storageTotal
  ))
end

while true do
  draw()
  sleep(5)
end
