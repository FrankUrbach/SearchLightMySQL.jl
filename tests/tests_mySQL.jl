using Test, TestSetExtensions, SafeTestsets

include(joinpath(@__DIR__,"test_models.jl"))

module TestSetupTeardown

  using SearchLight
  using SearchLightMySQL

  export prepareDbConnection, tearDown

  connection_file = "mysql_connection.yml"

  function prepareDbConnection()
      
    conn_info_mysql = SearchLight.Configuration.load(connection_file)
    conn = SearchLight.connect(conn_info_mysql)
    return conn
  end

  function tearDown(conn)
    if conn !== nothing
        ######## Dropping used tables
        SearchLight.Migration.drop_migrations_table()

        # insert tables you use in tests here
        tables = ["Book","BookWithIntern","Callback","Author","BookWithAuthor"]

        # obtain tables exists or not, if they does drop it
        wheres = join(map(x -> string("'", lowercase(SearchLight.Inflector.to_plural(x)), "'"), tables), " , ", " , ")
        queryString = string("show tables where tables_in_searchlight_tests in ($wheres)")
        result = SearchLight.query(queryString)
        for item in eachrow(result)
            try
                SearchLight.Migration.drop_table(lowercase(item[1]))
            catch ex
                @show "Table $item doesn't exist"
            end 
        end 
  
        SearchLight.disconnect(conn)
        rm(SearchLight.config.db_migrations_folder, force=true, recursive=true)
    end
  end
end

@safetestset "Core features MySQL" begin
    using SearchLight
    using SearchLightMySQL
    using Test, TestSetExtensions
    using Main.TestSetupTeardown


    @testset "PostgresSQL configuration" begin

        conn_info_postgres = SearchLight.Configuration.load(TestSetupTeardown.connection_file)

        @test conn_info_postgres["adapter"] == "MySQL"
        @test conn_info_postgres["host"] == "127.0.0.1"
        @test conn_info_postgres["password"] == "root1234"
        @test conn_info_postgres["config"]["log_level"] == ":debug"
        @test conn_info_postgres["port"] == 3306
        @test conn_info_postgres["username"] == "root"
        @test conn_info_postgres["config"]["log_queries"] == true
        @test conn_info_postgres["database"] == "searchlight_tests"

    end
end;

@safetestset "MySQL connection" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown

  
    conn = prepareDbConnection()

    keysInfo = Dict{String,String}()

    @test conn.host == "127.0.0.1"
    @test conn.port == "3306"
    @test conn.db   == "searchlight_tests"
    @test conn.user == "root"

    tearDown(conn)

end

@safetestset "MySQL query" begin
    using SearchLight
    using SearchLightMySQL
    using SearchLight.Configuration
    using SearchLight.Migrations
    using Main.TestSetupTeardown

    conn = prepareDbConnection()

    queryString = string("show tables where tables_in_searchlight_tests = '$(SearchLight.SEARCHLIGHT_MIGRATIONS_TABLE_NAME)'")

    @test isempty(SearchLight.query(queryString, conn)) === true
  
  # create migrations_table
    SearchLight.Migration.create_migrations_table()

    @test Array(SearchLight.query(queryString, conn))[1] == SearchLight.SEARCHLIGHT_MIGRATIONS_TABLE_NAME

    tearDown(conn)

end;

@safetestset "Utility functions PostgreSQL-Adapter" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown

    conn = prepareDbConnection()

    @test SearchLight.Migration.create_migrations_table() === nothing
    @test SearchLight.Migration.drop_migrations_table() === nothing


    tearDown(conn)

end

@safetestset "Models and tableMigration" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown
    using Main.TestModels

  ## establish the database-connection
    conn = prepareDbConnection()

  ## create migrations_table
    SearchLight.Migration.create_migrations_table()
  
  ## make Table "Book" 
    SearchLight.Generator.new_table_migration(Book)
    SearchLight.Migration.up()

    testBook = Book(title="Faust", author="Goethe")

    @test testBook.author == "Goethe"
    @test testBook.title == "Faust"
    @test typeof(testBook) == Book
    @test isa(testBook, AbstractModel)

    testBook |> SearchLight.save

    @test testBook |> SearchLight.save == true

  ############ tearDown ##################

    tearDown(conn)

end

@safetestset "Model Store and Query models without inern variables" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestModels

    using Main.TestSetupTeardown

  ## establish the database-connection
    conn = prepareDbConnection()

  ## create migrations_table
    SearchLight.Migration.create_migrations_table()
  
  ## make Table "Book" 
    SearchLight.Generator.new_table_migration(Book)
    SearchLight.Migration.up()

    testBooks = Book[]
  
  ## prepare the TestBooks
    for book in TestModels.seed() 
        push!(testBooks, Book(title=book[1], author=book[2]))
    end

    @test testBooks |> SearchLight.save == true

    booksReturn = SearchLight.find(Book)

    @test size(booksReturn) == (5,)

 
  ############ tearDown ##################

    tearDown(conn)

