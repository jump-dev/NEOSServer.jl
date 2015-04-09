# http://www.neos-server.org/neos/NEOS-API.html
module NEOS

warn("All models submitted to NEOS become part of the public domain. For more see\n
	http://www.neos-server.org")

using LightXML
using Requests
using Codecs
using JuMP

importall MathProgBase.SolverInterface

export NEOSSolver, NEOSSolve

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

type Job
	number::Int64
	password::ASCIIString
end

include("parser.jl")
include("xmlrpc.jl")
# =====================================
#  	Supported types
const SUPPORTED = [
	(:MILP, :SYMPHONY),
	(:MILP, :CPLEX),
	(:MILP, :XpressMP)
]

# ========================================================
#
# 	NEOSSolver creation
#
function NEOSSolver(;solver=:SYMPHONY, category=:MILP, email="")
	if !((category, solver) in SUPPORTED)
		error("The solver $(solver) for $(category) problems has not been implemented yet.")
	end
 	n = NEOSSolver(Server("neos-server.org", 3332), email, category, solver, "")
 	addTemplate!(n)
 	return n
end

function addTemplate!(n::NEOSSolver)
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



function submitMPSJob(n::NEOSSolver, mps_filename::String)
	xml = addModel(n.template, mps_filename)
	return submitJob(n, xml)	
end

function addModel(xml::String, mps_filename::String)
	return replace(xml, r"(?s)<MPS>.*</MPS>", "<MPS>" * readall(mps_filename) * "</MPS>")
end

function getResults!(m::JuMP.Model, j::Job)
	println("Waiting for results")
	results = bytestring(decode(Base64, replace(getFinalResults(m.solver, j)[1], "\n", "")))
	return parse_values!(m, results)
end

function NEOSSolve(m::JuMP.Model; kwargs...)
	if m.solver.solver in [:CPLEX, :XpressMP] && m.solver.email==""
		error("$(n.solver) requires that NEOS users supply a valid email. Use the addEmail!(n::NEOSSolver, email::ASCIIString) function to add one.")
	end
	fname = randstring(10) * ".mps"
	JuMP.writeMPS(m, fname)
	job = submitMPSJob(m.solver, fname)
	rm(fname)
	return getResults!(m, job)
end

end