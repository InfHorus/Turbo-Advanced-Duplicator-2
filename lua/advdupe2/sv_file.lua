





local function SaveFile(ply, cmd, args)
    if(not ply.AdvDupe2 or not ply.AdvDupe2.Entities or next(ply.AdvDupe2.Entities)==nil)then 
        AdvDupe2.Notify(ply,"Duplicator is empty, nothing to save.", NOTIFY_ERROR) 
        return 
    end
    
    if(not game.SinglePlayer() and CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
        AdvDupe2.Notify(ply,"Cannot save at the moment. Please Wait...", NOTIFY_ERROR)
        return
    end
    
    if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
        AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
        return false 
    end

    ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay")+2)
    
    local name = string.Explode("/", args[1])
    ply.AdvDupe2.Name = name[#name]
    
    -- Send dupe info using express
    express.Send("AdvDupe2_SetDupeInfo", {
        name = ply.AdvDupe2.Name,
        player = ply:Nick(),
        date = os.date("%d %B %Y"),
        time = os.date("%I:%M %p"),
        blank = "", -- Maintaining original empty string field
        description = args[2] or "",
        entities = table.Count(ply.AdvDupe2.Entities),
        constraints = #ply.AdvDupe2.Constraints
    }, ply)
    
    local Tab = {
        Entities = ply.AdvDupe2.Entities, 
        Constraints = ply.AdvDupe2.Constraints, 
        HeadEnt = ply.AdvDupe2.HeadEnt, 
        Description = args[2]
    }

    AdvDupe2.Encode(Tab, AdvDupe2.GenerateDupeStamp(ply), function(data)
        AdvDupe2.SendToClient(ply, data, 0)
    end)
end
concommand.Add("AdvDupe2_SaveFile", SaveFile)

function AdvDupe2.SendToClient(ply, data, autosave)
    if(not IsValid(ply))then return end
    if #data > AdvDupe2.MaxDupeSize then
        AdvDupe2.Notify(ply,"Copied duplicator filesize is too big!",NOTIFY_ERROR)
        return
    end

    ply.AdvDupe2.Downloading = true
    AdvDupe2.InitProgressBar(ply,"Saving:")

    -- Send file data using express
    express.Send("AdvDupe2_ReceiveFile", {
        autosave = autosave,
        data = data
    }, ply, function()
        ply.AdvDupe2.Downloading = false
    end)
end

function AdvDupe2.LoadDupe(ply, success, dupe, info, moreinfo)
    if(not IsValid(ply))then return end
            
    if not success then 
        AdvDupe2.Notify(ply,"Could not open "..dupe,NOTIFY_ERROR)
        return
    end
            
    if(not game.SinglePlayer())then
        if(tonumber(GetConVarString("AdvDupe2_MaxConstraints"))~=0 and #dupe["Constraints"]>tonumber(GetConVarString("AdvDupe2_MaxConstraints")))then
            AdvDupe2.Notify(ply,"Amount of constraints is greater than "..GetConVarString("AdvDupe2_MaxConstraints"),NOTIFY_ERROR)
            return false
        end
    end

    ply.AdvDupe2.Entities = {}
    ply.AdvDupe2.Constraints = {}
    ply.AdvDupe2.HeadEnt={}
    ply.AdvDupe2.Revision = info.revision

    if(info.ad1)then
        ply.AdvDupe2.HeadEnt.Index = tonumber(moreinfo.Head)
        local spx,spy,spz = moreinfo.StartPos:match("^(.-),(.-),(.+)$")
        ply.AdvDupe2.HeadEnt.Pos = Vector(tonumber(spx) or 0, tonumber(spy) or 0, tonumber(spz) or 0)
        local z = (tonumber(moreinfo.HoldPos:match("^.-,.-,(.+)$")) or 0)*-1
        ply.AdvDupe2.HeadEnt.Z = z
        ply.AdvDupe2.HeadEnt.Pos.Z = ply.AdvDupe2.HeadEnt.Pos.Z + z
        local Pos
        local Ang
        for k,v in pairs(dupe["Entities"])do
            Pos = nil
            Ang = nil
            if(v.SavedParentIdx)then 
                if(not v.BuildDupeInfo)then v.BuildDupeInfo = {} end
                v.BuildDupeInfo.DupeParentID = v.SavedParentIdx
                Pos = v.LocalPos*1
                Ang = v.LocalAngle*1
            end
            for i,p in pairs(v.PhysicsObjects)do
                p.Pos = Pos or (p.LocalPos*1)
                p.Pos.Z = p.Pos.Z - z
                p.Angle = Ang or (p.LocalAngle*1)
                p.LocalPos = nil
                p.LocalAngle = nil
                p.Frozen = not p.Frozen
            end
            v.LocalPos = nil
            v.LocalAngle = nil
        end

        ply.AdvDupe2.Entities = dupe["Entities"]
        ply.AdvDupe2.Constraints = dupe["Constraints"]
        
    else    
        ply.AdvDupe2.Entities = dupe["Entities"]
        ply.AdvDupe2.Constraints = dupe["Constraints"]
        ply.AdvDupe2.HeadEnt = dupe["HeadEnt"]
    end
    AdvDupe2.ResetOffsets(ply, true)
end

-- Setup receivers when Express is loaded
hook.Add("ExpressLoaded", "AdvDupe2_SetupExpress", function()
    express.Receive("AdvDupe2_ReceiveFile", function(ply, data)
        if not IsValid(ply) then return end
        if not ply.AdvDupe2 then ply.AdvDupe2 = {} end

        ply.AdvDupe2.Name = string.match(data.name, "([%w_ ]+)") or "Advanced Duplication"

        if ply.AdvDupe2.Uploading then
            AdvDupe2.Notify(ply, "Duplicator is Busy!", NOTIFY_ERROR, 5)
            return
        end

        ply.AdvDupe2.Uploading = true
        AdvDupe2.InitProgressBar(ply, "Opening: ")

        local success, dupe, info, moreinfo = AdvDupe2.Decode(data.fileData)
        if success then
            AdvDupe2.LoadDupe(ply, success, dupe, info, moreinfo)
        else
            AdvDupe2.Notify(ply, "Duplicator Upload Failed!", NOTIFY_ERROR, 5)
        end
        ply.AdvDupe2.Uploading = false
    end)
end)