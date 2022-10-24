# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, ProgressBars, Printf, DataStructures, StochasticPrograms

function build_model(
    instance::Instance,
    graphs::Vector{Graph},
    probs::Vector{Float64};
    optimizer,
    method=:ef,
)
    T = instance.time

    @stochastic_model model begin
        # Stage 1: Build plants
        # =====================================================================
        @stage 1 begin
            pn = graphs[1].process_nodes
            PN = length(pn)

            # Var: open_plant
            @decision(
                model,
                open_plant[n in 1:PN, t in 1:T],
                binary = true,
            )

            # Var: is_open
            @decision(
                model,
                is_open[n in 1:PN, t in 1:T],
                binary = true,
            )

            # Objective function
            @objective(
                model,
                Min,

                # Opening, fixed operating costs
                sum(
                    pn[n].location.sizes[1].opening_cost[t] * open_plant[n, t] +
                    pn[n].location.sizes[1].fixed_operating_cost[t] * is_open[n, t]                  
                    for n in 1:PN
                    for t in 1:T
                ),
            )

            for t = 1:T, n in 1:PN
                # Plant is currently open if it was already open in the previous time period or
                # if it was built just now
                if t > 1
                    @constraint(
                        model,
                        is_open[n, t] == is_open[n, t-1] + open_plant[n, t]
                    )
                else
                    @constraint(model, is_open[n, t] == open_plant[n, t])
                end
        
                # Plant can only be opened during building period
                if t ∉ instance.building_period
                    @constraint(model, open_plant[n, t] == 0)
                end
            end
        end

        # Stage 2: Flows, disposal, capacity & storage
        # =====================================================================
        @stage 2 begin
            @uncertain graph
            pn = graph.process_nodes
            psn = graph.plant_shipping_nodes
            csn = graph.collection_shipping_nodes
            arcs = graph.arcs
        
            A = length(arcs)
            PN = length(pn)
            CSN = length(csn)
            PSN = length(psn)

            # Var: flow
            @recourse(
                model,
                flow[a in 1:A, t in 1:T],
                lower_bound = 0,
            )

            # Var: plant_dispose
            @recourse(
                model,
                plant_dispose[n in 1:PSN, t in 1:T],
                lower_bound = 0,
                upper_bound = psn[n].location.disposal_limit[psn[n].product][t],
            )

            # Var: collection_dispose
            @recourse(
                model,
                collection_dispose[n in 1:CSN, t in 1:T],
                lower_bound = 0,
                upper_bound = graph.collection_shipping_nodes[n].location.amount[t],
            )

            # Var: store
            @recourse(
                model,
                store[
                    n in 1:PN,
                    t in 1:T,
                ],
                lower_bound = 0,
                upper_bound = pn[n].location.storage_limit,
            )

            # Var: process
            @recourse(
                model,
                process[
                    n in 1:PN,
                    t in 1:T,
                ],
                lower_bound = 0,
            )

            # Var: capacity
            @recourse(
                model,
                capacity[
                    n in 1:PN,
                    t in 1:T,
                ],
                lower_bound = 0,
                upper_bound = pn[n].location.sizes[2].capacity,
            )

            # Var: expansion
            @recourse(
                model,
                expansion[
                    n in 1:PN,
                    t in 1:T,
                ],
                lower_bound = 0,
                upper_bound = (
                    pn[n].location.sizes[2].capacity -
                    pn[n].location.sizes[1].capacity
                ),
            )

            # Objective function
            @objective(
                model,
                Min,
                sum(
                    # Transportation costs
                    pn[n].location.input.transportation_cost[t] * 
                        a.values["distance"] *
                        flow[a.index,t]

                    for n in 1:PN
                    for a in pn[n].incoming_arcs
                    for t in 1:T
                ) + sum(
                    # Fixed operating costs (expansion)
                    slope_fix_oper_cost(pn[n].location, t) * expansion[n, t] +

                    # Processing costs
                    pn[n].location.sizes[1].variable_operating_cost[t] * process[n, t] +

                    # Storage costs
                    pn[n].location.storage_cost[t] * store[n, t] +

                    # Expansion costs
                    (
                        t < T ? (
                            (
                                slope_open(pn[n].location, t) -
                                slope_open(pn[n].location, t + 1)
                            ) * expansion[n, t]
                        ) : slope_open(pn[n].location, t) * expansion[n, t]
                    )

                    for n in 1:PN
                    for t in 1:T
                ) + sum(
                    # Disposal costs (plants)
                    psn[n].location.disposal_cost[psn[n].product][t] * plant_dispose[n, t]
                    for n in 1:PSN
                    for t in 1:T
                ) + sum(
                    # Disposal costs (collection centers)
                    csn[n].location.product.disposal_cost[t] * collection_dispose[n, t]
                    for n in 1:CSN
                    for t in 1:T
                )
            )

            # Process node constraints
            for t = 1:T, n in 1:PN
                node = pn[n]

                # Output amount is implied by amount processed
                for arc in node.outgoing_arcs
                    @constraint(
                        model,
                        flow[arc.index, t] == arc.values["weight"] * process[n, t]
                    )
                end
        
                # If plant is closed, capacity is zero
                @constraint(
                    model,
                    capacity[n, t] <= node.location.sizes[2].capacity * is_open[n, t]
                )
        
                # If plant is open, capacity is greater than base
                @constraint(
                    model,
                    capacity[n, t] >= node.location.sizes[1].capacity * is_open[n, t]
                )
        
                # Capacity is linked to expansion
                @constraint(
                    model,
                    capacity[n, t] <=
                        node.location.sizes[1].capacity + expansion[n, t]
                )
        
                # Can only process up to capacity
                @constraint(model, process[n, t] <= capacity[n, t])
        
                if t > 1
                    # Plant capacity can only increase over time
                    @constraint(model, capacity[n, t] >= capacity[n, t-1])
                    @constraint(model, expansion[n, t] >= expansion[n, t-1])
                end
        
                # Amount received equals amount processed plus stored
                store_in = 0
                if t > 1
                    store_in = store[n, t-1]
                end
                if t == T
                    @constraint(model, store[n, t] == 0)
                end
                @constraint(
                    model,
                    sum(
                        flow[arc.index, t]
                        for arc in node.incoming_arcs
                    ) + store_in == store[n, t] + process[n, t]
                )

            end

            # Material flow at collection shipping nodes
            @constraint(
                model,
                eq_balance_centers[
                    n in 1:CSN,
                    t in 1:T,
                ],
                sum(
                    flow[arc.index, t]
                    for arc in csn[n].outgoing_arcs
                ) == csn[n].location.amount[t] - collection_dispose[n, t]
            )

            # Material flow at plant shipping nodes
            @constraint(
                model,
                eq_balance_plant[
                    n in 1:PSN,
                    t in 1:T,
                ],
                sum(flow[a.index, t] for a in psn[n].incoming_arcs) ==
                sum(flow[a.index, t] for a in psn[n].outgoing_arcs) +
                plant_dispose[n, t]
            )

            # Enforce product disposal limit at collection centers
            for t in 1:T, prod in instance.products
                if isempty(prod.collection_centers)
                    continue
                end
                @constraint(
                    model,
                    sum(
                        collection_dispose[n, t]
                        for n in 1:CSN
                        if csn[n].product.name == prod.name
                    ) <= prod.disposal_limit[t]
                )
            end
        end
    end

    ξ = [
        @scenario graph = graphs[i] probability = probs[i]
        for i in 1:length(graphs)
    ]

    if method == :ef
        sp = instantiate(model, ξ; optimizer=optimizer)
    elseif method == :lshaped
        sp = instantiate(model, ξ; optimizer=LShaped.Optimizer)
        set_optimizer_attribute(sp, MasterOptimizer(), optimizer)
        set_optimizer_attribute(sp, SubProblemOptimizer(), optimizer)
        set_optimizer_attribute(sp, FeasibilityStrategy(), FeasibilityCuts())
    else
        error("unknown method: $method")
    end

    return sp
end


function slope_open(plant, t)
    if plant.sizes[2].capacity <= plant.sizes[1].capacity
        0.0
    else
        (plant.sizes[2].opening_cost[t] - plant.sizes[1].opening_cost[t]) /
        (plant.sizes[2].capacity - plant.sizes[1].capacity)
    end
end

function slope_fix_oper_cost(plant, t)
    if plant.sizes[2].capacity <= plant.sizes[1].capacity
        0.0
    else
        (plant.sizes[2].fixed_operating_cost[t] - plant.sizes[1].fixed_operating_cost[t]) /
        (plant.sizes[2].capacity - plant.sizes[1].capacity)
    end
end
