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
            msg = "$(result.reason) in $(result.path)"
        else
            msg = convert(String, result)
        end
        throw("Error parsing input file: $(msg)")
    end
end
