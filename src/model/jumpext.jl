# This file extends some JuMP functions so that decision variables can be safely
# replaced by (constant) floating point numbers.

using Printf
using JuMP

import JuMP: value, fix, set_name

function value(x::Float64)
    return x
end

function fix(x::Float64, v::Float64; force)
    return abs(x - v) < 1e-6 || error("Value mismatch: $x != $v")
end

function set_name(::Number, ::String)
    # nop
end

function _init(model::JuMP.Model, key::Symbol)::OrderedDict
    if !(key in keys(object_dictionary(model)))
        model[key] = OrderedDict()
    end
    return model[key]
end

function _set_names!(model::JuMP.Model)
    @info "Setting variable and constraint names..."
    time_varnames = @elapsed begin
        _set_names!(object_dictionary(model))
    end
    @info @sprintf("Set names in %.2f seconds", time_varnames)
end

function _set_names!(dict::Dict)
    for name in keys(dict)
        dict[name] isa AbstractDict || continue
        for idx in keys(dict[name])
            if dict[name][idx] isa AffExpr
                continue
            end
            idx_str = join(map(string, idx), ",")
            set_name(dict[name][idx], "$name[$idx_str]")
        end
    end
end


"""
    _add_pwl_constraints(model, xvar, yvars, xpts, ypts)

Add piecewise-linear constraints to a JuMP model for multiple y variables.

Creates constraints y_i = f_i(x) where each f_i is a piecewise-linear function 
defined by the breakpoints (xpts, ypts[:, i]).

# Arguments
- `model`: JuMP model
- `xvar`: The x variable (JuMP variable)
- `yvars`: Vector of y variables (JuMP variables)  
- `xpts`: Vector of x values for breakpoints (must be in non-decreasing order)
- `ypts`: Matrix of y values where ypts[i, j] is the y value for the j-th variable 
         at the i-th breakpoint

# Example
```julia
@variable(model, y1)
@variable(model, y2)
ypts_matrix = [1.5 2.0; 0.0 1.5; 3.0 0.5]  # 3 breakpoints, 2 y variables
_add_pwl_constraints(model, x, [y1, y2], [0.0, 1.0, 2.0], ypts_matrix, name="multiPWL")
```
"""
function _add_pwl_constraints(model, xvar, yvars, xpts, ypts)
    # Input validation
    ypts isa AbstractMatrix || throw(ArgumentError("ypts must be a matrix"))
    length(xpts) == size(ypts, 1) ||
        throw(ArgumentError("xpts length must match number of rows in ypts"))
    length(yvars) == size(ypts, 2) ||
        throw(ArgumentError("Number of y variables must match number of columns in ypts"))
    length(xpts) >= 1 || throw(ArgumentError("At least one breakpoint is required"))

    # Check that xpts is increasing
    for i = 2:length(xpts)
        xpts[i] > xpts[i-1] || throw(ArgumentError("xpts must be in increasing order"))
    end

    n_points = length(xpts)
    n_yvars = length(yvars)

    if n_points == 1
        # Single point case: y_j = ypts[1,j], x = xpts[1]
        @constraint(model, xvar == xpts[1])
        for j = 1:n_yvars
            @constraint(model, yvars[j] == ypts[1, j])
        end

    elseif n_points == 2
        # Two points case: single linear segment for each y variable
        x1, x2 = xpts[1], xpts[2]

        # Linear relationship for each y variable: y_j = y1_j + slope_j * (x-x1)
        for j = 1:n_yvars
            y1, y2 = ypts[1, j], ypts[2, j]
            slope = (y2 - y1) / (x2 - x1)
            @constraint(model, yvars[j] == y1 + slope * (xvar - x1))
        end
    else
        # Multiple segments case (3+ points): use SOS2 formulation
        λ = @variable(model, [1:n_points], lower_bound = 0, upper_bound = 1)
        @constraint(model, λ in SOS2())
        @constraint(model, sum(λ) == 1)
        @constraint(model, xvar == sum(xpts[i] * λ[i] for i = 1:n_points))
        for j = 1:n_yvars
            @constraint(model, yvars[j] == sum(ypts[i, j] * λ[i] for i = 1:n_points))
        end
    end

    return
end
