rollout Maxtool "Batch_Import&Export" width:212 height:52
(
	button 'btn7' "Import" pos:[12,12] width:90 height:30 align:#left
	button 'btn8' "Export" pos:[111,12] width:90 height:30 align:#left

	-- ==================== ???? ====================
	on btn7 pressed  do
	(
		-- One-click import all FBX files in a folder
		(
			-- Use .NET to select a folder
			fn selectFolder =
			(
				local folderDialog = dotNetObject "System.Windows.Forms.FolderBrowserDialog"
				folderDialog.Description = "Select folder containing FBX files"
				folderDialog.ShowNewFolderButton = false
				local result = folderDialog.ShowDialog()
				if result == (dotNetClass "System.Windows.Forms.DialogResult").OK then
					return folderDialog.SelectedPath
				else
					return undefined
			)

			-- Get folder path
			local folderPath = selectFolder()
			if folderPath == undefined do return false

			-- Get all FBX files (case-insensitive)
			local fbxFiles = getFiles (folderPath + "\\*.fbx")
			if fbxFiles.count == 0 do
			(
				messageBox "No FBX files found in the folder." title:"Info"
				return false
			)

			-- Set FBX import options (adjust as needed)
			FbxImporterSetParam "Mode" #merge      -- merge into current scene
			FbxImporterSetParam "Animation" true
			FbxImporterSetParam "Cameras" true
			FbxImporterSetParam "Lights" true
			FbxImporterSetParam "Shapes" true
			FbxImporterSetParam "Units" #scene      -- use scene units

			-- Start import
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

			-- Display result
			local msg = stringstream ""
			format "Import completed. % files successfully imported." importedCount to:msg
			if failedFiles.count > 0 then
			(
				format "\nThe following files failed to import:\n" to:msg
				for f in failedFiles do format "%\n" f to:msg
			)
			messageBox (msg as string) title:"Import Result"

			OK
		)
	)

	-- ==================== ???? ====================
	on btn8 pressed  do
	(
		--------------------------------------------------------------------------------
		-- Mesh + Collision Exporter
		-- Description: Exports visual meshes (and their associated collision(s), if any)
		-- as separate FBX files to a user-specified folder.
		-- Naming: FBX file is named after the visual mesh (not the collision).
		-- Behavior: If objects are selected, only selected visual meshes are exported;
		--           otherwise all visual meshes in the scene are exported.
		-- Collision objects are identified by common prefixes/suffixes and can have
		-- an optional numeric suffix (e.g., UCX_Box_01). All collisions sharing the
		-- same base mesh name are grouped together and exported with that mesh.
		-- Export Settings: The first export will pop up the FBX export options dialog
		--                  to allow global settings; subsequent exports reuse the same settings.
		-- After export, a summary dialog lists all exported meshes and their collision status.
		-- Recent Folder: Automatically opens the last used export folder when selecting output path.
		--------------------------------------------------------------------------------

		-- ??????????????,???????????
		global collisionPrefixes = #("UCX_", "UBX_", "UCP_", "COL_", "COLLISION_", "PCX_", "PCO_")
		global collisionSuffixes = #("_COL", "_COLLISION", "_UCX", "_UBX", "_UCP", "_PCX", "_PCO")

		-- ?????????????
		global exportResults = #()

		-- ??????????????????
		global settingsFile = (getDir #plugcfg) + "\\MeshCollisionExporter.ini"

		--------------------------------------------------------------------------------
		-- ?????(??????????,?????????)
		fn exportMeshesWithCollisions outputDir =
		(
			-- ?????????????
			global collisionPrefixes, collisionSuffixes, settingsFile, exportResults

			--------------------------------------------------------------------------------
			-- ??????(????? exportMeshesWithCollisions ??)
			--------------------------------------------------------------------------------
			-- ??????????????
			fn isCollisionObject objName =
			(
				for p in collisionPrefixes do
					if matchPattern objName pattern:(p + "*") then return true
				for s in collisionSuffixes do
					if matchPattern objName pattern:("*" + s) then return true
				false
			)

			-- ??????,???????????;???????????? undefined
			fn stripPrefix objName =
			(
				for p in collisionPrefixes do
				(
					if matchPattern objName pattern:(p + "*") then
						return (substring objName (p.count+1) -1)
				)
				undefined
			)

			-- ????????????
			fn isNumeric str =
			(
				if str == "" then return false
				for i = 1 to str.count do
					if str[i] < "0" or str[i] > "9" then return false
				true
			)

			-- ?????????????????
			fn findMatchingMeshName collisionObj meshNames =
			(
				local colName = collisionObj.name
				-- ??????
				local stripped = stripPrefix colName
				if stripped == undefined then return undefined

				-- ????
				if (findItem meshNames stripped) != 0 then return stripped

				-- ????“???_??”???
				for meshName in meshNames do
				(
					local prefixLen = meshName.count + 1  -- ??? + "_"
					if stripped.count > prefixLen and (substring stripped 1 meshName.count) == meshName then
					(
						if stripped[meshName.count+1] == "_" then
						(
							local suffix = substring stripped (meshName.count+2) -1
							if isNumeric suffix then
								return meshName
						)
					)
				)
				undefined
			)

			-- ????????(?????????)
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

			--------------------------------------------------------------------------------
			-- ?????
			--------------------------------------------------------------------------------
			-- ?????????
			exportResults = #()
			
			-- ????????????
			allGeom = for obj in geometry where superClassOf obj == GeometryClass collect obj
			
			-- ???????????
			visualMeshes = #()
			collisionObjects = #()
			for obj in allGeom do
			(
				if isCollisionObject obj.name then
					append collisionObjects obj
				else
					append visualMeshes obj
			)
			
			-- ??????????????
			local meshesToExport = #()
			if selection.count > 0 then
			(
				-- ??????????
				for obj in selection do
				(
					if findItem visualMeshes obj != 0 then
						append meshesToExport obj
				)
			)
			else
			(
				-- ????????
				meshesToExport = visualMeshes
			)
			
			-- ??????????,?????
			if meshesToExport.count == 0 do
			(
				messageBox "No visual meshes selected or found in the scene." title:"Export Error"
				return false
			)
			
			-- ???????????????
			local meshNames = for m in visualMeshes collect m.name
			
			-- ????:??? -> ??????
			local collisionDict = #()  -- ????? #(meshName, collisionArray)
			for col in collisionObjects do
			(
				local meshName = findMatchingMeshName col meshNames
				if meshName != undefined then
				(
					-- ????????????
					local entry = undefined
					for i = 1 to collisionDict.count do
						if collisionDict[i][1] == meshName then
						(
							entry = collisionDict[i]
							exit
						)
					if entry == undefined then
					(
						-- ?????
						entry = #(meshName, #(col))
						append collisionDict entry
					)
					else
					(
						-- ???????
						append entry[2] col
					)
				)
				else
				(
					-- ?????:???????????
					format "Warning: Collision object '%' could not be matched to any mesh.\n" col.name
				)
			)
			
			-- ??????,??????
			oldSelection = getCurrentSelection()
			
			-- ???????(????FBX?????)
			firstExport = true
			exportCancelled = false
			
			-- ??????????
			for mesh in meshesToExport while not exportCancelled do
			(
				-- ????????????
				local collisionList = #()
				for entry in collisionDict where entry[1] == mesh.name do
				(
					collisionList = entry[2]
					exit
				)
				
				-- ???????
				fileName = safeFileName mesh.name + ".fbx"
				fullPath = outputDir + "\\" + fileName
				
				-- ????????????
				select mesh
				if collisionList.count > 0 then selectmore collisionList
				
				-- ??????
				if firstExport then
				(
					-- ?????:??FBX?????
					try
					(
						exportFile fullPath selectedOnly:true using:FBXEXP
						firstExport = false
					)
					catch
					(
						-- ???????,????????
						exportCancelled = true
						format "Export cancelled by user or error occurred.\n"
					)
				)
				else
				(
					-- ????:?????????
					exportFile fullPath #noPrompt selectedOnly:true using:FBXEXP
				)
				
				-- ??????(??????)
				if not exportCancelled then
					append exportResults #(mesh.name, (collisionList.count > 0))
				
				-- ????????
				format "Exported: % (with % collision(s)) -> %\n" mesh.name collisionList.count fullPath
			)
			
			-- ???????,????
			if exportCancelled then
				messageBox "Export cancelled by user." title:"Export Cancelled"
			
			-- ??????
			select oldSelection
			
			-- ?????????
			if exportResults.count > 0 then
			(
				rollout summaryRollout "Export Summary"
				(
					ListBox lbxResults "Results:" height:20 width:400
					button btnOK "OK"
					
					on summaryRollout open do
					(
						local items = for res in exportResults collect \
							(res[1] + (if res[2] then " [Collision]" else " [No Collision]"))
						lbxResults.items = items
					)
					on btnOK pressed do destroyDialog summaryRollout
				)
				createDialog summaryRollout width:450 height:400
			)
			
			true
		) -- end of exportMeshesWithCollisions

		--------------------------------------------------------------------------------
		-- ?????:????????????
		lastPath = getINISetting settingsFile "Settings" "LastOutputPath"
		if lastPath == "" or not doesFileExist lastPath then
			initialDir = getDir #export
		else
			initialDir = lastPath

		-- ??????????
		outputDir = getSavePath caption:"Select Output Folder for FBX files" initialDir:initialDir
		if outputDir != undefined do
		(
			-- ??????????
			setINISetting settingsFile "Settings" "LastOutputPath" outputDir
			
			-- ??????
			exportMeshesWithCollisions outputDir
		)

		--------------------------------------------------------------------------------
		-- ??????
	) -- end of btn8 pressed
) -- end of rollout

-- ?????
CreateDialog Maxtool