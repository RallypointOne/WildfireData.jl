using WildfireData
using WildfireData.WFIGS
using WildfireData.IRWIN
using WildfireData.FPA_FOD
using WildfireData.MTBS
using WildfireData.FIRMS
using WildfireData.LANDFIRE
using Test
using DataFrames

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
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"
                @test haskey(data, :features)
                @test length(data.features) <= 2

                # Check feature structure
                if length(data.features) > 0
                    feature = data.features[1]
                    @test haskey(feature, :type)
                    @test feature.type == "Feature"
                    @test haskey(feature, :geometry)
                    @test haskey(feature, :properties)
                end
            end

            @testset "download() with where clause" begin
                # Download with a filter
                data = WFIGS.download(:current_perimeters, where="1=1", limit=1, verbose=false)
                @test haskey(data, :features)
            end

            @testset "download_file() and load_file()" begin
                # Download to file
                filepath = WFIGS.download_file(:current_locations, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                # Load from file
                data = WFIGS.load_file(:current_locations)
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"

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
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"
                @test haskey(data, :features)
                @test length(data.features) <= 2

                # Check feature structure
                if length(data.features) > 0
                    feature = data.features[1]
                    @test haskey(feature, :type)
                    @test feature.type == "Feature"
                    @test haskey(feature, :geometry)
                    @test haskey(feature, :properties)
                end
            end

            @testset "download() perimeters" begin
                data = IRWIN.download(:usa_current_perimeters, limit=1, verbose=false)
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"
            end

            @testset "download_file() and load_file()" begin
                # Download to file
                filepath = IRWIN.download_file(:usa_current_incidents, limit=2, verbose=false, force=true)
                @test isfile(filepath)
                @test endswith(filepath, ".geojson")

                # Load from file
                data = IRWIN.load_file(:usa_current_incidents)
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"

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
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"
                @test haskey(data, :features)
                @test length(data.features) <= 2

                # Check feature structure
                if length(data.features) > 0
                    feature = data.features[1]
                    @test haskey(feature, :type)
                    @test feature.type == "Feature"
                    @test haskey(feature, :geometry)
                    @test haskey(feature, :properties)
                end
            end

            @testset "download() burn boundaries" begin
                data = MTBS.download(:burn_boundaries, limit=1, verbose=false)
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"
                @test haskey(data, :features)
            end

            @testset "download() with where clause" begin
                data = MTBS.download(:fire_occurrence, where="ACRES > 50000", limit=5, verbose=false)
                @test haskey(data, :features)

                # Check that returned fires are actually large
                if length(data.features) > 0
                    for feature in data.features
                        @test feature.properties.ACRES > 50000
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
                @test haskey(data, :type)
                @test data.type == "FeatureCollection"

                # Clean up
                rm(filepath)
            end

            @testset "fires() convenience function" begin
                data = MTBS.fires(limit=5)
                @test haskey(data, :features)
                @test length(data.features) <= 5

                # Test with min_acres filter (more reliable than year filter)
                data_large = MTBS.fires(min_acres=100000, limit=5)
                @test haskey(data_large, :features)
            end

            @testset "boundaries() convenience function" begin
                data = MTBS.boundaries(limit=3)
                @test haskey(data, :features)
                @test length(data.features) <= 3
            end

            @testset "largest_fires()" begin
                lf = MTBS.largest_fires(5)
                @test lf isa AbstractVector
                @test length(lf) <= 5

                if length(lf) > 1
                    # Check sorted by size descending
                    sizes = [f.properties.ACRES for f in lf]
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

end
