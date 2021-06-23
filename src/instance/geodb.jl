# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using CRC
using CSV
using DataFrames
using Shapefile
using Statistics
using ZipFile

crc32 = crc(CRC_32)

struct GeoPoint
    lat::Float64
    lon::Float64
end

DB_CACHE = Dict{String,Dict{String,GeoPoint}}()

function centroid(geom::Shapefile.Polygon)::GeoPoint
    x_max, x_min, y_max, y_min = -Inf, Inf, -Inf, Inf
    for p in geom.points
        x_max = max(x_max, p.x)
        x_min = min(x_min, p.x)
        y_max = max(y_max, p.y)
        y_min = min(y_min, p.y)
    end
    x_center = (x_max + x_min) / 2.0
    y_center = (y_max + y_min) / 2.0
    return GeoPoint(round(y_center, digits = 5), round(x_center, digits = 5))
end

function download_census_gov(url, outputdir, expected_crc32)::Nothing
    if isdir(outputdir)
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

function load_2018_us_county()::Dict{String,GeoPoint}
    db_name = "2018-us-county"
    basedir = joinpath(dirname(@__FILE__), "..", "..", "data", db_name)
    csv_filename = "$basedir/locations.csv"
    if !isfile(csv_filename)
        download_census_gov(
            "https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_500k.zip",
            basedir,
            0x83eaec6d,
        )
        table = Shapefile.Table("$basedir/cb_2018_us_county_500k.shp")
        geoms = Shapefile.shapes(table)
        df = DataFrame(id = String[], latitude = Float64[], longitude = Float64[])
        for (i, geom) in enumerate(geoms)
            c = centroid(geom)
            id = table.STATEFP[i] * table.COUNTYFP[i]
            push!(df, [id, c.lat, c.lon])
        end
        sort!(df)
        @info "Writing: $csv_filename"
        CSV.write(csv_filename, df)
    end
    if db_name ∉ keys(DB_CACHE)
        csv = CSV.File(csv_filename; types = [String, Float64, Float64])
        DB_CACHE[db_name] =
            Dict(row.id => GeoPoint(row.latitude, row.longitude) for row in csv)
    end
    return DB_CACHE[db_name]
end

function load_latlon_database(db_name)
    db_name == "2018-us-county" && return load_2018_us_county()
    error("Unknown database: $db_name")
end

function geodb_query(name)
    db_name, id = split(name, ":")
    return load_latlon_database(db_name)[id]
end
