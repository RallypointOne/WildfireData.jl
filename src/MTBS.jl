module MTBS

using ..WildfireData
using HTTP
using JSON3
using GeoJSON
using Downloads

export datasets, download, info, download_shapefile

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("MTBS")

#-----------------------------------------------------------------------------# Constants

# ArcGIS MapServer (for queries)
const MAPSERVER_BASE = "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_MTBS_01/MapServer"

# Direct file downloads from USDA Forest Service
const DOWNLOAD_BASE = "https://data.fs.usda.gov/geodata/edw"

# Layer IDs in the MapServer
const LAYER_FIRE_OCCURRENCE = 62  # Fire Occurrence Locations (All Years) - points
const LAYER_BURN_BOUNDARIES = 63  # Burned Area Boundaries (All Years) - polygons

# Time coverage
const YEAR_START = 1984
const YEAR_END = 2024

# Fire size thresholds (acres)
const SIZE_THRESHOLD_WEST = 1000  # Western US
const SIZE_THRESHOLD_EAST = 500   # Eastern US

# Available direct downloads
const DOWNLOADS = Dict(
    :burn_boundaries_shp => (
        url = "$DOWNLOAD_BASE/edw_resources/shp/S_USA.MTBS_BURN_AREA_BOUNDARY.zip",
        filename = "MTBS_Burn_Area_Boundary.zip",
        description = "Burn area boundaries shapefile (~374 MB)"
    ),
    :burn_boundaries_gdb => (
        url = "$DOWNLOAD_BASE/edw_resources/fc/S_USA.MTBS_BURN_AREA_BOUNDARY.gdb.zip",
        filename = "MTBS_Burn_Area_Boundary.gdb.zip",
        description = "Burn area boundaries geodatabase (~158 MB)"
    ),
    :fire_occurrence_shp => (
        url = "$DOWNLOAD_BASE/edw_resources/shp/S_USA.MTBS_FIRE_OCCURRENCE_PT.zip",
        filename = "MTBS_Fire_Occurrence.zip",
        description = "Fire occurrence points shapefile (~3 MB)"
    ),
    :fire_occurrence_gdb => (
        url = "$DOWNLOAD_BASE/edw_resources/fc/S_USA.MTBS_FIRE_OCCURRENCE_PT.gdb.zip",
        filename = "MTBS_Fire_Occurrence.gdb.zip",
        description = "Fire occurrence points geodatabase (~2 MB)"
    ),
)

#-----------------------------------------------------------------------------# Dataset Definitions

"""
    MTBSDataset

Metadata for an MTBS MapServer layer.
"""
struct MTBSDataset
    layer::Int
    name::String
    description::String
    geometry_type::Symbol  # :point or :polygon
end

const DATASETS = Dict{Symbol, MTBSDataset}(
    :fire_occurrence => MTBSDataset(
        LAYER_FIRE_OCCURRENCE,
        "Fire Occurrence Locations (All Years)",
        "Point locations of all inventoried MTBS fires from 1984 to present. Includes fire name, date, acres, and burn severity assessment data.",
        :point
    ),
    :burn_boundaries => MTBSDataset(
        LAYER_BURN_BOUNDARIES,
        "Burned Area Boundaries (All Years)",
        "Polygon boundaries of burned areas from 1984 to present. Includes fire perimeters with burn severity thresholds.",
        :polygon
    ),
)

#-----------------------------------------------------------------------------# URL Builder

"""
    query_url(dataset::Symbol; where="1=1", outfields="*", limit=nothing, format="geojson")

Build a MapServer query URL for the dataset.
"""
function query_url(dataset::Symbol; where::String="1=1", outfields::String="*",
                   limit::Union{Int,Nothing}=nothing, format::String="geojson")
    haskey(DATASETS, dataset) || error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")

    d = DATASETS[dataset]
    url = "$MAPSERVER_BASE/$(d.layer)/query"
    params = [
        "where" => HTTP.escapeuri(where),
        "outFields" => outfields,
        "f" => format,
        "outSR" => "4326",
    ]
    if !isnothing(limit)
        push!(params, "resultRecordCount" => string(limit))
    end
    return url * "?" * join(["$k=$v" for (k, v) in params], "&")
