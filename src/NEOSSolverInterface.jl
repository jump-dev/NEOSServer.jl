const SUPPORTED = [
	(:MILP, :SYMPHONY),
	(:MILP, :CPLEX),
	(:MILP, :XpressMP)
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
	NEOSSolver(server, email, category, solver, template) = new(server, email, category, solver, template)
end

function NEOSSolver(;solver=:SYMPHONY, category=:MILP, email="")
	if !((category, solver) in SUPPORTED)
		error("The solver $(solver) for $(category) problems has not been implemented yet.")
	end
 	n = NEOSSolver(Server("neos-server.org", 3332), email, category, solver, "")
 	addTemplate!(n)
 	return n
end

function addTemplate!(n::NEOSSolver)
	println("Getting template from NEOS for $(n.solver):$(n.category)")
	xml = getSolverTemplate(n, n.category, n.solver, :MPS)
	xml = addNEOSsettings(xml, n)
	xml = addSolverSpecific(xml, n.solver)
	n.template = xml
end

function addNEOSsettings(xml::String, n::NEOSSolver)
	if n.email != ""
		xml = replace(xml, r"<document>", "<document>\n<email>$(n.email)</email>")
	end
	xml
end

function addSolverSpecific(xml::String, solver::Symbol)
	if solver == :CPLEX
		xml = replace(xml, r"(?s)<post>.*</post>", "<post><![CDATA[disp sol objective\ndisplay solution variables -]]></post>")
	elseif solver == :XpressMP
		xml = replace(xml, r"(?s)<par>.*</par>", "<par></par>")
		xml = replace(xml, r"(?s)<algorithm>.*</algorithm>", "<algorithm><![CDATA[SIMPLEX]]></algorithm>")
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

type NEOSMathProgModel <: AbstractMathProgModel
	solver::NEOSSolver

	mps::String

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

	objVal::Float64
	solution::Vector{Float64}
	status::Symbol
	NEOSMathProgModel(;solver=NEOSSolver()) = new(solver, "", 0, 0, :nothing, :nothing, :nothing, :nothing, :nothing, :nothing, :nothing, :nothing, 0., [], :UnSolved)
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

function loadproblem!(m::NEOSMathProgModel, filename::String)
	if filename[end-3:end] != ".mps"
		error("Unable to load $filename. Must be MPS file.")
	end
	setMPS!(m, filename)
end

function setMPS!(m::NEOSMathProgModel, filename::String)
	m.mps = readall(filename)
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
	xml = addModel(m)
	job = submitJob(m.solver, xml)
	println("Waiting for results")
	results = bytestring(decode(Base64, replace(getFinalResults(m.solver, job)[1], "\n", "")))
	println(results)
	return parse_values!(m, results)	
end

function addModel(m::NEOSMathProgModel)
	return replace(m.solver.template, r"(?s)<MPS>.*</MPS>", "<MPS>" * buildMPS(m) * "</MPS>")
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

function getsense(m::NEOSMathProgModel)
	return m.sense
end

function setvartype!(m::NEOSMathProgModel, t::Vector{Symbol})
	m.colcat = t
end

function getobjbound(m::NEOSMathProgModel)
	return :unknown
end