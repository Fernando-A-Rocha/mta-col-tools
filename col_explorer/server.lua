--[[
    GTA:SA stores collisions inside .col files that possess multiple game model collisions inside them.
    This script reads all COL container files and extracts the names of the collisions inside them.
]]

local function getFilesInFolder(path)
    if not pathIsDirectory(path) then
        return {}
    end
    return pathListDir(path)
end

local function readColFile(path)
    local file = fileOpen(path, true)
    if not file then
        return false
    end
    local fileSize = fileGetSize(file)
    local binaryData = fileRead(file, fileSize)
    fileClose(file)
    return binaryData, fileSize
end

local function readCharacters(data, offset, length)
    local characters = {}
    for i = 0, length - 1 do
        local char = string.char(data:byte(offset + i))
        if char == "\0" then
            break
        end
        table.insert(characters, char)
    end
    return table.concat(characters)
end

local function getColNamesFromFile(data, size)
    local offset = 1
    local insideCol = false
    local colNames = {}
    while offset < size do
        if not insideCol then
            local colType = readCharacters(data, offset, 4)
            if colType == "COL2" or colType == "COL3" then
                offset = offset + 4 + 4
                insideCol = true
            else
                offset = offset + 1
            end
        else
            local colName = readCharacters(data, offset, 22)
            colNames[#colNames+1] = colName
            offset = offset + 22
            
            insideCol = false
        end
    end
    return colNames
end

local function asyncParseFiles(filesInFolder, path, onFileProcessed)
    local co = coroutine.create(function()
        for _, fileName in pairs(filesInFolder) do
            local thisPath = path .. "/" .. fileName
            local data, size = readColFile(thisPath)
            if data then
                local colNames = getColNamesFromFile(data, size)
                local filePathNew = string.gsub(thisPath, "files/original", "files/extracted")
                local file = fileCreate(filePathNew .. ".txt")
                if file then
                    local str = "File '" .. fileName .. "' contains " .. #colNames .. " collisions named:\n\n"
                    for _, colName in pairs(colNames) do
                        str = str .. colName .. "\n"
                    end
                    fileWrite(file, str)
                    fileClose(file)
                    -- print("   Parsed: " .. fileName)
                end
            end
            coroutine.yield()
        end
    end)

    return co
end

local function parseColFiles()
    print("Starting. Please wait (30sec/1min) ...")
    local startMs = getTickCount()

    local coroutines = {}
    for _, path in pairs({"files/original/gta_int", "files/original/gta3", "files/original/SAMPCOL"}) do
        local filesInFolder = getFilesInFolder(path)
        table.insert(coroutines, asyncParseFiles(filesInFolder, path))
    end

    local function resumeCoroutines()
        local allFinished = true
        for _, co in ipairs(coroutines) do
            if coroutine.status(co) ~= "dead" then
                allFinished = false
                local success, message = coroutine.resume(co)
                if not success then
                    print("Coroutine error: " .. message)
                end
            end
        end

        if allFinished then
            killTimer(resumeTimer)  -- Stop the timer when all coroutines are done
            print("Finished after " .. (getTickCount() - startMs) .. "ms")
        end
    end

    -- Timer to resume coroutines periodically
    resumeTimer = setTimer(resumeCoroutines, 50, 0)
end

addEventHandler("onResourceStart", resourceRoot, function()
    parseColFiles()
end, false)
