module FPA_FOD

using ..WildfireData
using SQLite
using DBInterface
using Downloads
using ZipFile


#-----------------------------------------------------------------------------# Data Directory
dir() = WildfireData.dir("FPA_FOD")

#-----------------------------------------------------------------------------# Constants

const ARCHIVE_URL = "https://www.fs.usda.gov/rds/archive/products/RDS-2013-0009.6"
const SQLITE_URL = "$ARCHIVE_URL/RDS-2013-0009.6_Data_Format4_SQLITE.zip"
const GPKG_URL = "$ARCHIVE_URL/RDS-2013-0009.6_Data_Format3_GPKG.zip"
const DATABASE_FILENAME = "FPA_FOD_20221014.sqlite"

# Time coverage
const YEAR_START = 1992
const YEAR_END = 2020

# Fire size classes (acres)
const SIZE_CLASSES = Dict(
    'A' => (0.0, 0.25),      # 0 to 0.25 acres
    'B' => (0.26, 9.9),      # 0.26 to 9.9 acres
    'C' => (10.0, 99.9),     # 10 to 99.9 acres
    'D' => (100.0, 299.9),   # 100 to 299.9 acres
    'E' => (300.0, 999.9),   # 300 to 999.9 acres
    'F' => (1000.0, 4999.9), # 1000 to 4999.9 acres
    'G' => (5000.0, Inf),    # 5000+ acres
)

# NWCG cause classifications
const CAUSE_CLASSIFICATIONS = ["Human", "Natural", "Missing/Undefined"]

const GENERAL_CAUSES = [
    "Arson/Incendiarism",
    "Debris and Open Burning",
    "Equipment and Vehicle Use",
    "Firearms and Explosives Use",
    "Fireworks",
    "Misuse of Fire by a Minor",
    "Natural",
    "Power Generation/Transmission/Distribution",
    "Railroad Operations and Maintenance",
    "Recreation and Ceremony",
    "Smoking",
    "Other Causes",
    "Missing data/Not specified/Undetermined",
]

#-----------------------------------------------------------------------------# Database Path

"""
    db_path()

Return the path to the FPA-FOD SQLite database file.
Returns `nothing` if the database hasn't been downloaded yet.
"""
function db_path()
    path = joinpath(dir(), DATABASE_FILENAME)
    return isfile(path) ? path : nothing
end

#-----------------------------------------------------------------------------# Download Functions

"""
    download_database(; force=false, verbose=true)

Download the FPA-FOD SQLite database (~214 MB compressed, ~214 MB uncompressed).

The database contains 2.3 million wildfire records from 1992-2020.

# Arguments
- `force::Bool`: Re-download even if the file already exists
- `verbose::Bool`: Print progress information

# Returns
The path to the downloaded SQLite database file.

# Example
```julia
FPA_FOD.download_database()
```
"""
function download_database(; force::Bool=false, verbose::Bool=true)
    mkpath(dir())
    dbpath = joinpath(dir(), DATABASE_FILENAME)

    if isfile(dbpath) && !force
        verbose && println("Database already exists: $dbpath")
        verbose && println("Use `force=true` to re-download.")
        return dbpath
    end

    zippath = joinpath(dir(), "FPA_FOD_SQLITE.zip")

    verbose && println("Downloading FPA-FOD database (~214 MB)...")
    verbose && println("URL: $SQLITE_URL")

    Downloads.download(SQLITE_URL, zippath)

    verbose && println("Extracting...")

    # Extract the sqlite file from the zip archive
    reader = ZipFile.Reader(zippath)
    try
        for f in reader.files
            if endswith(f.name, ".sqlite")
                open(dbpath, "w") do io
                    write(io, read(f))
                end
                break
            end
        end
    finally
        close(reader)
    end

    # Clean up
    rm(zippath; force=true)

    verbose && println("Database saved to: $dbpath")
    return dbpath
end

#-----------------------------------------------------------------------------# Database Connection

"""
    with_db(f::Function)

Execute a function with a database connection, ensuring the connection is closed afterward.
"""
function with_db(f::Function)
    path = db_path()
    if isnothing(path)
        error("Database not found. Run `FPA_FOD.download_database()` first.")
    end
    db = SQLite.DB(path)
    try
        return f(db)
    finally
        DBInterface.close!(db)
    end
