# This file extends some JuMP functions so that decision variables can be safely
# replaced by (constant) floating point numbers.

using Printf
using JuMP
using OrderedCollections

import JuMP: value, fix, set_name

function value(x::Float64)
    return x
end

function fix(x::Float64, v::Float64; force)
    return abs(x - v) < 1e-6 || error("Value mismatch: $x != $v")
end

function set_name(x::Number, n::String)
    # nop
end

function _init(model::JuMP.Model, key::Symbol)::OrderedDict
    if !(key in keys(object_dictionary(model)))
        model[key] = OrderedDict()
    end
    return model[key]
end

function _set_names!(model::JuMP.Model)
    time_varnames = @elapsed begin
        _set_names!(object_dictionary(model))
    end
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
