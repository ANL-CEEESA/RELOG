# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

function model_resolve_test()
    @testset "Resolve" begin
        # Shoud not crash
        filename = fixture("s1.json")
        solution_old, model_old = RELOG.solve(filename, return_model = true)
        solution_new = RELOG.resolve(model_old, filename)
    end
end
