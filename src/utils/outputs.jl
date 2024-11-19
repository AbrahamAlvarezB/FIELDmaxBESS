function charge_discharge_dataframe(model::Model, markets, datetimes)
    pc = model[:pc]
    pd = model[:pd]
    df = DataFrame(
        :Date_Time => datetimes,
        :Charge_M1 => value.(pc["m1", datetimes].data),
        :Discharge_M1 => value.(pd["m1", datetimes].data),
    )
    return df
end

function profits_dataframe(model::Model, markets, datetimes, operational_costs, capex)
    rp = model[:raw_profits]
    sp = model[:profits]
    tot_capex = sum(capex)
    df = DataFrame(
        :Date_Time => datetimes,
        :Raw_Profits => value.(rp[datetimes].data),
        :Std_Profits => value.(sp[datetimes].data),
        :Operational_costs => value.(operational_costs[datetimes].data),
        :Total_Capex => fill(tot_capex, length(datetimes)),
    )
    return df
end
