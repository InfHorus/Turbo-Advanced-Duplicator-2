function AdvDupe2.SendGhost(ply, AddOne)
    express.Send("AdvDupe2_AddGhost", {
        Model = AddOne.Model,
        PhysicsObjects = AddOne.PhysicsObjects
    }, ply)
end

function AdvDupe2.SendGhosts(ply)
    if(not ply.AdvDupe2.Entities)then return end

    local cache = {}
    local temp = {}
    local mdls = {}
    local cnt = 1
    local add = true
    local head

    for k,v in pairs(ply.AdvDupe2.Entities)do
        temp[cnt] = v
        for i=1,#cache do
            if(cache[i]==v.Model)then
                mdls[cnt] = i
                add=false
                break
            end
        end
        if(add)then
            mdls[cnt] = table.insert(cache, v.Model)
        else
            add = true
        end
        if(k==ply.AdvDupe2.HeadEnt.Index)then
            head = cnt
        end
        cnt = cnt+1
    end

    if(!head)then
        AdvDupe2.Notify(ply, "Invalid head entity for ghosts.", NOTIFY_ERROR);
        return
    end

    -- Build ghost data array
    local ghostData = {}
    for i=1, #temp do
        ghostData[i] = {
            model = mdls[i],
            physicsObjects = temp[i].PhysicsObjects
        }
    end

    -- Send everything in one message
    express.Send("AdvDupe2_SendGhosts", {
        head = head,
        headZ = ply.AdvDupe2.HeadEnt.Z,
        headPos = ply.AdvDupe2.HeadEnt.Pos,
        models = cache,
        ghostData = ghostData
    }, ply)
end