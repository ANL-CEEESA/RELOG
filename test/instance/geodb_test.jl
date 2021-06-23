# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG

@testset "geodb_query (2018-us-county)" begin
    point = RELOG.geodb_query("2018-us-county:17043")
    @test point.lat == 41.83956
    @test point.lon == -88.08857
end

@testset "geodb_query (2018-us-zcta)" begin
    point = RELOG.geodb_query("2018-us-zcta:60439")
    @test point.lat == 41.68241
    @test point.lon == -87.98954
end

@testset "geodb_query (us-state)" begin
    point = RELOG.geodb_query("us-state:IL")
    @test point.lat == 39.73939
    @test point.lon == -89.50414
end
