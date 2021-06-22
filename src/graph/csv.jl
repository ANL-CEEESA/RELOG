# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function to_csv(graph::Graph)
    result = ""
    for a in graph.arcs
        result *= "$(a.source.index),$(a.dest.index)\n"
    end
    return result
end
