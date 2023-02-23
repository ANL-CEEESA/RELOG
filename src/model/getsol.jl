# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, ProgressBars, Printf, DataStructures

function get_solution(model::JuMP.Model; marginal_costs = true)
    graph, instance = model[:graph], model[:instance]
    T = instance.time

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

    plant_to_process_node = OrderedDict(n.location => n for n in graph.process_nodes)
    plant_to_shipping_nodes = OrderedDict()
    for p in instance.plants
        plant_to_shipping_nodes[p] = []
        for a in plant_to_process_node[p].outgoing_arcs
            push!(plant_to_shipping_nodes[p], a.dest)
        end
    end

    # Products
    for n in graph.collection_shipping_nodes
        location_dict = OrderedDict{Any,Any}(
            "Latitude (deg)" => n.location.latitude,
            "Longitude (deg)" => n.location.longitude,
            "Amount (tonne)" => n.location.amount,
            "Dispose (tonne)" =>
                [JuMP.value(model[:collection_dispose][n, t]) for t = 1:T],
            "Acquisition cost (\$)" => [
                (n.location.amount[t] - JuMP.value(model[:collection_dispose][n, t])) * n.location.product.acquisition_cost[t] for t = 1:T
            ],
            "Disposal cost (\$)" => [
                (
                    JuMP.value(model[:collection_dispose][n, t]) *
                    n.location.product.disposal_cost[t]
                ) for t = 1:T
            ],
        )
        if marginal_costs
            location_dict["Marginal cost (\$/tonne)"] = [
                round(abs(JuMP.shadow_price(model[:eq_balance][n, t])), digits = 2) for
                t = 1:T
            ]
        end
        if n.product.name ∉ keys(output["Products"])
            output["Products"][n.product.name] = OrderedDict()
        end
        output["Products"][n.product.name][n.location.name] = location_dict
    end

    # Plants
    for plant in instance.plants
        skip_plant = true
        process_node = plant_to_process_node[plant]
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
                [JuMP.value(model[:capacity][process_node, t]) for t = 1:T],
            "Opening cost (\$)" => [
                JuMP.value(model[:open_plant][process_node, t]) *
                plant.sizes[1].opening_cost[t] for t = 1:T
            ],
            "Fixed operating cost (\$)" => [
                JuMP.value(model[:is_open][process_node, t]) *
                plant.sizes[1].fixed_operating_cost[t] +
                JuMP.value(model[:expansion][process_node, t]) *
                slope_fix_oper_cost(plant, t) for t = 1:T
            ],
            "Expansion cost (\$)" => [
                (
                    if t == 1
                        slope_open(plant, t) * (
                            JuMP.value(model[:expansion][process_node, t]) -
                            model[:expansion][process_node, 0]
                        )
                    else
                        slope_open(plant, t) * (
                            JuMP.value(model[:expansion][process_node, t]) -
                            JuMP.value(model[:expansion][process_node, t-1])
                        )
                    end
                ) for t = 1:T
            ],
            "Process (tonne)" =>
                [JuMP.value(model[:process][process_node, t]) for t = 1:T],
            "Variable operating cost (\$)" => [
                JuMP.value(model[:process][process_node, t]) *
                plant.sizes[1].variable_operating_cost[t] for t = 1:T
            ],
            "Storage (tonne)" =>
                [JuMP.value(model[:store][process_node, t]) for t = 1:T],
            "Storage cost (\$)" => [
                JuMP.value(model[:store][process_node, t]) * plant.storage_cost[t]
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
            vals = [JuMP.value(model[:flow][a, t]) for t = 1:T]
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
        for shipping_node in plant_to_shipping_nodes[plant]
            product_name = shipping_node.product.name
            plant_dict["Total output"][product_name] = zeros(T)
            plant_dict["Output"]["Send"][product_name] = product_dict = OrderedDict()

            disposal_amount =
                [JuMP.value(model[:plant_dispose][shipping_node, t]) for t = 1:T]
            if sum(disposal_amount) > 1e-5
                skip_plant = false
                plant_dict["Output"]["Dispose"][product_name] =
                    disposal_dict = OrderedDict()
                disposal_dict["Amount (tonne)"] =
                    [JuMP.value(model[:plant_dispose][shipping_node, t]) for t = 1:T]
                disposal_dict["Cost (\$)"] = [
                    disposal_dict["Amount (tonne)"][t] *
                    plant.disposal_cost[shipping_node.product][t] for t = 1:T
                ]
                plant_dict["Total output"][product_name] += disposal_amount
                output["Costs"]["Disposal (\$)"] += disposal_dict["Cost (\$)"]
            end

            for a in shipping_node.outgoing_arcs
                vals = [JuMP.value(model[:flow][a, t]) for t = 1:T]
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
