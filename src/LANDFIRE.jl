module LANDFIRE

using ..WildfireData
using Downloads
using HTTP

export products, versions, download_product, wcs_url, wms_url, info

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("LANDFIRE")

#-----------------------------------------------------------------------------# Constants

const DOWNLOAD_BASE = "https://landfire.gov/data-downloads"
const WCS_BASE = "https://edcintl.cr.usgs.gov/geoserver/landfire_wcs"
const WMS_BASE = "https://edcintl.cr.usgs.gov/geoserver/landfire"

# Available regions
const REGIONS = Dict{Symbol, NamedTuple{(:name, :code, :wcs_code, :wms_code), Tuple{String, String, String, String}}}(
    :conus => (name="Continental US", code="US", wcs_code="us", wms_code="us"),
    :alaska => (name="Alaska", code="AK", wcs_code="ak", wms_code="ak"),
    :hawaii => (name="Hawaii", code="HI", wcs_code="hi", wms_code="hi"),
)

# Available versions with their numeric codes
const VERSIONS = Dict{Symbol, NamedTuple{(:year, :code), Tuple{Int, String}}}(
    :LF2024 => (year=2024, code="250"),
    :LF2023 => (year=2023, code="240"),
    :LF2022 => (year=2022, code="230"),
    :LF2020 => (year=2020, code="220"),
    :LF2016 => (year=2016, code="200"),
    :LF2014 => (year=2014, code="140"),
    :LF2012 => (year=2012, code="130"),
    :LF2010 => (year=2010, code="120"),
    :LF2008 => (year=2008, code="110"),
    :LF2001 => (year=2001, code="105"),
)

# Product categories and their products
const PRODUCTS = Dict{Symbol, NamedTuple{(:name, :category, :description), Tuple{String, Symbol, String}}}(
    # Fuel Products
    :FBFM13 => (
        name = "13 Anderson Fire Behavior Fuel Models",
        category = :fuel,
        description = "Fire behavior fuel models based on Anderson's 13 fuel model classification"
    ),
    :FBFM40 => (
        name = "40 Scott and Burgan Fire Behavior Fuel Models",
        category = :fuel,
        description = "Fire behavior fuel models based on Scott and Burgan's 40 fuel model classification"
    ),
    :CFFDRS => (
        name = "Canadian Forest Fire Danger Rating System",
        category = :fuel,
        description = "Fuel types mapped to the Canadian Forest Fire Danger Rating System"
    ),
    :CBD => (
        name = "Canopy Bulk Density",
        category = :fuel,
        description = "Mass of available canopy fuel per unit canopy volume (kg/m³)"
    ),
    :CBH => (
        name = "Canopy Base Height",
        category = :fuel,
        description = "Height from ground to the base of the canopy (m)"
    ),
    :CC => (
        name = "Canopy Cover",
        category = :fuel,
        description = "Percent cover of the tree canopy"
    ),
    :CH => (
        name = "Canopy Height",
        category = :fuel,
        description = "Average height of the top of the canopy (m)"
    ),
    :FVC => (
        name = "Fuel Vegetation Cover",
        category = :fuel,
        description = "Percent cover of fuel vegetation"
    ),
    :FVH => (
        name = "Fuel Vegetation Height",
        category = :fuel,
        description = "Average height of fuel vegetation"
    ),
    :FVT => (
        name = "Fuel Vegetation Type",
        category = :fuel,
        description = "Classification of fuel vegetation types"
    ),

    # Vegetation Products
    :BPS => (
        name = "Biophysical Settings",
        category = :vegetation,
        description = "Potential natural vegetation that may have been dominant prior to Euro-American settlement"
    ),
    :EVC => (
        name = "Existing Vegetation Cover",
        category = :vegetation,
        description = "Vertically projected percent cover of the existing vegetation"
    ),
    :EVH => (
        name = "Existing Vegetation Height",
        category = :vegetation,
        description = "Average height of the dominant vegetation"
    ),
    :EVT => (
        name = "Existing Vegetation Type",
        category = :vegetation,
        description = "Classification of existing vegetation types"
    ),
    :SCLASS => (
        name = "Succession Class",
        category = :vegetation,
        description = "Current vegetation conditions relative to reference conditions"
    ),
    :VCC => (
        name = "Vegetation Condition Class",
        category = :vegetation,
        description = "Departure of current vegetation from historical reference conditions"
    ),
    :VDEP => (
        name = "Vegetation Departure",
        category = :vegetation,
        description = "Degree to which current vegetation has departed from simulated historical reference"
    ),

    # Disturbance Products
    :Dist => (
        name = "Annual Disturbance",
        category = :disturbance,
        description = "Annual disturbance events including fire, insects, disease, and other factors"
    ),
    :HDist => (
        name = "Historical Disturbance",
        category = :disturbance,
        description = "Cumulative disturbance from 1999 to present"
    ),

    # Topographic Products
    :Elev => (
        name = "Elevation",
        category = :topographic,
        description = "Elevation above sea level (m)"
    ),
    :Slp => (
        name = "Slope",
        category = :topographic,
        description = "Slope steepness (degrees)"
    ),
    :Asp => (
        name = "Aspect",
        category = :topographic,
        description = "Slope direction (degrees from north)"
    ),

    # Fire Regime Products
    :FRG => (
        name = "Fire Regime Group",
        category = :fire_regime,
        description = "Groupings of fire frequency and severity"
    ),
    :MFRI => (
        name = "Mean Fire Return Interval",
        category = :fire_regime,
        description = "Average period between fires under historical conditions"
    ),
    :PLS => (
        name = "Percent Low Severity",
        category = :fire_regime,
        description = "Percent of fires that were low severity under historical conditions"
    ),
    :PMS => (
        name = "Percent Mixed Severity",
        category = :fire_regime,
        description = "Percent of fires that were mixed severity under historical conditions"
    ),
    :PRS => (
        name = "Percent Replacement Severity",
        category = :fire_regime,
        description = "Percent of fires that were stand-replacing under historical conditions"
    ),
)

