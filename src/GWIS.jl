module GWIS

using ..WildfireData
using HTTP

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("GWIS")

#-----------------------------------------------------------------------------# Constants

const WMS_BASE_GWIS = "https://maps.effis.emergency.copernicus.eu/gwis"
const WMS_BASE_EFFIS = "https://maps.effis.emergency.copernicus.eu/effis"

"""
    LAYERS

Dictionary of available GWIS/EFFIS WMS layers. Each entry maps a `Symbol` key to a `NamedTuple`
with fields `id`, `name`, `description`, `category`, `base`, and `geometry`.

Categories: `:active_fires`, `:burnt_areas`, `:fire_danger`, `:fire_danger_mf`, `:severity`
"""
const LAYERS = Dict{Symbol, NamedTuple{(:id, :name, :description, :category, :base, :geometry), Tuple{String, String, String, Symbol, String, Symbol}}}(
    # Active Fires
    :modis_hotspots => (
        id = "modis.hs",
        name = "MODIS Active Fires",
        description = "MODIS satellite active fire/hotspot detections.",
        category = :active_fires,
        base = WMS_BASE_GWIS,
        geometry = :point,
    ),
    :viirs_hotspots => (
        id = "viirs.hs",
        name = "VIIRS Active Fires",
        description = "VIIRS satellite active fire/hotspot detections.",
        category = :active_fires,
        base = WMS_BASE_GWIS,
        geometry = :point,
    ),
    # Burnt Areas
    :modis_burnt_areas => (
        id = "modis.ba",
        name = "MODIS Burnt Areas",
        description = "Burnt area perimeters derived from MODIS satellite data (>= 30 hectares).",
        category = :burnt_areas,
        base = WMS_BASE_EFFIS,
        geometry = :polygon,
    ),
    :viirs_burnt_areas => (
        id = "nrt.ba",
        name = "VIIRS Burnt Areas (NRT)",
        description = "Near real-time burnt area perimeters derived from VIIRS/Sentinel-2 satellite data.",
        category = :burnt_areas,
        base = WMS_BASE_GWIS,
        geometry = :polygon,
    ),
    # Fire Danger (ECMWF)
    :fwi => (
        id = "ecmwf.fwi",
        name = "Fire Weather Index (ECMWF)",
        description = "Fire Weather Index from ECMWF forecasts (8 km resolution).",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :ffmc => (
        id = "ecmwf.ffmc",
        name = "Fine Fuel Moisture Code (ECMWF)",
        description = "Fine Fuel Moisture Code from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :dmc => (
        id = "ecmwf.dmc",
        name = "Duff Moisture Code (ECMWF)",
        description = "Duff Moisture Code from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :dc => (
        id = "ecmwf.dc",
        name = "Drought Code (ECMWF)",
        description = "Drought Code from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :isi => (
        id = "ecmwf.isi",
        name = "Initial Spread Index (ECMWF)",
        description = "Initial Spread Index from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :bui => (
        id = "ecmwf.bui",
        name = "Build Up Index (ECMWF)",
        description = "Build Up Index from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :fwi_anomaly => (
        id = "ecmwf.anomaly",
        name = "FWI Anomaly (ECMWF)",
        description = "Fire Weather Index anomaly from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    :fwi_ranking => (
        id = "ecmwf.ranking",
        name = "Fire Danger Ranking (ECMWF)",
        description = "Fire danger ranking from ECMWF forecasts.",
        category = :fire_danger,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
    # Fire Danger (Meteo France)
    :fwi_mf => (
        id = "mf010.fwi",
        name = "Fire Weather Index (Meteo France)",
        description = "Fire Weather Index from Meteo France forecasts.",
        category = :fire_danger_mf,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    ),
)

# Add severity layers for available years
for yr in 2018:2024
    LAYERS[Symbol("severity_$yr")] = (
        id = "severity_$yr",
        name = "Fire Severity ($yr)",
        description = "Annual fire severity assessment for $yr.",
        category = :severity,
        base = WMS_BASE_GWIS,
        geometry = :raster,
    )
end

#-----------------------------------------------------------------------------# Info Functions

"""
    info()

Print information about GWIS/EFFIS data services.
"""
function info()
    println("GWIS: Global Wildfire Information System / EFFIS")
    println("=" ^ 60)
    println("GWIS WMS: $WMS_BASE_GWIS")
    println("EFFIS WMS: $WMS_BASE_EFFIS")
    println()
    println("Copernicus Emergency Management Service for global fire")
    println("monitoring. Provides fire danger forecasts, active fire")
    println("detections, burnt area mapping, and fire severity data.")
    println()
    println("Coverage: Europe, Middle East, North Africa (EFFIS) + Global (GWIS)")
    println("License: CC BY 4.0")
    println()
    println("Data access: WMS map tile URLs for use with mapping tools.")
    println("Use `GWIS.layers()` to list available layers.")
    return nothing
end

"""
    layers(; category=nothing)

List available GWIS/EFFIS layers.

### Arguments
- `category::Symbol`: Filter by category (`:active_fires`, `:burnt_areas`, `:fire_danger`, `:fire_danger_mf`, `:severity`)

### Examples
```julia
GWIS.layers()
GWIS.layers(category=:active_fires)
GWIS.layers(category=:fire_danger)
```
"""
function layers(; category::Union{Symbol, Nothing}=nothing)
    if isnothing(category)
        return LAYERS
    else
        return Dict(k => v for (k, v) in LAYERS if v.category == category)
    end
end

#-----------------------------------------------------------------------------# WMS URL Builder

"""
    wms_url(layer::Symbol; bbox=(-180, -90, 180, 90), width=1024, height=512, days=1, format="image/png", srs="EPSG:4326")

Build a WMS GetMap URL for a GWIS/EFFIS layer.

### Arguments
- `layer::Symbol`: Layer key (see `GWIS.layers()`)
- `bbox`: Bounding box as `(west, south, east, north)` tuple (default: global)
- `width::Int`: Image width in pixels
- `height::Int`: Image height in pixels
- `days::Int`: Temporal range — 1, 7, 30, or 0 for full fire season (applies to active fires and burnt areas)
- `format::String`: Image format (default: `"image/png"`)
- `srs::String`: Spatial reference system (default: `"EPSG:4326"`)

### Examples
```julia
# Get VIIRS hotspots for Europe, last 7 days
url = GWIS.wms_url(:viirs_hotspots, bbox=(-25, 27, 45, 72), days=7)

# Get Fire Weather Index for Mediterranean
url = GWIS.wms_url(:fwi, bbox=(-10, 30, 40, 50))

# Get MODIS burnt areas for the full fire season
url = GWIS.wms_url(:modis_burnt_areas, bbox=(-25, 27, 45, 72), days=0)
```
"""
function wms_url(layer::Symbol;
                 bbox::NTuple{4, Real}=(-180, -90, 180, 90),
                 width::Int=1024, height::Int=512,
                 days::Int=1,
                 format::String="image/png",
                 srs::String="EPSG:4326")
    if !haskey(LAYERS, layer)
        error("Unknown layer: $layer. Use `GWIS.layers()` to list available layers.")
    end

    l = LAYERS[layer]
    bbox_str = join(bbox, ",")

    params = [
        "service" => "WMS",
        "request" => "GetMap",
        "version" => "1.1.1",
        "layers" => l.id,
        "styles" => "",
        "format" => format,
        "transparent" => "true",
        "width" => string(width),
        "height" => string(height),
        "srs" => srs,
        "bbox" => bbox_str,
    ]

    # Add temporal range for fire observation layers
    if l.category in (:active_fires, :burnt_areas)
        push!(params, "time" => string(days))
    end

    return l.base * "?" * join(["$k=$v" for (k, v) in params], "&")
end

"""
    download_tile(layer::Symbol; filename=nothing, force=false, verbose=true, kwargs...)

Download a WMS map tile image to the local data directory.

### Returns
The path to the downloaded image file.

### Examples
```julia
# Download VIIRS hotspots tile for Europe
path = GWIS.download_tile(:viirs_hotspots, bbox=(-25, 27, 45, 72), days=7)
```
"""
function download_tile(layer::Symbol; filename::Union{String, Nothing}=nothing,
                       force::Bool=false, verbose::Bool=true, kwargs...)
    if !haskey(LAYERS, layer)
        error("Unknown layer: $layer. Use `GWIS.layers()` to list available layers.")
    end

    mkpath(dir())

    if isnothing(filename)
        filename = string(layer) * ".png"
    end
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to overwrite.")
        return filepath
    end

    url = wms_url(layer; kwargs...)

    verbose && println("Downloading: $(LAYERS[layer].name)")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false)

    if response.status != 200
        error("Failed to download tile. HTTP status: $(response.status)")
    end

    open(filepath, "w") do io
        write(io, response.body)
    end
    verbose && println("Saved to: $filepath")

    return filepath
end

end # module
