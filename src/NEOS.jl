# http://www.neos-server.org/neos/NEOS-API.html
module NEOS

warn("Make sure you comply with the NEOS terms of use: http://www.neos-server.org/neos/termofuse.html")

using LightXML
using Requests
using Codecs
using Libz
using AmplNLWriter

importall MathProgBase.SolverInterface

include("NEOSServer.jl")
include("NEOSSolver.jl")
include("NEOSSolverInterface.jl")
include("MPSWriter.jl")
include("nl.jl")
include("mps.jl")

include("solvers/CPLEX_MPS.jl")
include("solvers/MOSEK_MPS.jl")
include("solvers/SYMPHONY_MPS.jl")
include("solvers/FICOXpress_MPS.jl")
include("solvers/CPLEX_NL.jl")

export NEOSServer, NEOSSolver,
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
