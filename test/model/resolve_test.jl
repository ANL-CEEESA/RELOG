# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

@testset "Resolve" begin
    # Shoud not crash
    filename = "$(pwd())/../instances/s1.json"
    solution_old, model_old = RELOG.solve(filename, return_model = true)
    solution_new = RELOG.resolve(model_old, filename)
end
