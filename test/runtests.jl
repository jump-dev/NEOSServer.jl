# Copyright (c) 2015: Oscar Dowson and NEOS.jl contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestNEOSServer

using NEOSServer
using Test

const MOI = NEOSServer.AmplNLWriter.MOI

const EMAIL = "odow@users.noreply.github.com"
const SERVER = NEOSServer.Server(EMAIL)

function runtests()
    for name in names(@__MODULE__, all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_help()
    @test occursin("class NeosServer", neos_help(SERVER))
    return
end

function test_welcome()
    @test occursin("WELCOME TO NEOS!", neos_welcome(SERVER))
    return
end

function test_version()
    @test occursin("neos version", neos_version(SERVER))
    return
end

function test_ping()
    @test "NeosServer is alive\n" == neos_ping(SERVER)
    return
end

function test_printQueue()
    @test occursin("Running:\n", neos_printQueue(SERVER))
    return
end

function test_listAllSolvers()
    @test length(neos_listAllSolvers(SERVER)) > 200
    return
end

function test_listCategories()
    categories = neos_listCategories(SERVER)
    @test length(categories) > 20
    @test length(neos_listSolversInCategory(SERVER, categories[1])) > 0
    return
end

function test_getSolverTemplate()
    template = neos_getSolverTemplate(SERVER, "NCO", "Ipopt", "AMPL")
    @test occursin("CDATA", template)
    return
end

function test_Optimizer_no_email()
    @test_throws UndefVarError Optimizer(solver = "Ipopt")
    return
end

function test_Optimizer()
    io = IOBuffer()
    model = NEOSServer.Optimizer(email = EMAIL, solver = "Ipopt", stdout = io)
    MOI.set(model, MOI.RawOptimizerAttribute("print_level"), 0)
    MOI.optimize!(model)
    seekstart(io)
    ret = String(take!(io))
    m = match(r"Job ([0-9]+) dispatched\npassword: ([a-zA-Z]+)\n"i, ret)
    job = NEOSServer.Job(parse(Int, m[1]), m[2])
    server = model.solver_command.server
    @test neos_getCompletionCode(server, job) == "Normal"
    @test neos_getJobInfo(server, job) == Any["nco", "Ipopt", "NL", "Done"]
    @test neos_killJob(server, job) == Any["Job #$(job.number) is finished"]
    ret, offset = neos_getIntermediateResults(server, job, 0)
    @test occursin("dispatched", ret)
    @test offset > 0
    @test occursin("ipopt", neos_getFinalResults(server, job))
    @test occursin("ipopt", neos_getFinalResultsNonBlocking(server, job))
    return
end

function test_Optimizer_unsupported_solver()
    @test_throws(
        ErrorException(
            "NEOS.Optimizer only supports the following solvers: " *
            join(collect(keys(NEOS._SUPPORTED_SOLVERS)), ", "),
        ),
        NEOSServer.Optimizer(email = EMAIL, solver = "foobar"),
    )
    return
end

function test_Optimizer_options()
    model = MOI.Utilities.Model{Float64}()
    x = MOI.add_variable(model)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    f = (x - 1.0)^2
    MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
    io = IOBuffer()
    neos = NEOSServer.Optimizer(email = EMAIL, solver = "Ipopt", stdout = io)
    MOI.set(neos, MOI.RawOptimizerAttribute("max_iter"), 0)
    MOI.optimize!(neos, model)
    seekstart(io)
    ret = String(take!(io))
    m = match(r"Job ([0-9]+) dispatched\npassword: ([a-zA-Z]+)\n"i, ret)
    job = NEOSServer.Job(parse(Int, m[1]), m[2])
    server = neos.solver_command.server
    @test occursin(
        "Maximum Number of Iterations Exceeded.",
        neos_getFinalResults(server, job),
    )
    return
end

end  # module

TestNEOSServer.runtests()