end

@safetestset "Query and Models with intern variables" begin
    using Test
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown
    using Main.TestModels

    ## establish the database-connection
    conn = prepareDbConnection()

    ## make Table "BooksWithInterns" 
    SearchLight.Migration.create_migrations_table()
    SearchLight.Generator.new_table_migration(BookWithInterns)
    SearchLight.Migration.up()

    booksWithInterns = BookWithInterns[]

    ## prepare the TestBooks
    for book in TestModels.seed() 
        push!(booksWithInterns, BookWithInterns(title=book[1], author=book[2]))
    end

    testItem = BookWithInterns(author="Alexej Tolstoi", title="Krieg oder Frieden")

    savedTestItem = SearchLight.save(testItem)
    @test savedTestItem === true

    savedTestItems = booksWithInterns |> save
    @test savedTestItems === true

    idTestItem = SearchLight.save!(testItem)
    @test idTestItem.id !== nothing
    @test idTestItem.id.value  > 0

    resultBooksWithInterns = booksWithInterns |> save!

    fullTestBooks = find(BookWithInterns)
    @test isa(fullTestBooks, Array{BookWithInterns,1})
    @test length(fullTestBooks) > 0
 
    ############ tearDown ##################
    tearDown(conn)

end## end of testset

@safetestset "Saving and Reading with callbacks" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown
    using Test
    using Dates
    using Main.TestModels

    conn = prepareDbConnection()

    SearchLight.Migration.create_migrations_table()
    SearchLight.Generator.new_table_migration(Callback)
    SearchLight.Migration.up()

    testItem = Callback(title="testing")

    @test testItem |> save! !== nothing

    tearDown(conn)
end;

@safetestset "Saving and Reading fields and datatbase columns are different" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown
    using Main.TestModels

    conn = prepareDbConnection()


    SearchLight.Migration.create_migrations_table()
    SearchLight.Generator.new_table_migration(BookWithAuthor)
    SearchLight.Migration.up()
    SearchLight.Generator.new_table_migration(Author)
    SearchLight.Migration.up()


    testAuthor = Author(firstname="Johann Wolfgang", lastname="Goethe")
    testId = testAuthor |> save! 

    @test length(find(Author)) > 0 

    ####### tearDown #########
    tearDown(conn)
end;

@safetestset "Saving and Reading fields and datatbase columns are different" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown
    using Main.TestModels

    conn = prepareDbConnection()
    SearchLight.Migration.create_migrations_table()
    SearchLight.Generator.new_table_migration(BookWithAuthor)
    SearchLight.Migration.up()
    SearchLight.Generator.new_table_migration(Author)
    SearchLight.Migration.up()

    testAuthor = Author(firstname="Johann Wolfgang", lastname="Goethe")
    testId = testAuthor |> save! 

    @test length(find(Author)) > 0 

    ####### tearDown #########
    tearDown(conn)
end;

@safetestset "Saving and Reading Models with fields containing submodels" begin
    using SearchLight
    using SearchLightMySQL
    using Main.TestSetupTeardown
    using Main.TestModels

    conn = prepareDbConnection()
    SearchLight.Migration.create_migrations_table()
    SearchLight.Generator.new_table_migration(BookWithAuthor)
    SearchLight.Migration.up()
    SearchLight.Generator.new_table_migration(Author)
    SearchLight.Migration.up()

    #create an author
    testAuthor = Author(firstname="John", lastname="Grisham")
    #create books from the author above and bring it to them 
    testAuthor.books = map(book -> BookWithAuthor(title=book), seedBook())
   
    testId = testAuthor |> save! 

    idAuthor = testAuthor.id.value
    for book in testId.books
      @test book.id_author.value == idAuthor
    end

    result = find(Author)
    @test length(result) > 0 

    @test !isempty(result[1].books)
    @test length(result[1].books) == length(seedBook())

    ####### tearDown #########
    tearDown(conn)
end;

@safetestset "functions findone_or_create, updateby_or_create etc" begin
  using SearchLight
  using SearchLightMySQL
  using Main.TestSetupTeardown
  using Main.TestModels

  conn = prepareDbConnection()
  SearchLight.Migration.create_migrations_table()
  SearchLight.Generator.new_table_migration(BookWithAuthor)
  SearchLight.Migration.up()
  SearchLight.Generator.new_table_migration(Author)
  SearchLight.Migration.up()

  #create an author
  testAuthor = Author(firstname="John", lastname="Grisham")
  #create books from the author above and bring it to them 
  testAuthor.books = map(book -> BookWithAuthor(title=book), seedBook())

  result = findone_or_create(typeof(testAuthor))

  @test result !== nothing
  @test result.first_name == ""
  @test result.last_name == ""
  @test isempty(result.books)

  ####### tearDown #########
  tearDown(conn)
end;
