# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG

@testset "KnnDrivingDistance" begin
    # Euclidean distance between Chicago and Indianapolis
    @test RELOG._calculate_distance(
        41.866,
        -87.656,
        39.764,
        -86.148,
        RELOG._EuclideanDistance(),
    ) == 265.818

    # Approximate driving distance between Chicago and Indianapolis
    @test RELOG._calculate_distance(
        41.866,
        -87.656,
        39.764,
        -86.148,
        RELOG._KnnDrivingDistance(),
    ) == 316.43
end
