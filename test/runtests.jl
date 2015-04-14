using JuMP
using NEOS
using FactCheck

using MathProgBase

#
# As part of the NEOS terms of use, some solvers
# 	require a valid email to be supplied.
#
TESTING_EMAIL = "odow@users.noreply.github.com"
MIP_SOLVERS = [:SYMPHONY, :scip, :CPLEX, :XpressMP]
LP_SOLVERS = [:CPLEX]

for solver in LP_SOLVERS
	println("\n\nTesting solver $solver\n")

	# These tests taken from github.com/JuliaOpt/MathProgBase/test/linprog.jl

    # min -x
    # s.t. 2x + y <= 1.5
    # x,y >= 0
    # solution is (0.75,0) with objval -0.75
    sol = linprog([-1,0],[2 1],'<',1.5, NEOSSolver(solver=solver, category=:LP, email=TESTING_EMAIL))
    facts() do
	    @fact sol.status => :Optimal
	    @fact sol.objval => roughly(-0.75, 1e-5)
	    @fact sol.sol => roughly([0.75, 0.], 1e-5)
	    @fact sol.attrs[:lambda] => roughly([-0.5], 1e-5)
	    @fact sol.attrs[:redcost] => roughly([0., 0.5], 1e-5)
    end

    sol = linprog([-1,0],sparse([2 1]),'<',1.5, NEOSSolver(solver=solver, category=:LP, email=TESTING_EMAIL))
    facts() do
	    @fact sol.status => :Optimal
	    @fact sol.objval => roughly(-0.75, 1e-5)
	    @fact sol.sol => roughly([0.75, 0.], 1e-5)
	    @fact sol.attrs[:lambda] => roughly([-0.5], 1e-5)
	    @fact sol.attrs[:redcost] => roughly([0., 0.5], 1e-5)
    end

    # test infeasible problem:
    # min x
    # s.t. 2x+y <= -1
    # x,y >= 0
    sol = linprog([1,0],[2 1],'<',-1, NEOSSolver(solver=solver, category=:LP, email=TESTING_EMAIL))
    facts() do
	    @fact sol.status => :Infeasible
    end

    # test unbounded problem:
    # min -x-y
    # s.t. -x+2y <= 0
    # x,y >= 0
    sol = linprog([-1,-1],[-1 2],'<',[0], NEOSSolver(solver=solver, category=:LP, email=TESTING_EMAIL))
    facts() do
	    @fact sol.status => :Unbounded
    end

end



include("JuMP_tests.jl")
include(joinpath(Pkg.dir("MathProgBase"),"test","mixintprog.jl"))
import MathProgBase
# Stub methods
MathProgBase.getobjbound(m::NEOSMathProgModel) = nothing

for solver in MIP_SOLVERS
	println("\n\nTesting solver $solver\n")
	mixintprogtest(NEOSSolver(solver=solver, email=TESTING_EMAIL))
	run_JuMP_tests(solver, TESTING_EMAIL)
end

FactCheck.exitstatus()