local M = {}

---Clears terminal and sets cursor at the beginning
function M.reset() 
    term.clear()
    term.setCursorPos(1,1)
end

return M