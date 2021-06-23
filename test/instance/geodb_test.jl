# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG

@testset "geodb_query (2018-us-county)" begin
    point = RELOG.geodb_query("2018-us-county:17043")
    @test point.lat == 41.83956
    @test point.lon == -88.08857
end
