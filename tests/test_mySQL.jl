using Pkg

using Test, TestSetExtensions, SafeTestsets
using SearchLight

@testset "Core features MySQL" begin

  @safetestset "MySQL configuration" begin
    using SearchLight
    using SearchLightMySQL

    connection_file = "mysql_connection.yml"

    conn_info_mysql = SearchLight.Configuration.load(connection_file)

    @test conn_info_mysql["adapter"] == "MySQL"
    @test conn_info_mysql["host"] == "127.0.0.1"
    @test conn_info_mysql["config"]["log_level"] == ":debug"
    @test conn_info_mysql["config"]["log_queries"] == true
    @test conn_info_mysql["port"] == 3306
    @test conn_info_mysql["username"] == "root"
    @test conn_info_mysql["database"] == "searchlight_tests"

  end;

  @safetestset "MySQL connection" begin
    using SearchLight
    using SearchLightMySQL

    connection_file = "mysql_connection.yml"

    conn_info_mysql = SearchLight.Configuration.load(connection_file)

    mySQL_Connection = SearchLight.connect(conn_info_mysql)

    @test mySQL_Connection.host == "127.0.0.1"
    @test mySQL_Connection.port == "3306"
    @test mySQL_Connection.db == "searchlight_tests"
    @test mySQL_Connection.user == "root"

    ######## teardwon #######
    if mySQL_Connection !== nothing
      SearchLight.disconnect(mySQL_Connection)
      println("Database connection was disconnected")
    end

  end;

  @safetestset "MySQL query" begin
    using SearchLight
    using SearchLightMySQL
    using SearchLight.Configuration
    using SearchLight.Migrations

    conn_file = "mysql_connection.yml"

    conn_info = SearchLight.Configuration.load(conn_file)
    conn = SearchLight.connect(conn_info)

    queryString = "SHOW TABLES"

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
      queryString = "SHOW TABLES"
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