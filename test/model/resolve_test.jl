# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

basedir = @__DIR__

@testset "Resolve" begin
    # Shoud not crash
    filename = "$basedir/../../instances/s1.json"
    solution_old, model_old = RELOG.solve(filename, return_model = true)
    solution_new = RELOG.resolve(model_old, filename)
end
