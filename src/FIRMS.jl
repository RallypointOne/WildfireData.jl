module FIRMS

using ..WildfireData
using HTTP
using CSV
using DataFrames
using Dates


#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("FIRMS")

#-----------------------------------------------------------------------------# Constants

const API_BASE = "https://firms.modaps.eosdis.nasa.gov/api"

# Available data sources
const SOURCES = Dict{Symbol, NamedTuple{(:name, :description, :start_date, :type), Tuple{String, String, String, Symbol}}}(
    :MODIS_NRT => (
        name = "MODIS_NRT",
        description = "MODIS Collection 6.1 Near Real-Time (Aqua/Terra satellites)",
        start_date = "2000-11-01",
        type = :NRT
    ),
    :MODIS_SP => (
        name = "MODIS_SP",
        description = "MODIS Collection 6.1 Standard Processing (science quality)",
        start_date = "2000-11-01",
        type = :SP
    ),
    :VIIRS_SNPP_NRT => (
        name = "VIIRS_SNPP_NRT",
        description = "VIIRS 375m S-NPP Near Real-Time",
        start_date = "2012-01-20",
        type = :NRT
    ),
    :VIIRS_SNPP_SP => (
        name = "VIIRS_SNPP_SP",
        description = "VIIRS 375m S-NPP Standard Processing",
        start_date = "2012-01-20",
        type = :SP
    ),
    :VIIRS_NOAA20_NRT => (
        name = "VIIRS_NOAA20_NRT",
        description = "VIIRS 375m NOAA-20 Near Real-Time",
        start_date = "2018-04-01",
        type = :NRT
    ),
    :VIIRS_NOAA20_SP => (
        name = "VIIRS_NOAA20_SP",
        description = "VIIRS 375m NOAA-20 Standard Processing",
        start_date = "2018-04-01",
        type = :SP
    ),
    :VIIRS_NOAA21_NRT => (
        name = "VIIRS_NOAA21_NRT",
        description = "VIIRS 375m NOAA-21 Near Real-Time",
        start_date = "2024-01-17",
        type = :NRT
    ),
    :LANDSAT_NRT => (
        name = "LANDSAT_NRT",
        description = "Landsat 8/9 30m Near Real-Time (US/Canada only)",
        start_date = "2022-06-20",
        type = :NRT
    ),
)

# Common bounding boxes for convenience
const REGIONS = Dict{Symbol, String}(
    :world => "world",
    :conus => "-125,24,-66,50",           # Continental US
    :alaska => "-180,51,-129,72",          # Alaska
    :california => "-125,32,-114,42",      # California
    :western_us => "-125,31,-102,49",      # Western US
    :eastern_us => "-102,24,-66,50",       # Eastern US
    :canada => "-141,41,-52,84",           # Canada
    :australia => "112,-44,154,-10",       # Australia
    :europe => "-25,35,40,72",             # Europe
    :amazon => "-82,-20,-34,13",           # Amazon basin
    :africa => "-18,-35,52,38",            # Africa
)

#-----------------------------------------------------------------------------# MAP_KEY Management

"""
    get_map_key()

Get the current FIRMS MAP_KEY from the `FIRMS_MAP_KEY` environment variable.

Returns `nothing` if not configured.
"""
get_map_key() = get(ENV, "FIRMS_MAP_KEY", nothing)

"""
    set_map_key!(key::String)

Set the FIRMS MAP_KEY by setting the `FIRMS_MAP_KEY` environment variable.

You can obtain a free MAP_KEY by registering at:
https://firms.modaps.eosdis.nasa.gov/api/map_key/

# Example
```julia
FIRMS.set_map_key!("your-32-character-map-key-here")
```
"""
function set_map_key!(key::String)
    if length(key) != 32 || !all(c -> isletter(c) || isdigit(c), key)
        @warn "MAP_KEY should be a 32-character alphanumeric string"
    end
    ENV["FIRMS_MAP_KEY"] = key
    return nothing
end

function require_map_key()
    key = get_map_key()
    if isnothing(key)
        error("""
            FIRMS MAP_KEY not configured.

            To use the FIRMS API, you need a free MAP_KEY:
            1. Register at: https://firms.modaps.eosdis.nasa.gov/api/map_key/
            2. Set it via: FIRMS.set_map_key!("your-key")
               Or set the FIRMS_MAP_KEY environment variable
            """)
    end
    return key
end

#-----------------------------------------------------------------------------# Info Functions

