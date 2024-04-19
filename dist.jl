# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020-2024, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Geodesy
using NearestNeighbors
using DataFrames
using CRC
using ZipFile
using Statistics
using TimerOutputs

crc32 = crc(CRC_32)

abstract type DistanceMetric end

Base.@kwdef mutable struct KnnDrivingDistance <: DistanceMetric
    tree = nothing
    ratios = nothing
end

mutable struct EuclideanDistance <: DistanceMetric end

function _calculate_distance(
    source_lat,
    source_lon,
    dest_lat,
    dest_lon,
    ::EuclideanDistance,
)::Float64
    x = LLA(source_lat, source_lon, 0.0)
    y = LLA(dest_lat, dest_lon, 0.0)
    return round(euclidean_distance(x, y) / 1000.0, digits=3)
end

function _download_file(url, output, expected_crc32)::Nothing
    if isfile(output)
        return
    end
    mkpath(dirname(output))
    @info "Downloading: $url"
    fname = download(url)
    actual_crc32 = open(crc32, fname)
    expected_crc32 == actual_crc32 || error("CRC32 mismatch")
    cp(fname, output)
    return
end

function _download_zip(url, outputdir, expected_output_file, expected_crc32)::Nothing
    if isfile(expected_output_file)
        return
    end
    mkpath(outputdir)
    @info "Downloading: $url"
    zip_filename = download(url)
    actual_crc32 = open(crc32, zip_filename)
    expected_crc32 == actual_crc32 || error("CRC32 mismatch")
    open(zip_filename) do zip_file
        zr = ZipFile.Reader(zip_file)
        for file in zr.files
            open(joinpath(outputdir, file.name), "w") do output_file
                write(output_file, read(file))
            end
        end
    end
    return
end

function _calculate_distance(
    source_lat,
    source_lon,
    dest_lat,
    dest_lon,
    metric::KnnDrivingDistance,
)::Float64
    if metric.tree === nothing
        basedir = joinpath(dirname(@__FILE__), "data")
        csv_filename = joinpath(basedir, "dist_driving.csv")

        # Download pre-computed driving data
        @timeit "Download data" begin
            if !isfile(csv_filename)
                _download_zip(
                    "https://axavier.org/RELOG/0.6/data/dist_driving_0b9a6ad6.zip",
                    basedir,
                    csv_filename,
                    0x0b9a6ad6,
                )
            end
        end

        @timeit "Fit KNN model" begin
            df = DataFrame(CSV.File(csv_filename, missingstring="NaN"))
            dropmissing!(df)
            coords = Matrix(df[!, [:source_lat, :source_lon, :dest_lat, :dest_lon]])'
            metric.ratios = Matrix(df[!, [:ratio]])
            metric.tree = KDTree(coords)
        end
    end

    @timeit "Compute Euclidean distance" begin
        dist_euclidean =
            _calculate_distance(source_lat, source_lon, dest_lat, dest_lon, EuclideanDistance())
    end

    @timeit "Predict driving distance" begin
        idxs, _ = knn(metric.tree, [source_lat, source_lon, dest_lat, dest_lon], 5)
        ratio_pred = mean(metric.ratios[idxs])
        dist_pred = round(dist_euclidean * ratio_pred, digits=3)
        isfinite(dist_pred) || error("non-finite distance detected: $dist_pred")
    end

    return dist_pred
end