#-----------------------------------------------------------------------------# Info Functions

"""
    info()

Print information about LANDFIRE data products and access methods.
"""
function info()
    println("LANDFIRE: Landscape Fire and Resource Management Planning Tools")
    println("=" ^ 65)
    println("A joint USDI/USDA Forest Service program providing geospatial data")
    println("for wildland fire and natural resource management.")
    println()
    println("Data Categories:")
    println("  - Fuel: Fire behavior fuel models, canopy characteristics")
    println("  - Vegetation: Existing and potential vegetation classifications")
    println("  - Disturbance: Annual and historical disturbance events")
    println("  - Topographic: Elevation, slope, aspect")
    println("  - Fire Regime: Historical fire frequency and severity")
    println()
    println("Access Methods:")
    println("  - Full extent downloads (GeoTIFF rasters)")
    println("  - WCS/WMS web services for streaming access")
    println()
    println("Regions: CONUS, Alaska, Hawaii")
    println("Versions: 2001-2024")
    println()
    println("Use `LANDFIRE.products()` to list available products")
    println("Use `LANDFIRE.download_product()` to download data")
    return nothing
end

"""
    products(; category=nothing)

List available LANDFIRE products. Optionally filter by category.

# Categories
- `:fuel` - Fire behavior fuel models and canopy characteristics
- `:vegetation` - Existing and potential vegetation
- `:disturbance` - Annual and historical disturbances
- `:topographic` - Elevation, slope, aspect
- `:fire_regime` - Historical fire patterns

# Example
```julia
LANDFIRE.products()  # all products
LANDFIRE.products(category=:fuel)  # only fuel products
```
"""
function products(; category::Union{Symbol, Nothing}=nothing)
    if isnothing(category)
        return PRODUCTS
    else
        return Dict(k => v for (k, v) in PRODUCTS if v.category == category)
    end