"""
    info()

Print information about the FIRMS API and available data sources.
"""
function info()
    println("NASA FIRMS: Fire Information for Resource Management System")
    println("=" ^ 60)
    println("API: $API_BASE")
    println()
    println("Satellite fire detection data from MODIS, VIIRS, and Landsat.")
    println("Data available within 3 hours of satellite observation globally,")
    println("real-time for US/Canada.")
    println()
    println("Rate Limit: 5000 transactions per 10-minute interval")
    println()

    key = get_map_key()
    if isnothing(key)
        println("Status: MAP_KEY not configured")
        println("Register for free at: https://firms.modaps.eosdis.nasa.gov/api/map_key/")
    else
        println("Status: MAP_KEY configured")
    end

    return nothing
end

"""
    sources(; type=nothing)

List available FIRMS data sources.

# Arguments
- `type::Symbol`: Filter by type (`:NRT` for Near Real-Time, `:SP` for Standard Processing)

# Example
```julia
FIRMS.sources()  # all sources
FIRMS.sources(type=:NRT)  # only NRT sources
```
"""
function sources(; type::Union{Symbol, Nothing}=nothing)
    if isnothing(type)
        return SOURCES
    else
        return Dict(k => v for (k, v) in SOURCES if v.type == type)
    end
end

"""
    regions()

List predefined geographic regions for convenience queries.

# Example
```julia
FIRMS.regions()
```
"""
regions() = REGIONS

#-----------------------------------------------------------------------------# API Functions

"""
    query_url(source::Symbol, area::String, days::Int; date=nothing)

Build a FIRMS API query URL.

# Arguments
- `source::Symbol`: Data source (see `FIRMS.sources()`)
- `area::String`: Bounding box as "west,south,east,north" or "world"
- `days::Int`: Number of days (1-10)
- `date`: Optional date (Date or "YYYY-MM-DD" string) for historical queries
"""
function query_url(source::Symbol, area::String, days::Int; date::Union{Date, String, Nothing}=nothing)
    haskey(SOURCES, source) || error("Unknown source: $source. Use `FIRMS.sources()` to list available sources.")
    1 <= days <= 10 || error("days must be between 1 and 10")

    key = require_map_key()
    source_name = SOURCES[source].name

    url = "$API_BASE/area/csv/$key/$source_name/$area/$days"

    if !isnothing(date)
        date_str = date isa Date ? Dates.format(date, "yyyy-mm-dd") : date
        url *= "/$date_str"
    end

    return url
end

"""
    download(source::Symbol; area="world", region=nothing, days=1, date=nothing, verbose=true)

Download active fire data from FIRMS.

# Arguments
- `source::Symbol`: Data source (e.g., `:VIIRS_NOAA20_NRT`, `:MODIS_NRT`)
- `area::String`: Bounding box as "west,south,east,north" (default: "world")
- `region::Symbol`: Use a predefined region instead of area (see `FIRMS.regions()`)
- `days::Int`: Number of days to query (1-10, default: 1)
- `date`: Specific date for historical data (Date or "YYYY-MM-DD" string)
- `verbose::Bool`: Print progress information

# Returns
A `DataFrame` containing the fire detection data.

# Examples
```julia
# Download last day of VIIRS NOAA-20 NRT data worldwide
df = FIRMS.download(:VIIRS_NOAA20_NRT)

# Download 3 days of data for California
df = FIRMS.download(:VIIRS_NOAA20_NRT, region=:california, days=3)

# Download data for a specific bounding box
df = FIRMS.download(:MODIS_NRT, area="-120,35,-115,40", days=2)

# Download historical data for a specific date
df = FIRMS.download(:VIIRS_SNPP_SP, region=:western_us, days=1, date="2023-08-15")
```
"""
function download(source::Symbol; area::String="world", region::Union{Symbol, Nothing}=nothing,
                  days::Int=1, date::Union{Date, String, Nothing}=nothing, verbose::Bool=true)

    # Handle region shortcut
    if !isnothing(region)
        haskey(REGIONS, region) || error("Unknown region: $region. Use `FIRMS.regions()` to list available regions.")
        area = REGIONS[region]
    end

    url = query_url(source, area, days; date=date)

    verbose && println("Downloading: $(SOURCES[source].description)")
    verbose && println("Area: $area")
    verbose && println("Days: $days")
    !isnothing(date) && verbose && println("Date: $date")
    verbose && println("URL: $(replace(url, get_map_key() => "[MAP_KEY]"))")

    response = HTTP.get(url; status_exception=false)

    if response.status != 200
        error("Failed to download data. HTTP status: $(response.status)\nResponse: $(String(response.body))")
    end

    body = String(response.body)

    # Check for error messages
    if startswith(body, "Invalid") || startswith(body, "Error") || contains(body, "exceeded")
        error("FIRMS API error: $body")
    end

    # Parse CSV
    verbose && println("Parsing CSV...")
    df = CSV.read(IOBuffer(body), DataFrame)

    verbose && println("Downloaded $(nrow(df)) fire detections")

    return df
