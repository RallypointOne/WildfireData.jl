module WFIGS

using ..WildfireData: WildfireData, ArcGISDataset,
    _datasets, _info, _download, _download_file, _load_file, _count, _fields


#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("WFIGS")

#-----------------------------------------------------------------------------# Constants
const ARCGIS_BASE = "https://services3.arcgis.com/T4QMspbfLg3qTGWY/ArcGIS/rest/services"

#-----------------------------------------------------------------------------# Dataset Definitions
const DATASETS = Dict{Symbol, ArcGISDataset}(
    :current_perimeters => ArcGISDataset(
        ARCGIS_BASE,
        "WFIGS_Interagency_Perimeters_Current",
        0,
        "Current Interagency Fire Perimeters",
        "Best available perimeters for recent and ongoing wildland fires. Updated every 5 minutes.",
        :perimeters
    ),
    :current_locations => ArcGISDataset(
        ARCGIS_BASE,
        "WFIGS_Incident_Locations_Current",
        0,
        "Current Wildland Fire Locations",
        "Point locations for recent and ongoing wildland fires. Updated every 5 minutes.",
        :locations
    ),
    :historic_geomac => ArcGISDataset(
        ARCGIS_BASE,
        "Historic_Geomac_Perimeters_Combined_2000_2018",
        0,
        "Historic GeoMAC Perimeters (2000-2018)",
        "Historical fire perimeters from the GeoMAC system covering 2000-2018.",
        :history
    ),
    :perimeters_all_years => ArcGISDataset(
        ARCGIS_BASE,
        "InteragencyFirePerimeterHistory_All_Years_View",
        0,
        "Interagency Fire Perimeter History (All Years)",
        "Consolidated historical fire perimeter data across all available years.",
        :history
    ),
)

# Add year-specific Historic GeoMAC datasets
for yr in 2000:2018
    DATASETS[Symbol("historic_geomac_$yr")] = ArcGISDataset(
        ARCGIS_BASE,
        "Historic_Geomac_Perimeters_$yr",
        0,
        "Historic GeoMAC Perimeters ($yr)",
        "Historical fire perimeters from the GeoMAC system for $yr.",
        :history
    )
end

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

List available WFIGS datasets. Optionally filter by category:
- `:perimeters` - Fire perimeter polygons
- `:locations` - Fire location points
- `:history` - Historical data

# Example
```julia
WFIGS.datasets()  # all datasets
WFIGS.datasets(category=:perimeters)  # only perimeter datasets
```
"""
datasets(; category::Union{Symbol,Nothing}=nothing) = _datasets(DATASETS; category)

"""
    info(dataset::Symbol)

Print information about a specific dataset.

# Example
```julia
WFIGS.info(:current_perimeters)
```
"""
info(dataset::Symbol) = _info(DATASETS, dataset, "WFIGS")

"""
    download(dataset::Symbol; where="1=1", fields="*", limit=nothing, bbox=nothing, verbose=true)

Download a WFIGS dataset and return it as parsed GeoJSON.

# Arguments
- `dataset::Symbol`: The dataset key (see `WFIGS.datasets()` for options)
- `where::String`: SQL-like where clause (default: "1=1" for all records)
- `fields::String`: Comma-separated field names or "*" for all
- `limit::Int`: Maximum number of features to return (default: unlimited)
- `bbox`: Bounding box for spatial filtering, as `(west, south, east, north)` tuple or `"west,south,east,north"` string
- `verbose::Bool`: Print progress information

# Common Fields
- `:current_perimeters`: `IncidentName`, `GISAcres`, `CreateDate`, `DateCurrent`, `FeatureCategory`, `MapMethod`
- `:current_locations`: `IncidentName`, `DailyAcres`, `PercentContained`, `FireDiscoveryDateTime`, `POOState`
- Use `WFIGS.fields(dataset)` to see all available fields.

# Returns
A `GeoJSON.FeatureCollection`.

# Examples
```julia
# Download all current fire perimeters
data = WFIGS.download(:current_perimeters)

# Download only large fires (over 1000 acres)
data = WFIGS.download(:current_perimeters, where="GISAcres > 1000")

# Download with limit
data = WFIGS.download(:current_locations, limit=10)

# Download fires within a bounding box (California)
data = WFIGS.download(:current_perimeters, bbox=(-125, 32, -114, 42))

# Download specific fields
data = WFIGS.download(:current_perimeters, fields="IncidentName,GISAcres,CreateDate")
```
"""
download(dataset::Symbol; kwargs...) = _download(DATASETS, dataset, "WFIGS"; kwargs...)

"""
    download_file(dataset::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download a WFIGS dataset and save it to the local data directory.

# Arguments
- `dataset::Symbol`: The dataset key (see `WFIGS.datasets()` for options)
- `filename::String`: Custom filename (default: dataset key + .geojson)
- `force::Bool`: Overwrite existing file if it exists
- `verbose::Bool`: Print progress information
- `kwargs...`: Additional arguments passed to `download()`

# Returns
The path to the downloaded file.

# Example
```julia
path = WFIGS.download_file(:current_perimeters)
path = WFIGS.download_file(:current_perimeters, where="GISAcres > 1000")
```
"""
download_file(dataset::Symbol; kwargs...) = _download_file(DATASETS, dataset, "WFIGS", dir(); kwargs...)

"""
    load_file(dataset::Symbol; filename=nothing)

Load a previously downloaded dataset from the local data directory.

# Example
```julia
WFIGS.download_file(:current_perimeters)  # download first
data = WFIGS.load_file(:current_perimeters)
```
"""
load_file(dataset::Symbol; kwargs...) = _load_file(dir(), dataset; kwargs...)

"""
    count(dataset::Symbol; where="1=1")

Get the count of features in a dataset matching the where clause.

# Example
```julia
WFIGS.count(:current_perimeters)  # total count
WFIGS.count(:current_perimeters, where="GISAcres > 1000")  # large fires only
```
"""
count(dataset::Symbol; kwargs...) = _count(DATASETS, dataset, "WFIGS"; kwargs...)

"""
    fields(dataset::Symbol)

Get the field names and types for a dataset.

# Example
```julia
WFIGS.fields(:current_perimeters)
```
"""
fields(dataset::Symbol) = _fields(DATASETS, dataset, "WFIGS")

end # module
