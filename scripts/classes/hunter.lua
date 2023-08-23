function MS:HR_GetBeastAttackSpeed()
    local name = GetUnitName("target")
    local speed = UnitAttackSpeedTarget("target")

    MS:Print(name .. ": atk. speed is " .. speed)
end
