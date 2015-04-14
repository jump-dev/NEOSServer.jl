const SUPPORTED = [
	(:MILP, :SYMPHONY),
	(:MILP, :CPLEX),
	(:LP, :CPLEX),
	(:MILP, :XpressMP),
	(:MILP, :scip)
]

type Server
	useragent::String
	host::String
	contenttype::String
	Server(host, port) = new("JuliaXMLRPC", "http://$(host):$(port)", "text/xml")
end

type NEOSSolver <: AbstractMathProgSolver
	server::Server
	email::String
	category::Symbol
	solver::Symbol
	template::String
	params::Vector{String}
	resultdirectory::String
	NEOSSolver(server, email, category, solver, template, params, result) = new(server, email, category, solver, template, params, result)
end

function NEOSSolver(;solver=:SYMPHONY, category=:MILP, email="", params=[], resultdirectory="")
	if !((category, solver) in SUPPORTED)
		error("The solver $(solver) for $(category) problems has not been implemented yet.")
	end
 	n = NEOSSolver(Server("neos-server.org", 3332), email, category, solver, "", params, resultdirectory)
 	addTemplate!(n)
 	return n
end

function addTemplate!(n::NEOSSolver)
	println("Getting template from NEOS for $(n.solver):$(n.category)")
	xml = getSolverTemplate(n, n.category, n.solver, :MPS)
	xml = addNEOSsettings(xml, n)
	# xml = addSolverSpecific(xml, n.solver)
	n.template = xml
end

function addNEOSsettings(xml::String, n::NEOSSolver)
	if n.email != ""
		xml = replace(xml, r"<document>", "<document>\n<email>$(n.email)</email>")
	end
	xml
end

function addEmail!(n::NEOSSolver, email::ASCIIString)
	n.email = email
	if contains(n.template, "<email>")
		n.template = replace(n.template, r"<email>.*</email>", "<email>$(n.email)</email>")
	else
		n.template = replace(n.template, r"<document>", "<document>\n<email>$(n.email)</email>")
	end
end

type SOS
	order::Int64
	indices::Vector
	weights::Vector
	SOS(order, indices, weights) = new(order, indices, weights)
end

type NEOSMathProgModel <: AbstractMathProgModel
	solver::NEOSSolver

	sModel::String

	ncol::Int64
	nrow::Int64

	A
	collb
	colub
	f
	rowlb
	rowub
	sense
	colcat
	
	sos::Vector{SOS}

	objVal::Float64
	reducedcosts::Vector{Float64}
	duals::Vector{Float64}
	solution::Vector{Float64}
	status::Symbol
	NEOSMathProgModel(;solver=NEOSSolver()) = new(solver, "", 0, 0, :nothing, :nothing, :nothing, :nothing, :nothing, :nothing, :nothing, :nothing, [], 0., [], [], [], :UnSolved)
end

function model(s::NEOSSolver)
	return NEOSMathProgModel(solver=s)
end

type Job
	number::Int64
	password::ASCIIString
end

function loadproblem!(m::NEOSMathProgModel, A, collb, colub, f, rowlb, rowub, sense)
	m.ncol = length(f)
	m.nrow = length(rowlb)
	m.A = A
	m.collb = collb
	m.colub = colub
	m.f = f
	m.rowlb = rowlb
	m.rowub = rowub
	m.sense = sense
end

function writeproblem!(m::NEOSMathProgModel, filename::String)
	f = open(filename, "w")
	write(f, m.mps)
	close(f)
end

function optimize!(m::NEOSMathProgModel)
	if m.solver.solver in [:CPLEX, :XpressMP] && m.solver.email==""
		error("$(m.solver.solver) requires that NEOS users supply a valid email")
	end
	addSolverSpecific!(m)
	addModel!(m)
	job = submitJob(m.solver, m.sModel)
	println("Waiting for results")
	results = bytestring(decode(Base64, replace(getFinalResults(m.solver, job)[1], "\n", "")))
	println(results)
	if m.solver.resultdirectory != ""
		open(m.solver.resultdirectory * "/$(job.number).txt", "w") do f
			write(f, results)
			println("Results written to $(m.solver.resultdirectory)/$(job.number).txt.")
		end
	end
	return parse_values!(m, results)	
end

function addModel!(m::NEOSMathProgModel)
	if m.solver.solver == :scip
		m.sModel = replace(m.sModel, r"(?s)<mps>.*</mps>", "<mps>" * buildMPS(m) * "</mps>")
	else
		m.sModel = replace(m.sModel, r"(?s)<MPS>.*</MPS>", "<MPS>" * buildMPS(m) * "</MPS>")
	end
end

function addSolverSpecific!(m::NEOSMathProgModel)
	params = ""
	for p in m.solver.params
		params *= (p * "\n")
	end
	if m.solver.solver == :SYMPHONY
		parameter_tag = "options"
	elseif m.solver.solver == :CPLEX
		parameter_tag = "options"
		m.solver.template = replace(m.solver.template, r"(?s)<post>.*</post>", "<post><![CDATA[disp sol objective\ndisplay solution variables -\ndisplay solution dual -\ndisplay solution reduced -]]></post>")
	elseif m.solver.solver == :XpressMP
		parameter_tag = "par"
		m.solver.template = replace(m.solver.template, r"(?s)<algorithm>.*</algorithm>", "<algorithm><![CDATA[SIMPLEX]]></algorithm>")
	elseif m.solver.solver == :scip
		m.solver.template = replace(m.solver.template, r"(?s)<lp>.*</osil>", "")
		parameter_tag = "par"
	end
	m.sModel = replace(m.solver.template, Regex("(?s)<$(parameter_tag)>.*</$(parameter_tag)>"), "<$(parameter_tag)><![CDATA[$(params)]]></$(parameter_tag)>")
end

function addsos1!(m::NEOSMathProgModel, indices::Vector, weights::Vector)
	push!(m.sos, SOS(1, indices, weights))
end

function addsos2!(m::NEOSMathProgModel, indices::Vector, weights::Vector)
	push!(m.sos, SOS(2, indices, weights))
end

function addParameter!(n::NEOSSolver, param::String)
	push!(n.params, param)
end
function addParameter!(m::NEOSMathProgModel, param::String)
	push!(m.solver.params, param)
end

function status(m::NEOSMathProgModel)
	return m.status
end

function getobjval(m::NEOSMathProgModel)
	return m.objVal
end

function getsolution(m::NEOSMathProgModel)
	return m.solution
end

function getreducedcosts(m::NEOSMathProgModel)
	if m.solver.category == :MILP
		warn("Reduced costs not available from MILP solvers. Use LP solver category instead")
	end
	return m.reducedcosts
end

function getconstrduals(m::NEOSMathProgModel)
	if m.solver.category == :MILP
		warn("Duals not available for MILP solvers. Use LP solver category instead.")
	end
	return m.duals
end

function getsense(m::NEOSMathProgModel)
	return m.sense
end

function setvartype!(m::NEOSMathProgModel, t::Vector{Symbol})
	if (t==:Int || t==:Bin) && m.solver.category != :MILP
		error("Choose a MILP solver if your model has integer variables.")
	end
	m.colcat = t
end
