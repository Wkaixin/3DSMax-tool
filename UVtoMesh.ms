-- UV to Mesh Tool (With Custom Scale Multiplier)
try(destroyDialog UVtoMeshDialog)catch()

rollout UVtoMeshDialog "UV to Mesh Tool" width:320
(
    pickButton btn_pick "Pick Editable Poly" width:280
    label lbl_obj "Object: None" align:#center
    spinner spn_chan "UV Channel:" range:[1,99,1] type:#integer fieldWidth:60
    checkbox chk_scale "Match source object size" checked:true
    spinner spn_scale "Scale Multiplier:" range:[0.01,100,1.0] type:#float fieldWidth:80 scale:0.01
    checkbox chk_mat "Copy Material" checked:true
    checkbox chk_smooth "Auto Smooth" checked:true
    spinner spn_angle "Smooth Angle:" range:[0,180,45] type:#float enabled:true
    edittext edt_name "Mesh Name:" text:"UV_Mesh" fieldWidth:180
    button btn_gen "Generate UV Mesh" width:280 height:40

    local sourceObj = undefined
    local eps = 1e-5

    on btn_pick picked obj do
    (
        if isKindOf obj Editable_Poly then
        (
            sourceObj = obj
            lbl_obj.text = "Object: " + obj.name
            if edt_name.text == "UV_Mesh" do edt_name.text = obj.name + "_UV_Mesh"
        )
        else
        (
            messageBox "Please select an Editable Poly object." title:"Error"
            sourceObj = undefined
            lbl_obj.text = "Object: None"
        )
    )

    on chk_smooth changed state do spn_angle.enabled = state

    fn findVertexIndexTol vertsArray pos eps =
    (
        for i = 1 to vertsArray.count do
            if (abs(vertsArray[i].x - pos.x) <= eps) and 
               (abs(vertsArray[i].y - pos.y) <= eps) and 
               (abs(vertsArray[i].z - pos.z) <= eps) do
                return i
        return 0
    )

    fn collectUVdataPoly obj chan =
    (
        local verts = #()
        local faces = #()
        local matIDs = #()
        local numFaces = polyop.getNumFaces obj
        
        for f = 1 to numFaces do
        (
            local uvFace = polyop.getMapFace obj chan f
            if uvFace == undefined or uvFace.count < 3 then continue
            
            local uvIndices = for i = 1 to uvFace.count collect uvFace[i]
            local uvPoints = #()
            local valid = true
            for idx in uvIndices do
            (
                local uv = polyop.getMapVert obj chan idx
                if uv == undefined then (valid = false; exit)
                append uvPoints [uv.x, uv.y, 0]
            )
            if not valid or uvPoints.count < 3 then continue
            
            local faceVerts = #()
            for p in uvPoints do
            (
                local i = findVertexIndexTol verts p eps
                if i == 0 then
                (
                    append verts p
                    i = verts.count
                )
                append faceVerts i
            )
            append faces faceVerts
            append matIDs (polyop.getFaceMatID obj f)
        )
        
        if verts.count == 0 then return undefined
        return #(verts, faces, matIDs)
    )

    fn createUVPolyFromFaces uvData name matIDs autoSmooth angle scaleToSource scaleMult srcObj =
    (
        local verts = deepCopy uvData[1]
        local faces = uvData[2]
        local matIDsArray = uvData[3]
        
        -- ==================== ?????? ====================
        if scaleToSource and srcObj != undefined then
        (
            local srcBB = nodeLocalBoundingBox srcObj
            local srcWidth  = srcBB[2].x - srcBB[1].x
            local srcHeight = srcBB[2].y - srcBB[1].y
            local srcCenter = (srcBB[1] + srcBB[2]) / 2.0
            
            local uvMin = [1e9, 1e9, 0]
            local uvMax = [-1e9, -1e9, 0]
            for v in verts do
            (
                uvMin.x = amin uvMin.x v.x
                uvMin.y = amin uvMin.y v.y
                uvMax.x = amax uvMax.x v.x
                uvMax.y = amax uvMax.y v.y
            )
            local uvWidth  = uvMax.x - uvMin.x
            local uvHeight = uvMax.y - uvMin.y
            
            if uvWidth > 0.0001 and uvHeight > 0.0001 then
            (
                local scaleX = srcWidth  / uvWidth
                local scaleY = srcHeight / uvHeight
                local scaleFactor = amax scaleX scaleY
                
                -- ???????????
                scaleFactor *= scaleMult
                
                for i = 1 to verts.count do
                    verts[i] *= scaleFactor
            )
            
            -- ????????
            for i = 1 to verts.count do
                verts[i] += [srcCenter.x, srcCenter.y, 0]
        )
        else
        (
            -- ???????,????????(??UV????)
            if scaleMult != 1.0 then
                for i = 1 to verts.count do
                    verts[i] *= scaleMult
        )
        
        -- ????
        local tempMesh = mesh name:name vertices:verts faces:#()
        local polyObj = convertToPoly tempMesh
        
        local nVerts = polyop.getNumVerts polyObj
        if nVerts > 0 do polyop.deleteVerts polyObj #{1..nVerts}
        
        local vertIndices = for v in verts collect (polyop.createVert polyObj v)
        
        for i = 1 to faces.count do
        (
            local origFace = faces[i]
            local faceVerts = for j = origFace.count to 1 by -1 collect vertIndices[origFace[j]]
            if faceVerts.count >= 3 then
            (
                local newFace = polyop.createPolygon polyObj faceVerts
                if newFace > 0 and matIDsArray[i] != undefined do
                    polyop.setFaceMatID polyObj newFace matIDsArray[i]
            )
        )
        
        if autoSmooth then
        (
            polyObj.autoSmoothThreshold = angle
            polyop.autoSmooth polyObj
        )
        
        -- ????
        local theMesh = snapshotAsMesh polyObj
        meshop.unifyNormals theMesh #{1..(meshop.getNumFaces theMesh)}
        meshop.flipNormals theMesh #{1..(meshop.getNumFaces theMesh)}
        
        local finalMesh = mesh()
        finalMesh.mesh = theMesh
        finalMesh.name = name
        
        local finalPoly = convertToPoly finalMesh
        
        delete theMesh
        delete polyObj
        
        update finalPoly
        return finalPoly
    )

    on btn_gen pressed do
    (
        if sourceObj == undefined then
        (
            messageBox "Please pick an Editable Poly object first." title:"Error"
            return false
        )
        
        local uvChan = spn_chan.value
        local uvData = collectUVdataPoly sourceObj uvChan
        
        if uvData == undefined then
        (
            messageBox ("No valid UV data found in channel " + uvChan as string + ".") title:"Error"
            return false
        )
        
        local meshName = if edt_name.text != "" then edt_name.text else (sourceObj.name + "_UV_Mesh")
        
        local newPoly = createUVPolyFromFaces uvData meshName uvData[3] \
            chk_smooth.checked spn_angle.value chk_scale.checked spn_scale.value sourceObj
        
        if newPoly != undefined then
        (
            if chk_mat.checked and sourceObj.material != undefined do 
                newPoly.material = sourceObj.material
                
            select newPoly
            messageBox ("UV Mesh created successfully!\nVertices: " + uvData[1].count as string + 
                       "\nFaces: " + uvData[2].count as string) title:"Success"
        )
        else
            messageBox "Failed to create mesh." title:"Error"
    )
)

createDialog UVtoMeshDialog