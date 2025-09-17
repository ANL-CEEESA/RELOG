# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG

function model_dist_test()
    # Euclidean distance between Chicago and Indianapolis
    @test RELOG._calculate_distance(
        41.866,
        -87.656,
        39.764,
        -86.148,
        RELOG.EuclideanDistance(),
    ) == 265.818

    # Driving distance between Chicago and Indianapolis
    @test RELOG._calculate_distance(
        41.866,
        -87.656,
        39.764,
        -86.148,
        RELOG.KnnDrivingDistance(),
    ) == 316.43
end
