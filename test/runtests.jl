using JuMP
using NEOS

#
# As part of the NEOS terms of use, some solvers
# 	require a valid email to be supplied.
#
TESTING_EMAIL = "odow@users.noreply.github.com"
SOLVERS = [:SYMPHONY, :CPLEX, :XpressMP]

include(joinpath(Pkg.dir("MathProgBase"),"test","mixintprog.jl"))


for solver in SOLVERS
	println("\n\nTesting solver $solver\n")

	println("\tMathProgBase tests")
	mixintprogtest(NEOSSolver(solver=solver, email=TESTING_EMAIL))

	println("\tTesting infeasible problem")
	m = Model(solver=NEOSSolver(solver=solver, email=TESTING_EMAIL))
	@defVar(m, 0 <= x <= 1)
	@defVar(m, 0 <= y <= 1)
	@defVar(m, z, Bin)
	@setObjective(m, :Min, x + y - 2z)
	@addConstraint(m, x + y >= 5.5)
	@addConstraint(m, x >= z)

	status = solve(m)
	@assert status == :Infeasible

	println("\tTesting unbounded problem")
	m = Model(solver=NEOSSolver(solver=solver, email=TESTING_EMAIL))
	@defVar(m, 0 <= x <= 1)
	@defVar(m, y >= 0)
	@defVar(m, z, Bin)
	@setObjective(m, :Min, x - y - 2z)
	@addConstraint(m, x + y >= 5.5)
	@addConstraint(m, x >= z)

	status = solve(m)
	@assert status == :Unbounded


	println("\tTesting maximisation problem")
	m = Model(solver=NEOSSolver(solver=solver, email=TESTING_EMAIL))

	@defVar(m, 0 <= x <= 0.5)
	@defVar(m, 0 <= y <= 2)
	@defVar(m, z, Bin)
	@setObjective(m, :Max, x - y + z)
	@addConstraint(m, x + y >= 2)
	@addConstraint(m, x >= z)

	status = solve(m)
	@assert status == :Optimal
	@assert getValue(x) == 0.5
	@assert getValue(y) == 1.5
	@assert getValue(z) == 0.0
	@assert getObjectiveValue(m) == -1.0
end
