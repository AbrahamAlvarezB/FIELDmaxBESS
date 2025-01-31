# Define functions so that `latex` can be dispatched over them
function con_state_of_charge! end
function con_charge_discharge_rates! end
function con_max_cycles! end
function con_profits_over_time! end

# State of Charge Constraint
function latex(::typeof(con_state_of_charge!))
    return """
        ``s_{t} = \\gamma_s s_{t-1} + \\tau \\sum_{m \\in \\mathcal{M}} [\\gamma_c pc_{m, t} - ( pd_{m, t}  / \\gamma_d )  ] \\forall m \\in \\mathcal{M}, t \\in \\mathcal{T}``
        """
end

"""
    con_state_of_charge!(model::Model, gamma_s, gamma_c, gamma_d, datetimes)

Add State of charge constraints to the model:

$(latex(con_state_of_charge!))

The constraints are named `con_state_of_charge` and `con_state_of_charge_initial`.
"""
function con_state_of_charge!(model::Model, gamma_s, gamma_c, gamma_d, markets, datetimes)
    # Get variables and time steps
    s = model[:s]
    pc = model[:pc]
    pd = model[:pd]
    Δh = first(diff(datetimes))
    h1 = first(datetimes)
    tau = 1 # One half an hour since S_max = MWh and 0 <= s_t <= S_max/2
    @constraint(
        model,
        con_state_of_charge[t in datetimes[2:end]],
        s[t] == gamma_s * s[t-Δh] + tau * sum(
            gamma_c * pc[m, t] - (pd[m, t] / gamma_d) for m in markets
        )
    )
    @constraint(
        model,
        con_state_of_charge_initial,
        s[h1] == 0.0
    )
    return model
end

# Charging and Discharging Rates
function latex(::typeof(con_charge_discharge_rates!))
    return """
        ``0 \\leq \\sum_{m \\in \\mathcal{M}} [pc_{m, t}] \\leq RR_c \\forall m \\in \\mathcal{M}, t \\in \\mathcal{T}`` \n
        ``0 \\leq \\sum_{m \\in \\mathcal{M}} [pd_{m, t}] \\leq RR_d \\forall m \\in \\mathcal{M}, t \\in \\mathcal{T}``
        """
end
"""
    con_charge_discharge_rates!(model::Model, RR_c, RR_d, markets, datetimes)

Add charge and discharge rates limit constraints to the model:

$(latex(con_charge_discharge_rates!))

The constraints added are named `con_charge_rate_lo`, `con_charge_rate_hi`,
`con_discharge_rate_lo`, `con_discharge_rate_hi` and their initials.
"""
function con_charge_discharge_rates!(model::Model, RR_c, RR_d, markets, datetimes)
    # Get variables and time steps
    pc = model[:pc]
    pd = model[:pd]
    h1 = first(datetimes)
    # Low Boundaries
    @constraint(
        model,
        con_charge_rate_lo[t in datetimes[2:end]],
        0.0 <= sum(pc[m, t] for m in markets)
    )
    @constraint(
        model,
        con_discharge_rate_lo[t in datetimes[2:end]],
        0.0 <= sum(pd[m, t] for m in markets)
    )
    # High Boundaries
    @constraint(
        model,
        con_charge_rate_hi[t in datetimes[2:end]],
        sum(pc[m, t] for m in markets) <= RR_c
    )
    @constraint(
        model,
        con_discharge_rate_hi[t in datetimes[2:end]],
        sum(pd[m, t] for m in markets) <= RR_d
    )
    # Initial States
    @constraint(
        model,
        con_charge_rate_initial,
        sum(pc[m, h1] for m in markets) == 0.0
    )
    @constraint(
        model,
        con_discharge_rate_initial,
        sum(pd[m, h1] for m in markets) == 0.0
    )
    return model
end


# Cycle lifetime constraints
function latex(::typeof(con_max_cycles!))
    return """
        ``z = \\sum_{t \\in \\mathcal{T}} [ \\sum_{m \\in \\mathcal{M}} [((100 \\tau pd_{m, t}) / (S_max/2))/100 ] ]  `` \n
        """
end
"""
    con_max_cycles!(model::Model, lifetime_cycles, S_max, markets, datetimes)

Add Maximum battery lifetime constraint in battery cycles equivalent - one cycle is defined
as charging up to max storage volume and then discharging all stored energy. This does not
have to be done in one go - e.g. charging up to 75%, discharging to 0%, then charging up to
25% and discharging to 0% still counts as one cycle.

$(latex(con_max_cycles!))

The constraints added are named `con_total_cycles` and `con_max_cycles`.
"""
function con_max_cycles!(model::Model, lifetime_cycles, S_max, markets, datetimes)
    # Get variables and time steps
    z = model[:z]
    pd = model[:pd]
    # Add constraints for max cycles
    @constraint(
        model,
        con_total_cycles,
        z == S_max * sum(pd[m, t] for m in markets, t in datetimes)
    )
    @constraint(
        model,
        con_max_cycles,
        z <= lifetime_cycles
    )
    return model
end

# Profits over time
function latex(::typeof(con_profits_over_time!))
    return """
        ``profits[t] = \\sum_{m \\in \\mathcal{M}} [ \\Lambda_{m, t} ( pd_{m, t} - pc_{m, t} )] \\tau - capex[t] - operational_costs[t]``
    """
end
"""
    con_profits_over_time!(model::Model, price, operational_costs, capex, markets, datetimes)

Add Profits calculation minus operational fees and capex.

$(latex(con_profits_over_time!))

The constraints added are named `con_profits_over_time`.
"""
function con_profits_over_time!(model::Model, price, operational_costs, capex, markets, datetimes)
    # Get variables
    pd = model[:pd]
    pc = model[:pc]
    profits = model[:profits]
    raw_profits = model[:raw_profits]
    Δh = first(diff(datetimes))
    h1 = first(datetimes)
    # Add constraints for calculation over time.
    @constraint(
        model,
        con_profits_over_time[t in datetimes[2:end]],
        profits[t] == profits[t-Δh] + sum(price[m, t] * (pd[m, t] - pc[m, t]) for m in markets) - operational_costs[t]
    )
    @constraint(
        model,
        con_profits_over_time_initial,
        profits[h1] == sum(price[m, h1] * (pd[m, h1] - pc[m, h1]) for m in markets) - operational_costs[h1] - sum(capex)
    )
    @constraint(
        model,
        con_raw_profits_over_time[t in datetimes[2:end]],
        raw_profits[t] == raw_profits[t-Δh] + sum(price[m, t] * (pd[m, t] - pc[m, t]) for m in markets)
    )
    @constraint(
        model,
        con_raw_profits_over_time_initial,
        raw_profits[h1] == sum(price[m, h1] * (pd[m, h1] - pc[m, h1]) for m in markets)
    )
    return model
end
