using Compat
using FactCheck
using MathProgBase
importall NEOS

# Null out this method for testing
NEOS.getobjbound(m::NEOSMathProgModel) = 0

#
# As part of the NEOS terms of use, some solvers
# 	require a valid email to be supplied.
#
# TESTING_EMAIL = readchomp(`git config --get user.email`)
TESTING_EMAIL = "odow@users.noreply.github.com"

facts("Test NEOS Server") do
	s = NEOSServer()
	addemail!(s, TESTING_EMAIL)
	@fact s.email => TESTING_EMAIL
	addemail!(s, "")
	s = NEOSServer(email=TESTING_EMAIL)
	@fact s.email => TESTING_EMAIL
	@fact match(r"neos version ([0-9]+) \(.+\)", version(s)) == nothing => false

	@fact contains(neosHelp(s), "class NeosServer") => true

	_solvers = listAllSolvers(s)
	@fact "milp:CPLEX:MPS" in _solvers => true
	@fact "milp:SYMPHONY:MPS" in _solvers => true
	@fact "milp:XpressMP:MPS" in _solvers => true

	@fact "Mixed Integer Linear Programming" in listCategories(s) => true

	_solvers = listSolversInCategory(s, :MILP)
	@fact "CPLEX:MPS" in _solvers => true
	@fact "SYMPHONY:MPS" in _solvers => true
	@fact "XpressMP:MPS" in _solvers => true

	j = NEOS.NEOSJob(3804943, "OfRcoMbp")
	_info = getJobInfo(s, j)
	@fact _info[1] => "milp"
	@fact _info[2] => "XpressMP"
	@fact _info[3] => "MPS"
	@fact _info[4] => "Done"

	@fact getJobStatus(s, j) => "Done"
	@fact killJob(s, j) => "Job #3804943 is finished"

	@fact getIntermediateResults(s, j) == getIntermediateResultsNonBlocking(s, j) == "Job 3804943 dispatched\npassword: OfRcoMbp\n---------- Begin Solver Output -----------\nJob submitted to NEOS HTCondor pool.\n" => true
end

facts("Test NEOSMathProgModel") do
	m = model(NEOS.UnsetSolver())
	@fact isa(m.solver, NEOS.UnsetSolver) => true
	@fact getsolution(m) => []
	@fact getobjval(m) => 0.
	@fact getsense(m) => :Min
	setsense!(m, :Max)
	@fact getsense(m) => :Max
	@fact status(m) => NEOS.NOTSOLVED
end

SOLVERS = [(NEOSCPLEXSolver, :timelimit), (NEOSSYMPHONYSolver, :time_limit), (NEOSXpressMPSolver, :MAXTIME)]

for (s, timelimit) in SOLVERS
	solver = s()

	facts("Test basic solver stuff for $(typeof(solver))") do
		@fact isa(solver, NEOS.AbstractNEOSSolver) => true

		fields = @compat fieldnames(solver)
		@fact :server in fields => true
		@fact :requires_email in fields => true
		@fact :solves_sos in fields => true
		@fact :provides_duals in fields => true
		@fact :template in fields => true
		@fact :params in fields => true

		@fact method_exists(NEOS.parse_status!, (typeof(solver), NEOSMathProgModel)) => true
		@fact method_exists(NEOS.parse_objective!, (typeof(solver), NEOSMathProgModel)) => true
		@fact method_exists(NEOS.parse_solution!, (typeof(solver), NEOSMathProgModel)) => true

		m = model(solver)

		m.nrow, m.ncol = 1, 2
		if solver.provides_duals
			@fact method_exists(NEOS.parse_duals!, (typeof(solver), NEOSMathProgModel)) => true
			@fact getreducedcosts(m) => []
			@fact getconstrduals(m) => []
		else
			@fact isnan(getreducedcosts(m)) => [true, true;]
			@fact isnan(getconstrduals(m)) => [true;]
		end

		if !solver.solves_sos
			@fact_throws addsos1(m, [], [])
			@fact_throws addsos2(m, [], [])
		end

		addemail!(m, "Test")
		@fact m.solver.server.email => "Test"
		addemail!(solver, TESTING_EMAIL)
		@fact solver.server.email => TESTING_EMAIL


		addparameter!(solver, "key", 0)
		@fact solver.params["key"] => 0
		solver.params = Dict{ASCIIString, Any}()

		_solver = @eval $(s)($(timelimit)=60, email=TESTING_EMAIL)
		@fact _solver.params[string(timelimit)] => 60
		@fact _solver.server.email => TESTING_EMAIL

	end

    facts("Testing feasible problem $(typeof(solver))") do
	    sol = linprog([-1.,0.;],sparse([2. 1.;]),'<',1.5, solver)
	    @fact sol.status => :Optimal
	    @fact sol.objval => roughly(-0.75, 1e-5)
	    @fact sol.sol => roughly([0.75, 0.;], 1e-5)
		if solver.provides_duals
	    	@fact sol.attrs[:lambda] => roughly([-0.5;], 1e-5)
	    	@fact sol.attrs[:redcost] => roughly([0., 0.5;], 1e-5)
		else
			@fact isnan(sol.attrs[:lambda]) => [true]
	    	@fact isnan(sol.attrs[:redcost]) => [true, true;]
		end

        sol = mixintprog(-[5.,3.,2.,7.,4.;],Float64[2. 8. 4. 2. 5.;],'<',10.,:Int,0.,1.,solver)
		@fact sol.status => :Optimal
 		@fact sol.objval => roughly(-16.0, 1e-6)
		@fact sol.sol => roughly([1.0, 0.0, 0.0, 1.0, 1.0;], 1e-4)
	end

	facts("Testing infeasible problem $(typeof(solver))") do
	    sol = linprog([1.,0.;],[2. 1.;],'<',-1., solver)
		@fact sol.status => :Infeasible
	end

	facts("Testing unbounded problem $(typeof(solver))") do
		addparameter!(solver, string(timelimit), 60)
	    sol = linprog([-1.,-1.;],[-1. 2.;],'<',[0.;], solver)
	    @fact sol.status => :Unbounded
    end

	!solver.solves_sos && continue
	facts("Testing SOS problem $(typeof(solver))") do
		m = model(solver)
		loadproblem!(m, [1. 2. 3.; 1. 1. 1.], [0., 0., 0.], [1., 1., 1.], [0., 0., 1.], [1.25, 1.], [1.25, 1.], :Max)
		addsos2!(m, [1, 2, 3], [1., 2., 3.])
		@fact optimize!(m) => :Optimal
		@fact getobjval(m) => roughly(0., 1e-6)
		@fact getsolution(m) => roughly([0.75, 0.25, 0.], 1e-6)

		# m = model(solver, print_results=true)
		# loadproblem!(m, [1. 1. 1.], [0., 0., 0.], [1., 1., 1.], [1., 3., 2.], [0.], [1.5], :Max)
		# addsos1!(m, [1, 2, 3], [1., 2., 3.])
		# @fact optimize!(m) => :Optimal
		# @fact getobjval(m) => roughly(3., 1e-6)
		# @fact getsolution(m) => roughly([0., 1., 0.], 1e-6)
	end
end

FactCheck.exitstatus()
