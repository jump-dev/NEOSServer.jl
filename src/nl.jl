using ZipFile

mutable struct NLModel <: NEOSModel
    solver::NEOSSolver
	xmlmodel::String
	last_results::String
    inner::AmplNLWriter.AmplNLMathProgModel
end
LinearQuadraticModel{S}(s::NEOSSolver{S, :NL}) = NLModel(
    s,
    "",
    "",
    AmplNLWriter.AmplNLMathProgModel("", String[], "")
)

function loadproblem!(m::NLModel, A::AbstractMatrix, x_l, x_u, c, g_l, g_u, sense)
    loadproblem!(AmplNLWriter.AmplNLLinearQuadraticModel(m.inner), A, x_l, x_u, c, g_l, g_u, sense)
end

function neos_writexmlmodel!(m::NLModel)
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
    # Convert the model to NL and add
    m.xmlmodel = replace(m.solver.template, r"<model>.*</model>"is, String(take!(io)))
end

# Wrapper functions
for f in [:getvartype,:getsense,:status,:getsolution,:getobjval,:numvar,:numconstr,:get_solve_result,:get_solve_result_num,:get_solve_message,:get_solve_exitcode,:getsolvetime]
  @eval $f(m::NLModel) = $f(m.inner)
end
for f in [:setvartype!,:setsense!,:setwarmstart!]
  @eval $f(m::NLModel, x) = $f(m.inner, x)
end

function solfilename(job)
    "https://neos-server.org/neos/jobs/$(10_000 * floor(Int, job.number / 10_000))/$(job.number)-$(job.password)-solver-output.zip"
end

getreducedcosts(m::NLModel) = fill(NaN, numvar(m))
getconstrduals(m::NLModel) = fill(NaN, numconstr(m))
getobjbound(m::NLModel) = NaN

function parseresults!(m::NLModel, job)
    # https://neos-server.org/neos/jobs/5710000/5711322-FLWbgxPt-solver-output.zip
    println("Getting solution file from $(solfilename(job))...")
    res = get(solfilename(job))
	if res.status != 200
        error("Error retrieving results for job $(job.number):$(job.password). Response status is $(res.status).")
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
