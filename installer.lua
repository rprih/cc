-- Installer for CC: Tweaked machine scripts.
-- Run this on a fresh or existing computer to install/update one of the
-- roles defined in manifest.lua.

local BASE_URL = "https://raw.githubusercontent.com/rprih/cc/main/"

local function fetch(path)
    local response, err = http.get(BASE_URL .. path)
    if not response then
        error("Failed to download '" .. path .. "': " .. tostring(err))
    end
    local body = response.readAll()
    response.close()
    return body
end

local function loadManifest()
    local source = fetch("manifest.lua")
    local chunk, err = load(source, "manifest.lua")
    if not chunk then
        error("Failed to parse manifest.lua: " .. tostring(err))
    end
    local ok, roles = pcall(chunk)
    if not ok then
        error("Failed to run manifest.lua: " .. tostring(roles))
    end
    if type(roles) ~= "table" or #roles == 0 then
        error("manifest.lua did not return a non-empty list of roles")
    end
    return roles
end

local function chooseRole(roles)
    print("Select a role to install:")
    for i, role in ipairs(roles) do
        print(i .. ". " .. role.name)
    end

    while true do
        write("> ")
        local input = read()
        local choice = tonumber(input)
        if choice and roles[choice] then
            return roles[choice]
        end
        print("Invalid selection, try again.")
    end
end

local function targetPaths(role)
    local paths = { "startup.lua" }
    for _, path in ipairs(role.files) do
        table.insert(paths, path)
    end
    return paths
end

local function confirmOverwrite(paths)
    local existing = {}
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            table.insert(existing, path)
        end
    end

    if #existing == 0 then
        return true
    end

    print("The following files already exist:")
    for _, path in ipairs(existing) do
        print("  " .. path)
    end
    write("Overwrite? (y/n): ")
    local answer = read()
    return answer == "y" or answer == "Y"
end

local function writeFile(path, contents)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local file = fs.open(path, "w")
    file.write(contents)
    file.close()
end

local function installRole(role)
    for _, path in ipairs(role.files) do
        print("Downloading " .. path .. " ...")
        local body = fetch(path)
        writeFile(path, body)
    end

    local startupContent = "shell.run(\"" .. role.startup .. "\")\n"
    writeFile("startup.lua", startupContent)
end

local function main()
    local roles = loadManifest()
    local role = chooseRole(roles)
    local paths = targetPaths(role)

    if not confirmOverwrite(paths) then
        print("Aborted. No files were changed.")
        return
    end

    installRole(role)

    print("")
    print("Installed: " .. role.name)
    for _, path in ipairs(role.files) do
        print("  " .. path)
    end
    print("  startup.lua -> " .. role.startup)
    print("")
    print("Run 'reboot' to start it automatically, or run the entry")
    print("script directly right now.")
end

main()
