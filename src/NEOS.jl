# http://www.neos-server.org/neos/NEOS-API.html
module NEOS

warn("All models submitted to NEOS become part of the public domain. For more see http://www.neos-server.org")

using LightXML
using Requests
using Codecs
using GZip

using Compat

importall MathProgBase.SolverInterface

include("NEOSServer.jl")
include("NEOSSolverInterface.jl")
include("writer.jl")

include("solvers/CPLEX.jl")
include("solvers/SYMPHONY.jl")
include("solvers/XpressMP.jl")

export NEOSServer, NEOSMathProgModel,
	NEOSSYMPHONYSolver, NEOSCPLEXSolver, NEOSXpressMPSolver,

 	# MathProgBase functions
	model, loadproblem!, writeproblem!, optimize!,
	setvartype!, addsos1!, addsos2!, setsense!,
	status, getobjval, getsolution, getsense,
	getreducedcosts, getconstrduals,

	addparameter!, addemail!, print_neos_result,

 	# NEOS API functions
	neosHelp, emailHelp, welcome, version, ping, printQueue,
	listAllSolvers, listCategories,
	getSolverTemplate,
	listSolversInCategory,
	submitJob,
	getJobStatus, killJob, getFinalResults, getFinalResultsNonBlocking,
	getJobInfo,
	getIntermediateResults, getIntermediateResultsNonBlocking
end