end

#-----------------------------------------------------------------------------# API Functions

"""
    datasets()

List available MTBS datasets.

# Example
```julia
MTBS.datasets()
```
"""
datasets() = DATASETS

"""
    info(dataset::Symbol)

Print information about a specific dataset.

# Example
```julia
MTBS.info(:fire_occurrence)
MTBS.info(:burn_boundaries)
```
"""
function info(dataset::Symbol)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")
    end
    d = DATASETS[dataset]
    println("Dataset: ", d.name)
    println("Geometry: ", d.geometry_type)
    println("Description: ", d.description)
    println("Layer ID: ", d.layer)
    println("Query URL: ", query_url(dataset))
    return nothing
end

"""
    download(dataset::Symbol; where="1=1", fields="*", limit=nothing, verbose=true)

Download an MTBS dataset and return it as parsed GeoJSON.

# Arguments
- `dataset::Symbol`: The dataset key (`:fire_occurrence` or `:burn_boundaries`)
- `where::String`: SQL-like where clause (default: "1=1" for all records)
- `fields::String`: Comma-separated field names or "*" for all
- `limit::Int`: Maximum number of features to return (default: unlimited, but MapServer has 2000 record limit)
- `verbose::Bool`: Print progress information

# Returns
A `JSON3.Object` containing the GeoJSON FeatureCollection.

# Examples
```julia
# Download fire occurrence points (limited to 100)
data = MTBS.download(:fire_occurrence, limit=100)

# Download fires in California
data = MTBS.download(:fire_occurrence, where="FIRE_NAME LIKE '%CA%'", limit=100)

# Download large fires (over 10,000 acres)
data = MTBS.download(:burn_boundaries, where="ACRES > 10000", limit=50)

# Download fires from a specific year
data = MTBS.download(:fire_occurrence, where="YEAR = 2020", limit=100)
```
"""
function download(dataset::Symbol; where::String="1=1", fields::String="*",
                  limit::Union{Int,Nothing}=nothing, verbose::Bool=true)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")
    end

    d = DATASETS[dataset]
    url = query_url(dataset; where=where, outfields=fields, limit=limit)

    verbose && println("Downloading: $(d.name)")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false)

    if response.status != 200
        error("Failed to download dataset. HTTP status: $(response.status)\nResponse: $(String(response.body))")
    end

    verbose && println("Parsing GeoJSON...")
    body = String(response.body)

    # First check for ArcGIS error response using JSON3
    json_data = JSON3.read(body)
    if haskey(json_data, :error)
        error("ArcGIS API error: $(json_data.error)")
    end

    # Parse as GeoJSON
    data = GeoJSON.read(body)

    n = length(data)
    verbose && println("Downloaded $n features")
    if haskey(json_data, :properties) && haskey(json_data.properties, :exceededTransferLimit) && json_data.properties.exceededTransferLimit
        verbose && println("⚠ Warning: Transfer limit exceeded (max 2000 records). Use `limit` parameter or refine `where` clause.")
    end

    return data
end

"""
    download_file(dataset::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download an MTBS dataset and save it to the local data directory as GeoJSON.

# Arguments
- `dataset::Symbol`: The dataset key (`:fire_occurrence` or `:burn_boundaries`)
- `filename::String`: Custom filename (default: dataset key + .geojson)
- `force::Bool`: Overwrite existing file if it exists
- `verbose::Bool`: Print progress information
- `kwargs...`: Additional arguments passed to `download()`

# Returns
The path to the downloaded file.

# Example
```julia
path = MTBS.download_file(:fire_occurrence, limit=1000)
```
"""
function download_file(dataset::Symbol; filename::Union{String,Nothing}=nothing,
                       force::Bool=false, verbose::Bool=true, kwargs...)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")
    end

    mkpath(dir())

    if isnothing(filename)
        filename = string(dataset) * ".geojson"
    end
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to overwrite.")
        return filepath
    end

    data = download(dataset; verbose=verbose, kwargs...)

    open(filepath, "w") do io
        JSON3.write(io, data)
    end
    verbose && println("Saved to: $filepath")

    return filepath
