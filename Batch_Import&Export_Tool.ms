rollout Maxtool "Batch_Import&Export" width:212 height:52
(
    button 'btn7' "Import FBX" pos:[12,12] width:90 height:30 align:#left
    button 'btn8' "Export FBX" pos:[111,12] width:90 height:30 align:#left

    -- ====================== ????(Export ??) ======================
    fn isCollisionObject objName =
    (
        global collisionPrefixes, collisionSuffixes
        for p in collisionPrefixes do if matchPattern objName pattern:(p + "*") then return true
        for s in collisionSuffixes do if matchPattern objName pattern:("*" + s) then return true
        false
    )

    fn stripPrefix objName =
    (
        global collisionPrefixes
        for p in collisionPrefixes do
            if matchPattern objName pattern:(p + "*") then return (substring objName (p.count + 1) -1)
        undefined
    )

    fn isNumeric str =
    (
        if str == "" then return false
        for i = 1 to str.count do if str[i] < "0" or str[i] > "9" then return false
        true
    )

    fn findMatchingMeshName collisionObj meshNames =
    (
        local colName = collisionObj.name
        local stripped = stripPrefix colName
        if stripped == undefined then return undefined
        if (findItem meshNames stripped) != 0 then return stripped

        for meshName in meshNames do
        (
            local prefixLen = meshName.count + 1
            if stripped.count > prefixLen and (substring stripped 1 meshName.count) == meshName then
            (
                if stripped[meshName.count + 1] == "_" then
                (
                    local suffix = substring stripped (meshName.count + 2) -1
                    if isNumeric suffix then return meshName
                )
            )
        )
        undefined
    )

    fn safeFileName name =
    (
        local safe = name
        safe = substituteString safe " " "_"
        safe = substituteString safe "/" "_"
        safe = substituteString safe "\\" "_"
        safe = substituteString safe ":" "_"
        safe = substituteString safe "*" "_"
        safe = substituteString safe "?" "_"
        safe = substituteString safe "\"" "_"
        safe = substituteString safe "<" "_"
        safe = substituteString safe ">" "_"
        safe = substituteString safe "|" "_"
        safe
    )

    -- ====================== Import FBX(???) ======================
    on btn7 pressed do
    (
        -- ?? Max ?? getSavePath,????????????
        local folderPath = getSavePath caption:"Select Folder Containing FBX Files" initialDir:(getDir #export)

        if folderPath == undefined do return false

        local fbxFiles = getFiles (folderPath + "\\*.fbx")
        if fbxFiles.count == 0 do
        (
            messageBox "No FBX files found in the selected folder." title:"Info"
            return false
        )

        -- FBX Import ??
        FbxImporterSetParam "Mode" #merge
        FbxImporterSetParam "Animation" true
        FbxImporterSetParam "Cameras" true
        FbxImporterSetParam "Lights" true
        FbxImporterSetParam "Shapes" true
        FbxImporterSetParam "Units" #scene

        local importedCount = 0
        local failedFiles = #()

        progressStart "Importing FBX files..."
        for i = 1 to fbxFiles.count do
        (
            local file = fbxFiles[i]
            progressUpdate (100.0 * i / fbxFiles.count)

            try
            (
                importFile file #noPrompt
                importedCount += 1
            )
            catch
            (
                append failedFiles (filenameFromPath file)
                format "Import failed: %\n" file
            )
        )
        progressEnd()

        local msg = stringstream ""
        format "Import completed.\n% files successfully imported." importedCount to:msg
        if failedFiles.count > 0 then
        (
            format "\n\nFailed files:\n" to:msg
            for f in failedFiles do format "%\n" f to:msg
        )
        messageBox (msg as string) title:"Import Result"
    )

    -- ====================== Export FBX ======================
    on btn8 pressed do
    (
        global collisionPrefixes = #("UCX_", "UBX_", "UCP_", "COL_", "COLLISION_", "PCX_", "PCO_")
        global collisionSuffixes = #("_COL", "_COLLISION", "_UCX", "_UBX", "_UCP", "_PCX", "_PCO")

        global exportResults = #()
        global settingsFile = (getDir #plugcfg) + "\\MeshCollisionExporter.ini"

        fn exportMeshesWithCollisions outputDir =
        (
            -- ...(Export ????????,????????)...
            -- ?????,???????? exportMeshesWithCollisions ??
            -- ??????????????? exportMeshesWithCollisions ????
            -- ???????? Export ??????,????
        )

        local lastPath = getINISetting settingsFile "Settings" "LastOutputPath"
        local initialDir = if lastPath != "" and doesFileExist lastPath then lastPath else (getDir #export)
        
        local outputDir = getSavePath caption:"Select Output Folder for FBX files" initialDir:initialDir
        if outputDir != undefined do
        (
            setINISetting settingsFile "Settings" "LastOutputPath" outputDir
            exportMeshesWithCollisions outputDir
        )
    )
)

createDialog Maxtool