end

#-----------------------------------------------------------------------------# Info Functions

"""
    info()

Print information about the FPA-FOD database.

# Example
```julia
FPA_FOD.info()
```
"""
function info()
    println("FPA-FOD: Fire Program Analysis Fire-Occurrence Database")
    println("=========================================================")
    println("Coverage: $(YEAR_START)-$(YEAR_END) ($(YEAR_END - YEAR_START + 1) years)")
    println("Source: USDA Forest Service Research Data Archive")
    println("DOI: https://doi.org/10.2737/RDS-2013-0009.6")
    println()

    path = db_path()
    if isnothing(path)
        println("Status: Not downloaded")
        println("Run `FPA_FOD.download_database()` to download (~214 MB)")
    else
        println("Status: Downloaded")
        println("Path: $path")
        println("Size: $(round(filesize(path) / 1024^2, digits=1)) MB")

        n = count()
        println("Records: $(format_number(n))")
    end
    return nothing
end

"""
    tables()

List all tables in the database.
"""
function tables()
    with_db() do db
        result = DBInterface.execute(db, "SELECT name FROM sqlite_master WHERE type='table'")
        return [row.name for row in result]
    end
end

"""
    schema(table::String="Fires")

Get the schema (column names and types) for a table.
"""
function schema(table::String="Fires")
    if !all(c -> isletter(c) || c == '_', table)
        error("Invalid table name: $table")
    end
    with_db() do db
        result = DBInterface.execute(db, "PRAGMA table_info(\"$table\")")
        return [(name=row.name, type=row.type, notnull=row.notnull == 1) for row in result]
    end
end

#-----------------------------------------------------------------------------# Query Functions

"""
    query(sql::String; limit=nothing)

Execute a SQL query against the FPA-FOD database.

# Arguments
- `sql::String`: SQL query string
- `limit::Int`: Optional limit on number of rows returned

# Returns
A vector of NamedTuples representing the query results.

# Examples
```julia
# Get 10 largest fires
FPA_FOD.query("SELECT FIRE_NAME, FIRE_SIZE, FIRE_YEAR, STATE FROM Fires ORDER BY FIRE_SIZE DESC LIMIT 10")

# Get fires in California in 2020
FPA_FOD.query("SELECT * FROM Fires WHERE STATE = 'CA' AND FIRE_YEAR = 2020", limit=100)
```
"""
function query(sql::String; limit::Union{Int,Nothing}=nothing)
    with_db() do db
        if !isnothing(limit) && !occursin(r"LIMIT\s+\d+"i, sql)
            sql = "$sql LIMIT $limit"
        end
        result = DBInterface.execute(db, sql)
        return [NamedTuple(row) for row in result]
    end
end

"""
    count(; where::String="1=1")

Get the count of fire records matching the where clause.

# Examples
```julia
FPA_FOD.count()  # total records
FPA_FOD.count(where="STATE = 'CA'")  # California fires
FPA_FOD.count(where="FIRE_YEAR = 2020")  # 2020 fires
FPA_FOD.count(where="FIRE_SIZE > 1000")  # fires over 1000 acres
```
"""
function count(; where::String="1=1")
    with_db() do db
        result = DBInterface.execute(db, "SELECT COUNT(*) as n FROM Fires WHERE $where")
        return first(result).n
    end
end

#-----------------------------------------------------------------------------# Convenience Functions

"""
    states()

Get a list of all states in the database with fire counts.

# Example
```julia
FPA_FOD.states()
```
"""
function states()
    query("SELECT STATE, COUNT(*) as count FROM Fires GROUP BY STATE ORDER BY count DESC")
end

"""
    causes()

Get a summary of fire causes.

# Example
```julia
FPA_FOD.causes()
```
"""
function causes()
    query("""
        SELECT NWCG_GENERAL_CAUSE as cause, COUNT(*) as count
        FROM Fires
        GROUP BY NWCG_GENERAL_CAUSE
        ORDER BY count DESC
    """)
end

"""
    years()

Get fire counts by year.

# Example
```julia
FPA_FOD.years()
```
"""
function years()
    query("SELECT FIRE_YEAR as year, COUNT(*) as count FROM Fires GROUP BY FIRE_YEAR ORDER BY year")