end

"""
    load_file(dataset::Symbol; filename=nothing)

Load a previously downloaded dataset from the local data directory.

# Example
```julia
MTBS.download_file(:fire_occurrence, limit=100)  # download first
data = MTBS.load_file(:fire_occurrence)
```
"""
function load_file(dataset::Symbol; filename::Union{String,Nothing}=nothing)
    if isnothing(filename)
        filename = string(dataset) * ".geojson"
    end
    filepath = joinpath(dir(), filename)

    if !isfile(filepath)
        error("File not found: $filepath. Download the dataset first.")
    end

    return GeoJSON.read(filepath)
end

"""
    count(dataset::Symbol; where="1=1")

Get the count of features in a dataset matching the where clause.

# Example
```julia
MTBS.count(:fire_occurrence)  # total count
MTBS.count(:burn_boundaries, where="YEAR = 2020")  # 2020 fires
MTBS.count(:fire_occurrence, where="ACRES > 10000")  # large fires
```
"""
function count(dataset::Symbol; where::String="1=1")
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")
    end

    d = DATASETS[dataset]
    url = "$MAPSERVER_BASE/$(d.layer)/query"
    params = [
        "where" => HTTP.escapeuri(where),
        "returnCountOnly" => "true",
        "f" => "json",
    ]
    full_url = url * "?" * join(["$k=$v" for (k, v) in params], "&")

    response = HTTP.get(full_url; status_exception=false)
    if response.status != 200
        error("Failed to get count. HTTP status: $(response.status)")
    end

    data = JSON3.read(response.body)
    return data.count
end

"""
    fields(dataset::Symbol)

Get the field names and types for a dataset.

# Example
```julia
MTBS.fields(:fire_occurrence)
MTBS.fields(:burn_boundaries)
```
"""
function fields(dataset::Symbol)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")
    end

    d = DATASETS[dataset]
    url = "$MAPSERVER_BASE/$(d.layer)?f=json"

    response = HTTP.get(url; status_exception=false)
    if response.status != 200
        error("Failed to get field info. HTTP status: $(response.status)")
    end

    data = JSON3.read(response.body)

    if haskey(data, :fields)
        return [(name=f.name, type=f.type, alias=get(f, :alias, f.name)) for f in data.fields]
    else
        error("Could not retrieve field information for this dataset.")
    end
end

#-----------------------------------------------------------------------------# Direct Download Functions

"""
    available_downloads()

List available direct file downloads (shapefiles and geodatabases).

# Example
```julia
MTBS.available_downloads()
```
"""
function available_downloads()
    println("Available MTBS Direct Downloads:")
    println("=" ^ 40)
    for (key, info) in DOWNLOADS
        println("\n:$key")
        println("  $(info.description)")
    end
    println("\nUse `MTBS.download_shapefile(:key)` to download.")
    return keys(DOWNLOADS)
end

