## Unreleased

## v0.1.0

### Breaking
- **New exports**: `FEDS`, `CWFIS`, `HMS`, `GWIS`, `EGP` are now exported from `WildfireData`

### Features
- Add **FEDS** module: NASA Fire Events Data Suite — satellite-derived fire event tracking with perimeters, fire lines, and new fire pixels via OGC API
- Add **CWFIS** module: Canadian Wildland Fire Information System — active fires, hotspots, fire perimeters, fire danger, and weather stations via WFS
- Add **HMS** module: NOAA Hazard Mapping System — daily fire point detections and smoke plume polygons
- Add **GWIS** module: Global Wildfire Information System / EFFIS — WMS map tiles for fire danger, active fires, burnt areas, and severity (global coverage)
- Add **EGP** module: NIFC Enterprise Geospatial Portal — GACC boundaries, dispatch boundaries, PSA boundaries, PODs, and IA frequency zones via ArcGIS REST
- Increase HTTP connect and read timeouts from 30s to 60s across all modules to improve CI reliability

### Documentation
- Add documentation pages for all 5 new modules
- Update index page and README with new data source table
- Update API page with card header styling from package template

### Infrastructure
- Sync CI workflows with JuliaPackageTemplate (TagBot runner, Docs triggers)
- Update CLAUDE.md from package template

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
