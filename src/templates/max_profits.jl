"""
    build_max_BESS_profits(
        solver,
        markets,
        datetimes,
        price,
        S_min,
        S_max,
        gamma_s,
        gamma_c,
        gamma_d,
        RR_c,
        RR_d,
        operational_costs,
        capex;
        consider_lifetime = false,
        lifetime_cycles = 5000,
        consider_fees = consider_fees,
    ) -> Model

Defines the model template that maximises the profits of a Battery Energy Storage System
with the following formulation:

$(_write_formulation(
    objectives=[
        latex(obj_raw_profits!)
    ],
    constraints=[
        latex(con_state_of_charge!),
        latex(con_charge_discharge_rates!),
        latex(con_max_cycles!),
    ],
    variables=[
        latex(var_charge_discharge!),
        latex(var_state_of_charge!),
        latex(var_cycles!),
    ]
))

# Arguments
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `markets`: The markets IDs
 - `datetimes`: The time periods considered in the model.
 - `price`: The set of prices for each market and each period within datetimes
 - `S_min`: Min Storage Volume [MW/h]
 - `S_max`: Max Storage Volume [MW/h]
 - `gamma_s`: Battery storage efficiency [fraction]
 - `gamma_c`: Battery charging efficiency [fraction]
 - `gamma_d`: Battery discharging efficiency [fraction]
 - `RR_c`: Max charging rate [MW]
 - `RR_d`: Max discharging rate [MW]
 - `operational_costs`: DenseAxisArray Cost per year £/year divided by all datetimes
 - `capex`: DenseAxisArray Cost purchasing and installing the battery divided by all datetimes

# Keywords
 - `consider_lifetime = false`: If set to `true`, battery lifetime will be considered.
 - `lifetime_cycles = 5000`: Maximum battery lifetime in battery cycles equivalent.
 - `consider_fees = false`: If set to `true`, battery fees will be considered.
"""
function build_max_BESS_profits(
    solver,
    markets,
    datetimes,
    price,
    S_min,
    S_max,
    gamma_s,
    gamma_c,
    gamma_d,
    RR_c,
    RR_d,
    operational_costs,
    capex;
    consider_lifetime=false,
    lifetime_cycles=5000,
    consider_fees=false
)
    # Create basic Model
    model = Model(solver)
    # Variables
    var_charge_discharge!(model, RR_c, RR_d, markets, datetimes)
    var_state_of_charge!(model, S_min, S_max, datetimes)
    if consider_lifetime == true
        var_cycles!(model)
    end
    var_profits_over_time!(model, datetimes)
    # Constraints
    con_state_of_charge!(model, gamma_s, gamma_c, gamma_d, markets, datetimes)
    con_charge_discharge_rates!(model, RR_c, RR_d, markets, datetimes)
    if consider_lifetime == true
        con_max_cycles!(model, lifetime_cycles, S_max, markets, datetimes)
    end
    if consider_fees == true
        con_profits_over_time!(model, price, operational_costs, capex, markets, datetimes)
    else
        con_profits_over_time!(model, price, markets, datetimes)
    end
    # Objectives
    obj_raw_profits!(model, price, datetimes, markets)
    # Optimizer
    set_optimizer(model, solver)
    return model
end
