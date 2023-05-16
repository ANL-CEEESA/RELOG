# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures
using JSON
using JSONSchema
using Printf
using Statistics

"""
    _compress(instance::Instance)

Create a single-period instance from a multi-period one. Specifically,
replaces every time-dependent attribute, such as initial_amounts,
by a list with a single element, which is either a sum, an average,
or something else that makes sense to that specific attribute.
"""
function _compress(instance::Instance)::Instance
    T = instance.time
    compressed = deepcopy(instance)
    compressed.time = 1
    compressed.building_period = [1]

    # Compress products
    for p in compressed.products
        p.acquisition_cost = [mean(p.acquisition_cost)]
        p.disposal_cost = [mean(p.disposal_cost)]
        p.disposal_limit = [sum(p.disposal_limit)]
        p.transportation_cost = [mean(p.transportation_cost)]
        p.transportation_energy = [mean(p.transportation_energy)]
        for (emission_name, emission_value) in p.transportation_emissions
            p.transportation_emissions[emission_name] = [mean(emission_value)]
        end
    end

    # Compress collection centers
    for c in compressed.collection_centers
        c.amount = [maximum(c.amount) * T]
    end

    # Compress plants
    for plant in compressed.plants
        plant.energy = [mean(plant.energy)]
        for (emission_name, emission_value) in plant.emissions
            plant.emissions[emission_name] = [mean(emission_value)]
        end
        for s in plant.sizes
            s.capacity *= T
            s.variable_operating_cost = [mean(s.variable_operating_cost)]
            s.opening_cost = [s.opening_cost[1]]
            s.fixed_operating_cost = [sum(s.fixed_operating_cost)]
        end
        for (prod_name, disp_limit) in plant.disposal_limit
            plant.disposal_limit[prod_name] = [sum(disp_limit)]
        end
        for (prod_name, disp_cost) in plant.disposal_cost
            plant.disposal_cost[prod_name] = [mean(disp_cost)]
        end
    end

    return compressed
end
