using WildfireData
using WildfireData.WFIGS
using WildfireData.IRWIN
using WildfireData.FPA_FOD
using WildfireData.MTBS
using WildfireData.FIRMS
using WildfireData.LANDFIRE
using WildfireData.FEDS
using WildfireData.CWFIS
using WildfireData.HMS
using WildfireData.GWIS
using WildfireData.EGP
using Test
using DataFrames
using Dates
using GeoJSON

@testset "WildfireData.jl" begin

    @testset "WFIGS Module" begin

        @testset "datasets()" begin
            # Test that datasets returns a Dict
            ds = WFIGS.datasets()
            @test ds isa Dict{Symbol, WildfireData.ArcGISDataset}
            @test length(ds) > 0

            # Test that expected datasets exist
            @test haskey(ds, :current_perimeters)
            @test haskey(ds, :current_locations)
            @test haskey(ds, :historic_geomac)
            @test haskey(ds, :perimeters_all_years)

            # Test category filtering
            perimeters = WFIGS.datasets(category=:perimeters)
            @test all(d.category == :perimeters for d in values(perimeters))
            @test haskey(perimeters, :current_perimeters)
            @test !haskey(perimeters, :current_locations)

            locations = WFIGS.datasets(category=:locations)
            @test all(d.category == :locations for d in values(locations))
            @test haskey(locations, :current_locations)

            history = WFIGS.datasets(category=:history)
            @test all(d.category == :history for d in values(history))
            @test haskey(history, :historic_geomac)
        end

        @testset "Dataset struct" begin
            ds = WFIGS.datasets()
            d = ds[:current_perimeters]

            @test d.service == "WFIGS_Interagency_Perimeters_Current"
            @test d.layer == 0
            @test d.name == "Current Interagency Fire Perimeters"
            @test d.category == :perimeters
            @test !isempty(d.description)
        end

        @testset "query_url()" begin
            url = WFIGS.query_url(:current_perimeters)
            @test occursin("services3.arcgis.com", url)
            @test occursin("WFIGS_Interagency_Perimeters_Current", url)
            @test occursin("FeatureServer/0/query", url)
            @test occursin("f=geojson", url)
            @test occursin("outSR=4326", url)

            # Test with limit
            url_limit = WFIGS.query_url(:current_perimeters, limit=10)
            @test occursin("resultRecordCount=10", url_limit)

            # Test with where clause
            url_where = WFIGS.query_url(:current_perimeters, where="GISAcres > 1000")
            @test occursin("where=", url_where)

            # Test error for unknown dataset
            @test_throws ErrorException WFIGS.query_url(:nonexistent_dataset)
        end

        @testset "info() output" begin
            # Test that info doesn't throw and returns nothing
            result = @test_nowarn WFIGS.info(:current_perimeters)
            @test isnothing(result)

            # Test error for unknown dataset
            @test_throws ErrorException WFIGS.info(:nonexistent_dataset)
        end

        @testset "dir()" begin
            d = WFIGS.dir()
            @test d isa String
            @test occursin("WFIGS", d)
        end

        @testset "Historic GeoMAC year datasets" begin
            ds = WFIGS.datasets()
            # Check that year-specific datasets were created
            for yr in 2000:2018
                key = Symbol("historic_geomac_$yr")
                @test haskey(ds, key)
                @test ds[key].category == :history
                @test occursin(string(yr), ds[key].service)
            end
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "count()" begin
                n = WFIGS.count(:current_perimeters)
                @test n isa Integer
                @test n >= 0

                # Test with where clause
                n_large = WFIGS.count(:current_perimeters, where="1=1")
                @test n_large >= 0
            end

            @testset "fields()" begin
                f = WFIGS.fields(:current_perimeters)
                @test f isa Vector
                @test length(f) > 0

                # Check field structure
                first_field = f[1]
                @test haskey(first_field, :name)
                @test haskey(first_field, :type)
                @test haskey(first_field, :alias)
            end

            @testset "download() with limit" begin
                data = WFIGS.download(:current_locations, limit=2, verbose=false)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 2

                # Check feature structure
                if length(data) > 0
                    feature = data[1]
                    @test feature isa GeoJSON.Feature
                    @test !isnothing(GeoJSON.geometry(feature))
                end
            end

            @testset "download() with where clause" begin
                # Download with a filter
                data = WFIGS.download(:current_perimeters, where="1=1", limit=1, verbose=false)
                @test data isa GeoJSON.FeatureCollection
            end

            @testset "download_file() and load_file()" begin
                # Download to file
                filepath = WFIGS.download_file(:current_locations, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                # Load from file
                data = WFIGS.load_file(:current_locations)
                @test data isa GeoJSON.FeatureCollection

                # Clean up
                rm(filepath)
            end

            @testset "Error handling" begin
                @test_throws ErrorException WFIGS.download(:nonexistent_dataset)
                @test_throws ErrorException WFIGS.count(:nonexistent_dataset)
                @test_throws ErrorException WFIGS.fields(:nonexistent_dataset)
                @test_throws ErrorException WFIGS.load_file(:nonexistent_dataset)
            end
        end

    end

    @testset "IRWIN Module" begin

        @testset "datasets()" begin
            # Test that datasets returns a Dict
            ds = IRWIN.datasets()
            @test ds isa Dict{Symbol, WildfireData.ArcGISDataset}
            @test length(ds) > 0

            # Test that expected datasets exist
            @test haskey(ds, :fire_occurrence)
            @test haskey(ds, :usa_current_incidents)
            @test haskey(ds, :usa_current_perimeters)

            # Test category filtering
            incidents = IRWIN.datasets(category=:incidents)
            @test all(d.category == :incidents for d in values(incidents))
            @test haskey(incidents, :fire_occurrence)
            @test haskey(incidents, :usa_current_incidents)

            perimeters = IRWIN.datasets(category=:perimeters)
            @test all(d.category == :perimeters for d in values(perimeters))
            @test haskey(perimeters, :usa_current_perimeters)
        end

        @testset "Dataset struct" begin
            ds = IRWIN.datasets()
            d = ds[:fire_occurrence]

            @test d.service == "InFORM_FireOccurrence_Public"
            @test d.layer == 0
            @test d.name == "InFORM Fire Occurrence Data Records"
            @test d.category == :incidents
            @test !isempty(d.description)
            @test !isempty(d.base_url)
        end

        @testset "query_url()" begin
            url = IRWIN.query_url(:usa_current_incidents)
            @test occursin("services9.arcgis.com", url)
            @test occursin("USA_Wildfires_v1", url)
            @test occursin("FeatureServer/0/query", url)
            @test occursin("f=geojson", url)
            @test occursin("outSR=4326", url)

            # Test with limit
            url_limit = IRWIN.query_url(:usa_current_incidents, limit=10)
            @test occursin("resultRecordCount=10", url_limit)

            # Test fire_occurrence uses different base URL
            url_fodr = IRWIN.query_url(:fire_occurrence)
            @test occursin("services3.arcgis.com", url_fodr)
            @test occursin("InFORM_FireOccurrence_Public", url_fodr)

            # Test error for unknown dataset
            @test_throws ErrorException IRWIN.query_url(:nonexistent_dataset)
        end

        @testset "info() output" begin
            # Test that info doesn't throw and returns nothing
            result = @test_nowarn IRWIN.info(:usa_current_incidents)
            @test isnothing(result)

            # Test error for unknown dataset
            @test_throws ErrorException IRWIN.info(:nonexistent_dataset)
        end

        @testset "dir()" begin
            d = IRWIN.dir()
            @test d isa String
            @test occursin("IRWIN", d)
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "count()" begin
                n = IRWIN.count(:usa_current_incidents)
                @test n isa Integer
                @test n >= 0

                # Test fire_occurrence count
                n_fodr = IRWIN.count(:fire_occurrence)
                @test n_fodr isa Integer
                @test n_fodr >= 0
            end

            @testset "fields()" begin
                f = IRWIN.fields(:usa_current_incidents)
                @test f isa Vector
                @test length(f) > 0

                # Check field structure
                first_field = f[1]
                @test haskey(first_field, :name)
                @test haskey(first_field, :type)
                @test haskey(first_field, :alias)

                # Check some expected fields exist
                field_names = [field.name for field in f]
                @test "IncidentName" in field_names
                @test "DailyAcres" in field_names
            end

            @testset "download() with limit" begin
                data = IRWIN.download(:usa_current_incidents, limit=2, verbose=false)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 2

                # Check feature structure
                if length(data) > 0
                    feature = data[1]
                    @test feature isa GeoJSON.Feature
                    @test !isnothing(GeoJSON.geometry(feature))
                end
            end

            @testset "download() perimeters" begin
                data = IRWIN.download(:usa_current_perimeters, limit=1, verbose=false)
                @test data isa GeoJSON.FeatureCollection
            end

            @testset "download_file() and load_file()" begin
                # Download to file
                filepath = IRWIN.download_file(:usa_current_incidents, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                # Load from file
                data = IRWIN.load_file(:usa_current_incidents)
                @test data isa GeoJSON.FeatureCollection

                # Clean up
                rm(filepath)
            end

            @testset "Error handling" begin
                @test_throws ErrorException IRWIN.download(:nonexistent_dataset)
                @test_throws ErrorException IRWIN.count(:nonexistent_dataset)
                @test_throws ErrorException IRWIN.fields(:nonexistent_dataset)
                @test_throws ErrorException IRWIN.load_file(:nonexistent_dataset)
            end
        end

    end

    @testset "FPA_FOD Module" begin

        @testset "Constants" begin
            # Test time coverage constants
            @test FPA_FOD.YEAR_START == 1992
            @test FPA_FOD.YEAR_END == 2020

            # Test size classes
            @test FPA_FOD.SIZE_CLASSES isa Dict
            @test haskey(FPA_FOD.SIZE_CLASSES, 'A')
            @test haskey(FPA_FOD.SIZE_CLASSES, 'G')
            @test FPA_FOD.SIZE_CLASSES['A'] == (0.0, 0.25)
            @test FPA_FOD.SIZE_CLASSES['G'][1] == 5000.0

            # Test cause classifications
            @test FPA_FOD.CAUSE_CLASSIFICATIONS isa Vector
            @test "Human" in FPA_FOD.CAUSE_CLASSIFICATIONS
            @test "Natural" in FPA_FOD.CAUSE_CLASSIFICATIONS

            # Test general causes
            @test FPA_FOD.GENERAL_CAUSES isa Vector
            @test "Arson/Incendiarism" in FPA_FOD.GENERAL_CAUSES
            @test "Natural" in FPA_FOD.GENERAL_CAUSES
            @test "Smoking" in FPA_FOD.GENERAL_CAUSES

            # Test URLs
            @test occursin("fs.usda.gov", FPA_FOD.SQLITE_URL)
            @test occursin("RDS-2013-0009", FPA_FOD.SQLITE_URL)
        end

        @testset "dir()" begin
            d = FPA_FOD.dir()
            @test d isa String
            @test occursin("FPA_FOD", d)
        end

        @testset "db_path() without database" begin
            # If database doesn't exist, should return nothing
            # (or the path if it exists)
            path = FPA_FOD.db_path()
            @test path === nothing || isfile(path)
        end

        @testset "info() output" begin
            # Test that info doesn't throw
            result = @test_nowarn FPA_FOD.info()
            @test isnothing(result)
        end

        @testset "format_number()" begin
            # Test the internal number formatting function
            @test FPA_FOD.format_number(1000) == "1,000"
            @test FPA_FOD.format_number(1000000) == "1,000,000"
            @test FPA_FOD.format_number(123) == "123"
            @test FPA_FOD.format_number(1234567) == "1,234,567"
        end

        # Database-dependent tests - only run if database is downloaded
        if !isnothing(FPA_FOD.db_path())
            @testset "Database Tests" begin

                @testset "tables()" begin
                    t = FPA_FOD.tables()
                    @test t isa Vector
                    @test "Fires" in t
                end

                @testset "schema()" begin
                    s = FPA_FOD.schema()
                    @test s isa Vector
                    @test length(s) > 0

                    # Check schema structure
                    first_col = s[1]
                    @test haskey(first_col, :name)
                    @test haskey(first_col, :type)
                    @test haskey(first_col, :notnull)

                    # Check some expected columns exist
                    col_names = [col.name for col in s]
                    @test "FIRE_NAME" in col_names
                    @test "FIRE_SIZE" in col_names
                    @test "FIRE_YEAR" in col_names
                    @test "STATE" in col_names
                end

                @testset "count()" begin
                    n = FPA_FOD.count()
                    @test n isa Integer
                    @test n > 2_000_000  # Should have ~2.3 million records

                    # Test with where clause
                    n_ca = FPA_FOD.count(where="STATE = 'CA'")
                    @test n_ca isa Integer
                    @test n_ca > 0
                    @test n_ca < n
                end

                @testset "query()" begin
                    # Simple query
                    results = FPA_FOD.query("SELECT FIRE_NAME, FIRE_SIZE FROM Fires LIMIT 5")
                    @test results isa Vector
                    @test length(results) == 5
                    @test haskey(first(results), :FIRE_NAME)
                    @test haskey(first(results), :FIRE_SIZE)

                    # Query with limit parameter
                    results2 = FPA_FOD.query("SELECT * FROM Fires", limit=3)
                    @test length(results2) == 3
                end

                @testset "states()" begin
                    s = FPA_FOD.states()
                    @test s isa Vector
                    @test length(s) > 0
                    @test haskey(first(s), :STATE)
                    @test haskey(first(s), :count)

                    # Check some expected states
                    state_codes = [row.STATE for row in s]
                    @test "CA" in state_codes
                    @test "TX" in state_codes
                end

                @testset "causes()" begin
                    c = FPA_FOD.causes()
                    @test c isa Vector
                    @test length(c) > 0
                    @test haskey(first(c), :cause)
                    @test haskey(first(c), :count)
                end

                @testset "years()" begin
                    y = FPA_FOD.years()
                    @test y isa Vector
                    @test length(y) == FPA_FOD.YEAR_END - FPA_FOD.YEAR_START + 1
                    @test haskey(first(y), :year)
                    @test haskey(first(y), :count)

                    # Check year range
                    years_list = [row.year for row in y]
                    @test minimum(years_list) == FPA_FOD.YEAR_START
                    @test maximum(years_list) == FPA_FOD.YEAR_END
                end

                @testset "fires()" begin
                    # Basic query
                    f = FPA_FOD.fires(limit=10)
                    @test f isa Vector
                    @test length(f) <= 10
                    @test haskey(first(f), :FOD_ID)
                    @test haskey(first(f), :FIRE_NAME)
                    @test haskey(first(f), :FIRE_SIZE)

                    # Query with filters
                    f_ca = FPA_FOD.fires(state="CA", limit=5)
                    @test length(f_ca) <= 5
                    @test all(row.STATE == "CA" for row in f_ca)

                    f_2020 = FPA_FOD.fires(year=2020, limit=5)
                    @test all(row.FIRE_YEAR == 2020 for row in f_2020)

                    f_large = FPA_FOD.fires(min_size=10000, limit=5)
                    @test all(row.FIRE_SIZE >= 10000 for row in f_large)
                end

                @testset "largest_fires()" begin
                    # Basic query
                    lf = FPA_FOD.largest_fires(10)
                    @test lf isa Vector
                    @test length(lf) == 10
                    @test haskey(first(lf), :FOD_ID)
                    @test haskey(first(lf), :FIRE_SIZE)

                    # Should be sorted by size descending
                    sizes = [row.FIRE_SIZE for row in lf]
                    @test issorted(sizes, rev=true)

                    # Query with year filter
                    lf_2020 = FPA_FOD.largest_fires(5, year=2020)
                    @test length(lf_2020) == 5
                    @test all(row.FIRE_YEAR == 2020 for row in lf_2020)

                    # Query with state filter
                    lf_ca = FPA_FOD.largest_fires(5, state="CA")
                    @test all(row.STATE == "CA" for row in lf_ca)
                end

            end
        else
            @info "FPA_FOD database not downloaded - skipping database tests. Run FPA_FOD.download_database() to enable."
        end

        @testset "Error handling without database" begin
            if isnothing(FPA_FOD.db_path())
                @test_throws ErrorException FPA_FOD.query("SELECT * FROM Fires")
                @test_throws ErrorException FPA_FOD.count()
                @test_throws ErrorException FPA_FOD.tables()
                @test_throws ErrorException FPA_FOD.schema()
            end
        end

    end

    @testset "MTBS Module" begin

        @testset "Constants" begin
            # Test time coverage constants
            @test MTBS.YEAR_START == 1984
            @test MTBS.YEAR_END == 2024

            # Test layer IDs
            @test MTBS.LAYER_FIRE_OCCURRENCE == 62
            @test MTBS.LAYER_BURN_BOUNDARIES == 63

            # Test size thresholds
            @test MTBS.SIZE_THRESHOLD_WEST == 1000
            @test MTBS.SIZE_THRESHOLD_EAST == 500

            # Test URLs
            @test occursin("apps.fs.usda.gov", MTBS.MAPSERVER_BASE)
            @test occursin("EDW_MTBS_01", MTBS.MAPSERVER_BASE)
        end

        @testset "datasets()" begin
            ds = MTBS.datasets()
            @test ds isa Dict{Symbol, MTBS.MTBSDataset}
            @test length(ds) == 2

            # Test that expected datasets exist
            @test haskey(ds, :fire_occurrence)
            @test haskey(ds, :burn_boundaries)
        end

        @testset "MTBSDataset struct" begin
            ds = MTBS.datasets()

            d = ds[:fire_occurrence]
            @test d.layer == 62
            @test d.name == "Fire Occurrence Locations (All Years)"
            @test d.geometry_type == :point
            @test !isempty(d.description)

            d2 = ds[:burn_boundaries]
            @test d2.layer == 63
            @test d2.geometry_type == :polygon
        end

        @testset "query_url()" begin
            url = MTBS.query_url(:fire_occurrence)
            @test occursin("apps.fs.usda.gov", url)
            @test occursin("MapServer/62/query", url)
            @test occursin("f=geojson", url)
            @test occursin("outSR=4326", url)

            # Test burn boundaries URL
            url2 = MTBS.query_url(:burn_boundaries)
            @test occursin("MapServer/63/query", url2)

            # Test with limit
            url_limit = MTBS.query_url(:fire_occurrence, limit=10)
            @test occursin("resultRecordCount=10", url_limit)

            # Test with where clause
            url_where = MTBS.query_url(:fire_occurrence, where="ACRES > 1000")
            @test occursin("where=", url_where)

            # Test error for unknown dataset
            @test_throws ErrorException MTBS.query_url(:nonexistent_dataset)
        end

        @testset "info() output" begin
            # Test that info doesn't throw and returns nothing
            result = @test_nowarn MTBS.info(:fire_occurrence)
            @test isnothing(result)

            result2 = @test_nowarn MTBS.info(:burn_boundaries)
            @test isnothing(result2)

            # Test error for unknown dataset
            @test_throws ErrorException MTBS.info(:nonexistent_dataset)
        end

        @testset "dir()" begin
            d = MTBS.dir()
            @test d isa String
            @test occursin("MTBS", d)
        end

        @testset "available_downloads()" begin
            keys = MTBS.available_downloads()
            @test :burn_boundaries_shp in keys
            @test :burn_boundaries_gdb in keys
            @test :fire_occurrence_shp in keys
            @test :fire_occurrence_gdb in keys
        end

        @testset "DOWNLOADS constant" begin
            @test haskey(MTBS.DOWNLOADS, :burn_boundaries_shp)
            @test haskey(MTBS.DOWNLOADS, :fire_occurrence_shp)

            info = MTBS.DOWNLOADS[:fire_occurrence_shp]
            @test haskey(info, :url)
            @test haskey(info, :filename)
            @test haskey(info, :description)
            @test occursin("data.fs.usda.gov", info.url)
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "count()" begin
                n = MTBS.count(:fire_occurrence)
                @test n isa Integer
                @test n > 0

                n2 = MTBS.count(:burn_boundaries)
                @test n2 isa Integer
                @test n2 > 0

                # Test with where clause
                n_large = MTBS.count(:fire_occurrence, where="ACRES > 10000")
                @test n_large >= 0
                @test n_large < n
            end

            @testset "fields()" begin
                f = MTBS.fields(:fire_occurrence)
                @test f isa Vector
                @test length(f) > 0

                # Check field structure
                first_field = f[1]
                @test haskey(first_field, :name)
                @test haskey(first_field, :type)
                @test haskey(first_field, :alias)

                # Check some expected fields exist
                field_names = [field.name for field in f]
                @test "FIRE_NAME" in field_names
                @test "ACRES" in field_names
                @test "FIRE_ID" in field_names

                # Test burn boundaries fields
                f2 = MTBS.fields(:burn_boundaries)
                @test f2 isa Vector
                @test length(f2) > 0
            end

            @testset "download() with limit" begin
                data = MTBS.download(:fire_occurrence, limit=2, verbose=false)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 2

                # Check feature structure
                if length(data) > 0
                    feature = data[1]
                    @test feature isa GeoJSON.Feature
                    @test !isnothing(GeoJSON.geometry(feature))
                end
            end

            @testset "download() burn boundaries" begin
                data = MTBS.download(:burn_boundaries, limit=1, verbose=false)
                @test data isa GeoJSON.FeatureCollection
            end

            @testset "download() with where clause" begin
                data = MTBS.download(:fire_occurrence, where="ACRES > 50000", limit=5, verbose=false)
                @test data isa GeoJSON.FeatureCollection

                # Check that returned fires are actually large
                if length(data) > 0
                    for feature in data
                        @test feature.ACRES > 50000
                    end
                end
            end

            @testset "download_file() and load_file()" begin
                # Download to file
                filepath = MTBS.download_file(:fire_occurrence, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                # Load from file
                data = MTBS.load_file(:fire_occurrence)
                @test data isa GeoJSON.FeatureCollection

                # Clean up
                rm(filepath)
            end

            @testset "fires() convenience function" begin
                data = MTBS.fires(limit=5)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 5

                # Test with min_acres filter (more reliable than year filter)
                data_large = MTBS.fires(min_acres=100000, limit=5)
                @test data_large isa GeoJSON.FeatureCollection
            end

            @testset "boundaries() convenience function" begin
                data = MTBS.boundaries(limit=3)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 3
            end

            @testset "largest_fires()" begin
                lf = MTBS.largest_fires(5)
                @test lf isa AbstractVector
                @test length(lf) <= 5

                if length(lf) > 1
                    # Check sorted by size descending
                    sizes = [f.ACRES for f in lf]
                    @test issorted(sizes, rev=true)
                end
            end

            @testset "Error handling" begin
                @test_throws ErrorException MTBS.download(:nonexistent_dataset)
                @test_throws ErrorException MTBS.count(:nonexistent_dataset)
                @test_throws ErrorException MTBS.fields(:nonexistent_dataset)
                @test_throws ErrorException MTBS.load_file(:nonexistent_dataset)
                @test_throws ErrorException MTBS.download_shapefile(:nonexistent_download)
            end
        end

    end

    @testset "FIRMS Module" begin

        @testset "Constants" begin
            # Test API base URL
            @test occursin("firms.modaps.eosdis.nasa.gov", FIRMS.API_BASE)

            # Test SOURCES constant
            @test FIRMS.SOURCES isa Dict
            @test haskey(FIRMS.SOURCES, :MODIS_NRT)
            @test haskey(FIRMS.SOURCES, :VIIRS_NOAA20_NRT)
            @test haskey(FIRMS.SOURCES, :VIIRS_SNPP_NRT)
            @test haskey(FIRMS.SOURCES, :LANDSAT_NRT)

            # Test REGIONS constant
            @test FIRMS.REGIONS isa Dict
            @test haskey(FIRMS.REGIONS, :world)
            @test haskey(FIRMS.REGIONS, :conus)
            @test haskey(FIRMS.REGIONS, :california)
            @test FIRMS.REGIONS[:world] == "world"
        end

        @testset "sources()" begin
            s = FIRMS.sources()
            @test s isa Dict
            @test length(s) == 8  # 8 sources

            # Check source structure
            src = s[:VIIRS_NOAA20_NRT]
            @test haskey(src, :name)
            @test haskey(src, :description)
            @test haskey(src, :start_date)
            @test haskey(src, :type)
            @test src.type == :NRT

            # Test filtering by type
            nrt_sources = FIRMS.sources(type=:NRT)
            @test all(v.type == :NRT for v in values(nrt_sources))

            sp_sources = FIRMS.sources(type=:SP)
            @test all(v.type == :SP for v in values(sp_sources))
        end

        @testset "regions()" begin
            r = FIRMS.regions()
            @test r isa Dict
            @test length(r) > 5

            # Check some regions have valid bounding box format
            @test r[:conus] isa String
            @test Base.count(==(','), r[:conus]) == 3  # west,south,east,north
        end

        @testset "dir()" begin
            d = FIRMS.dir()
            @test d isa String
            @test occursin("FIRMS", d)
        end

        @testset "info() output" begin
            result = @test_nowarn FIRMS.info()
            @test isnothing(result)
        end

        @testset "MAP_KEY management" begin
            # Save current key
            original_key = get(ENV, "FIRMS_MAP_KEY", nothing)

            # Test set_map_key!
            FIRMS.set_map_key!("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6")
            @test FIRMS.get_map_key() == "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
            @test ENV["FIRMS_MAP_KEY"] == "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"

            # Restore original key
            if !isnothing(original_key)
                ENV["FIRMS_MAP_KEY"] = original_key
            else
                delete!(ENV, "FIRMS_MAP_KEY")
            end
        end

        # Network-dependent tests - only run if MAP_KEY is configured
        if !isnothing(FIRMS.get_map_key())
            @testset "Network API Tests" begin

                @testset "query_url()" begin
                    url = FIRMS.query_url(:VIIRS_NOAA20_NRT, "world", 1)
                    @test occursin("firms.modaps.eosdis.nasa.gov", url)
                    @test occursin("VIIRS_NOAA20_NRT", url)
                    @test occursin("/area/csv/", url)

                    # Test with date
                    url_date = FIRMS.query_url(:MODIS_NRT, "-120,35,-115,40", 1; date="2024-01-15")
                    @test occursin("2024-01-15", url_date)

                    # Test error for invalid source
                    @test_throws ErrorException FIRMS.query_url(:nonexistent_source, "world", 1)

                    # Test error for invalid days
                    @test_throws ErrorException FIRMS.query_url(:VIIRS_NOAA20_NRT, "world", 15)
                end

                @testset "download() basic" begin
                    # Download a small amount of data (1 day, small region)
                    df = FIRMS.download(:VIIRS_NOAA20_NRT, region=:california, days=1, verbose=false)
                    @test df isa DataFrame

                    # Check expected columns exist (may vary by source)
                    if nrow(df) > 0
                        @test "latitude" in names(df)
                        @test "longitude" in names(df)
                    end
                end

                @testset "download() with bounding box" begin
                    # Small bounding box around Los Angeles
                    df = FIRMS.download(:VIIRS_NOAA20_NRT, area="-119,33,-117,35", days=1, verbose=false)
                    @test df isa DataFrame
                end

                @testset "data_availability()" begin
                    avail = FIRMS.data_availability(:VIIRS_NOAA20_NRT)
                    @test avail isa DataFrame
                    @test nrow(avail) > 0
                end

                @testset "recent_fires()" begin
                    df = FIRMS.recent_fires(source=:VIIRS_NOAA20_NRT, region=:western_us, days=1)
                    @test df isa DataFrame
                end

                @testset "download_file() and load_file()" begin
                    # Download to file
                    filepath = FIRMS.download_file(:VIIRS_NOAA20_NRT, region=:california, days=1,
                                                   filename="test_firms.csv", verbose=false, force=true)
                    @test isfile(filepath)
                    @test endswith(filepath, ".csv")

                    # Load from file
                    df = FIRMS.load_file("test_firms.csv")
                    @test df isa DataFrame

                    # Clean up
                    rm(filepath)
                end

                @testset "Error handling" begin
                    @test_throws ErrorException FIRMS.download(:nonexistent_source)
                    @test_throws ErrorException FIRMS.data_availability(:nonexistent_source)
                    @test_throws ErrorException FIRMS.load_file("nonexistent_file.csv")
                end
            end
        else
            @info "FIRMS MAP_KEY not configured - skipping network tests. Set FIRMS_MAP_KEY environment variable to enable."
        end

    end

    @testset "FEDS Module" begin

        @testset "collections()" begin
            c = FEDS.collections()
            @test c isa Dict{Symbol, <:NamedTuple}
            @test length(c) == 9

            # Test that expected collections exist
            @test haskey(c, :snapshot_perimeters)
            @test haskey(c, :snapshot_firelines)
            @test haskey(c, :snapshot_newfirepix)
            @test haskey(c, :lf_perimeters)
            @test haskey(c, :lf_firelines)
            @test haskey(c, :lf_newfirepix)
            @test haskey(c, :archive_perimeters)
            @test haskey(c, :archive_firelines)
            @test haskey(c, :archive_newfirepix)

            # Test category filtering
            snap = FEDS.collections(category=:snapshot)
            @test length(snap) == 3
            @test all(v.category == :snapshot for v in values(snap))

            lf = FEDS.collections(category=:large_fire)
            @test length(lf) == 3
            @test all(v.category == :large_fire for v in values(lf))

            arch = FEDS.collections(category=:archive)
            @test length(arch) == 3
            @test all(v.category == :archive for v in values(arch))
        end

        @testset "Collection struct" begin
            c = FEDS.collections()
            sp = c[:snapshot_perimeters]

            @test sp.id == "public.eis_fire_snapshot_perimeter_nrt"
            @test sp.category == :snapshot
            @test sp.geometry == :polygon
            @test !isempty(sp.name)
            @test !isempty(sp.description)
        end

        @testset "query_url()" begin
            url = FEDS.query_url(:snapshot_perimeters)
            @test occursin("openveda.cloud", url)
            @test occursin("eis_fire_snapshot_perimeter_nrt", url)
            @test occursin("f=geojson", url)

            # Test with limit
            url_limit = FEDS.query_url(:snapshot_perimeters, limit=10)
            @test occursin("limit=10", url_limit)

            # Test with bbox tuple
            url_bbox = FEDS.query_url(:lf_perimeters, bbox=(-125, 32, -114, 42))
            @test occursin("bbox=-125,32,-114,42", url_bbox)

            # Test with bbox string
            url_bbox_str = FEDS.query_url(:lf_perimeters, bbox="-125,32,-114,42")
            @test occursin("bbox=-125,32,-114,42", url_bbox_str)

            # Test with datetime
            url_dt = FEDS.query_url(:archive_perimeters, datetime="2020-01-01T00:00:00Z/2020-12-31T23:59:59Z")
            @test occursin("datetime=", url_dt)

            # Test with sortby
            url_sort = FEDS.query_url(:snapshot_perimeters, sortby="-farea")
            @test occursin("sortby=-farea", url_sort)

            # Test error for unknown collection
            @test_throws ErrorException FEDS.query_url(:nonexistent_collection)
        end

        @testset "info() output" begin
            result = @test_nowarn FEDS.info(:snapshot_perimeters)
            @test isnothing(result)

            # Test error for unknown collection
            @test_throws ErrorException FEDS.info(:nonexistent_collection)
        end

        @testset "dir()" begin
            d = FEDS.dir()
            @test d isa String
            @test occursin("FEDS", d)
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "download() with limit" begin
                data = FEDS.download(:snapshot_perimeters, limit=2, verbose=false)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 2

                if length(data) > 0
                    feature = data[1]
                    @test feature isa GeoJSON.Feature
                    @test !isnothing(GeoJSON.geometry(feature))
                end
            end

            @testset "download_file() and load_file()" begin
                filepath = FEDS.download_file(:snapshot_perimeters, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                data = FEDS.load_file(:snapshot_perimeters)
                @test data isa GeoJSON.FeatureCollection

                # Clean up
                rm(filepath)
            end

            @testset "Error handling" begin
                @test_throws ErrorException FEDS.download(:nonexistent_collection)
                @test_throws ErrorException FEDS.download_file(:nonexistent_collection)
                @test_throws ErrorException FEDS.load_file(:nonexistent_collection)
            end
        end

    end

    @testset "LANDFIRE Module" begin

        @testset "Constants" begin
            # Test base URLs
            @test occursin("landfire.gov", LANDFIRE.DOWNLOAD_BASE)
            @test occursin("usgs.gov", LANDFIRE.WCS_BASE)
            @test occursin("usgs.gov", LANDFIRE.WMS_BASE)

            # Test REGIONS
            @test LANDFIRE.REGIONS isa Dict
            @test haskey(LANDFIRE.REGIONS, :conus)
            @test haskey(LANDFIRE.REGIONS, :alaska)
            @test haskey(LANDFIRE.REGIONS, :hawaii)

            # Test VERSIONS
            @test LANDFIRE.VERSIONS isa Dict
            @test haskey(LANDFIRE.VERSIONS, :LF2024)
            @test haskey(LANDFIRE.VERSIONS, :LF2020)
            @test LANDFIRE.VERSIONS[:LF2024].year == 2024

            # Test PRODUCTS
            @test LANDFIRE.PRODUCTS isa Dict
            @test haskey(LANDFIRE.PRODUCTS, :FBFM40)
            @test haskey(LANDFIRE.PRODUCTS, :Elev)
            @test haskey(LANDFIRE.PRODUCTS, :EVT)
        end

        @testset "products()" begin
            p = LANDFIRE.products()
            @test p isa Dict
            @test length(p) > 20  # Many products

            # Check product structure
            prod = p[:FBFM40]
            @test haskey(prod, :name)
            @test haskey(prod, :category)
            @test haskey(prod, :description)
            @test prod.category == :fuel

            # Test filtering by category
            fuel_prods = LANDFIRE.products(category=:fuel)
            @test all(v.category == :fuel for v in values(fuel_prods))
            @test haskey(fuel_prods, :FBFM40)
            @test haskey(fuel_prods, :CBD)

            veg_prods = LANDFIRE.products(category=:vegetation)
            @test all(v.category == :vegetation for v in values(veg_prods))
            @test haskey(veg_prods, :EVT)

            topo_prods = LANDFIRE.products(category=:topographic)
            @test all(v.category == :topographic for v in values(topo_prods))
            @test haskey(topo_prods, :Elev)
        end

        @testset "versions()" begin
            v = LANDFIRE.versions()
            @test v isa Dict
            @test length(v) >= 10  # Multiple versions

            # Check version structure
            ver = v[:LF2024]
            @test haskey(ver, :year)
            @test haskey(ver, :code)
            @test ver.year == 2024
            @test ver.code == "250"
        end

        @testset "regions()" begin
            r = LANDFIRE.regions()
            @test r isa Dict
            @test length(r) == 3

            # Check region structure
            reg = r[:conus]
            @test haskey(reg, :name)
            @test haskey(reg, :code)
            @test reg.code == "US"
        end

        @testset "dir()" begin
            d = LANDFIRE.dir()
            @test d isa String
            @test occursin("LANDFIRE", d)
        end

        @testset "info() output" begin
            result = @test_nowarn LANDFIRE.info()
            @test isnothing(result)
        end

        @testset "wcs_url()" begin
            url = LANDFIRE.wcs_url(:conus, :LF2024)
            @test occursin("usgs.gov", url)
            @test occursin("us_250", url)
            @test occursin("wcs", url)

            url_ak = LANDFIRE.wcs_url(:alaska, :LF2024)
            @test occursin("ak_250", url_ak)

            # Test error for invalid region/version
            @test_throws ErrorException LANDFIRE.wcs_url(:invalid, :LF2024)
            @test_throws ErrorException LANDFIRE.wcs_url(:conus, :invalid)
        end

        @testset "wms_url()" begin
            url = LANDFIRE.wms_url(:conus, :LF2024)
            @test occursin("usgs.gov", url)
            @test occursin("us_250", url)
            @test occursin("ows", url)

            url_hi = LANDFIRE.wms_url(:hawaii, :LF2020)
            @test occursin("hi_220", url_hi)
        end

        @testset "capabilities URLs" begin
            wms_caps = LANDFIRE.wms_capabilities_url(:conus, :LF2024)
            @test occursin("GetCapabilities", wms_caps)
            @test occursin("WMS", wms_caps)

            wcs_caps = LANDFIRE.wcs_capabilities_url(:conus, :LF2024)
            @test occursin("GetCapabilities", wcs_caps)
            @test occursin("WCS", wcs_caps)
        end

        @testset "download_url()" begin
            url = LANDFIRE.download_url(:FBFM40, :conus, :LF2024)
            @test occursin("landfire.gov", url)
            @test occursin("FBFM40", url)
            @test occursin("CONUS", url)
            @test endswith(url, ".zip")

            url_ak = LANDFIRE.download_url(:FBFM40, :alaska, :LF2024)
            @test occursin("AK", url_ak)

            # Test historical disturbance special case
            url_hdist = LANDFIRE.download_url(:HDist, :conus, :LF2024)
            @test occursin("AnnualDist", url_hdist)
            @test occursin("1999_present", url_hdist)

            # Test error for invalid product
            @test_throws ErrorException LANDFIRE.download_url(:invalid, :conus, :LF2024)
        end

        @testset "convenience functions" begin
            @test LANDFIRE.fuel_products() == LANDFIRE.products(category=:fuel)
            @test LANDFIRE.vegetation_products() == LANDFIRE.products(category=:vegetation)
            @test LANDFIRE.topographic_products() == LANDFIRE.products(category=:topographic)
            @test LANDFIRE.fire_regime_products() == LANDFIRE.products(category=:fire_regime)
            @test LANDFIRE.disturbance_products() == LANDFIRE.products(category=:disturbance)
        end

        @testset "list_downloads()" begin
            downloads = LANDFIRE.list_downloads()
            @test downloads isa Vector{String}
        end

    end

    @testset "CWFIS Module" begin

        @testset "collections()" begin
            c = CWFIS.collections()
            @test c isa Dict{Symbol, <:NamedTuple}
            @test length(c) == 8

            # Test that expected collections exist
            @test haskey(c, :active_fires)
            @test haskey(c, :reported_fires)
            @test haskey(c, :hotspots)
            @test haskey(c, :hotspots_24h)
            @test haskey(c, :fire_perimeters)
            @test haskey(c, :fire_points)
            @test haskey(c, :fire_danger)
            @test haskey(c, :weather_stations)

            # Test category filtering
            current = CWFIS.collections(category=:current)
            @test length(current) == 2
            @test all(v.category == :current for v in values(current))

            detection = CWFIS.collections(category=:detection)
            @test length(detection) == 2
            @test all(v.category == :detection for v in values(detection))

            archive = CWFIS.collections(category=:archive)
            @test length(archive) == 2
            @test all(v.category == :archive for v in values(archive))

            weather = CWFIS.collections(category=:weather)
            @test length(weather) == 2
            @test all(v.category == :weather for v in values(weather))
        end

        @testset "Collection struct" begin
            c = CWFIS.collections()
            af = c[:active_fires]

            @test af.id == "public:activefires_current"
            @test af.category == :current
            @test af.geometry == :point
            @test !isempty(af.name)
            @test !isempty(af.description)
        end

        @testset "query_url()" begin
            url = CWFIS.query_url(:active_fires)
            @test occursin("cwfis.cfs.nrcan.gc.ca", url)
            @test occursin("activefires_current", url)
            @test occursin("outputFormat=application/json", url)
            @test occursin("srsName=EPSG:4326", url)

            # Test with count
            url_count = CWFIS.query_url(:active_fires, count=10)
            @test occursin("count=10", url_count)

            # Test with bbox tuple
            url_bbox = CWFIS.query_url(:fire_perimeters, bbox=(-130, 48, -110, 60))
            @test occursin("bbox=-130,48,-110,60", url_bbox)

            # Test with cql_filter
            url_cql = CWFIS.query_url(:fire_points, cql_filter="YEAR=2023")
            @test occursin("CQL_FILTER=", url_cql)

            # Test error for unknown collection
            @test_throws ErrorException CWFIS.query_url(:nonexistent_collection)
        end

        @testset "info() output" begin
            result = @test_nowarn CWFIS.info(:active_fires)
            @test isnothing(result)

            # Test error for unknown collection
            @test_throws ErrorException CWFIS.info(:nonexistent_collection)
        end

        @testset "dir()" begin
            d = CWFIS.dir()
            @test d isa String
            @test occursin("CWFIS", d)
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "download() with count" begin
                data = CWFIS.download(:weather_stations, count=2, verbose=false)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 2

                if length(data) > 0
                    feature = data[1]
                    @test feature isa GeoJSON.Feature
                    @test !isnothing(GeoJSON.geometry(feature))
                end
            end

            @testset "download_file() and load_file()" begin
                filepath = CWFIS.download_file(:weather_stations, count=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                data = CWFIS.load_file(:weather_stations)
                @test data isa GeoJSON.FeatureCollection

                # Clean up
                rm(filepath)
            end

            @testset "Error handling" begin
                @test_throws ErrorException CWFIS.download(:nonexistent_collection)
                @test_throws ErrorException CWFIS.download_file(:nonexistent_collection)
                @test_throws ErrorException CWFIS.load_file(:nonexistent_collection)
            end
        end

    end

    @testset "HMS Module" begin

        @testset "products()" begin
            p = HMS.products()
            @test p isa Dict{Symbol, <:NamedTuple}
            @test length(p) == 2
            @test haskey(p, :fire_points)
            @test haskey(p, :smoke_polygons)

            fp = p[:fire_points]
            @test fp.format == :csv
            @test fp.start_year == 2003
            @test !isempty(fp.name)
            @test !isempty(fp.description)
        end

        @testset "download_url()" begin
            url = HMS.download_url(:fire_points, "2024-08-15")
            @test occursin("satepsanone.nesdis.noaa.gov", url)
            @test occursin("Fire_Points/Text", url)
            @test occursin("2024/08", url)
            @test occursin("hms_fire20240815", url)

            url_smoke = HMS.download_url(:smoke_polygons, Date(2024, 8, 15))
            @test occursin("Smoke_Polygons/Shapefile", url_smoke)
            @test occursin("hms_smoke20240815", url_smoke)

            # Test error for unknown product
            @test_throws ErrorException HMS.download_url(:nonexistent, "2024-08-15")
        end

        @testset "info() output" begin
            result = @test_nowarn HMS.info()
            @test isnothing(result)
        end

        @testset "dir()" begin
            d = HMS.dir()
            @test d isa String
            @test occursin("HMS", d)
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "download() fire points" begin
                df = HMS.download("2024-08-15", verbose=false)
                @test df isa DataFrame
                @test nrow(df) > 0
                @test "Lon" in names(df)
                @test "Lat" in names(df)
                @test "Satellite" in names(df)
                @test "FRP" in names(df)
            end

            @testset "download_file() and load_file()" begin
                filepath = HMS.download_file("2024-08-15", filename="test_hms.csv", verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".csv")

                df = HMS.load_file("test_hms.csv")
                @test df isa DataFrame

                # Clean up
                rm(filepath)
            end
        end

    end

    @testset "GWIS Module" begin

        @testset "layers()" begin
            l = GWIS.layers()
            @test l isa Dict{Symbol, <:NamedTuple}
            @test length(l) >= 18  # 11 base + 7 severity years

            # Test expected layers exist
            @test haskey(l, :modis_hotspots)
            @test haskey(l, :viirs_hotspots)
            @test haskey(l, :modis_burnt_areas)
            @test haskey(l, :viirs_burnt_areas)
            @test haskey(l, :fwi)
            @test haskey(l, :ffmc)
            @test haskey(l, :severity_2024)

            # Test category filtering
            active = GWIS.layers(category=:active_fires)
            @test length(active) == 2
            @test all(v.category == :active_fires for v in values(active))

            burnt = GWIS.layers(category=:burnt_areas)
            @test length(burnt) == 2
            @test all(v.category == :burnt_areas for v in values(burnt))

            danger = GWIS.layers(category=:fire_danger)
            @test length(danger) == 8
            @test all(v.category == :fire_danger for v in values(danger))

            severity = GWIS.layers(category=:severity)
            @test length(severity) == 7  # 2018-2024
            @test all(v.category == :severity for v in values(severity))
        end

        @testset "Layer struct" begin
            l = GWIS.layers()
            vh = l[:viirs_hotspots]

            @test vh.id == "viirs.hs"
            @test vh.category == :active_fires
            @test vh.geometry == :point
            @test !isempty(vh.name)
            @test !isempty(vh.description)
        end

        @testset "wms_url()" begin
            url = GWIS.wms_url(:viirs_hotspots)
            @test occursin("maps.effis.emergency.copernicus.eu", url)
            @test occursin("viirs.hs", url)
            @test occursin("service=WMS", url)
            @test occursin("request=GetMap", url)
            @test occursin("format=image/png", url)

            # Test with bbox
            url_bbox = GWIS.wms_url(:fwi, bbox=(-10, 30, 40, 50))
            @test occursin("bbox=-10,30,40,50", url_bbox)

            # Test with days
            url_days = GWIS.wms_url(:viirs_hotspots, days=7)
            @test occursin("time=7", url_days)

            # Test raster layer doesn't get time param
            url_fwi = GWIS.wms_url(:fwi)
            @test !occursin("time=", url_fwi)

            # Test error for unknown layer
            @test_throws ErrorException GWIS.wms_url(:nonexistent_layer)
        end

        @testset "info() output" begin
            result = @test_nowarn GWIS.info()
            @test isnothing(result)
        end

        @testset "dir()" begin
            d = GWIS.dir()
            @test d isa String
            @test occursin("GWIS", d)
        end

    end

    @testset "EGP Module" begin

        @testset "datasets()" begin
            ds = EGP.datasets()
            @test ds isa Dict{Symbol, WildfireData.ArcGISDataset}
            @test length(ds) == 6

            # Test expected datasets exist
            @test haskey(ds, :gacc_boundaries)
            @test haskey(ds, :dispatch_boundaries)
            @test haskey(ds, :dispatch_locations)
            @test haskey(ds, :psa_boundaries)
            @test haskey(ds, :pods)
            @test haskey(ds, :ia_frequency_zones)

            # Test category filtering
            boundaries = EGP.datasets(category=:boundaries)
            @test all(d.category == :boundaries for d in values(boundaries))
            @test haskey(boundaries, :gacc_boundaries)
            @test !haskey(boundaries, :pods)

            planning = EGP.datasets(category=:planning)
            @test all(d.category == :planning for d in values(planning))
            @test haskey(planning, :pods)
        end

        @testset "Dataset struct" begin
            ds = EGP.datasets()
            d = ds[:gacc_boundaries]

            @test d.service == "DMP_NationalGACCBoundaries_Public"
            @test d.layer == 0
            @test d.category == :boundaries
            @test !isempty(d.name)
            @test !isempty(d.description)
        end

        @testset "query_url()" begin
            url = EGP.query_url(:gacc_boundaries)
            @test occursin("services3.arcgis.com", url)
            @test occursin("DMP_NationalGACCBoundaries_Public", url)
            @test occursin("FeatureServer/0/query", url)
            @test occursin("f=geojson", url)

            # Test with limit
            url_limit = EGP.query_url(:gacc_boundaries, limit=10)
            @test occursin("resultRecordCount=10", url_limit)

            # Test error for unknown dataset
            @test_throws ErrorException EGP.query_url(:nonexistent_dataset)
        end

        @testset "info() output" begin
            result = @test_nowarn EGP.info(:gacc_boundaries)
            @test isnothing(result)

            @test_throws ErrorException EGP.info(:nonexistent_dataset)
        end

        @testset "dir()" begin
            d = EGP.dir()
            @test d isa String
            @test occursin("EGP", d)
        end

        # Network-dependent tests
        @testset "Network API Tests" begin
            @testset "count()" begin
                n = EGP.count(:gacc_boundaries)
                @test n isa Integer
                @test n >= 0
            end

            @testset "fields()" begin
                f = EGP.fields(:gacc_boundaries)
                @test f isa Vector
                @test length(f) > 0

                first_field = f[1]
                @test haskey(first_field, :name)
                @test haskey(first_field, :type)
                @test haskey(first_field, :alias)
            end

            @testset "download() with limit" begin
                data = EGP.download(:gacc_boundaries, limit=2, verbose=false)
                @test data isa GeoJSON.FeatureCollection
                @test length(data) <= 2

                if length(data) > 0
                    feature = data[1]
                    @test feature isa GeoJSON.Feature
                    @test !isnothing(GeoJSON.geometry(feature))
                end
            end

            @testset "download_file() and load_file()" begin
                filepath = EGP.download_file(:gacc_boundaries, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                data = EGP.load_file(:gacc_boundaries)
                @test data isa GeoJSON.FeatureCollection

                # Clean up
                rm(filepath)
            end

            @testset "Error handling" begin
                @test_throws ErrorException EGP.download(:nonexistent_dataset)
                @test_throws ErrorException EGP.count(:nonexistent_dataset)
                @test_throws ErrorException EGP.fields(:nonexistent_dataset)
                @test_throws ErrorException EGP.load_file(:nonexistent_dataset)
            end
        end

    end

end