end

"""
    versions()

List available LANDFIRE versions.

# Example
```julia
LANDFIRE.versions()
```
"""
versions() = VERSIONS

"""
    regions()

List available LANDFIRE regions.

# Example
```julia
LANDFIRE.regions()
```
"""
regions() = REGIONS

#-----------------------------------------------------------------------------# WCS/WMS URLs

"""
    wcs_url(region::Symbol, version::Symbol)

Get the WCS (Web Coverage Service) URL for a region and version.

WCS provides pixel-level data access for analysis without downloading.

# Arguments
- `region::Symbol`: `:conus`, `:alaska`, or `:hawaii`
- `version::Symbol`: e.g., `:LF2024`, `:LF2023`, `:LF2020`

# Example
```julia
LANDFIRE.wcs_url(:conus, :LF2024)
```
"""
function wcs_url(region::Symbol, version::Symbol)
    haskey(REGIONS, region) || error("Unknown region: $region. Options: $(keys(REGIONS))")
    haskey(VERSIONS, version) || error("Unknown version: $version. Options: $(keys(VERSIONS))")

    r = REGIONS[region]
    v = VERSIONS[version]
    return "$WCS_BASE/$(r.wcs_code)_$(v.code)/wcs"
end

"""
    wms_url(region::Symbol, version::Symbol)

Get the WMS (Web Map Service) URL for a region and version.

WMS provides map image access for viewing in GIS applications.

# Arguments
- `region::Symbol`: `:conus`, `:alaska`, or `:hawaii`
- `version::Symbol`: e.g., `:LF2024`, `:LF2023`, `:LF2020`

# Example
```julia
LANDFIRE.wms_url(:conus, :LF2024)
# Add ?service=WMS&request=GetCapabilities for capabilities document
```
"""
function wms_url(region::Symbol, version::Symbol)
    haskey(REGIONS, region) || error("Unknown region: $region. Options: $(keys(REGIONS))")
    haskey(VERSIONS, version) || error("Unknown version: $version. Options: $(keys(VERSIONS))")

    r = REGIONS[region]
    v = VERSIONS[version]
    return "$WMS_BASE/$(r.wms_code)_$(v.code)/ows"
end

"""
    wms_capabilities_url(region::Symbol, version::Symbol)

Get the WMS GetCapabilities URL for a region and version.

# Example
```julia
LANDFIRE.wms_capabilities_url(:conus, :LF2024)
```
"""
function wms_capabilities_url(region::Symbol, version::Symbol)
    return wms_url(region, version) * "?service=WMS&request=GetCapabilities"
end

"""
    wcs_capabilities_url(region::Symbol, version::Symbol)

Get the WCS GetCapabilities URL for a region and version.

# Example
```julia
LANDFIRE.wcs_capabilities_url(:conus, :LF2024)
```
"""
function wcs_capabilities_url(region::Symbol, version::Symbol)
    return wcs_url(region, version) * "?request=GetCapabilities&service=WCS"
end

#-----------------------------------------------------------------------------# Download Functions

