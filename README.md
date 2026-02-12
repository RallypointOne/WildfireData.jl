[![CI](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/CI.yml)
[![Docs Build](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/Docs.yml/badge.svg)](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/Docs.yml)
[![Stable Docs](https://img.shields.io/badge/docs-stable-blue)](https://RallypointOne.github.io/WildfireData.jl/stable/)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue)](https://RallypointOne.github.io/WildfireData.jl/dev/)

# WildfireData.jl

A Julia package for accessing wildfire and fire-related geospatial data from various U.S. government sources.

## Data Sources

- **WFIGS** - Wildland Fire Interagency Geospatial Services
- **IRWIN** - Integrated Reporting of Wildland-Fire Information
- **FPA-FOD** - Fire Program Analysis Fire-Occurrence Database
- **MTBS** - Monitoring Trends in Burn Severity
- **FIRMS** - Fire Information for Resource Management System (NASA)
- **LANDFIRE** - Landscape Fire and Resource Management Planning Tools

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
