# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Geodesy

function _calculate_distance(source_lat, source_lon, dest_lat, dest_lon)::Float64
    x = LLA(source_lat, source_lon, 0.0)
    y = LLA(dest_lat, dest_lon, 0.0)
    return round(euclidean_distance(x, y) / 1000.0, digits = 3)
end