end

"""
    download_file(source::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download FIRMS data and save it to the local data directory.

# Arguments
- `source::Symbol`: Data source
- `filename::String`: Custom filename (default: auto-generated)
- `force::Bool`: Overwrite existing file
- `verbose::Bool`: Print progress information
- `kwargs...`: Additional arguments passed to `download()`

# Returns
The path to the downloaded CSV file.

# Example
```julia
path = FIRMS.download_file(:VIIRS_NOAA20_NRT, region=:california, days=3)
```
"""
function download_file(source::Symbol; filename::Union{String, Nothing}=nothing,
                       force::Bool=false, verbose::Bool=true, kwargs...)
    mkpath(dir())

    if isnothing(filename)
        date_str = Dates.format(today(), "yyyymmdd")
        filename = "$(SOURCES[source].name)_$date_str.csv"
    end
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to overwrite.")
        return filepath
    end

    df = download(source; verbose=verbose, kwargs...)

    CSV.write(filepath, df)
    verbose && println("Saved to: $filepath")

    return filepath
end

"""
    load_file(filename::String)

Load a previously downloaded FIRMS CSV file.

# Example
```julia
df = FIRMS.load_file("VIIRS_NOAA20_NRT_20240115.csv")
```
"""
function load_file(filename::String)
    filepath = joinpath(dir(), filename)
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    return CSV.read(filepath, DataFrame)
end

#-----------------------------------------------------------------------------# Data Availability

"""
    data_availability(source::Symbol=:VIIRS_NOAA20_NRT)

Check data availability for a specific source.

Returns a DataFrame showing available dates and their status.

# Example
```julia
FIRMS.data_availability(:VIIRS_NOAA20_NRT)
```
"""
function data_availability(source::Symbol=:VIIRS_NOAA20_NRT)
    haskey(SOURCES, source) || error("Unknown source: $source")

    key = require_map_key()
    source_name = SOURCES[source].name
    url = "$API_BASE/data_availability/csv/$key/$source_name"

    response = HTTP.get(url; status_exception=false)
    if response.status != 200
        error("Failed to get data availability. HTTP status: $(response.status)")
    end

    return CSV.read(IOBuffer(String(response.body)), DataFrame)
end

#-----------------------------------------------------------------------------# Convenience Functions

"""
    recent_fires(; source=:VIIRS_NOAA20_NRT, region=:conus, days=1, min_confidence=nothing)

Get recent fire detections with optional confidence filtering.

# Arguments
- `source::Symbol`: Data source (default: `:VIIRS_NOAA20_NRT`)
- `region::Symbol`: Geographic region (default: `:conus`)
- `days::Int`: Number of days (default: 1)
- `min_confidence::Real`: Minimum confidence value to include (source-dependent)

# Example
```julia
df = FIRMS.recent_fires(region=:california, days=2)
```
"""
function recent_fires(; source::Symbol=:VIIRS_NOAA20_NRT, region::Symbol=:conus,
                      days::Int=1, min_confidence::Union{Real, Nothing}=nothing)
    df = download(source; region=region, days=days, verbose=false)

    if !isnothing(min_confidence) && "confidence" in names(df)
        # VIIRS confidence can be "l", "n", "h" (low, nominal, high) or numeric
        # MODIS confidence is 0-100
        if eltype(df.confidence) <: Number
            df = filter(row -> row.confidence >= min_confidence, df)
        end
    end

    return df
end

"""
    hotspots_by_date(; source=:VIIRS_NOAA20_NRT, region=:conus, days=7)

Get fire detections grouped by date.

# Returns
A dictionary mapping dates to DataFrames of fire detections.

# Example
```julia
by_date = FIRMS.hotspots_by_date(region=:western_us, days=5)
```
"""
function hotspots_by_date(; source::Symbol=:VIIRS_NOAA20_NRT, region::Symbol=:conus, days::Int=7)
    df = download(source; region=region, days=days, verbose=false)

    if "acq_date" in names(df)
        return Dict(date => filter(row -> row.acq_date == date, df) for date in unique(df.acq_date))
    else
        return Dict("all" => df)
    end
end

end # module
