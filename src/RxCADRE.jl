module RxCADRE

using ..WildfireData
using HTTP
using CSV
using DataFrames
using ZipFile

#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("RxCADRE")

#-----------------------------------------------------------------------------# Constants

const ARCHIVE_BASE = "https://www.fs.usda.gov/rds/archive"
const CATALOG_BASE = "$ARCHIVE_BASE/Catalog"
const PRODUCTS_BASE = "$ARCHIVE_BASE/products"

# Browser-like headers required by USFS Research Data Archive CDN
const DOWNLOAD_HEADERS = [
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept" => "*/*",
    "Sec-Fetch-Dest" => "document",
    "Sec-Fetch-Mode" => "navigate",
    "Sec-Fetch-Site" => "none",
]

#-----------------------------------------------------------------------------# Dataset Definitions

"""
    RxCADREDataset

Metadata for an RxCADRE dataset archived in the USFS Research Data Archive.

# Fields
- `rds_id::String`: Research Data Series identifier (e.g., "RDS-2014-0028")
- `name::String`: Human-readable name
- `description::String`: Dataset description
- `category::Symbol`: Category (`:fuels`, `:fire_behavior`, `:meteorology`, `:energy`, `:emissions`)
- `zip_files::Vector{String}`: ZIP file names available for download
- `size_mb::Float64`: Approximate total download size in MB
- `years::Vector{Int}`: Campaign years included
- `doi::String`: Digital Object Identifier
"""
struct RxCADREDataset
    rds_id::String
    name::String
    description::String
    category::Symbol
    zip_files::Vector{String}
    size_mb::Float64
    years::Vector{Int}
    doi::String
end

const DATASETS = Dict{Symbol, RxCADREDataset}(
    :fuel_loading => RxCADREDataset(
        "RDS-2014-0028",
        "Ground Fuel Measurements",
        "Fuel loading, consumption, and fuel moisture content data for 28 sample units from prescribed fires in longleaf pine ecosystems at Eglin AFB and Joseph Jones Ecological Research Center.",
        :fuels,
        ["RDS-2014-0028_Data.zip"],
        0.06,
        [2008, 2011, 2012],
        "10.2737/RDS-2014-0028",
    ),
    :ground_cover => RxCADREDataset(
        "RDS-2014-0029",
        "Ground Cover Fractions",
        "Pre- and post-burn percent cover of green vegetation, non-photosynthetic vegetation (NPV), char, ash, and mineral soil.",
        :fuels,
        ["RDS-2014-0029.zip"],
        0.6,
        [2008, 2011, 2012],
        "10.2737/RDS-2014-0029",
    ),
    :fire_behavior => RxCADREDataset(
        "RDS-2016-0038",
        "In-situ Fire Behavior Measurements",
        "Flame temperature, horizontal/vertical mass flow, fire intensity, rate of spread, and wind speed/direction from sonic anemometers and thermocouple arrays.",
        :fire_behavior,
        ["RDS-2016-0038_Data_1_of_3.zip", "RDS-2016-0038_Data_2_of_3.zip", "RDS-2016-0038_Data_3_of_3.zip"],
        3665.0,
        [2012],
        "10.2737/RDS-2016-0038",
    ),
    :weather => RxCADREDataset(
        "RDS-2015-0027",
        "Background Weather Time Series",
        "2D wind speeds/directions, temperature, relative humidity at 4 heights, pressure (2-second sampling), and 10 Hz sonic anemometer 3D wind at 2 heights.",
        :meteorology,
        ["RDS-2015-0027.zip"],
        54.0,
        [2012],
        "10.2737/RDS-2015-0027",
    ),
    :wind_lidar => RxCADREDataset(
        "RDS-2015-0026",
        "CSU-MAPS Wind LiDAR and Profiler Data",
        "Doppler wind LiDAR velocity profiles and microwave temperature/relative humidity profiler data from surface to 10 km AGL.",
        :meteorology,
        ["RDS-2015-0026.zip"],
        238.0,
        [2012],
        "10.2737/RDS-2015-0026",
    ),
    :radiometer_locations => RxCADREDataset(
        "RDS-2015-0035",
        "Radiometer Locations",
        "Geographic locations of dual-band ground radiometers deployed within prescribed fire burn blocks.",
        :energy,
        ["RDS-2015-0035.zip"],
        0.65,
        [2008, 2011, 2012],
        "10.2737/RDS-2015-0035",
    ),
    :radiometer_data => RxCADREDataset(
        "RDS-2015-0036",
        "Radiometer Data",
        "Fire radiative power (FRP) and fire radiative energy (FRE) flux measurements from dual-band ground radiometers.",
        :energy,
        ["RDS-2015-0036.zip"],
        107.0,
        [2012],
        "10.2737/RDS-2015-0036",
    ),
    :smoke_emissions => RxCADREDataset(
        "RDS-2014-0015",
        "Airborne Smoke Emission and Dispersion Measurements",
        "Airborne measurements of CO2, CO, CH4, and H2O concentrations in smoke plumes from prescribed fires, plus smoke dispersion transects.",
        :emissions,
        ["RDS-2014-0015.zip"],
        0.82,
        [2012],
        "10.2737/RDS-2014-0015",
    ),
)

#-----------------------------------------------------------------------------# Info Functions

"""
    datasets(; category=nothing)

List available RxCADRE datasets. Optionally filter by category.

Categories: `:fuels`, `:fire_behavior`, `:meteorology`, `:energy`, `:emissions`

### Examples
```julia
RxCADRE.datasets()
RxCADRE.datasets(category=:fuels)
```
"""
function datasets(; category::Union{Symbol, Nothing}=nothing)
    if isnothing(category)
        return DATASETS
    else
        return Dict(k => v for (k, v) in DATASETS if v.category == category)
    end
end

"""
    info(dataset::Symbol)

Print information about a specific RxCADRE dataset.

### Examples
```julia
RxCADRE.info(:fuel_loading)
RxCADRE.info(:smoke_emissions)
```
"""
function info(dataset::Symbol)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `RxCADRE.datasets()` to list available datasets.")
    end
    d = DATASETS[dataset]
    println("Dataset: ", d.name)
    println("RDS ID: ", d.rds_id)
    println("Category: ", d.category)
    println("Years: ", join(d.years, ", "))
    println("Size: ", d.size_mb < 1 ? "$(round(d.size_mb * 1024, digits=0)) KB" : "$(d.size_mb) MB")
    println("DOI: https://doi.org/", d.doi)
    println("Description: ", d.description)
    println("ZIP files: ", join(d.zip_files, ", "))
    return nothing
end

"""
    catalog_url(dataset::Symbol)

Return the USFS Research Data Archive catalog URL for a dataset.

### Examples
```julia
RxCADRE.catalog_url(:fuel_loading)
```
"""
function catalog_url(dataset::Symbol)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `RxCADRE.datasets()` to list available datasets.")
    end
    return "$CATALOG_BASE/$(DATASETS[dataset].rds_id)"
end

#-----------------------------------------------------------------------------# Download Functions

"""
    download(dataset::Symbol; force=false, verbose=true)

Download an RxCADRE dataset ZIP file(s) and extract CSV data files to the local data directory.

### Arguments
- `dataset::Symbol`: Dataset key (see `RxCADRE.datasets()`)
- `force::Bool`: Re-download even if files already exist
- `verbose::Bool`: Print progress information

### Returns
The path to the extracted dataset directory.

### Examples
```julia
path = RxCADRE.download(:fuel_loading)
path = RxCADRE.download(:smoke_emissions, force=true)
```
"""
function download(dataset::Symbol; force::Bool=false, verbose::Bool=true)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `RxCADRE.datasets()` to list available datasets.")
    end

    d = DATASETS[dataset]
    dataset_dir = joinpath(dir(), string(dataset))

    if isdir(dataset_dir) && !isempty(readdir(dataset_dir)) && !force
        verbose && println("Dataset already downloaded: $dataset_dir")
        verbose && println("Use `force=true` to re-download.")
        return dataset_dir
    end

    mkpath(dataset_dir)

    verbose && println("Downloading: $(d.name) ($(d.rds_id))")
    verbose && println("Size: ~$(d.size_mb < 1 ? "$(round(d.size_mb * 1024, digits=0)) KB" : "$(d.size_mb) MB")")

    for zipname in d.zip_files
        url = "$PRODUCTS_BASE/$(d.rds_id)/$zipname"
        verbose && println("URL: $url")

        response = HTTP.get(url; headers=DOWNLOAD_HEADERS, status_exception=false,
                            connect_timeout=60, readtimeout=300)

        if response.status != 200
            error("Failed to download $zipname. HTTP status: $(response.status). " *
                  "Try downloading manually from: $(catalog_url(dataset))")
        end

        verbose && println("Extracting CSV files from $zipname...")

        reader = ZipFile.Reader(IOBuffer(response.body))
        try
            for f in reader.files
                # Extract CSV and text data files (skip metadata, supplements, geodatabases)
                if _is_data_file(f.name)
                    outname = basename(f.name)
                    outpath = joinpath(dataset_dir, outname)
                    open(outpath, "w") do io
                        write(io, read(f))
                    end
                    verbose && println("  Extracted: $outname")
                end
            end
        finally
            close(reader)
        end
    end

    n_files = length(filter(f -> _is_data_file(f), readdir(dataset_dir)))
    verbose && println("Downloaded $n_files data files to: $dataset_dir")

    return dataset_dir
end

function _is_data_file(name::String)
    lname = lowercase(name)
    return (endswith(lname, ".csv") || endswith(lname, ".txt")) &&
           !startswith(basename(lname), "_") &&
           !contains(lname, "metadata") &&
           !contains(lname, "fileindex")
end

#-----------------------------------------------------------------------------# Load Functions

"""
    list_files(dataset::Symbol)

List the data files available in a downloaded dataset.

### Examples
```julia
RxCADRE.download(:fuel_loading)
RxCADRE.list_files(:fuel_loading)
```
"""
function list_files(dataset::Symbol)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `RxCADRE.datasets()` to list available datasets.")
    end

    dataset_dir = joinpath(dir(), string(dataset))
    if !isdir(dataset_dir)
        error("Dataset not downloaded. Run `RxCADRE.download(:$dataset)` first.")
    end

    return sort(readdir(dataset_dir))
end

"""
    load(dataset::Symbol; file=nothing, skipto=nothing)

Load CSV data from a downloaded RxCADRE dataset as a `DataFrame`.

If the dataset contains a single CSV file, it is loaded directly. If the dataset
contains multiple CSV files, specify `file` to choose which one.

### Arguments
- `dataset::Symbol`: Dataset key
- `file::String`: Specific filename to load (required for multi-file datasets)
- `skipto::Int`: Row number to start reading data from (useful for files with metadata rows)

### Returns
A `DataFrame`.

### Examples
```julia
# Single-file dataset
RxCADRE.download(:ground_cover)
df = RxCADRE.load(:ground_cover)

# Multi-file dataset
RxCADRE.download(:fuel_loading)
RxCADRE.list_files(:fuel_loading)
df = RxCADRE.load(:fuel_loading, file="CADRE_2008_2011_2012_Fuel_moistures.csv")

# Smoke emissions
RxCADRE.download(:smoke_emissions)
df = RxCADRE.load(:smoke_emissions, file="Emissions_L2F_20121111.csv")
```
"""
function load(dataset::Symbol; file::Union{String, Nothing}=nothing, skipto::Union{Int, Nothing}=nothing)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `RxCADRE.datasets()` to list available datasets.")
    end

    dataset_dir = joinpath(dir(), string(dataset))
    if !isdir(dataset_dir)
        error("Dataset not downloaded. Run `RxCADRE.download(:$dataset)` first.")
    end

    files = sort(filter(f -> endswith(lowercase(f), ".csv") || endswith(lowercase(f), ".txt"), readdir(dataset_dir)))

    if isempty(files)
        error("No CSV/text files found in $dataset_dir")
    end

    if isnothing(file)
        if length(files) == 1
            file = files[1]
        else
            error("Dataset has $(length(files)) files. Specify which file to load with the `file` keyword.\n" *
                  "Available files: $(join(files, ", "))")
        end
    end

    filepath = joinpath(dataset_dir, file)
    if !isfile(filepath)
        error("File not found: $file. Available files: $(join(files, ", "))")
    end

    kwargs = isnothing(skipto) ? (;) : (; skipto)
    return CSV.read(filepath, DataFrame; kwargs...)
end

"""
    load_all(dataset::Symbol; skipto=nothing)

Load all CSV files from a downloaded RxCADRE dataset as a `Dict{String, DataFrame}`.

### Examples
```julia
RxCADRE.download(:smoke_emissions)
all_data = RxCADRE.load_all(:smoke_emissions)
```
"""
function load_all(dataset::Symbol; skipto::Union{Int, Nothing}=nothing)
    if !haskey(DATASETS, dataset)
        error("Unknown dataset: $dataset. Use `RxCADRE.datasets()` to list available datasets.")
    end

    dataset_dir = joinpath(dir(), string(dataset))
    if !isdir(dataset_dir)
        error("Dataset not downloaded. Run `RxCADRE.download(:$dataset)` first.")
    end

    files = sort(filter(f -> endswith(lowercase(f), ".csv") || endswith(lowercase(f), ".txt"), readdir(dataset_dir)))
    kwargs = isnothing(skipto) ? (;) : (; skipto)

    return Dict(f => CSV.read(joinpath(dataset_dir, f), DataFrame; kwargs...) for f in files)
end

end # module
