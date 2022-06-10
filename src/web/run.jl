println("Initializing...")

using Logging
using Cbc
using JSON
using JuMP
using RELOG

function solve(root, filename)
    ref_file = "$root/$filename"
    optimizer = optimizer_with_attributes(
        Cbc.Optimizer,
        "seconds" => 900,
    )
    ref_solution, ref_model = RELOG.solve(
        ref_file,
        optimizer=optimizer,
        return_model=true,
        marginal_costs=false,
    )
    Libc.flush_cstdio()
    flush(stdout)
    sleep(1)
    
    if length(ref_solution) == 0
        return
    end
    RELOG.write_products_report(
        ref_solution,
        replace(ref_file, ".json" => "_products.csv"),
    )
    RELOG.write_plants_report(
        ref_solution,
        replace(ref_file, ".json" => "_plants.csv"),
    )
    RELOG.write_plant_outputs_report(
        ref_solution,
        replace(ref_file, ".json" => "_plant_outputs.csv"),
    )
    RELOG.write_plant_emissions_report(
        ref_solution,
        replace(ref_file, ".json" => "_plant_emissions.csv"),
    )
    RELOG.write_transportation_report(
        ref_solution,
        replace(ref_file, ".json" => "_tr.csv"),
    )
    RELOG.write_transportation_emissions_report(
        ref_solution,
        replace(ref_file, ".json" => "_tr_emissions.csv"),
    )

    isdir("$root/scenarios") || return
    for filename in readdir("$root/scenarios")
        scenario = "$root/scenarios/$filename"
        endswith(filename, ".json") || continue

        sc_solution = RELOG.resolve(
            ref_model,
            scenario,
            optimizer=optimizer,
        )
        if length(sc_solution) == 0
            return
        end
        RELOG.write_plants_report(
            sc_solution,
            replace(scenario, ".json" => "_plants.csv"),
        )
        RELOG.write_products_report(
            sc_solution,
            replace(scenario, ".json" => "_products.csv"),
        )
        RELOG.write_plant_outputs_report(
            sc_solution,
            replace(scenario, ".json" => "_plant_outputs.csv"),
        )
        RELOG.write_plant_emissions_report(
            sc_solution,
            replace(scenario, ".json" => "_plant_emissions.csv"),
        )
        RELOG.write_transportation_report(
            sc_solution,
            replace(scenario, ".json" => "_tr.csv"),
        )
        RELOG.write_transportation_emissions_report(
            sc_solution,
            replace(scenario, ".json" => "_tr_emissions.csv"),
        )
    end
end

function solve_recursive(path)
    cd(path)

    # Solve instances
    for (root, dirs, files) in walkdir(".")
        if occursin(r"scenarios"i, root)
            continue
        end
        for filename in files
            endswith(filename, ".json") || continue
            solve(root, filename)
        end
    end

    # Collect results
    results = []
    for (root, dirs, files) in walkdir(".")
        for filename in files
            endswith(filename, "_plants.csv") || continue
            push!(
                results,
                joinpath(
                    replace(root, path => ""),
                    replace(filename, "_plants.csv" => ""),
                ),
            )
        end
    end
    open("output.json", "w") do file
        JSON.print(file, results)
    end

    run(`zip -r output.zip .`)
end

solve_recursive(ARGS[1])