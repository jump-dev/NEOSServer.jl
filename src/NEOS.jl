# http://www.neos-server.org/neos/NEOS-API.html
module NEOS

warn("All models submitted to NEOS become part of the public domain. For more see\n
	http://www.neos-server.org")

using LightXML
using Requests
using Codecs
using JuMP

import Compat

importall MathProgBase.SolverInterface

include("NEOSSolverInterface.jl")
include("parser.jl")
include("xmlrpc.jl")
include("writer.jl")

export NEOSSolver, NEOSMathProgModel,
	# MathProgBase functions
	model, loadproblem!, writeproblem!, optimize!,
	setvartype!, addsos1!, addsos2!,
	status, getobjval, getsolution, getsense,

	addParameter!,

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
