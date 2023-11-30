using JSON
using OrderedCollections

function parsefile(path::String)::Instance
    return RELOG.parse(JSON.parsefile(path, dicttype = () -> OrderedDict()))
end

function parse(json)::Instance
    # Read parameters
    time_horizon = json["parameters"]["time horizon (years)"]
    building_period = json["parameters"]["building period (years)"]
    distance_metric = json["parameters"]["distance metric"]

    timeseries(x::Union{Nothing,Number}) = repeat([x], time_horizon)
    timeseries(x::Array) = x
    timeseries(d::OrderedDict) = OrderedDict(k => timeseries(v) for (k,v) in d)

    # Read products
    products = Product[]
    products_by_name = OrderedDict{String,Product}()
    for (pname, pdict) in json["products"]
        tr_cost = timeseries(pdict["transportation cost (\$/km/tonne)"])
        tr_energy = timeseries(pdict["transportation energy (J/km/tonne)"])
        tr_emissions = timeseries(pdict["transportation emissions (tonne/km/tonne)"])
        prod = Product(; name = pname, tr_cost, tr_energy, tr_emissions)
        push!(products, prod)
        products_by_name[pname] = prod
    end

    # Read centers
    centers = Center[]
    centers_by_name = OrderedDict{String,Center}()
    for (cname, cdict) in json["centers"]
        latitude = cdict["latitude (deg)"]
        longitude = cdict["longitude (deg)"]
        input = nothing
        revenue = [0.0 for t = 1:time_horizon]
        if cdict["input"] !== nothing
            input = products_by_name[cdict["input"]]
            revenue = timeseries(cdict["revenue (\$/tonne)"])
        end
        outputs = [products_by_name[p] for p in cdict["outputs"]]
        operating_cost = timeseries(cdict["operating cost (\$)"])
        prod_dict(key, null_val) = OrderedDict(
            p => [v === nothing ? null_val : v for v in timeseries(cdict[key][p.name])] for
            p in outputs
        )
        fixed_output = prod_dict("fixed output (tonne)", 0.0)
        var_output = prod_dict("variable output (tonne/tonne)", 0.0)
        collection_cost = prod_dict("collection cost (\$/tonne)", 0.0)
        disposal_limit = prod_dict("disposal limit (tonne)", Inf)
        disposal_cost = prod_dict("disposal cost (\$/tonne)", 0.0)

        center = Center(;
            latitude,
            longitude,
            input,
            outputs,
            revenue,
            operating_cost,
            fixed_output,
            var_output,
            collection_cost,
            disposal_cost,
            disposal_limit,
        )
        push!(centers, center)
        centers_by_name[cname] = center
    end

    return Instance(;
        time_horizon,
        building_period,
        distance_metric,
        products,
        products_by_name,
        centers,
        centers_by_name,
    )
end
