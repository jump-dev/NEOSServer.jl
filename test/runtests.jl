using FactCheck
using MathProgBase
importall NEOS

# Null out this method for testing
NEOS.getobjbound(m::NEOS.NEOSMathProgModel) = 0

#
# As part of the NEOS terms of use, some solvers
# 	require a valid email to be supplied.
#
# TESTING_EMAIL = readchomp(`git config --get user.email`)
TESTING_EMAIL = "odow@users.noreply.github.com"

facts("Test NEOS Server") do
	s = NEOSServer()
	addemail!(s, TESTING_EMAIL)
	@fact s.email --> TESTING_EMAIL
	addemail!(s, "")
	s = NEOSServer(email=TESTING_EMAIL)
	@fact s.email --> TESTING_EMAIL
	v = version(s)
	@fact match(r"neos version ([0-9]+) \(.+\)", v) == nothing --> false

	@fact contains(neosHelp(s), "class NeosServer") --> true

	_solvers = listAllSolvers(s)
	@fact "milp:CPLEX:MPS" in _solvers --> true
	@fact "milp:MOSEK:MPS" in _solvers --> true
	@fact "lp:MOSEK:MPS" in _solvers --> true
	@fact "milp:SYMPHONY:MPS" in _solvers --> true
	@fact "milp:XpressMP:MPS" in _solvers --> true

	@fact "Mixed Integer Linear Programming" in listCategories(s) --> true

	_solvers = listSolversInCategory(s, :MILP)
	@fact "CPLEX:MPS" in _solvers --> true
	@fact "MOSEK:MPS" in _solvers --> true
	@fact "SYMPHONY:MPS" in _solvers --> true
	@fact "XpressMP:MPS" in _solvers --> true

	j = NEOS.NEOSJob(3804943, "OfRcoMbp")
	_info = getJobInfo(s, j)
	@fact _info[1] --> "milp"
	@fact _info[2] --> "XpressMP"
	@fact _info[3] --> "MPS"
	@fact _info[4] --> "Done"

	@fact getJobStatus(s, j) --> "Done"
	@fact killJob(s, j) --> "Job #3804943 is finished"

	@fact getIntermediateResults(s, j) == getIntermediateResultsNonBlocking(s, j) == "Results for Job #3804943 are no longer available" --> true
end

facts("Test NEOSMathProgModel") do
	m = MathProgBase.LinearQuadraticModel(NEOSSYMPHONYSolver())
	@fact MathProgBase.getsolution(m) --> []
	@fact MathProgBase.getobjval(m) --> 0.
	@fact MathProgBase.getsense(m) --> :Min
	MathProgBase.setsense!(m, :Max)
	@fact MathProgBase.getsense(m) --> :Max
	@fact MathProgBase.status(m) --> NEOS.NOTSOLVED
	MathProgBase.loadproblem!(m, [1. 2. 3.; 1. 1. 1.], [-1., 0., 0.], [1., 1., Inf], [0., 0., 1.], [1.25, 1.], [1.25, 1.], :Max)
	MathProgBase.setvartype!(m, [:SemiCont, :Cont, :Bin])
	@fact_throws NEOS.addCOLS(m, "")
	MathProgBase.setvartype!(m, [:SemiInt, :Cont, :Bin])
	@fact_throws NEOS.addCOLS(m, "")
end

SOLVERS = [(NEOSCPLEXSolver, :timelimit), (NEOSMOSEKSolver, :MSK_DPAR_OPTIMIZER_MAX_TIME), (NEOSSYMPHONYSolver, :time_limit), (NEOSXpressMPSolver, :MAXTIME)]

