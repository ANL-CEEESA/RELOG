# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG

@testset "geodb_query (2018-us-county)" begin
    region = RELOG.geodb_query("2018-us-county:17043")
    @test region.centroid.lat == 41.83956
    @test region.centroid.lon == -88.08857
    @test region.population == 922_921
end

# @testset "geodb_query (2018-us-zcta)" begin
#     region = RELOG.geodb_query("2018-us-zcta:60439")
#     @test region.centroid.lat == 41.68241
#     @test region.centroid.lon == -87.98954
# end

@testset "geodb_query (us-state)" begin
    region = RELOG.geodb_query("us-state:IL")
    @test region.centroid.lat == 39.73939
    @test region.centroid.lon == -89.50414
    @test region.population == 12_671_821
end