"""
    download_url(product::Symbol, region::Symbol, version::Symbol)

Get the download URL for a specific product, region, and version.

Note: Not all product/region/version combinations are available.

# Example
```julia
LANDFIRE.download_url(:FBFM40, :conus, :LF2024)
```
"""
function download_url(product::Symbol, region::Symbol, version::Symbol)
    haskey(PRODUCTS, product) || error("Unknown product: $product. Use `LANDFIRE.products()` to list.")
    haskey(REGIONS, region) || error("Unknown region: $region. Options: $(keys(REGIONS))")
    haskey(VERSIONS, version) || error("Unknown version: $version. Options: $(keys(VERSIONS))")

    r = REGIONS[region]
    v = VERSIONS[version]
    p = PRODUCTS[product]

    # Build the download path based on product category and naming conventions
    region_code = r.code
    version_code = v.code
    year = v.year

    # Different products have different URL patterns
    if p.category == :topographic
        dir_suffix = "Topo_$(year)"
        filename = "LF$(year)_$(product)_$(version_code)_$(region_code).zip"
    elseif p.category == :disturbance
        if product == :HDist
            # Historical disturbance has special naming
            if region == :conus
                return "$DOWNLOAD_BASE/AnnualDist/USAnnualDisturbance_1999_present.zip"
            elseif region == :alaska
                return "$DOWNLOAD_BASE/AnnualDist/AKAnnualDisturbance_1999_present.zip"
            else
                return "$DOWNLOAD_BASE/AnnualDist/HIAnnualDisturbance_2011_present.zip"
            end
        else
            dir_suffix = "Disturbance"
            filename = "LF$(year)_$(product)_$(version_code)_$(region_code).zip"
        end
    else
        dir_suffix = version_code
        filename = "LF$(year)_$(product)_$(version_code)_$(region_code == "US" ? "CONUS" : region_code).zip"
    end

    return "$DOWNLOAD_BASE/$(region_code)_$(dir_suffix)/$filename"
end

"""
    download_product(product::Symbol, region::Symbol, version::Symbol; force=false, verbose=true)

Download a LANDFIRE product for a specific region and version.

Note: Files can be very large (hundreds of MB to several GB). Not all combinations are available.

# Arguments
- `product::Symbol`: Product key (see `LANDFIRE.products()`)
- `region::Symbol`: `:conus`, `:alaska`, or `:hawaii`
- `version::Symbol`: e.g., `:LF2024`, `:LF2023`, `:LF2020`
- `force::Bool`: Re-download even if file exists
- `verbose::Bool`: Print progress information

# Returns
The path to the downloaded file.

# Example
```julia
# Download FBFM40 fuel model for CONUS (warning: ~3 GB)
path = LANDFIRE.download_product(:FBFM40, :conus, :LF2024)

# Download aspect data for Alaska
path = LANDFIRE.download_product(:Asp, :alaska, :LF2020)
```
"""
function download_product(product::Symbol, region::Symbol, version::Symbol;
                          force::Bool=false, verbose::Bool=true)
    url = download_url(product, region, version)

    mkpath(dir())
    filename = basename(url)
    filepath = joinpath(dir(), filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to re-download.")
        return filepath
    end

    p = PRODUCTS[product]
    r = REGIONS[region]
    v = VERSIONS[version]

    verbose && println("Downloading: $(p.name)")
    verbose && println("Region: $(r.name)")
    verbose && println("Version: LF $(v.year)")
    verbose && println("URL: $url")
    verbose && println("Warning: LANDFIRE files can be very large (hundreds of MB to GB)")

    # Check if URL is valid first
    response = HTTP.head(url; status_exception=false)
    if response.status != 200
        error("Download not available for this product/region/version combination. HTTP status: $(response.status)")
    end

    Downloads.download(url, filepath)

    verbose && println("Saved to: $filepath")
    return filepath
end

"""
    list_downloads()

List all previously downloaded LANDFIRE files in the local data directory.

# Example
```julia
LANDFIRE.list_downloads()
```
"""
function list_downloads()
    d = dir()
    if !isdir(d)
        return String[]
    end
    return readdir(d)
end

#-----------------------------------------------------------------------------# Convenience Functions

"""
    fuel_products()

List all fuel-related products.
"""
fuel_products() = products(category=:fuel)

"""
    vegetation_products()

List all vegetation-related products.
"""
vegetation_products() = products(category=:vegetation)

"""
    topographic_products()

List all topographic products.
"""
topographic_products() = products(category=:topographic)

"""
    fire_regime_products()

List all fire regime products.
"""
fire_regime_products() = products(category=:fire_regime)

"""
    disturbance_products()

List all disturbance products.
"""
disturbance_products() = products(category=:disturbance)

end # module