"""
    download_shapefile(key::Symbol; force=false, verbose=true)

Download a shapefile or geodatabase directly from USDA Forest Service.

# Arguments
- `key::Symbol`: Download key (see `MTBS.available_downloads()`)
- `force::Bool`: Re-download even if file exists
- `verbose::Bool`: Print progress information

# Available keys
- `:burn_boundaries_shp` - Burn area boundaries shapefile (~374 MB)
- `:burn_boundaries_gdb` - Burn area boundaries geodatabase (~158 MB)
- `:fire_occurrence_shp` - Fire occurrence points shapefile (~3 MB)
- `:fire_occurrence_gdb` - Fire occurrence points geodatabase (~2 MB)

# Returns
The path to the downloaded file.

# Example
```julia
path = MTBS.download_shapefile(:fire_occurrence_shp)
```
"""
function download_shapefile(key::Symbol; force::Bool=false, verbose::Bool=true)
    if !haskey(DOWNLOADS, key)
        error("Unknown download key: $key. Use `MTBS.available_downloads()` to list options.")
    end

    info = DOWNLOADS[key]
    mkpath(dir())
    filepath = joinpath(dir(), info.filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to re-download.")
        return filepath
    end

    verbose && println("Downloading: $(info.description)")
    verbose && println("URL: $(info.url)")

    Downloads.download(info.url, filepath)

    verbose && println("Saved to: $filepath")
    return filepath
end

#-----------------------------------------------------------------------------# Convenience Functions

"""
    fires(; year=nothing, min_acres=nothing, max_acres=nothing, fire_type=nothing, limit=1000)

Query fire occurrence points with optional filters.

# Arguments
- `year::Int`: Filter by year (1984-2024)
- `min_acres::Real`: Minimum fire size in acres
- `max_acres::Real`: Maximum fire size in acres
- `fire_type::String`: Fire type (e.g., "Wildfire", "Prescribed Fire")
- `limit::Int`: Maximum number of records (default: 1000, max: 2000)

# Returns
A `JSON3.Object` containing the GeoJSON FeatureCollection.

# Examples
```julia
# Get fires from 2020
data = MTBS.fires(year=2020)

# Get large wildfires
data = MTBS.fires(min_acres=50000, fire_type="Wildfire", limit=100)
```
"""
function fires(; year::Union{Int,Nothing}=nothing,
               min_acres::Union{Real,Nothing}=nothing,
               max_acres::Union{Real,Nothing}=nothing,
               fire_type::Union{String,Nothing}=nothing,
               limit::Int=1000)
    conditions = String[]

    !isnothing(year) && push!(conditions, "YEAR = $year")
    !isnothing(min_acres) && push!(conditions, "ACRES >= $min_acres")
    !isnothing(max_acres) && push!(conditions, "ACRES <= $max_acres")
    !isnothing(fire_type) && push!(conditions, "FIRE_TYPE = '$fire_type'")

    where_clause = isempty(conditions) ? "1=1" : join(conditions, " AND ")

    return download(:fire_occurrence; where=where_clause, limit=limit, verbose=false)
end

"""
    boundaries(; year=nothing, min_acres=nothing, max_acres=nothing, limit=100)

Query burn area boundaries with optional filters.

# Arguments
- `year::Int`: Filter by year (1984-2024)
- `min_acres::Real`: Minimum fire size in acres
- `max_acres::Real`: Maximum fire size in acres
- `limit::Int`: Maximum number of records (default: 100, max: 2000)

# Returns
A `JSON3.Object` containing the GeoJSON FeatureCollection.

# Examples
```julia
# Get burn boundaries from 2020
data = MTBS.boundaries(year=2020)

# Get large fire boundaries
data = MTBS.boundaries(min_acres=100000, limit=50)
```
"""
function boundaries(; year::Union{Int,Nothing}=nothing,
                    min_acres::Union{Real,Nothing}=nothing,
                    max_acres::Union{Real,Nothing}=nothing,
                    limit::Int=100)
    conditions = String[]

    !isnothing(year) && push!(conditions, "YEAR = $year")
    !isnothing(min_acres) && push!(conditions, "ACRES >= $min_acres")
    !isnothing(max_acres) && push!(conditions, "ACRES <= $max_acres")

    where_clause = isempty(conditions) ? "1=1" : join(conditions, " AND ")

    return download(:burn_boundaries; where=where_clause, limit=limit, verbose=false)
end

"""
    largest_fires(n::Int=100; year=nothing)

Get the n largest fires by acreage.

# Examples
```julia
MTBS.largest_fires(10)  # top 10 largest fires ever
MTBS.largest_fires(10, year=2020)  # top 10 in 2020
```
"""
function largest_fires(n::Int=100; year::Union{Int,Nothing}=nothing)
    where_clause = isnothing(year) ? "1=1" : "YEAR = $year"

    # Note: MapServer doesn't support ORDER BY in the same way, so we get more records
    # and sort client-side
    data = download(:fire_occurrence; where=where_clause, limit=min(n * 2, 2000), verbose=false)

    if length(data) > 0
        # Sort by ACRES descending and take top n
        sorted_features = sort(collect(data), by=f -> -something(f.ACRES, 0))
        return sorted_features[1:min(n, length(sorted_features))]
    end

    return collect(data)
end

end # module
