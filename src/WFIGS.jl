module WFIGS

using ..WildfireData: WildfireData, ArcGISDataset,
    _datasets, _info, _download, _download_file, _load_file, _count, _fields
using GeoJSON
using Dates
using DataFrames
using HTTP
using JSON3


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
    :daily_perimeters => ArcGISDataset(
        ARCGIS_BASE,
        "WFIGS_Daily_Perimeters_Public",
        0,
        "WFIGS Daily Perimeters",
        "Every geometry change to the interagency perimeters, one feature per change with a sequential BurnPeriod and AcreageChange. Dense coverage from 2023 on (a few records in 2021-2022). Updated every 5 minutes.",
        :history
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

#-----------------------------------------------------------------------------# Fire Progression
const _PROGRESSION_FIELDS = (
    daily = (irwin=:poly_IRWINID, ufi=:attr_UniqueFireIdentifier, name=:poly_IncidentName, order=:BurnPeriod, time=:poly_DateCurrent, acres=:poly_GISAcres),
    geomac = (irwin=:irwinid, ufi=:uniquefireidentifier, name=:incidentname, order=:perimeterdatetime, time=:perimeterdatetime, acres=:gisacres),
)

function _progression_fields(dataset::Symbol)
    dataset == :daily_perimeters && return _PROGRESSION_FIELDS.daily
    startswith(string(dataset), "historic_geomac") && return _PROGRESSION_FIELDS.geomac
    error("progression is only available for :daily_perimeters and :historic_geomac* datasets, got :$dataset")
end

_sql(s::AbstractString) = replace(s, "'" => "''")

function _progression_where(fire::AbstractString, f)
    id = uppercase(strip(fire, ['{', '}']))
    if occursin(r"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$", id)
        "UPPER($(f.irwin)) IN ('{$id}','$id')"
    elseif occursin(r"^\d{4}-[A-Z0-9]+-\d+$", id)
        "$(f.ufi)='$id'"
    else
        "UPPER($(f.name))='$(_sql(uppercase(strip(fire))))'"
    end
end

# GET a query on `dataset` and `parse` the body. Retries network failures and truncated
# responses (the server can end a slow response early with status 200), not ArcGIS errors.
function _query(parse, dataset::Symbol, params; retries::Int=3)
    url = WildfireData.base_query_url(DATASETS[dataset]) * "?" * HTTP.escapeuri(params)
    err = nothing
    for attempt in 1:retries
        attempt > 1 && sleep(2^attempt)
        body = try
            String(HTTP.get(url; connect_timeout=60, readtimeout=60).body)
        catch e
            err = e
            continue
        end
        startswith(body, "{\"error\"") && error("ArcGIS API error: ", body)
        try
            return parse(body)
        catch e
            err = e
        end
    end
    throw(err)
end

"""
    incidents(name=""; dataset=:daily_perimeters, year=nothing)

Look up incidents by name in a perimeter archive. Returns a `DataFrame` with one row per
incident: `IncidentName`, `IrwinID`, `UniqueFireIdentifier`, `Perimeters` (number of archived
perimeters), `MaxAcres`, `FirstDate`, `LastDate`, sorted by `Perimeters` descending.
Pass `IrwinID` or `UniqueFireIdentifier` from a row to [`progression`](@ref).

# Arguments
- `name`: case-insensitive substring of the incident name; `""` matches every incident.
- `dataset`: `:daily_perimeters` or `:historic_geomac_YYYY` (see [`progression`](@ref)).
- `year`: keep only incidents whose UniqueFireIdentifier starts with this year.

### Examples
```julia
WFIGS.incidents("park", year=2024)
WFIGS.incidents("camp", dataset=:historic_geomac_2018)
```
"""
function incidents(name::AbstractString=""; dataset::Symbol=:daily_perimeters, year::Union{Integer,Nothing}=nothing)
    f = _progression_fields(dataset)
    where = "UPPER($(f.name)) LIKE '%$(_sql(uppercase(strip(name))))%'"
    isnothing(year) || (where *= " AND $(f.ufi) LIKE '$year-%'")
    stats = [
        (statisticType="count", onStatisticField=f.irwin, outStatisticFieldName="Perimeters"),
        (statisticType="max", onStatisticField=f.acres, outStatisticFieldName="MaxAcres"),
        (statisticType="min", onStatisticField=f.time, outStatisticFieldName="FirstDate"),
        (statisticType="max", onStatisticField=f.time, outStatisticFieldName="LastDate"),
    ]
    data = _query(JSON3.read, dataset, [
        "where" => where,
        "groupByFieldsForStatistics" => "$(f.name),$(f.irwin),$(f.ufi)",
        "outStatistics" => JSON3.write(stats),
        "orderByFields" => "Perimeters DESC",
        "f" => "json",
    ])
    rows = [x.attributes for x in data.features]
    date(ms) = isnothing(ms) ? missing : Date(unix2datetime(ms / 1000))
    return DataFrame(
        IncidentName = [r[f.name] for r in rows],
        IrwinID = [r[f.irwin] for r in rows],
        UniqueFireIdentifier = [r[f.ufi] for r in rows],
        Perimeters = [r.Perimeters for r in rows],
        MaxAcres = [something(r.MaxAcres, missing) for r in rows],
        FirstDate = [date(r.FirstDate) for r in rows],
        LastDate = [date(r.LastDate) for r in rows],
    )
end

"""
    progression(fire; dataset=:daily_perimeters, daily=false, tolerance=nothing, ntasks=6, verbose=true)

Download every archived perimeter of one fire, in chronological order, as a
`GeoJSON.FeatureCollection`. Each feature is the cumulative fire footprint at that
time, so the sequence is the fire's growth history.

# Arguments
- `fire::AbstractString`: IRWIN ID (`"{B5597100-...}"`, braces optional), UniqueFireIdentifier
  (`"2024-CABTU-013761"`), or incident name (case-insensitive; warns if several incidents match).
  Use [`incidents`](@ref) to find these identifiers.
- `dataset::Symbol`: `:daily_perimeters` (every geometry change, dense from 2023 on) or one of
  `:historic_geomac_2000` ... `:historic_geomac_2018` (every uploaded perimeter, 2000-2018).
  WFIGS keeps only the final perimeter for 2019-2022 fires.
- `daily::Bool`: keep only the last perimeter of each UTC day. Features without a timestamp are dropped.
- `tolerance`: server-side simplification tolerance in degrees (`1e-4` ≈ 11 m), or `nothing` for
  full resolution. Coordinates are always rounded to 6 decimal places (≈ 11 cm).
- `ntasks::Int`: number of perimeters downloaded concurrently.
- `verbose::Bool`: print progress information.

# Download time
Perimeters are fetched one per request. The NIFC server returns large polygons at tens of KB/s,
so a large fire at full resolution (tens of MB) takes minutes. `daily=true` is applied before
downloading geometry, and `tolerance=1e-4` reduces download size roughly tenfold.

# Ordering and time fields
`:daily_perimeters` is sorted by `BurnPeriod` (sequential per incident); timestamps are in
`poly_DateCurrent`, acreage in `poly_GISAcres`, growth since the previous perimeter in `AcreageChange`.
GeoMAC datasets are sorted by `perimeterdatetime`, acreage in `gisacres`.
Date fields are epoch milliseconds: `Dates.unix2datetime(t / 1000)`.

### Examples
```julia
# 2024 Park Fire, one perimeter per day, simplified to ~11 m
fc = WFIGS.progression("2024-CABTU-013761", daily=true, tolerance=1e-4)
for f in fc
    println(Dates.unix2datetime(f.poly_DateCurrent / 1000), "  ", f.poly_GISAcres, " acres")
end

# Every perimeter update at full resolution
fc = WFIGS.progression("2024-CABTU-013761")

# 2018 Camp Fire from the GeoMAC archive
fc = WFIGS.progression("2018-CABTU-016737", dataset=:historic_geomac_2018)
```
"""
function progression(fire::AbstractString; dataset::Symbol=:daily_perimeters, daily::Bool=false,
                     tolerance::Union{Real,Nothing}=nothing, ntasks::Int=6, verbose::Bool=true)
    f = _progression_fields(dataset)
    data = _query(JSON3.read, dataset, [
        "where" => _progression_where(fire, f),
        "outFields" => "*",
        "returnGeometry" => "false",
        "f" => "json",
    ])
    isempty(data.features) && error("No perimeters found for \"$fire\" in :$dataset. Use `WFIGS.incidents` to look up identifiers.")
    oid = Symbol(data.objectIdFieldName)
    rows = sort([x.attributes for x in data.features]; by=r -> something(r[f.order], 0))
    ids = unique(r[f.irwin] for r in rows)
    length(ids) > 1 && @warn "Multiple incidents match \"$fire\"; pass an IRWIN ID or UniqueFireIdentifier to select one" ids
    if daily
        filter!(r -> !isnothing(r[f.time]), rows)
        days = [Date(unix2datetime(r[f.time] / 1000)) for r in rows]
        rows = rows[[i == length(days) || days[i] != days[i + 1] for i in eachindex(days)]]
    end
    params = ["outFields" => "*", "outSR" => "4326", "geometryPrecision" => "6", "f" => "geojson"]
    isnothing(tolerance) || push!(params, "maxAllowableOffset" => string(tolerance))
    verbose && println("Downloading $(length(rows)) perimeters for \"$fire\" from $(DATASETS[dataset].name)")
    features = asyncmap(rows; ntasks) do r
        only(_query(GeoJSON.read, dataset, ["objectIds" => string(r[oid]); params]))
    end
    return GeoJSON.FeatureCollection(; features=identity.(features))
end

end # module
