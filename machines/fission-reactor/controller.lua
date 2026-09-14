local reactor = peripheral.find("fissionReactorLogicAdapter")
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
    local id, message = rednet.receive("matrix_telemetry", 2)

    print(message)
   
    if not id then 
        error("Matrix telemetry is not available")
    end

end