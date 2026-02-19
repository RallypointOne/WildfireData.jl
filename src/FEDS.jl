module FEDS

using ..WildfireData
using HTTP
using JSON3
using GeoJSON

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("FEDS")

#-----------------------------------------------------------------------------# Constants

const API_BASE = "https://openveda.cloud/api/features"

"""
    COLLECTIONS

Dictionary of available FEDS collections. Each entry maps a `Symbol` key to a `NamedTuple`
with fields `id`, `name`, `description`, `category`, and `geometry`.

Categories: `:snapshot`, `:large_fire`, `:archive`
"""
const COLLECTIONS = Dict{Symbol, NamedTuple{(:id, :name, :description, :category, :geometry), Tuple{String, String, String, Symbol, Symbol}}}(
    :snapshot_perimeters => (
        id = "public.eis_fire_snapshot_perimeter_nrt",
        name = "Snapshot Perimeters (NRT)",
        description = "Rolling ~20-day snapshot of fire perimeters from near real-time satellite data.",
        category = :snapshot,
        geometry = :polygon,
    ),
    :snapshot_firelines => (
        id = "public.eis_fire_snapshot_fireline_nrt",
        name = "Snapshot Fire Lines (NRT)",
        description = "Rolling ~20-day snapshot of active fire lines from near real-time satellite data.",
        category = :snapshot,
        geometry = :line,
    ),
    :snapshot_newfirepix => (
        id = "public.eis_fire_snapshot_newfirepix_nrt",
        name = "Snapshot New Fire Pixels (NRT)",
        description = "Rolling ~20-day snapshot of newly detected fire pixels from near real-time satellite data.",
        category = :snapshot,
        geometry = :point,
    ),
    :lf_perimeters => (
        id = "public.eis_fire_lf_perimeter_nrt",
        name = "Large Fire Perimeters (NRT)",
        description = "Current-year large fire (>5 km²) perimeters from near real-time satellite data.",
        category = :large_fire,
        geometry = :polygon,
    ),
    :lf_firelines => (
        id = "public.eis_fire_lf_fireline_nrt",
        name = "Large Fire Lines (NRT)",
        description = "Current-year large fire (>5 km²) active fire lines from near real-time satellite data.",
        category = :large_fire,
        geometry = :line,
    ),
    :lf_newfirepix => (
        id = "public.eis_fire_lf_newfirepix_nrt",
        name = "Large Fire New Fire Pixels (NRT)",
        description = "Current-year large fire (>5 km²) newly detected fire pixels from near real-time satellite data.",
        category = :large_fire,
        geometry = :point,
    ),
    :archive_perimeters => (
        id = "public.eis_fire_lf_perimeter_archive",
        name = "Archive Perimeters",
        description = "Archived large fire perimeters for the Western US (2018-2021).",
        category = :archive,
        geometry = :polygon,
    ),
    :archive_firelines => (
        id = "public.eis_fire_lf_fireline_archive",
        name = "Archive Fire Lines",
        description = "Archived large fire active fire lines for the Western US (2018-2021).",
        category = :archive,
        geometry = :line,
    ),
    :archive_newfirepix => (
        id = "public.eis_fire_lf_newfirepix_archive",
        name = "Archive New Fire Pixels",
        description = "Archived large fire newly detected fire pixels for the Western US (2018-2021).",
        category = :archive,
        geometry = :point,
    ),
)

#-----------------------------------------------------------------------------# Info Functions

"""
    collections(; category=nothing)

List available FEDS collections.

### Arguments
- `category::Symbol`: Filter by category (`:snapshot`, `:large_fire`, `:archive`)

### Examples
```julia
FEDS.collections()
FEDS.collections(category=:snapshot)
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

Print information about a specific FEDS collection.

### Examples
```julia
FEDS.info(:snapshot_perimeters)
```
"""
function info(collection::Symbol)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `FEDS.collections()` to list available collections.")
    end
    c = COLLECTIONS[collection]
    println("Collection: ", c.name)
    println("ID: ", c.id)
    println("Category: ", c.category)
    println("Geometry: ", c.geometry)
    println("Description: ", c.description)
    println("Items URL: ", "$API_BASE/collections/$(c.id)/items")
    return nothing
end

#-----------------------------------------------------------------------------# URL Builder

