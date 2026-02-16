module MTBS

using ..WildfireData: WildfireData, AbstractDataset,
    _download, _download_file, _load_file, _count, _fields
using Downloads


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
    MTBSDataset <: AbstractDataset

Metadata for an MTBS MapServer layer.
"""
struct MTBSDataset <: AbstractDataset
    base_url::String
    layer::Int
    name::String
    description::String
    geometry_type::Symbol  # :point or :polygon
end

WildfireData.base_query_url(d::MTBSDataset) = "$(d.base_url)/$(d.layer)/query"
WildfireData.base_layer_url(d::MTBSDataset) = "$(d.base_url)/$(d.layer)"

const DATASETS = Dict{Symbol, MTBSDataset}(
    :fire_occurrence => MTBSDataset(
        MAPSERVER_BASE,
        LAYER_FIRE_OCCURRENCE,
        "Fire Occurrence Locations (All Years)",
        "Point locations of all inventoried MTBS fires from 1984 to present. Includes fire name, date, acres, and burn severity assessment data.",
        :point
    ),
    :burn_boundaries => MTBSDataset(
        MAPSERVER_BASE,
        LAYER_BURN_BOUNDARIES,
        "Burned Area Boundaries (All Years)",
        "Polygon boundaries of burned areas from 1984 to present. Includes fire perimeters with burn severity thresholds.",
        :polygon
    ),
)

#-----------------------------------------------------------------------------# URL Builder

"""
    query_url(dataset::Symbol; kwargs...)

Build a MapServer query URL for the dataset.
"""
function query_url(dataset::Symbol; kwargs...)
    haskey(DATASETS, dataset) || error("Unknown dataset: $dataset. Use `MTBS.datasets()` to list available datasets.")
    WildfireData.query_url(DATASETS[dataset]; kwargs...)
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
    download(dataset::Symbol; where="1=1", fields="*", limit=nothing, bbox=nothing, verbose=true)

Download an MTBS dataset and return it as parsed GeoJSON.

!!! note "MapServer Record Limit"
    The MTBS MapServer enforces a maximum of 2000 records per request. If your query
    matches more than 2000 records, results will be silently truncated. Use `MTBS.count()`
    to check the total before downloading, and use `where` filters or `limit` to stay
    within bounds. For the full dataset, use `MTBS.download_shapefile()` instead.

# Arguments
- `dataset::Symbol`: The dataset key (`:fire_occurrence` or `:burn_boundaries`)
- `where::String`: SQL-like where clause (default: "1=1" for all records)
- `fields::String`: Comma-separated field names or "*" for all
- `limit::Int`: Maximum number of features to return (default: server max of 2000)
- `bbox`: Bounding box for spatial filtering, as `(west, south, east, north)` tuple or `"west,south,east,north"` string
- `verbose::Bool`: Print progress information

# Common Fields
- `:fire_occurrence`: `FIRE_NAME`, `YEAR`, `ACRES`, `FIRE_TYPE`, `IG_DATE`, `MTBS_ID`
- `:burn_boundaries`: `FIRE_NAME`, `YEAR`, `ACRES`, `IG_DATE`, `MTBS_ID`

# Returns
A `GeoJSON.FeatureCollection`.

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

# Download fires within a bounding box (Colorado)
data = MTBS.download(:fire_occurrence, bbox=(-109, 37, -102, 41), limit=500)
```
"""
download(dataset::Symbol; kwargs...) = _download(DATASETS, dataset, "MTBS"; kwargs...)

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
download_file(dataset::Symbol; kwargs...) = _download_file(DATASETS, dataset, "MTBS", dir(); kwargs...)

"""
    load_file(dataset::Symbol; filename=nothing)

Load a previously downloaded dataset from the local data directory.

# Example
```julia
MTBS.download_file(:fire_occurrence, limit=100)  # download first
data = MTBS.load_file(:fire_occurrence)
```
"""
load_file(dataset::Symbol; kwargs...) = _load_file(dir(), dataset; kwargs...)

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
count(dataset::Symbol; kwargs...) = _count(DATASETS, dataset, "MTBS"; kwargs...)

"""
    fields(dataset::Symbol)

Get the field names and types for a dataset.

# Example
```julia
MTBS.fields(:fire_occurrence)
MTBS.fields(:burn_boundaries)
```
"""
fields(dataset::Symbol) = _fields(DATASETS, dataset, "MTBS")

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

Note: The MapServer enforces a maximum of 2000 records per request.

# Arguments
- `year::Int`: Filter by year (1984-2024)
- `min_acres::Real`: Minimum fire size in acres
- `max_acres::Real`: Maximum fire size in acres
- `fire_type::String`: Fire type (e.g., "Wildfire", "Prescribed Fire")
- `limit::Int`: Maximum number of records (default: 1000, server max: 2000)

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
    !isnothing(fire_type) && push!(conditions, "FIRE_TYPE = '$(replace(fire_type, "'" => "''"))'")


    where_clause = isempty(conditions) ? "1=1" : join(conditions, " AND ")

    return download(:fire_occurrence; where=where_clause, limit=limit, verbose=false)
end

"""
    boundaries(; year=nothing, min_acres=nothing, max_acres=nothing, limit=100)

Query burn area boundaries with optional filters.

Note: The MapServer enforces a maximum of 2000 records per request.

# Arguments
- `year::Int`: Filter by year (1984-2024)
- `min_acres::Real`: Minimum fire size in acres
- `max_acres::Real`: Maximum fire size in acres
- `limit::Int`: Maximum number of records (default: 100, server max: 2000)

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