end

"""
    fires(; state=nothing, year=nothing, cause=nothing, min_size=nothing, max_size=nothing, limit=1000)

Query fires with optional filters.

# Arguments
- `state::String`: Two-letter state code (e.g., "CA")
- `year::Int`: Fire year (1992-2020)
- `cause::String`: NWCG general cause category
- `min_size::Real`: Minimum fire size in acres
- `max_size::Real`: Maximum fire size in acres
- `limit::Int`: Maximum number of records to return (default: 1000)

# Returns
A vector of NamedTuples with fire records.

# Examples
```julia
# Get California fires from 2020
FPA_FOD.fires(state="CA", year=2020)

# Get large fires (over 10,000 acres)
FPA_FOD.fires(min_size=10000, limit=100)

# Get fires caused by lightning in 2019
FPA_FOD.fires(year=2019, cause="Natural")
```
"""
function fires(; state::Union{String,Nothing}=nothing,
               year::Union{Int,Nothing}=nothing,
               cause::Union{String,Nothing}=nothing,
               min_size::Union{Real,Nothing}=nothing,
               max_size::Union{Real,Nothing}=nothing,
               limit::Int=1000)
    conditions = String[]
    params = Any[]

    if !isnothing(state)
        push!(conditions, "STATE = ?")
        push!(params, state)
    end
    if !isnothing(year)
        push!(conditions, "FIRE_YEAR = ?")
        push!(params, year)
    end
    if !isnothing(cause)
        push!(conditions, "NWCG_GENERAL_CAUSE = ?")
        push!(params, cause)
    end
    if !isnothing(min_size)
        push!(conditions, "FIRE_SIZE >= ?")
        push!(params, min_size)
    end
    if !isnothing(max_size)
        push!(conditions, "FIRE_SIZE <= ?")
        push!(params, max_size)
    end

    where_clause = isempty(conditions) ? "1=1" : join(conditions, " AND ")

    with_db() do db
        sql = """
            SELECT FOD_ID, FIRE_NAME, FIRE_YEAR, DISCOVERY_DATE, CONT_DATE,
                   FIRE_SIZE, FIRE_SIZE_CLASS, NWCG_CAUSE_CLASSIFICATION, NWCG_GENERAL_CAUSE,
                   STATE, COUNTY, LATITUDE, LONGITUDE
            FROM Fires
            WHERE $where_clause
            ORDER BY FIRE_SIZE DESC
            LIMIT ?
        """
        push!(params, limit)
        result = DBInterface.execute(db, sql, params)
        return [NamedTuple(row) for row in result]
    end
end

"""
    largest_fires(n::Int=100; year=nothing, state=nothing)

Get the n largest fires, optionally filtered by year or state.

# Examples
```julia
FPA_FOD.largest_fires(10)  # top 10 largest fires ever
FPA_FOD.largest_fires(10, year=2020)  # top 10 in 2020
FPA_FOD.largest_fires(10, state="CA")  # top 10 in California
```
"""
function largest_fires(n::Int=100; year::Union{Int,Nothing}=nothing, state::Union{String,Nothing}=nothing)
    conditions = String[]
    params = Any[]

    if !isnothing(year)
        push!(conditions, "FIRE_YEAR = ?")
        push!(params, year)
    end
    if !isnothing(state)
        push!(conditions, "STATE = ?")
        push!(params, state)
    end

    where_clause = isempty(conditions) ? "1=1" : join(conditions, " AND ")
    push!(params, n)

    with_db() do db
        sql = """
            SELECT FOD_ID, FIRE_NAME, FIRE_YEAR, FIRE_SIZE, STATE, COUNTY,
                   NWCG_GENERAL_CAUSE, LATITUDE, LONGITUDE
            FROM Fires
            WHERE $where_clause
            ORDER BY FIRE_SIZE DESC
            LIMIT ?
        """
        result = DBInterface.execute(db, sql, params)
        return [NamedTuple(row) for row in result]
    end
end

#-----------------------------------------------------------------------------# Utility Functions

function format_number(n::Integer)
    s = string(n)
    parts = String[]
    while length(s) > 3
        push!(parts, s[end-2:end])
        s = s[1:end-3]
    end
    push!(parts, s)
    return join(reverse(parts), ",")
end

end # module
