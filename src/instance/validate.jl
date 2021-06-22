# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures
using JSON
using JSONSchema
using Printf
using Statistics

function validate(json, schema)
    result = JSONSchema.validate(json, schema)
    if result !== nothing
        if result isa JSONSchema.SingleIssue
            path = join(result.path, " → ")
            if length(path) == 0
                path = "root"
            end
            msg = "$(result.msg) in $(path)"
        else
            msg = convert(String, result)
        end
        throw(msg)
    end
end
