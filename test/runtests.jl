module TestNEOS

using NEOS
using Test

const EMAIL = "odow@users.noreply.github.com"
const SERVER = NEOS.Server(EMAIL)

function test_help()
    @test occursin("class NeosServer", neos_help(SERVER))
end

function test_welcome()
    @test occursin("WELCOME TO NEOS!", neos_welcome(SERVER))
end

function test_version()
    @test occursin("neos version", neos_version(SERVER))
end

function test_ping()
    @test "NeosServer is alive\n" == neos_ping(SERVER)
end

function test_printQueue()
    @test occursin("Running:\n", neos_printQueue(SERVER))
end

function test_listAllSolvers()
    @test length(neos_listAllSolvers(SERVER)) > 200
end

function test_listCategories()
    categories = neos_listCategories(SERVER)
    @test length(categories) > 20
    @test length(neos_listSolversInCategory(SERVER, categories[1])) > 0
end

function test_Optimizer_no_email()
    @test_throws UndefVarError Optimizer(solver = "Ipopt")
end

function test_Optimizer()
    io = IOBuffer()
    model = NEOS.Optimizer(email = EMAIL, solver = "Ipopt", stdout = io)
    NEOS.AmplNLWriter.MOI.optimize!(model)
    seekstart(io)
    ret = String(take!(io))
    m = match(r"Job ([0-9]+) dispatched\npassword: ([a-zA-Z]+)\n"i, ret)
    job = NEOS.Job(parse(Int, m[1]), m[2])
    server = model.solver_command.server
    @test neos_getCompletionCode(server, job) == "Normal"
    @test neos_getJobInfo(server, job) == Any["nco", "Ipopt", "NL", "Done"]
    @test neos_killJob(server, job) == Any["Job #$(job.number) is finished"]
    ret, offset = neos_getIntermediateResults(server, job, 0)
    @test occursin("dispatched", ret)
    @test offset > 0
    @test occursin("ipopt", neos_getFinalResults(server, job))
    @test occursin("ipopt", neos_getFinalResultsNonBlocking(server, job))
end

function runtests()
    for name in names(@__MODULE__, all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

end

TestNEOS.runtests()
