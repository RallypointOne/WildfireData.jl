module EGP

using ..WildfireData: WildfireData, ArcGISDataset,
    _datasets, _info, _download, _download_file, _load_file, _count, _fields


#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("EGP")

#-----------------------------------------------------------------------------# Constants
const ARCGIS_BASE = "https://services3.arcgis.com/T4QMspbfLg3qTGWY/ArcGIS/rest/services"

#-----------------------------------------------------------------------------# Dataset Definitions

"""
    DATASETS

Operational and jurisdictional boundary datasets from the NIFC Enterprise Geospatial Portal.
These complement fire event data in WFIGS/IRWIN with management and planning boundaries.

Categories: `:boundaries`, `:planning`
"""
const DATASETS = Dict{Symbol, ArcGISDataset}(
    :gacc_boundaries => ArcGISDataset(
        ARCGIS_BASE,
        "DMP_NationalGACCBoundaries_Public",
        0,
        "National GACC Boundaries",
        "Geographic Area Coordination Center boundaries for wildland fire management coordination.",
        :boundaries
    ),
    :dispatch_boundaries => ArcGISDataset(
        ARCGIS_BASE,
        "DMP_National_Dispatch_Boundaries_Public",
        0,
        "National Dispatch Boundaries",
        "Interagency dispatch center boundaries for wildland fire resource dispatching.",
        :boundaries
    ),
    :dispatch_locations => ArcGISDataset(
        ARCGIS_BASE,
        "DMP_National_Dispatch_Locations_Public",
        0,
        "National Dispatch Locations",
        "Point locations of interagency dispatch centers.",
        :boundaries
    ),
    :psa_boundaries => ArcGISDataset(
        ARCGIS_BASE,
        "DMP_Predictive_Service_Area__PSA_Boundaries_Public",
        0,
        "Predictive Service Area Boundaries",
        "Predictive Service Area (PSA) boundaries used for fire weather forecasting.",
        :boundaries
    ),
    :pods => ArcGISDataset(
        ARCGIS_BASE,
        "Nat_PODs_Public",
        1,
        "Potential Operational Delineations (PODs)",
        "Pre-identified planning areas for wildfire response operations.",
        :planning
    ),
    :ia_frequency_zones => ArcGISDataset(
        ARCGIS_BASE,
        "DMP_National_IA_Frequency_Zones_Federal_Public",
        0,
        "Initial Attack Frequency Zones (Federal)",
        "Federal initial attack frequency zones for fire management planning.",
        :planning
    ),
)

#-----------------------------------------------------------------------------# API Functions

"""
    query_url(dataset::Symbol; kwargs...)

Build a FeatureServer query URL for the dataset.
"""
function query_url(dataset::Symbol; kwargs...)
    haskey(DATASETS, dataset) || error("Unknown dataset: $dataset. Use `EGP.datasets()` to list available datasets.")
    WildfireData.query_url(DATASETS[dataset]; kwargs...)
end

"""
    datasets(; category=nothing)

List available EGP datasets. Optionally filter by category:
- `:boundaries` — Jurisdictional and operational boundaries (GACC, dispatch, PSA)
- `:planning` — Fire management planning areas (PODs, IA frequency zones)

### Examples
```julia
EGP.datasets()
EGP.datasets(category=:boundaries)
EGP.datasets(category=:planning)
```
"""
datasets(; category::Union{Symbol, Nothing}=nothing) = _datasets(DATASETS; category)

"""
    info(dataset::Symbol)

Print information about a specific dataset.

### Examples
```julia
EGP.info(:gacc_boundaries)
```
"""
info(dataset::Symbol) = _info(DATASETS, dataset, "EGP")

"""
    download(dataset::Symbol; where="1=1", fields="*", limit=nothing, bbox=nothing, verbose=true)

Download an EGP dataset and return as a `GeoJSON.FeatureCollection`.

### Examples
```julia
# Download all GACC boundaries
data = EGP.download(:gacc_boundaries)

# Download dispatch boundaries with limit
data = EGP.download(:dispatch_boundaries, limit=10)

# Download PODs in California
data = EGP.download(:pods, bbox=(-125, 32, -114, 42), limit=50)
```
"""
download(dataset::Symbol; kwargs...) = _download(DATASETS, dataset, "EGP"; kwargs...)

"""
    download_file(dataset::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download an EGP dataset and save it to the local data directory.

### Returns
The path to the downloaded GeoJSON file.

### Examples
```julia
path = EGP.download_file(:gacc_boundaries)
```
"""
download_file(dataset::Symbol; kwargs...) = _download_file(DATASETS, dataset, "EGP", dir(); kwargs...)

"""
    load_file(dataset::Symbol; filename=nothing)

Load a previously downloaded dataset from the local data directory.

### Examples
```julia
data = EGP.load_file(:gacc_boundaries)
```
"""
load_file(dataset::Symbol; kwargs...) = _load_file(dir(), dataset; kwargs...)

"""
    count(dataset::Symbol; where="1=1")

Get the count of features in a dataset.

### Examples
```julia
EGP.count(:gacc_boundaries)
EGP.count(:pods, where="GISAcres > 10000")
```
"""
count(dataset::Symbol; kwargs...) = _count(DATASETS, dataset, "EGP"; kwargs...)

"""
    fields(dataset::Symbol)

Get the field names and types for a dataset.

### Examples
```julia
EGP.fields(:gacc_boundaries)
```
"""
fields(dataset::Symbol) = _fields(DATASETS, dataset, "EGP")

end # module
