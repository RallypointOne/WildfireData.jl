module CWFIS

using ..WildfireData
using HTTP
using JSON3
using GeoJSON

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("CWFIS")

#-----------------------------------------------------------------------------# Constants

const WFS_BASE = "https://cwfis.cfs.nrcan.gc.ca/geoserver/public/wfs"

"""
    COLLECTIONS

Dictionary of available CWFIS WFS collections. Each entry maps a `Symbol` key to a `NamedTuple`
with fields `id`, `name`, `description`, `category`, and `geometry`.

Categories: `:current`, `:detection`, `:archive`, `:weather`
"""
const COLLECTIONS = Dict{Symbol, NamedTuple{(:id, :name, :description, :category, :geometry), Tuple{String, String, String, Symbol, Symbol}}}(
    :active_fires => (
        id = "public:activefires_current",
        name = "Active Fires (Current)",
        description = "Current active wildland fires in Canada with size, agency, and stage of control.",
        category = :current,
        geometry = :point,
    ),
    :reported_fires => (
        id = "public:reportedfires_ytd",
        name = "Reported Fires (Year-to-Date)",
        description = "All reported fires in Canada for the current year with cause and control status.",
        category = :current,
        geometry = :point,
    ),
    :hotspots => (
        id = "public:hotspots",
        name = "Satellite Hotspots",
        description = "Satellite-detected fire hotspots with Fire Weather Index (FWI) components and fire behavior estimates.",
        category = :detection,
        geometry = :point,
    ),
    :hotspots_24h => (
        id = "public:hotspots_24h",
        name = "Satellite Hotspots (Last 24 Hours)",
        description = "Satellite-detected fire hotspots from the last 24 hours.",
        category = :detection,
        geometry = :point,
    ),
    :fire_perimeters => (
        id = "public:nbac",
        name = "National Burned Area Composite",
        description = "National Burned Area Composite (NBAC) fire perimeter polygons (1972-present).",
        category = :archive,
        geometry = :polygon,
    ),
    :fire_points => (
        id = "public:NFDB_point",
        name = "National Fire Database Points",
        description = "National Fire Database (NFDB) fire point locations for large fires >= 200 hectares (1970-present).",
        category = :archive,
        geometry = :point,
    ),
    :fire_danger => (
        id = "public:fdr_current_shp",
        name = "Fire Danger Rating (Current)",
        description = "Current fire danger rating polygons across Canada.",
        category = :weather,
        geometry = :polygon,
    ),
    :weather_stations => (
        id = "public:firewx_stns",
        name = "Fire Weather Stations",
        description = "Reporting weather stations with current observations and FWI components.",
        category = :weather,
        geometry = :point,
    ),
)

#-----------------------------------------------------------------------------# Info Functions

"""
    collections(; category=nothing)

List available CWFIS collections.

### Arguments
- `category::Symbol`: Filter by category (`:current`, `:detection`, `:archive`, `:weather`)

### Examples
```julia
CWFIS.collections()
CWFIS.collections(category=:current)
```
"""
function collections(; category::Union{Symbol, Nothing}=nothing)
    if isnothing(category)
        return COLLECTIONS
    else
        return Dict(k => v for (k, v) in COLLECTIONS if v.category == category)
    end
end

"""
    info(collection::Symbol)

Print information about a specific CWFIS collection.

### Examples
```julia
CWFIS.info(:active_fires)
```
"""
function info(collection::Symbol)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `CWFIS.collections()` to list available collections.")
    end
    c = COLLECTIONS[collection]
    println("Collection: ", c.name)
    println("WFS Layer: ", c.id)
    println("Category: ", c.category)
    println("Geometry: ", c.geometry)
    println("Description: ", c.description)
    return nothing
end

#-----------------------------------------------------------------------------# URL Builder

