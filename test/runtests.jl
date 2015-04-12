using JuMP
using NEOS
using FactCheck

#
# As part of the NEOS terms of use, some solvers
# 	require a valid email to be supplied.
#
TESTING_EMAIL = "odow@users.noreply.github.com"
SOLVERS = [:SYMPHONY, :CPLEX, :XpressMP]

include(joinpath(Pkg.dir("MathProgBase"),"test","mixintprog.jl"))
include("JuMP_tests.jl")

for solver in SOLVERS
	println("\n\nTesting solver $solver\n")

	println("\tMathProgBase tests")
	mixintprogtest(NEOSSolver(solver=solver, email=TESTING_EMAIL))

	println("\tJuMP tests")
	run_JuMP_tests(solver, TESTING_EMAIL)
end

FactCheck.exitstatus()