# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, ProgressBars, Printf, DataStructures

function get_solution(
    instance,
    graph,
    model,
    scenario_index::Int;
    marginal_costs=false,
)
    value(x) = StochasticPrograms.value(x, scenario_index)
    ivalue(x) = StochasticPrograms.value(x)
    shadow_price(x) = StochasticPrograms.shadow_price(x, scenario_index)

    T = instance.time

    pn = graph.process_nodes
    psn = graph.plant_shipping_nodes
    csn = graph.collection_shipping_nodes
    arcs = graph.arcs

    A = length(arcs)
    PN = length(pn)
    CSN = length(csn)
    PSN = length(psn)

    flow = model[2, :flow]

    output = OrderedDict(
        "Plants" => OrderedDict(),
        "Products" => OrderedDict(),
        "Costs" => OrderedDict(
            "Fixed operating (\$)" => zeros(T),
            "Variable operating (\$)" => zeros(T),
            "Opening (\$)" => zeros(T),
            "Transportation (\$)" => zeros(T),
            "Disposal (\$)" => zeros(T),
            "Expansion (\$)" => zeros(T),
            "Storage (\$)" => zeros(T),
            "Total (\$)" => zeros(T),
        ),
        "Energy" =>
            OrderedDict("Plants (GJ)" => zeros(T), "Transportation (GJ)" => zeros(T)),
        "Emissions" => OrderedDict(
            "Plants (tonne)" => OrderedDict(),
            "Transportation (tonne)" => OrderedDict(),
        ),
    )

    pn = graph.process_nodes
    psn = graph.plant_shipping_nodes

    plant_to_process_node_index = OrderedDict(
        pn[n].location => n
        for n in 1:length(pn)
    )

    plant_to_shipping_node_indices = OrderedDict(p => [] for p in instance.plants)
    for n in 1:length(psn)
        push!(plant_to_shipping_node_indices[psn[n].location], n)
    end

    # Products
    for n in 1:CSN
        node = csn[n]
        location_dict = OrderedDict{Any,Any}(
            "Latitude (deg)" => node.location.latitude,
            "Longitude (deg)" => node.location.longitude,
            "Amount (tonne)" => node.location.amount,
            "Dispose (tonne)" => [
                value(model[2, :collection_dispose][n, t])
                for t = 1:T
            ],
            "Disposal cost (\$)" => [
                value(model[2, :collection_dispose][n, t]) *
                    node.location.product.disposal_cost[t]
                for t = 1:T
            ]
        )
        if marginal_costs
            location_dict["Marginal cost (\$/tonne)"] = [
                round(abs(shadow_price(model[2, :eq_balance_centers][n, t])), digits=2) for t = 1:T
            ]
        end
        if node.product.name ∉ keys(output["Products"])
            output["Products"][node.product.name] = OrderedDict()
        end
        output["Products"][node.product.name][node.location.name] = location_dict
    end

    # Plants
    for plant in instance.plants
        skip_plant = true
        n = plant_to_process_node_index[plant]
        process_node = pn[n]
        plant_dict = OrderedDict{Any,Any}(
            "Input" => OrderedDict(),
            "Output" =>
                OrderedDict("Send" => OrderedDict(), "Dispose" => OrderedDict()),
            "Input product" => plant.input.name,
            "Total input (tonne)" => [0.0 for t = 1:T],
            "Total output" => OrderedDict(),
            "Latitude (deg)" => plant.latitude,
            "Longitude (deg)" => plant.longitude,
            "Capacity (tonne)" =>
                [value(model[2, :capacity][n, t]) for t = 1:T],
            "Opening cost (\$)" => [
                ivalue(model[1, :open_plant][n, t]) *
                plant.sizes[1].opening_cost[t] for t = 1:T
            ],
            "Fixed operating cost (\$)" => [
                ivalue(model[1, :is_open][n, t]) *
                plant.sizes[1].fixed_operating_cost[t] +
                value(model[2, :expansion][n, t]) *
                slope_fix_oper_cost(plant, t) for t = 1:T
            ],
            "Expansion cost (\$)" => [
                (
                    if t == 1
                        slope_open(plant, t) * value(model[2, :expansion][n, t])
                    else
                        slope_open(plant, t) * (
                            value(model[2, :expansion][n, t]) -
                            value(model[2, :expansion][n, t-1])
                        )
                    end
                ) for t = 1:T
            ],
            "Process (tonne)" =>
                [value(model[2, :process][n, t]) for t = 1:T],
            "Variable operating cost (\$)" => [
                value(model[2, :process][n, t]) *
                plant.sizes[1].variable_operating_cost[t] for t = 1:T
            ],
            "Storage (tonne)" =>
                [value(model[2, :store][n, t]) for t = 1:T],
            "Storage cost (\$)" => [
                value(model[2, :store][n, t]) * plant.storage_cost[t]
                for t = 1:T
            ],
        )
        output["Costs"]["Fixed operating (\$)"] += plant_dict["Fixed operating cost (\$)"]
        output["Costs"]["Variable operating (\$)"] +=
            plant_dict["Variable operating cost (\$)"]
        output["Costs"]["Opening (\$)"] += plant_dict["Opening cost (\$)"]
        output["Costs"]["Expansion (\$)"] += plant_dict["Expansion cost (\$)"]
        output["Costs"]["Storage (\$)"] += plant_dict["Storage cost (\$)"]

        # Inputs
        for a in process_node.incoming_arcs
            vals = [value(flow[a.index, t]) for t = 1:T]
            if sum(vals) <= 1e-3
                continue
            end
            skip_plant = false
            dict = OrderedDict{Any,Any}(
                "Amount (tonne)" => vals,
                "Distance (km)" => a.values["distance"],
                "Latitude (deg)" => a.source.location.latitude,
                "Longitude (deg)" => a.source.location.longitude,
                "Transportation cost (\$)" =>
                    a.source.product.transportation_cost .* vals .* a.values["distance"],
                "Transportation energy (J)" =>
                    vals .* a.values["distance"] .* a.source.product.transportation_energy,
                "Emissions (tonne)" => OrderedDict(),
            )
            emissions_dict = output["Emissions"]["Transportation (tonne)"]
            for (em_name, em_values) in a.source.product.transportation_emissions
                dict["Emissions (tonne)"][em_name] =
                    em_values .* dict["Amount (tonne)"] .* a.values["distance"]
                if em_name ∉ keys(emissions_dict)
                    emissions_dict[em_name] = zeros(T)
                end
                emissions_dict[em_name] += dict["Emissions (tonne)"][em_name]
            end
            if a.source.location isa CollectionCenter
                plant_name = "Origin"
                location_name = a.source.location.name
            else
                plant_name = a.source.location.plant_name
                location_name = a.source.location.location_name
            end

            if plant_name ∉ keys(plant_dict["Input"])
                plant_dict["Input"][plant_name] = OrderedDict()
            end
            plant_dict["Input"][plant_name][location_name] = dict
            plant_dict["Total input (tonne)"] += vals
            output["Costs"]["Transportation (\$)"] += dict["Transportation cost (\$)"]
            output["Energy"]["Transportation (GJ)"] +=
                dict["Transportation energy (J)"] / 1e9
        end

        plant_dict["Energy (GJ)"] = plant_dict["Total input (tonne)"] .* plant.energy
        output["Energy"]["Plants (GJ)"] += plant_dict["Energy (GJ)"]

        plant_dict["Emissions (tonne)"] = OrderedDict()
        emissions_dict = output["Emissions"]["Plants (tonne)"]
        for (em_name, em_values) in plant.emissions
            plant_dict["Emissions (tonne)"][em_name] =
                em_values .* plant_dict["Total input (tonne)"]
            if em_name ∉ keys(emissions_dict)
                emissions_dict[em_name] = zeros(T)
            end
            emissions_dict[em_name] += plant_dict["Emissions (tonne)"][em_name]
        end

        # Outputs
        for n2 in plant_to_shipping_node_indices[plant]
            shipping_node = psn[n2]
            product_name = shipping_node.product.name
            plant_dict["Total output"][product_name] = zeros(T)
            plant_dict["Output"]["Send"][product_name] = product_dict = OrderedDict()

            disposal_amount =
                [value(model[2, :plant_dispose][n2, t]) for t = 1:T]
            if sum(disposal_amount) > 1e-5
                skip_plant = false
                plant_dict["Output"]["Dispose"][product_name] =
                    disposal_dict = OrderedDict()
                disposal_dict["Amount (tonne)"] =
                    [value(model[2, :plant_dispose][n2, t]) for t = 1:T]
                disposal_dict["Cost (\$)"] = [
                    disposal_dict["Amount (tonne)"][t] *
                    plant.disposal_cost[shipping_node.product][t] for t = 1:T
                ]
                plant_dict["Total output"][product_name] += disposal_amount
                output["Costs"]["Disposal (\$)"] += disposal_dict["Cost (\$)"]
            end

            for a in shipping_node.outgoing_arcs
                vals = [value(flow[a.index, t]) for t = 1:T]
                if sum(vals) <= 1e-3
                    continue
                end
                skip_plant = false
                dict = OrderedDict(
                    "Amount (tonne)" => vals,
                    "Distance (km)" => a.values["distance"],
                    "Latitude (deg)" => a.dest.location.latitude,
                    "Longitude (deg)" => a.dest.location.longitude,
                )
                if a.dest.location.plant_name ∉ keys(product_dict)
                    product_dict[a.dest.location.plant_name] = OrderedDict()
                end
                product_dict[a.dest.location.plant_name][a.dest.location.location_name] =
                    dict
                plant_dict["Total output"][product_name] += vals
            end
        end

        if !skip_plant
            if plant.plant_name ∉ keys(output["Plants"])
                output["Plants"][plant.plant_name] = OrderedDict()
            end
            output["Plants"][plant.plant_name][plant.location_name] = plant_dict
        end
    end

    output["Costs"]["Total (\$)"] = sum(values(output["Costs"]))
    return output
end
