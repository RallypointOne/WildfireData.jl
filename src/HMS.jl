module HMS

using ..WildfireData
using HTTP
using CSV
using DataFrames
using Dates

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("HMS")

#-----------------------------------------------------------------------------# Constants

const ARCHIVE_BASE = "https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS"

const PRODUCTS = Dict{Symbol, NamedTuple{(:name, :description, :format, :start_year), Tuple{String, String, Symbol, Int}}}(
    :fire_points => (
        name = "Fire Points",
        description = "Satellite-detected fire locations from MODIS, VIIRS, GOES, and AVHRR sensors. Quality-controlled by NOAA analysts.",
        format = :csv,
        start_year = 2003,
    ),
    :smoke_polygons => (
        name = "Smoke Polygons",
        description = "Analyst-drawn smoke plume polygons with density classification (light, medium, heavy).",
        format = :shapefile,
        start_year = 2005,
    ),
)

#-----------------------------------------------------------------------------# Info Functions

"""
    info()

Print information about NOAA HMS data products.
"""
function info()
    println("NOAA HMS: Hazard Mapping System Fire and Smoke Product")
    println("=" ^ 60)
    println("Archive: $ARCHIVE_BASE")
    println()
    println("Satellite fire detection and smoke plume analysis produced")
    println("daily by NOAA/NESDIS Satellite Analysis Branch.")
    println()
    println("Products:")
    for (k, v) in sort(collect(PRODUCTS), by=first)
        println("  :$k — $(v.description)")
    end
    println()
    println("Fire points updated by ~8:00 AM ET daily.")
    println("Smoke analysis: ~11:00 AM ET and ~7:00 PM ET daily.")
    return nothing
end

"""
    products()

List available HMS data products.

### Examples
```julia
HMS.products()
```
"""
products() = PRODUCTS

#-----------------------------------------------------------------------------# URL Builder

"""
    download_url(product::Symbol, date::Union{Date, String})

Build the download URL for an HMS data product on a specific date.

### Arguments
- `product::Symbol`: `:fire_points` or `:smoke_polygons`
- `date`: Date as a `Date` object or `"YYYY-MM-DD"` string

### Examples
```julia
HMS.download_url(:fire_points, "2024-08-15")
HMS.download_url(:smoke_polygons, Date(2024, 8, 15))
```
"""
function download_url(product::Symbol, date::Union{Date, String})
    if !haskey(PRODUCTS, product)
        error("Unknown product: $product. Available: $(collect(keys(PRODUCTS)))")
    end

    d = date isa String ? Date(date) : date
    yyyy = Dates.format(d, "yyyy")
    mm = Dates.format(d, "mm")
    yyyymmdd = Dates.format(d, "yyyymmdd")

    if product == :fire_points
        return "$ARCHIVE_BASE/Fire_Points/Text/$yyyy/$mm/hms_fire$yyyymmdd.txt"
    elseif product == :smoke_polygons
        return "$ARCHIVE_BASE/Smoke_Polygons/Shapefile/$yyyy/$mm/hms_smoke$yyyymmdd.zip"
    end
end

#-----------------------------------------------------------------------------# Download Functions

"""
    download(date::Union{Date, String}; verbose=true)

Download HMS fire point detections for a specific date and return as a `DataFrame`.

### Arguments
- `date`: Date as a `Date` object or `"YYYY-MM-DD"` string
- `verbose::Bool`: Print progress information

### Returns
A `DataFrame` with columns: Lon, Lat, YearDay, Time, Satellite, Method, Ecosystem, FRP.

### Examples
```julia
df = HMS.download("2024-08-15")
df = HMS.download(Date(2024, 8, 15))
```
"""
function download(date::Union{Date, String}; verbose::Bool=true)
    url = download_url(:fire_points, date)

    verbose && println("Downloading: HMS Fire Points")
    verbose && println("Date: $date")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false, connect_timeout=60, readtimeout=60)

    if response.status != 200
        error("Failed to download fire points. HTTP status: $(response.status). Data may not be available for this date.")
    end

    body = String(response.body)

    verbose && println("Parsing CSV...")
    df = CSV.read(IOBuffer(body), DataFrame; header=false, skipto=1,
                  types=[Float64, Float64, Int, Int, String, String, Int, Float64])
    rename!(df, [:Lon, :Lat, :YearDay, :Time, :Satellite, :Method, :Ecosystem, :FRP])

    # Replace missing FRP sentinel values
    df.FRP = replace(df.FRP, -999.0 => missing)

    verbose && println("Downloaded $(nrow(df)) fire detections")

    return df
end

"""
    download_smoke(date::Union{Date, String}; force=false, verbose=true)

Download HMS smoke polygon shapefile for a specific date.

### Arguments
- `date`: Date as a `Date` object or `"YYYY-MM-DD"` string
- `force::Bool`: Re-download even if file exists
- `verbose::Bool`: Print progress information

### Returns
The path to the downloaded zip file containing shapefiles.

### Examples
```julia
path = HMS.download_smoke("2024-08-15")
```
"""
function download_smoke(date::Union{Date, String}; force::Bool=false, verbose::Bool=true)
    d = date isa String ? Date(date) : date
    url = download_url(:smoke_polygons, d)
    yyyymmdd = Dates.format(d, "yyyymmdd")

    mkpath(dir())
    filename = "hms_smoke$yyyymmdd.zip"
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to re-download.")
        return filepath
    end

    verbose && println("Downloading: HMS Smoke Polygons")
    verbose && println("Date: $date")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false, connect_timeout=60, readtimeout=60)

    if response.status != 200
        error("Failed to download smoke polygons. HTTP status: $(response.status). Data may not be available for this date.")
    end

    open(filepath, "w") do io
        write(io, response.body)
    end
    verbose && println("Saved to: $filepath")

    return filepath
end

"""
    download_file(date::Union{Date, String}; filename=nothing, force=false, verbose=true)

Download HMS fire point data and save it as a CSV file.

### Returns
The path to the saved CSV file.

### Examples
```julia
path = HMS.download_file("2024-08-15")
```
"""
function download_file(date::Union{Date, String}; filename::Union{String, Nothing}=nothing,
                       force::Bool=false, verbose::Bool=true)
    d = date isa String ? Date(date) : date

    mkpath(dir())

    if isnothing(filename)
        yyyymmdd = Dates.format(d, "yyyymmdd")
        filename = "hms_fire$yyyymmdd.csv"
    end
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to overwrite.")
        return filepath
    end

    df = download(d; verbose=verbose)

    CSV.write(filepath, df)
    verbose && println("Saved to: $filepath")

    return filepath
end

"""
    load_file(filename::String)

Load a previously downloaded HMS CSV file.

### Examples
```julia
df = HMS.load_file("hms_fire20240815.csv")
```
"""
function load_file(filename::String)
    filepath = joinpath(dir(), filename)
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    return CSV.read(filepath, DataFrame)
end

end # module
