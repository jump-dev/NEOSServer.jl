using ZipFile

type NEOSNonlinearModel <: AbstractMathProgModel
    solver::NEOSSolver
	xmlmodel::String
	last_results::String
    inner::AmplNLWriter.AmplNLMathProgModel
end
LinearQuadraticModel{T<:AbstractNEOSNLSolver}(s::NEOSSolver{T}) = NEOSNonlinearModel(
    s,
    "",
    "",
    AmplNLWriter.AmplNLMathProgModel("", String[], "")
)
# NonlinearModel{T<:AbstractNEOSNLSolver}(s::NEOSSolver{T}) = NEOSNonlinearModel(
#     s,
#     "",
#     "",
#     AmplNLWriter.AmplNLMathProgModel("", String[], "")
# )
addemail!(m::NEOSNonlinearModel, email::String) = addemail!(m.solver, email)

# function loadproblem!(m::NEOSNonlinearModel, nvar::Integer, ncon::Integer,
#   x_l, x_u, g_l, g_u, sense::Symbol, d::AbstractNLPEvaluator)
#   loadproblem!(AmplNLWriter.AmplNLNonlinearModel(m.inner), nvar, ncon, x_l, x_u, g_l, g_u, sense, d)
# end

function loadproblem!(m::NEOSNonlinearModel, A::AbstractMatrix, x_l, x_u, c, g_l, g_u, sense)
    loadproblem!(AmplNLWriter.AmplNLLinearQuadraticModel(m.inner), A, x_l, x_u, c, g_l, g_u, sense)
end

# Wrapper functions
for f in [:getvartype,:getsense,:status,:getsolution,:getobjval,:numvar,:numconstr,:get_solve_result,:get_solve_result_num,:get_solve_message,:get_solve_exitcode,:getsolvetime]
  @eval $f(m::NEOSNonlinearModel) = $f(m.inner)
end
for f in [:setvartype!,:setsense!,:setwarmstart!]
  @eval $f(m::NEOSNonlinearModel, x) = $f(m.inner, x)
end

function optimize!(m::NEOSNonlinearModel)
    # There is no non-linear binary type, only non-linear discrete, so make
    # sure binary vars have bounds in [0, 1]
    for i in 1:m.inner.nvar
        if m.inner.vartypes[i] == :Bin
            if m.inner.x_l[i] < 0
                m.inner.x_l[i] = 0
            end
            if m.inner.x_u[i] > 1
                m.inner.x_u[i] = 1
            end
        end
    end

    io = IOBuffer()
    print(io, "<model>")
    AmplNLWriter.make_var_index!(m.inner)
    AmplNLWriter.make_con_index!(m.inner)
    AmplNLWriter.write_nl_file(io, m.inner)
    print(io, "</model>")
    # Convert the model to MPS and add
    m.xmlmodel = replace(m.solver.template, r"<model>.*</model>"is, String(take!(io)))

	add_solver_xml!(m.solver, m)

	if m.solver.requires_email && m.solver.server.email==""
		throw(NEOSSolverError("$(typeof(m.solver)) requires that NEOS users supply a valid email"))
	end

	if m.solver.server.email != ""
		if match(r"<email>.*</email>", m.xmlmodel) == nothing
			m.xmlmodel = replace(m.xmlmodel, r"<document>", "<document>\n<email>$(m.solver.server.email)</email>")
		else
			m.xmlmodel = replace(m.xmlmodel, r"<email>.*</email>", "<email>$(m.solver.server.email)</email>")
		end
	end

	# println(m.xmlmodel)

	job = submitJob(m.solver.server, m.xmlmodel)

    while true
        info = getJobInfo(m.solver.server, job)
        println("Waiting for results. Status: $(info[4])")
        if info[4] == "Done"
            break
        else
            sleep(3.0)
        end
    end

	parseresults!(m, job)
    m.last_results = getFinalResults(m.solver.server, job)

    m.solver.print_results && println(m.last_results)
    if m.solver.result_file != ""
        open(m.solver.result_file, "w") do f
            write(f, m.last_results)
        end
    end
	m.inner.status
end

function solfilename(job)
    "https://neos-server.org/neos/jobs/$(10_000 * floor(Int, job.number / 10_000))/$(job.number)-$(job.password)-solver-output.zip"
end

getreducedcosts(m::NEOSNonlinearModel) = fill(NaN, numvar(m))
getconstrduals(m::NEOSNonlinearModel) = fill(NaN, numconstr(m))
getobjbound(m::NEOSNonlinearModel) = NaN

function parseresults!(m::NEOSNonlinearModel, job)
    # https://neos-server.org/neos/jobs/5710000/5711322-FLWbgxPt-solver-output.zip
    println("Getting solution file from $(solfilename(job))...")
    res = get(solfilename(job))
	if res.status != 200
        error("Error retrieving results for job $(job.number):$(job.password).")
    end
    println("Extracting file from .zip")
    io = IOBuffer()
    write(io, res.data)
    z = ZipFile.Reader(io)
    @assert length(z.files) == 1 # there should only be one .sol file in here
    sol = readstring(z.files[1])
    close(io)
    io = IOBuffer()
    write(io, sol)
    println("Reading results")
    seekstart(io)
    AmplNLWriter.read_results(io, m.inner)
end
