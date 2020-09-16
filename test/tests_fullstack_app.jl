@safetestset "Fullstack app" begin

  testdir = pwd()
  using Pkg

  @safetestset "Create and run a full stack app with resources" begin
    using Genie

    content = "Test OK!"

    workdir = Base.Filesystem.mktempdir()
    cd(workdir)

    Genie.newapp("fullstack_test", fullstack = true, testmode = true)
    Genie.Generator.newcontroller("Foo", pluralize = false)
    @test isfile(joinpath("app", "resources", "foo", "FooController.jl")) == true

    mkpath(joinpath("app", "resources", "foo", "views"))
    @test isdir(joinpath("app", "resources", "foo", "views")) == true

    open(joinpath("app", "resources", "foo", "views", "foo.jl.html"), "w") do io
      write(io, content)
    end
    @test isfile(joinpath("app", "resources", "foo", "views", "foo.jl.html")) == true

    Genie.Router.route("/test") do
      Genie.Renderer.Html.html(:foo, :foo)
    end

    r = Genie.Requests.HTTP.request("GET", "http://localhost:8000/test")

    @test occursin(content, String(r.body)) == true
  end;

  cd(testdir)
  Pkg.activate(".")

end;