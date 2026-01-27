# WildfireData.jl

[![Build Status](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Docs Build](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/docs.yml/badge.svg)](https://github.com/RallypointOne/WildfireData.jl/actions/workflows/docs.yml)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://rallypointone.github.io/WildfireData.jl/)

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

See the [documentation](https://rallypointone.github.io/WildfireData.jl/) for more details.
