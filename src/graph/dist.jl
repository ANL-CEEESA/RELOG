# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Geodesy
using NearestNeighbors
using DataFrames

Base.@kwdef mutable struct _KnnDrivingDistance
    tree = nothing
    ratios = nothing
end

mutable struct _EuclideanDistance end

function _calculate_distance(
    source_lat,
    source_lon,
    dest_lat,
    dest_lon,
    ::_EuclideanDistance,
)::Float64
    x = LLA(source_lat, source_lon, 0.0)
    y = LLA(dest_lat, dest_lon, 0.0)
    return round(euclidean_distance(x, y) / 1000.0, digits = 3)
end

function _calculate_distance(
    source_lat,
    source_lon,
    dest_lat,
    dest_lon,
    metric::_KnnDrivingDistance,
)::Float64
    if metric.tree === nothing
        basedir = joinpath(dirname(@__FILE__), "..", "..", "data")
        csv_filename = joinpath(basedir, "dist_driving.csv")

        # Download pre-computed driving data
        if !isfile(csv_filename)
            _download_zip(
                "https://axavier.org/RELOG/0.6/data/dist_driving_0b9a6ad6.zip",
                basedir,
                csv_filename,
                0x0b9a6ad6,
            )
        end

        # Fit kNN model
        df = DataFrame(CSV.File(csv_filename))
        coords = Matrix(df[!, [:source_lat, :source_lon, :dest_lat, :dest_lon]])'
        metric.ratios = Matrix(df[!, [:ratio]])
        metric.tree = KDTree(coords)
    end

    # Compute Euclidean distance
    dist_euclidean = _calculate_distance(
        source_lat,
        source_lon,
        dest_lat,
        dest_lon,
        _EuclideanDistance(),
    )

    # Predict ratio
    idxs, _ = knn(metric.tree, [source_lat, source_lon, dest_lat, dest_lon], 5)
    ratio_pred = mean(metric.ratios[idxs])
    return round(dist_euclidean * ratio_pred, digits = 3)
end
