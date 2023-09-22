function MS:WAR_Damage()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return end

    -- Start melee auto attacking
    if not MS.isMeleeAttacking then AttackTarget("target") end

    local rage = UnitMana("player")
    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local isEnemyCaster = MS:IsEnemyCaster()
    local isClose = CheckInteractDistance("target", 3)
    local inInstance = IsInInstance()
    local yieldsHonorOrExp = MS:YieldsHonorOrExp()

    -- TODO: requires 10 rage, decide when to use it
    local haveDemoShout = MS:FindBuff("Demoralizing Shout", "target")

    if not haveDemoShout then
        local hasCast = MS:CastSpell("Demoralizing Shout")
        if hasCast then return end
    end

    -- TODO: requires 10 rage, decide when to use it
    local haveBattleShout = MS:FindBuff("Battle Shout", "player")

    if not haveBattleShout then
        local hasCast = MS:CastSpell("Battle Shout")
        if hasCast then return end
    end
end

function MS:WAR_Protect()
end

function MS:WAR_AOE()
end