for (s, timelimit) in SOLVERS
	solver = s()

	facts("Test basic solver stuff for $(typeof(solver))") do
		@fact isa(solver, NEOS.NEOSSolver) --> true

		fields = fieldnames(solver)
		for sym in [:server, :requires_email, :solves_sos, :provides_duals,
			:template, :params, :gzipmodel, :print_results, :result_file]
			@fact sym in fields --> true
		end

		@fact method_exists(NEOS.parse_status!, (typeof(solver), NEOS.NEOSMathProgModel)) --> true
		@fact method_exists(NEOS.parse_objective!, (typeof(solver), NEOS.NEOSMathProgModel)) --> true
		@fact method_exists(NEOS.parse_solution!, (typeof(solver), NEOS.NEOSMathProgModel)) --> true

		m = MathProgBase.LinearQuadraticModel(solver)

		m.nrow, m.ncol = 1, 2
		if solver.provides_duals
			@fact method_exists(NEOS.parse_duals!, (typeof(solver), NEOS.NEOSMathProgModel)) --> true
			@fact MathProgBase.getreducedcosts(m) --> []
			@fact MathProgBase.getconstrduals(m) --> []
		else
			@fact isnan(MathProgBase.getreducedcosts(m)) --> [true, true;]
			@fact isnan(MathProgBase.getconstrduals(m)) --> [true;]
		end

		if !solver.solves_sos
			@fact_throws MathProgBase.addsos1!(m, [], [])
			@fact_throws MathProgBase.addsos2!(m, [], [])
		end

		addemail!(m, "Test")
		@fact m.solver.server.email --> "Test"
		addemail!(solver, TESTING_EMAIL)
		@fact solver.server.email --> TESTING_EMAIL


		addparameter!(solver, "key", 0)
		@fact solver.params["key"] --> 0
		solver.params = Dict{ASCIIString, Any}()

		_solver = @eval $(s)($(timelimit)=60, email=TESTING_EMAIL)
		@fact _solver.params[string(timelimit)] --> 60
		@fact _solver.server.email --> TESTING_EMAIL

		if solver.requires_email
			addemail!(solver, "")
			@fact_throws linprog([-1.,0.;],sparse([2. -1.;]),'<',1.5, [-1, -Inf], [1, 0.], solver)
			addemail!(solver, TESTING_EMAIL)
		end
	end

    facts("Testing feasible problem $(typeof(solver))") do
	    sol = linprog([-1.,0.;],sparse([2. -1.;]),'<',1.5, [-1, -Inf], [1, 0.], solver)
	    @fact sol.status --> :Optimal
	    @fact sol.objval --> roughly(-0.75, 1e-5)
	    @fact sol.sol --> roughly([0.75, 0.;], 1e-5)
		if solver.provides_duals
	    	@fact sol.attrs[:lambda] --> roughly([-0.5;], 1e-5)
	    	@fact sol.attrs[:redcost] --> roughly([0., -0.5;], 1e-5)
		else
			@fact isnan(sol.attrs[:lambda]) --> [true]
	    	@fact isnan(sol.attrs[:redcost]) --> [true, true;]
		end

		addparameter!(solver, string(timelimit), 60)
        sol = mixintprog(-[5.,3.,2.,7.,4.;],Float64[2. 8. 4. 2. 5.;],'<',10.,:Int,-0.5,1.,solver)
		@fact sol.status --> :Optimal
 		@fact sol.objval --> roughly(-16.0, 1e-6)
		@fact sol.sol --> roughly([1.0, 0.0, 0.0, 1.0, 1.0;], 1e-4)
	end

	facts("Testing infeasible problem $(typeof(solver))") do
		solver.gzipmodel=false
	    sol = linprog([1.,0.;],[-2. -1.;],'>',1., solver)
		@fact (sol.status == NEOS.INFEASIBLE || sol.status == NEOS.UNBNDORINF) --> true
	end

	facts("Testing unbounded problem $(typeof(solver))") do
	    solver.result_file = randstring(5)
		sol = linprog([-1.,-1.;],[-1. 2.;],'<',[0.;], solver)
	    @fact (sol.status == NEOS.UNBOUNDED || sol.status == NEOS.UNBNDORINF) --> true
		@fact length(readall(solver.result_file)) > 0 --> true
		rm(solver.result_file)
		solver.result_file = ""
    end

	!solver.solves_sos && continue
	facts("Testing SOS problem $(typeof(solver))") do
		m = MathProgBase.LinearQuadraticModel(solver)
		MathProgBase.loadproblem!(m, [1. 2. 3.; 1. 1. 1.], [-1., 0., 0.], [1., 1., Inf], [0., 0., 1.], [1.25, 1.], [1.25, 1.], :Max)
		MathProgBase.addsos2!(m, [1, 2, 3], [1., 2., 3.])
		@fact MathProgBase.optimize!(m) --> NEOS.OPTIMAL
		@fact MathProgBase.getobjval(m) --> roughly(0., 1e-6)
		@fact MathProgBase.getsolution(m) --> roughly([0.75, 0.25, 0.], 1e-6)

		m = MathProgBase.LinearQuadraticModel(solver)
		MathProgBase.loadproblem!(m, [1. 1. 1.], [0., 0., 0.], [1., 1., 1.], [1., 3., 2.], [0.], [1.5], :Max)
		MathProgBase.addsos1!(m, [1, 2, 3], [1., 2., 3.])
		@fact MathProgBase.optimize!(m) --> NEOS.OPTIMAL
		@fact MathProgBase.getobjval(m) --> roughly(3., 1e-6)
		@fact MathProgBase.getsolution(m) --> roughly([0., 1., 0.], 1e-6)
	end
end

FactCheck.exitstatus()
