[![CI](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/CI.yml)
[![Docs Build](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/Docs.yml/badge.svg)](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/Docs.yml)
[![Stable Docs](https://img.shields.io/badge/docs-stable-blue)](https://RallypointOne.github.io/WildfireData.jl/stable/)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue)](https://RallypointOne.github.io/WildfireData.jl/dev/)

# WildfireData.jl

A Julia package for accessing wildfire and fire-related geospatial data from U.S., Canadian, and global sources.

## Data Sources

| Module | Source | Description |
|--------|--------|-------------|
| **WFIGS** | NIFC | Wildland Fire Interagency Geospatial Services |
| **IRWIN** | NIFC | Integrated Reporting of Wildland-Fire Information |
| **FPA-FOD** | USDA | Fire Program Analysis Fire-Occurrence Database |
| **MTBS** | USGS/USDA | Monitoring Trends in Burn Severity |
| **FIRMS** | NASA | Fire Information for Resource Management System |
| **LANDFIRE** | USGS/USDA | Landscape Fire and Resource Management Planning Tools |
| **FEDS** | NASA | Fire Events Data Suite (satellite-derived fire tracking) |
| **CWFIS** | NRCan | Canadian Wildland Fire Information System |
| **HMS** | NOAA | Hazard Mapping System (fire detections & smoke plumes) |
| **GWIS** | Copernicus | Global Wildfire Information System (fire danger & burnt areas) |
| **EGP** | NIFC | Enterprise Geospatial Portal (operational boundaries) |

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/RallypointOne/WildfireData.jl")
```

## Quick Start

```julia
using WildfireData

# List available WFIGS datasets
WFIGS.datasets()

# Get info about a specific dataset
WFIGS.info(:current_perimeters)

# Download data
data = WFIGS.download(:current_perimeters; limit=10)
```

See the [documentation](https://RallypointOne.github.io/WildfireData.jl/stable/) for more details.
