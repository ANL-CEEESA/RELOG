# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using CRC
using CSV
using DataFrames
using Shapefile
using Statistics
using ZipFile
using ProgressBars
using OrderedCollections

import Downloads: download
import Base: parse

crc32 = crc(CRC_32)

struct GeoPoint
    lat::Float64
    lon::Float64
end

struct GeoRegion
    centroid::GeoPoint
    population::Int
    GeoRegion(; centroid, population) = new(centroid, population)
end

DB_CACHE = Dict{String,Dict{String,GeoRegion}}()

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

function _geodb_load_gov_census(;
    db_name,
    extract_cols,
    shp_crc32,
    shp_filename,
    shp_url,
    population_url,
    population_crc32,
    population_col,
    population_preprocess,
    population_join,
)::Dict{String,GeoRegion}
    basedir = joinpath(dirname(@__FILE__), "..", "..", "data", db_name)
    csv_filename = "$basedir/locations.csv"
    if !isfile(csv_filename)
        # Download required files
        _download_zip(shp_url, basedir, joinpath(basedir, shp_filename), shp_crc32)
        _download_file(population_url, "$basedir/population.csv", population_crc32)

        # Read shapefile
        @info "Processing: $shp_filename"
        table = Shapefile.Table(joinpath(basedir, shp_filename))
        geoms = Shapefile.shapes(table)

        # Build empty dataframe
        df = DataFrame()
        cols = extract_cols(table, 1)
        for k in keys(cols)
            df[!, k] = []
        end
        df[!, "latitude"] = Float64[]
        df[!, "longitude"] = Float64[]

        # Add regions to dataframe
        for (i, geom) in tqdm(enumerate(geoms))
            c = centroid(geom)
            cols = extract_cols(table, i)
            push!(df, [values(cols)..., c.lat, c.lon])
        end
        sort!(df)

        # Join with population data
        population = DataFrame(CSV.File("$basedir/population.csv"))
        population_preprocess(population)
        population = population[:, [population_join, population_col]]
        rename!(population, population_col => "population")
        df = leftjoin(df, population, on = population_join)

        # Write output
        CSV.write(csv_filename, df)
    end
    if db_name ∉ keys(DB_CACHE)
        csv = CSV.File(csv_filename)
        DB_CACHE[db_name] = Dict(
            string(row.id) => GeoRegion(
                centroid = GeoPoint(row.latitude, row.longitude),
                population = (row.population === missing ? 0 : row.population),
            ) for row in csv
        )
    end
    return DB_CACHE[db_name]
end

# 2018 US counties
# -----------------------------------------------------------------------------
function _extract_cols_2018_us_county(
    table::Shapefile.Table,
    i::Int,
)::OrderedDict{String,Any}
    return OrderedDict(
        "id" => table.STATEFP[i] * table.COUNTYFP[i],
        "statefp" => table.STATEFP[i],
        "countyfp" => table.COUNTYFP[i],
        "name" => table.NAME[i],
    )
end

function _population_preprocess_2018_us_county(df)
    df[!, "id"] = [@sprintf("%02d%03d", row.STATE, row.COUNTY) for row in eachrow(df)]
end

function _geodb_load_2018_us_county()::Dict{String,GeoRegion}
    return _geodb_load_gov_census(
        db_name = "2018-us-county",
        extract_cols = _extract_cols_2018_us_county,
        shp_crc32 = 0x83eaec6d,
        shp_filename = "cb_2018_us_county_500k.shp",
        shp_url = "https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_500k.zip",
        population_url = "https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/co-est2019-alldata.csv",
        population_crc32 = 0xf85b0405,
        population_col = "POPESTIMATE2019",
        population_join = "id",
        population_preprocess = _population_preprocess_2018_us_county,
    )
end

# US States
# -----------------------------------------------------------------------------
function _extract_cols_us_state(table::Shapefile.Table, i::Int)::OrderedDict{String,Any}
    return OrderedDict(
        "id" => table.STUSPS[i],
        "statefp" => parse(Int, table.STATEFP[i]),
        "name" => table.NAME[i],
    )
end

function _population_preprocess_us_state(df)
    rename!(df, "STATE" => "statefp")
end

function _geodb_load_us_state()::Dict{String,GeoRegion}
    return _geodb_load_gov_census(
        db_name = "us-state",
        extract_cols = _extract_cols_us_state,
        shp_crc32 = 0x9469e5ca,
        shp_filename = "cb_2018_us_state_500k.shp",
        shp_url = "https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_state_500k.zip",
        population_url = "http://www2.census.gov/programs-surveys/popest/datasets/2010-2019/national/totals/nst-est2019-alldata.csv",
        population_crc32 = 0x191cc64c,
        population_col = "POPESTIMATE2019",
        population_join = "statefp",
        population_preprocess = _population_preprocess_us_state,
    )
end

function geodb_load(db_name::AbstractString)::Dict{String,GeoRegion}
    db_name == "2018-us-county" && return _geodb_load_2018_us_county()
    db_name == "us-state" && return _geodb_load_us_state()
    error("Unknown database: $db_name")
end

function geodb_query(name)::GeoRegion
    db_name, id = split(name, ":")
    return geodb_load(db_name)[id]
end
