module IRWIN

using ..WildfireData: WildfireData, ArcGISDataset,
    _datasets, _info, _download, _download_file, _load_file, _count, _fields


#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("IRWIN")

#-----------------------------------------------------------------------------# Constants
const NIFC_BASE = "https://services3.arcgis.com/T4QMspbfLg3qTGWY/ArcGIS/rest/services"
const ESRI_BASE = "https://services9.arcgis.com/RHVPKKiFTONKtxq3/ArcGIS/rest/services"

#-----------------------------------------------------------------------------# Dataset Definitions
const DATASETS = Dict{Symbol, ArcGISDataset}(
    :fire_occurrence => ArcGISDataset(
        NIFC_BASE,
        "InFORM_FireOccurrence_Public",
        0,
        "InFORM Fire Occurrence Data Records",
        "Official fire occurrence records from InFORM/IRWIN. The authoritative dataset for federal and some state fire agencies. Complete from 2020 to present.",
        :incidents
    ),
    :usa_current_incidents => ArcGISDataset(
        ESRI_BASE,
        "USA_Wildfires_v1",
        0,
        "USA Current Wildfire Incidents",
        "Current wildfire incident points across the United States. Sourced from IRWIN via ESRI Living Atlas. Updated frequently.",
        :incidents
    ),
    :usa_current_perimeters => ArcGISDataset(
        ESRI_BASE,
        "USA_Wildfires_v1",
        1,
        "USA Current Wildfire Perimeters",
        "Current wildfire perimeters across the United States. Sourced from IRWIN via ESRI Living Atlas. Updated frequently.",
        :perimeters
    ),
)

#-----------------------------------------------------------------------------# API Functions

"""
    query_url(dataset::Symbol; kwargs...)

Build a FeatureServer query URL for the dataset.
"""
function query_url(dataset::Symbol; kwargs...)
    haskey(DATASETS, dataset) || error("Unknown dataset: $dataset")
    WildfireData.query_url(DATASETS[dataset]; kwargs...)
end

"""
    datasets(; category=nothing)

List available IRWIN datasets. Optionally filter by category:
- `:incidents` - Fire incident point locations
- `:perimeters` - Fire perimeter polygons
- `:history` - Historical data

# Example
```julia
IRWIN.datasets()  # all datasets
IRWIN.datasets(category=:incidents)  # only incident datasets
```
"""
datasets(; category::Union{Symbol,Nothing}=nothing) = _datasets(DATASETS; category)

"""
    info(dataset::Symbol)

Print information about a specific dataset.

# Example
```julia
IRWIN.info(:fire_occurrence)
```
"""
info(dataset::Symbol) = _info(DATASETS, dataset, "IRWIN")

"""
    download(dataset::Symbol; where="1=1", fields="*", limit=nothing, verbose=true)

Download an IRWIN dataset and return it as parsed GeoJSON.

# Arguments
- `dataset::Symbol`: The dataset key (see `IRWIN.datasets()` for options)
- `where::String`: SQL-like where clause (default: "1=1" for all records)
- `fields::String`: Comma-separated field names or "*" for all
- `limit::Int`: Maximum number of features to return (default: unlimited)
- `verbose::Bool`: Print progress information

# Returns
A `JSON3.Object` containing the GeoJSON FeatureCollection.

# Examples
```julia
# Download current US wildfire incidents
data = IRWIN.download(:usa_current_incidents)

# Download fire occurrence records for California
data = IRWIN.download(:fire_occurrence, where="POOState = 'US-CA'", limit=100)

# Download large fires only
data = IRWIN.download(:usa_current_incidents, where="DailyAcres > 1000")
```
"""
download(dataset::Symbol; kwargs...) = _download(DATASETS, dataset, "IRWIN"; kwargs...)

"""
    download_file(dataset::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download an IRWIN dataset and save it to the local data directory.

# Arguments
- `dataset::Symbol`: The dataset key (see `IRWIN.datasets()` for options)
- `filename::String`: Custom filename (default: dataset key + .geojson)
- `force::Bool`: Overwrite existing file if it exists
- `verbose::Bool`: Print progress information
- `kwargs...`: Additional arguments passed to `download()`

# Returns
The path to the downloaded file.

# Example
```julia
path = IRWIN.download_file(:usa_current_incidents)
path = IRWIN.download_file(:fire_occurrence, where="POOState = 'US-CA'")
```
"""
download_file(dataset::Symbol; kwargs...) = _download_file(DATASETS, dataset, "IRWIN", dir(); kwargs...)

"""
    load_file(dataset::Symbol; filename=nothing)

Load a previously downloaded dataset from the local data directory.

# Example
```julia
IRWIN.download_file(:usa_current_incidents)  # download first
data = IRWIN.load_file(:usa_current_incidents)
```
"""
load_file(dataset::Symbol; kwargs...) = _load_file(dir(), dataset; kwargs...)

"""
    count(dataset::Symbol; where="1=1")

Get the count of features in a dataset matching the where clause.

# Example
```julia
IRWIN.count(:usa_current_incidents)  # total count
IRWIN.count(:fire_occurrence, where="POOState = 'US-CA'")  # California fires
```
"""
count(dataset::Symbol; kwargs...) = _count(DATASETS, dataset, "IRWIN"; kwargs...)

"""
    fields(dataset::Symbol)

Get the field names and types for a dataset.

# Example
```julia
IRWIN.fields(:usa_current_incidents)
```
"""
fields(dataset::Symbol) = _fields(DATASETS, dataset, "IRWIN")

end # module
