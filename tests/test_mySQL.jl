using Pkg

using Test, TestSetExtensions, SafeTestsets
using SearchLight

@testset "Core features PostgreSQL" begin

  @safetestset "PostgresSQL configuration" begin
    using SearchLight
    using SearchLightPostgreSQL

    connection_file = joinpath("tests","postgres_connection.yml")

    conn_info_postgres = SearchLight.Configuration.load(connection_file)

    @test conn_info_postgres["adapter"] == "PostgreSQL"
    @test conn_info_postgres["host"] == "127.0.0.1"
    @test conn_info_postgres["password"] == "postgres"
    @test conn_info_postgres["config"]["log_level"] == ":debug"
    @test conn_info_postgres["config"]["log_queries"] == true
    @test conn_info_postgres["port"] == 5432
    @test conn_info_postgres["username"] == "postgres"
    @test conn_info_postgres["database"] == "searchlight_tests"

  end;

  @safetestset "PostgresSQL connection" begin
    using SearchLight
    using SearchLightPostgreSQL
    using LibPQ

    connection_file = joinpath("tests","postgres_connection.yml")

    conn_info_postgres = SearchLight.Configuration.load(connection_file)

    postgres_Connection = SearchLight.connect(conn_info_postgres)

    infoDB = LibPQ.conninfo(postgres_Connection)

    keysInfo = Dict{String, String}()

    push!(keysInfo, "host"=>"127.0.0.1")
    push!(keysInfo, "port"=>"5432")
    push!(keysInfo, "dbname" => "searchlight_tests")
    push!(keysInfo, "user"=> "postgres")

    for info in keysInfo
      infokey = info[1]
      infoVal = info[2]
      indexInfo = Base.findfirst(x->x.keyword == infokey, infoDB)
      valInfo = infoDB[indexInfo].val
      @test infoVal == valInfo
    end

    ######## teardwon #######
    if postgres_Connection !== nothing
      SearchLight.disconnect(postgres_Connection)
      println("Database connection was disconnected")
    end

  end;

  @safetestset "PostgresSQL query" begin
    using SearchLight
    using SearchLightPostgreSQL
    using SearchLight.Configuration
    using SearchLight.Migrations

    conn_file = joinpath("tests","postgres_connection.yml")

    conn_info = Configuration.load(conn_file)
    conn = SearchLight.connect(conn_info)

    queryString = string("select table_name from information_schema.tables where table_name = '",SearchLight.SEARCHLIGHT_MIGRATIONS_TABLE_NAME,"'")

    @test isempty(SearchLight.query(queryString,conn)) == true
    
    #create migrations_table
    try
      SearchLight.Migration.create_migrations_table()
    catch e
      nothing 
    end

    @test Array(SearchLight.query(queryString,conn))[1] == SearchLight.SEARCHLIGHT_MIGRATIONS_TABLE_NAME

    ############# teardown ###############
    if conn !== nothing
      ############ drop migrations_table ######################
      queryString = string("select table_name from information_schema.tables where table_name = '", SearchLight.SEARCHLIGHT_MIGRATIONS_TABLE_NAME , "'" )
      resQuery = SearchLight.query(queryString)
      if size(resQuery,1) >  0 
        queryString = string("drop table ", SearchLight.SEARCHLIGHT_MIGRATIONS_TABLE_NAME)
        resQuery = SearchLight.query(queryString)
      end
      SearchLight.disconnect(conn)
      println("Database connection was disconnected")
    end

  end;

end