"""
    query_url(collection::Symbol; count=nothing, start_index=nothing, bbox=nothing, cql_filter=nothing, sortby=nothing)

Build a CWFIS WFS query URL.

### Arguments
- `collection::Symbol`: Collection key (see `CWFIS.collections()`)
- `count::Int`: Maximum number of features to return
- `start_index::Int`: Number of features to skip (for pagination, 0-based)
- `bbox`: Bounding box as `(west, south, east, north)` tuple or `"west,south,east,north"` string
- `cql_filter::String`: CQL filter expression (e.g., `"YEAR=2023"`, `"SIZE_HA > 1000"`)
- `sortby::String`: Sort expression (e.g., `"YEAR"`)

### Examples
```julia
CWFIS.query_url(:active_fires)
CWFIS.query_url(:fire_points, count=10, cql_filter="YEAR=2023")
CWFIS.query_url(:fire_perimeters, bbox=(-130, 48, -110, 60))
```
"""
function query_url(collection::Symbol;
                   count::Union{Int, Nothing}=nothing,
                   start_index::Union{Int, Nothing}=nothing,
                   bbox::Union{NTuple{4, Real}, String, Nothing}=nothing,
                   cql_filter::Union{String, Nothing}=nothing,
                   sortby::Union{String, Nothing}=nothing)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `CWFIS.collections()` to list available collections.")
    end

    c = COLLECTIONS[collection]
    params = [
        "service" => "WFS",
        "version" => "2.0.0",
        "request" => "GetFeature",
        "typeNames" => c.id,
        "outputFormat" => "application/json",
        "srsName" => "EPSG:4326",
    ]

    if !isnothing(count)
        push!(params, "count" => string(count))
    end
    if !isnothing(start_index)
        push!(params, "startIndex" => string(start_index))
    end
    if !isnothing(bbox)
        bbox_str = bbox isa String ? bbox : join(bbox, ",")
        push!(params, "bbox" => bbox_str)
    end
    if !isnothing(cql_filter)
        push!(params, "CQL_FILTER" => HTTP.escapeuri(cql_filter))
    end
    if !isnothing(sortby)
        push!(params, "sortBy" => sortby)
    end

    return WFS_BASE * "?" * join(["$k=$v" for (k, v) in params], "&")
end

#-----------------------------------------------------------------------------# Download Functions

"""
    download(collection::Symbol; count=nothing, start_index=nothing, bbox=nothing, cql_filter=nothing, sortby=nothing, verbose=true)

Download features from a CWFIS collection and return as a `GeoJSON.FeatureCollection`.

### Arguments
- `collection::Symbol`: Collection key (see `CWFIS.collections()`)
- `count::Int`: Maximum number of features to return
- `start_index::Int`: Number of features to skip (for pagination, 0-based)
- `bbox`: Bounding box as `(west, south, east, north)` tuple or `"west,south,east,north"` string
- `cql_filter::String`: CQL filter expression (e.g., `"YEAR=2023"`)
- `sortby::String`: Sort expression
- `verbose::Bool`: Print progress information

### Examples
```julia
# Download current active fires
data = CWFIS.download(:active_fires)

# Download 10 fire perimeters from 2023
data = CWFIS.download(:fire_perimeters, count=10, cql_filter="year=2023")

# Download hotspots in British Columbia
data = CWFIS.download(:hotspots_24h, bbox=(-139, 48, -114, 60))
```
"""
function download(collection::Symbol;
                  count::Union{Int, Nothing}=nothing,
                  start_index::Union{Int, Nothing}=nothing,
                  bbox::Union{NTuple{4, Real}, String, Nothing}=nothing,
                  cql_filter::Union{String, Nothing}=nothing,
                  sortby::Union{String, Nothing}=nothing,
                  verbose::Bool=true)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `CWFIS.collections()` to list available collections.")
    end

    c = COLLECTIONS[collection]
    url = query_url(collection; count=count, start_index=start_index, bbox=bbox, cql_filter=cql_filter, sortby=sortby)

    verbose && println("Downloading: $(c.name)")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false, connect_timeout=60, readtimeout=60)

    if response.status != 200
        error("Failed to download collection. HTTP status: $(response.status)\nResponse: $(String(response.body))")
    end

    verbose && println("Parsing GeoJSON...")
    body = String(response.body)
    data = GeoJSON.read(body)

    n = length(data)
    verbose && println("Downloaded $n features")

    return data
end

"""
    download_file(collection::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download a CWFIS collection and save it to the local data directory.

### Returns
The path to the saved GeoJSON file.

### Examples
```julia
path = CWFIS.download_file(:active_fires)
path = CWFIS.download_file(:fire_perimeters, count=100, cql_filter="year=2023")
```
"""
function download_file(collection::Symbol;
                       filename::Union{String, Nothing}=nothing,
                       force::Bool=false, verbose::Bool=true, kwargs...)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `CWFIS.collections()` to list available collections.")
    end

    mkpath(dir())

    if isnothing(filename)
        filename = string(collection) * ".geojson"
    end
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to overwrite.")
        return filepath
    end

    data = download(collection; verbose=verbose, kwargs...)

    open(filepath, "w") do io
        JSON3.write(io, data)
    end
    verbose && println("Saved to: $filepath")

    return filepath
end

"""
    load_file(collection::Symbol; filename=nothing)

Load a previously downloaded CWFIS collection from the local data directory.

### Examples
```julia
data = CWFIS.load_file(:active_fires)
```
"""
function load_file(collection::Symbol; filename::Union{String, Nothing}=nothing)
    if isnothing(filename)
        filename = string(collection) * ".geojson"
    end
    filepath = joinpath(dir(), filename)

    if !isfile(filepath)
        error("File not found: $filepath. Download the collection first.")
    end

    return GeoJSON.read(read(filepath, String))
end

end # module