"""
    query_url(collection::Symbol; limit=nothing, offset=nothing, bbox=nothing, datetime=nothing, filter=nothing, sortby=nothing)

Build a FEDS OGC API query URL.

### Arguments
- `collection::Symbol`: Collection key (see `FEDS.collections()`)
- `limit::Int`: Maximum number of features to return
- `offset::Int`: Number of features to skip (for pagination)
- `bbox`: Bounding box as `(west, south, east, north)` tuple or `"west,south,east,north"` string
- `datetime::String`: Temporal filter (e.g., `"2024-01-01T00:00:00Z/2024-12-31T23:59:59Z"`)
- `filter::String`: CQL filter expression
- `sortby::String`: Sort expression (e.g., `"+farea"` or `"-t"`)

### Examples
```julia
FEDS.query_url(:snapshot_perimeters, limit=10)
FEDS.query_url(:lf_perimeters, bbox=(-125, 32, -114, 42))
FEDS.query_url(:archive_perimeters, datetime="2020-01-01T00:00:00Z/2020-12-31T23:59:59Z")
```
"""
function query_url(collection::Symbol;
                   limit::Union{Int, Nothing}=nothing,
                   offset::Union{Int, Nothing}=nothing,
                   bbox::Union{NTuple{4, Real}, String, Nothing}=nothing,
                   datetime::Union{String, Nothing}=nothing,
                   filter::Union{String, Nothing}=nothing,
                   sortby::Union{String, Nothing}=nothing)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `FEDS.collections()` to list available collections.")
    end

    c = COLLECTIONS[collection]
    params = ["f" => "geojson"]

    if !isnothing(limit)
        push!(params, "limit" => string(limit))
    end
    if !isnothing(offset)
        push!(params, "offset" => string(offset))
    end
    if !isnothing(bbox)
        bbox_str = bbox isa String ? bbox : join(bbox, ",")
        push!(params, "bbox" => bbox_str)
    end
    if !isnothing(datetime)
        push!(params, "datetime" => datetime)
    end
    if !isnothing(filter)
        push!(params, "filter" => HTTP.escapeuri(filter))
    end
    if !isnothing(sortby)
        push!(params, "sortby" => sortby)
    end

    return "$API_BASE/collections/$(c.id)/items?" * join(["$k=$v" for (k, v) in params], "&")
end

#-----------------------------------------------------------------------------# Download Functions

"""
    download(collection::Symbol; limit=nothing, offset=nothing, bbox=nothing, datetime=nothing, filter=nothing, sortby=nothing, verbose=true)

Download features from a FEDS collection and return as a `GeoJSON.FeatureCollection`.

### Arguments
- `collection::Symbol`: Collection key (see `FEDS.collections()`)
- `limit::Int`: Maximum number of features to return
- `offset::Int`: Number of features to skip (for pagination)
- `bbox`: Bounding box as `(west, south, east, north)` tuple or `"west,south,east,north"` string
- `datetime::String`: Temporal filter (e.g., `"2024-01-01T00:00:00Z/2024-12-31T23:59:59Z"`)
- `filter::String`: CQL filter expression
- `sortby::String`: Sort expression (e.g., `"+farea"` or `"-t"`)
- `verbose::Bool`: Print progress information

### Examples
```julia
# Download first 10 snapshot perimeters
data = FEDS.download(:snapshot_perimeters, limit=10)

# Download large fire perimeters in California
data = FEDS.download(:lf_perimeters, bbox=(-125, 32, -114, 42))

# Download archived perimeters for 2020
data = FEDS.download(:archive_perimeters, datetime="2020-01-01T00:00:00Z/2020-12-31T23:59:59Z")
```
"""
function download(collection::Symbol;
                  limit::Union{Int, Nothing}=nothing,
                  offset::Union{Int, Nothing}=nothing,
                  bbox::Union{NTuple{4, Real}, String, Nothing}=nothing,
                  datetime::Union{String, Nothing}=nothing,
                  filter::Union{String, Nothing}=nothing,
                  sortby::Union{String, Nothing}=nothing,
                  verbose::Bool=true)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `FEDS.collections()` to list available collections.")
    end

    c = COLLECTIONS[collection]
    url = query_url(collection; limit=limit, offset=offset, bbox=bbox, datetime=datetime, filter=filter, sortby=sortby)

    verbose && println("Downloading: $(c.name)")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false)

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

Download a FEDS collection and save it to the local data directory.

### Arguments
- `collection::Symbol`: Collection key (see `FEDS.collections()`)
- `filename::String`: Custom filename (default: `<collection>.geojson`)
- `force::Bool`: Overwrite existing file
- `verbose::Bool`: Print progress information
- `kwargs...`: Additional arguments passed to `download()`

### Returns
The path to the saved GeoJSON file.

### Examples
```julia
path = FEDS.download_file(:snapshot_perimeters, limit=100)
path = FEDS.download_file(:lf_perimeters, filename="ca_fires.geojson", bbox=(-125, 32, -114, 42))
```
"""
function download_file(collection::Symbol;
                       filename::Union{String, Nothing}=nothing,
                       force::Bool=false, verbose::Bool=true, kwargs...)
    if !haskey(COLLECTIONS, collection)
        error("Unknown collection: $collection. Use `FEDS.collections()` to list available collections.")
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

Load a previously downloaded FEDS collection from the local data directory.

### Arguments
- `collection::Symbol`: Collection key
- `filename::String`: Custom filename (default: `<collection>.geojson`)

### Examples
```julia
data = FEDS.load_file(:snapshot_perimeters)
data = FEDS.load_file(:lf_perimeters, filename="ca_fires.geojson")
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
