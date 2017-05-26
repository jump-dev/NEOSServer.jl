# http://www.neos-server.org/neos/NEOS-API.html
module NEOS

warn("All models submitted to NEOS become part of the public domain. For more see http://www.neos-server.org")

using LightXML
using Requests
using Codecs
using Libz

using Compat

importall MathProgBase.SolverInterface

include("NEOSServer.jl")
include("NEOSSolverInterface.jl")
include("MPSWriter.jl")

include("solvers/CPLEX.jl")
include("solvers/MOSEK.jl")
include("solvers/SYMPHONY.jl")
include("solvers/FICOXpress.jl")

export NEOSServer,
	NEOSCPLEXSolver, NEOSMOSEKSolver, NEOSSYMPHONYSolver, NEOSXpressSolver,

	addparameter!, addemail!,

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
