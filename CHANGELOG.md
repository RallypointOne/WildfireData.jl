## Unreleased

## v0.0.2

### Documentation
- Add interactive map visualizations using GeoMakie and Tyler for WFIGS, IRWIN, MTBS, and FIRMS modules
- Improve docstrings and module exports
- Update CI workflows and docs configuration from package template
- Add versioned docs deployment with backfill workflow
- Add dark mode support and search improvements to docs site

### Fixes
- Fix GeoJSON.read to pass file contents as string

## v0.0.1

Initial release of WildfireData.jl.

### Features
- **WFIGS** module: Access USGS Wildland Fire Interagency Geospatial Services data (historic perimeters, current perimeters, etc.)
- **IRWIN** module: Access Integrated Reporting of Wildland-Fire Information (fire occurrence data)
- **MTBS** module: Access Monitoring Trends in Burn Severity data (burned area boundaries, largest fires)
- **FIRMS** module: Access NASA FIRMS active fire/hotspot data (MODIS, VIIRS sensors)
- **FPA_FOD** module: Access Fire Program Analysis Fire-Occurrence Database (SQLite-based)
- **LANDFIRE** module: Access LANDFIRE geospatial data products (fuel models, vegetation, topography)

### Documentation
- Quarto-based documentation site with versioned deployment
- Interactive map visualizations using GeoMakie and Tyler for WFIGS, IRWIN, MTBS, and FIRMS modules
- Full API reference with expandable docstrings
- Getting started guide and per-module documentation
