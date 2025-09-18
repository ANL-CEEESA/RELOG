# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG
using JuMP
using HiGHS
using Test

function jumpext_test()
    jumpext_pwl_single_point()
    jumpext_pwl_two_points()
    jumpext_pwl_multiple_points()
    jumpext_pwl_input_validation()
    return
end

function jumpext_pwl_single_point()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @variable(model, y1)
    @variable(model, y2)
    xpts = [5.0]
    ypts = [10.0 20.0]
    RELOG._add_pwl_constraints(model, x, [y1, y2], xpts, ypts)
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value(x) ≈ 5.0 atol = 1e-6
    @test value(y1) ≈ 10.0 atol = 1e-6
    @test value(y2) ≈ 20.0 atol = 1e-6
    return
end

function jumpext_pwl_two_points()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @variable(model, y1)
    @variable(model, y2)
    xpts = [0.0, 2.0]
    ypts = [0.0 10.0; 4.0 6.0]
    RELOG._add_pwl_constraints(model, x, [y1, y2], xpts, ypts)

    # Test at x = 1
    JuMP.fix(x, 1.0)
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value(y1) ≈ 2.0 atol = 1e-6
    @test value(y2) ≈ 8.0 atol = 1e-6

    # Test at x = 2
    JuMP.fix(x, 2.0)
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value(y1) ≈ 4.0 atol = 1e-6
    @test value(y2) ≈ 6.0 atol = 1e-6
    return
end

function jumpext_pwl_multiple_points()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @variable(model, y1)
    @variable(model, y2)
    xpts = [0.0, 1.0, 2.0]
    ypts = [0.0 5.0; 2.0 3.0; 1.0 4.0]
    RELOG._add_pwl_constraints(model, x, [y1, y2], xpts, ypts)

    # Test at x = 0.5
    JuMP.fix(x, 0.5)
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value(y1) ≈ 1.0 atol = 1e-6
    @test value(y2) ≈ 4.0 atol = 1e-6

    # Test at x = 1
    JuMP.fix(x, 1.0)
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value(y1) ≈ 2.0 atol = 1e-6
    @test value(y2) ≈ 3.0 atol = 1e-6

    # Test at x = 1.5
    JuMP.fix(x, 1.5)
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value(y1) ≈ 1.5 atol = 1e-6
    @test value(y2) ≈ 3.5 atol = 1e-6
    return
end

function jumpext_pwl_input_validation()
    model = Model(HiGHS.Optimizer)
    @variable(model, x)
    @variable(model, y)

    # Test non-matrix ypts
    @test_throws ArgumentError RELOG._add_pwl_constraints(model, x, [y], [1.0], [1.0])

    # Test mismatched dimensions
    @test_throws ArgumentError RELOG._add_pwl_constraints(
        model,
        x,
        [y],
        [1.0, 2.0],
        [1.0 2.0],
    )
    @test_throws ArgumentError RELOG._add_pwl_constraints(
        model,
        x,
        [y],
        [1.0],
        [1.0 2.0; 3.0 4.0],
    )

    # Test empty breakpoints
    @test_throws ArgumentError RELOG._add_pwl_constraints(
        model,
        x,
        [y],
        Float64[],
        Matrix{Float64}(undef, 0, 1),
    )

    # Test non-increasing x points
    @test_throws ArgumentError RELOG._add_pwl_constraints(
        model,
        x,
        [y],
        [2.0, 1.0],
        [1.0; 2.0],
    )
    @test_throws ArgumentError RELOG._add_pwl_constraints(
        model,
        x,
        [y],
        [1.0, 1.0],
        [1.0; 2.0],
    )

    return
end
