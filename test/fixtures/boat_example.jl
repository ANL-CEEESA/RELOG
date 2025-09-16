using OrderedCollections
using JSON
using RELOG
dict = OrderedDict

function run_boat_example()
    cities_a = dict(
        "Chicago" => [41.881832, -87.623177],
        "New York City" => [40.712776, -74.005974],
        "Los Angeles" => [34.052235, -118.243683],
        "Houston" => [29.760427, -95.369804],
        "Phoenix" => [33.448376, -112.074036],
        "Philadelphia" => [39.952583, -75.165222],
        "San Antonio" => [29.424122, -98.493629],
        "San Diego" => [32.715736, -117.161087],
        "Dallas" => [32.776664, -96.796988],
        "San Jose" => [37.338208, -121.886329],
    )

    cities_b = dict(
        "Chicago" => [41.881832, -87.623177],
        "Phoenix" => [33.448376, -112.074036],
        "Dallas" => [32.776664, -96.796988],
    )

    parameters = dict(
        "time horizon (years)" => 5,
        "building period (years)" => [1],
        "distance metric" => "Euclidean",
    )

    nail_factory = dict(
        "input" => nothing,
        "outputs" => ["Nail"],
        "fixed output (tonne)" => dict("Nail" => 1),
        "variable output (tonne/tonne)" => dict("Nail" => 0),
        "revenue (\$/tonne)" => nothing,
        "collection cost (\$/tonne)" => dict("Nail" => 1000),
        "operating cost (\$)" => 0,
        "disposal limit (tonne)" => dict("Nail" => nothing),
        "disposal cost (\$/tonne)" => dict("Nail" => 0),
    )

    forest = dict(
        "input" => nothing,
        "outputs" => ["Wood"],
        "fixed output (tonne)" => dict("Wood" => 100),
        "variable output (tonne/tonne)" => dict("Wood" => 0),
        "revenue (\$/tonne)" => nothing,
        "collection cost (\$/tonne)" => dict("Wood" => 250),
        "operating cost (\$)" => 0,
        "disposal limit (tonne)" => dict("Wood" => nothing),
        "disposal cost (\$/tonne)" => dict("Wood" => 0),
    )

    retail = dict(
        "input" => "NewBoat",
        "outputs" => ["UsedBoat"],
        "fixed output (tonne)" => dict("UsedBoat" => 0),
        "variable output (tonne/tonne)" => dict("UsedBoat" => [0.10, 0.25, 0.10]),
        "revenue (\$/tonne)" => 12_000,
        "collection cost (\$/tonne)" => dict("UsedBoat" => 100),
        "operating cost (\$)" => 125_000,
        "disposal limit (tonne)" => dict("UsedBoat" => 0),
        "disposal cost (\$/tonne)" => dict("UsedBoat" => 0),
    )

    prod = dict(
        "transportation cost (\$/km/tonne)" => 0.30,
        "transportation energy (J/km/tonne)" => 7_500,
        "transportation emissions (tonne/km/tonne)" => dict("CO2" => 2.68),
    )

    boat_factory = dict(
        "input mix (%)" => dict("Wood" => 95, "Nail" => 5),
        "output (tonne)" => dict("NewBoat" => 1.0),
        "processing emissions (tonne)" => dict("CO2" => 5),
        "storage cost (\$/tonne)" => dict("Wood" => 500, "Nail" => 200),
        "storage limit (tonne)" => dict("Wood" => 5, "Nail" => 1),
        "disposal cost (\$/tonne)" => dict("NewBoat" => 0),
        "disposal limit (tonne)" => dict("NewBoat" => 0),
        "capacities" => [
            dict(
                "size (tonne)" => 500,
                "opening cost (\$)" => 1_00_000,
                "fixed operating cost (\$)" => 250_000,
                "variable operating cost (\$/tonne)" => 5,
            ),
            dict(
                "size (tonne)" => 1000,
                "opening cost (\$)" => 2_000_000,
                "fixed operating cost (\$)" => 500_000,
                "variable operating cost (\$/tonne)" => 5,
            ),
        ],
        "initial capacity (tonne)" => 0,
    )

    recycling_plant = dict(
        "input mix (%)" => dict("UsedBoat" => 100),
        "output (tonne)" => dict("Nail" => 0.025, "Wood" => 0.475),
        "processing emissions (tonne)" => dict("CO2" => 5),
        "storage cost (\$/tonne)" => dict("UsedBoat" => 0),
        "storage limit (tonne)" => dict("UsedBoat" => 0),
        "disposal cost (\$/tonne)" => dict("Nail" => 0, "Wood" => 0),
        "disposal limit (tonne)" => dict("Nail" => 0, "Wood" => 0),
        "capacities" => [
            dict(
                "size (tonne)" => 500,
                "opening cost (\$)" => 500_000,
                "fixed operating cost (\$)" => 125_000,
                "variable operating cost (\$/tonne)" => 2.5,
            ),
            dict(
                "size (tonne)" => 1000,
                "opening cost (\$)" => 1_000_000,
                "fixed operating cost (\$)" => 250_000,
                "variable operating cost (\$/tonne)" => 2.5,
            ),
        ],
        "initial capacity (tonne)" => 0,
    )

    lat_lon_dict(city_location) =
        dict("latitude (deg)" => city_location[1], "longitude (deg)" => city_location[2])

    data = dict(
        "parameters" => parameters,
        "products" =>
            dict("Nail" => prod, "Wood" => prod, "NewBoat" => prod, "UsedBoat" => prod),
        "centers" => merge(
            dict(
                "NailFactory ($city_name)" =>
                    merge(nail_factory, lat_lon_dict(city_location)) for
                (city_name, city_location) in cities_b
            ),
            dict(
                "Forest ($city_name)" => merge(forest, lat_lon_dict(city_location))
                for (city_name, city_location) in cities_b
            ),
            dict(
                "Retail ($city_name)" => merge(retail, lat_lon_dict(city_location))
                for (city_name, city_location) in cities_a
            ),
        ),
        "plants" => merge(
            dict(
                "BoatFactory ($city_name)" =>
                    merge(boat_factory, lat_lon_dict(city_location)) for
                (city_name, city_location) in cities_a
            ),
            dict(
                "RecyclingPlant ($city_name)" =>
                    merge(recycling_plant, lat_lon_dict(city_location)) for
                (city_name, city_location) in cities_a
            ),
        ),
    )

    # Generate instance file
    open(fixture("boat_example.json"), "w") do file
        JSON.print(file, data, 2)
    end

    # Load and solve example
    instance = RELOG.parsefile(fixture("boat_example.json"))
    model = RELOG.build_model(instance, optimizer = HiGHS.Optimizer, variable_names = true)
    optimize!(model)

    # Write reports
    mkpath(fixture("boat_example"))
    write_to_file(model, fixture("boat_example/model.lp"))
    RELOG.write_plants_report(model, fixture("boat_example/plants.csv"))
    RELOG.write_plant_outputs_report(model, fixture("boat_example/plant_outputs.csv"))
    RELOG.write_centers_report(model, fixture("boat_example/centers.csv"))
    RELOG.write_center_outputs_report(model, fixture("boat_example/center_outputs.csv"))
    RELOG.write_transportation_report(model, fixture("boat_example/transportation.csv"))

    return
end
