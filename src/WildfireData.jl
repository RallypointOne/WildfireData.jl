module WildfireData

using Scratch
using HTTP
using JSON3
using GeoJSON

export WFIGS, IRWIN, FPA_FOD, MTBS, FIRMS, LANDFIRE

#-----------------------------------------------------------------------------# Data Directory
dir(x...) = joinpath(Scratch.@get_scratch!("data"), x...)

#-----------------------------------------------------------------------------# Abstract Dataset Interface

"""
    AbstractDataset

Abstract type for dataset metadata. Subtypes must have a `name::String` field
and implement `base_query_url(d)` and `base_layer_url(d)`.
"""
abstract type AbstractDataset end

"""
    base_query_url(d::AbstractDataset) -> String

Return the base URL for query requests (without parameters).
"""
function base_query_url end

"""
    base_layer_url(d::AbstractDataset) -> String

Return the base URL for layer metadata requests.
"""
function base_layer_url end

#-----------------------------------------------------------------------------# ArcGIS Dataset

"""
    ArcGISDataset

Metadata for an ArcGIS FeatureServer dataset.

# Fields
- `base_url::String`: Base URL for the ArcGIS service
- `service::String`: ArcGIS service name
- `layer::Int`: Layer index (usually 0)
- `name::String`: Human-readable name
- `description::String`: Dataset description
- `category::Symbol`: Category (e.g., :perimeters, :locations, :incidents, :history)
"""
struct ArcGISDataset <: AbstractDataset
    base_url::String
    service::String
    layer::Int
    name::String
    description::String
    category::Symbol
end

base_query_url(d::ArcGISDataset) = "$(d.base_url)/$(d.service)/FeatureServer/$(d.layer)/query"
base_layer_url(d::ArcGISDataset) = "$(d.base_url)/$(d.service)/FeatureServer/$(d.layer)"

#-----------------------------------------------------------------------------# Common URL Builder

"""
    query_url(d::AbstractDataset; where="1=1", outfields="*", limit=nothing, format="geojson")

Build a query URL for the dataset.
"""
function query_url(d::AbstractDataset; where::String="1=1", outfields::String="*", limit::Union{Int,Nothing}=nothing, format::String="geojson")
    url = base_query_url(d)
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

#-----------------------------------------------------------------------------# Common API Functions

"""
    _datasets(all_datasets::Dict{Symbol,<:AbstractDataset}; category=nothing)

Filter datasets by category. Used internally by submodules.
"""
function _datasets(all_datasets::Dict{Symbol,<:AbstractDataset}; category::Union{Symbol,Nothing}=nothing)
    if isnothing(category)
        return all_datasets
    else
        return Dict(k => v for (k, v) in all_datasets if v.category == category)
    end
end

"""
    _info(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String)

Print information about a specific dataset. Used internally by submodules.
"""
function _info(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String)
    if !haskey(all_datasets, dataset)
        error("Unknown dataset: $dataset. Use `$module_name.datasets()` to list available datasets.")
    end
    d = all_datasets[dataset]
    println("Dataset: ", d.name)
    println("Category: ", d.category)
    println("Description: ", d.description)
    println("Service: ", d.service)
    println("Query URL: ", query_url(d))
    return nothing
end

"""
    _download(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String; kwargs...)

Download a dataset and return it as a GeoJSON FeatureCollection. Used internally by submodules.
"""
function _download(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String;
                   where::String="1=1", fields::String="*", limit::Union{Int,Nothing}=nothing, verbose::Bool=true)
    if !haskey(all_datasets, dataset)
        error("Unknown dataset: $dataset. Use `$module_name.datasets()` to list available datasets.")
    end

    d = all_datasets[dataset]
    url = query_url(d; where=where, outfields=fields, limit=limit)

    verbose && println("Downloading: $(d.name)")
    verbose && println("URL: $url")

    response = HTTP.get(url; status_exception=false)

    if response.status != 200
        error("Failed to download dataset. HTTP status: $(response.status)\nResponse: $(String(response.body))")
    end

    verbose && println("Parsing GeoJSON...")
    body = String(response.body)

    # Check for ArcGIS error response (avoid full double-parse)
    if contains(body, "\"error\"")
        json_data = JSON3.read(body)
        if haskey(json_data, :error)
            error("ArcGIS API error: $(json_data.error)")
        end
    end

    # Parse as GeoJSON
    data = GeoJSON.read(body)

    n = length(data)
    verbose && println("Downloaded $n features")
    if contains(body, "exceededTransferLimit") && contains(body, "true")
        verbose && println("⚠ Warning: Transfer limit exceeded. Use `limit` parameter or refine `where` clause to get all data.")
    end

    return data
end

"""
    _download_file(all_datasets, dataset, module_name, data_dir; kwargs...)

Download a dataset and save it to the local data directory. Used internally by submodules.
"""
function _download_file(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String, data_dir::String;
                        filename::Union{String,Nothing}=nothing, force::Bool=false, verbose::Bool=true, kwargs...)
    if !haskey(all_datasets, dataset)
        error("Unknown dataset: $dataset. Use `$module_name.datasets()` to list available datasets.")
    end

    mkpath(data_dir)

    if isnothing(filename)
        filename = string(dataset) * ".geojson"
    end
    filepath = joinpath(data_dir, filename)

    if isfile(filepath) && !force
        verbose && println("File already exists: $filepath")
        verbose && println("Use `force=true` to overwrite.")
        return filepath
    end

    data = _download(all_datasets, dataset, module_name; verbose=verbose, kwargs...)

    open(filepath, "w") do io
        JSON3.write(io, data)
    end
    verbose && println("Saved to: $filepath")

    return filepath
end

"""
    _load_file(data_dir, dataset; filename=nothing)

Load a previously downloaded dataset from the local data directory. Used internally by submodules.
"""
function _load_file(data_dir::String, dataset::Symbol; filename::Union{String,Nothing}=nothing)
    if isnothing(filename)
        filename = string(dataset) * ".geojson"
    end
    filepath = joinpath(data_dir, filename)

    if !isfile(filepath)
        error("File not found: $filepath. Download the dataset first.")
    end

    return GeoJSON.read(read(filepath, String))
end

"""
    _count(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String; where="1=1")

Get the count of features in a dataset. Used internally by submodules.
"""
function _count(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String; where::String="1=1")
    if !haskey(all_datasets, dataset)
        error("Unknown dataset: $dataset. Use `$module_name.datasets()` to list available datasets.")
    end

    d = all_datasets[dataset]
    params = [
        "where" => HTTP.escapeuri(where),
        "returnCountOnly" => "true",
        "f" => "json",
    ]
    full_url = base_query_url(d) * "?" * join(["$k=$v" for (k, v) in params], "&")

    response = HTTP.get(full_url; status_exception=false)
    if response.status != 200
        error("Failed to get count. HTTP status: $(response.status)")
    end

    data = JSON3.read(response.body)
    return data.count
end

"""
    _fields(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String)

Get the field names and types for a dataset. Used internally by submodules.
"""
function _fields(all_datasets::Dict{Symbol,<:AbstractDataset}, dataset::Symbol, module_name::String)
    if !haskey(all_datasets, dataset)
        error("Unknown dataset: $dataset. Use `$module_name.datasets()` to list available datasets.")
    end

    d = all_datasets[dataset]
    url = base_layer_url(d) * "?f=json"

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

#-----------------------------------------------------------------------------# Submodules
include("WFIGS.jl")
include("IRWIN.jl")
include("FPA_FOD.jl")
include("MTBS.jl")
include("FIRMS.jl")
include("LANDFIRE.jl")

end
