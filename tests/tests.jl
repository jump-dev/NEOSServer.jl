using JuMP
using NEOS

#
# As part of the NEOS terms of use, some solvers
# 	require a valid email to be supplied.
#
TESTING_EMAIL = "odow003@aucklanduni.ac.nz"

println("Testing solver SYMPHONY")
m = Model(solver=NEOSSolver(solver=:SYMPHONY))
setSolveHook(m, NEOSSolve)

@defVar(m, 0 <= x <= 1)
@defVar(m, 0 <= y <= 5)
@defVar(m, z, Bin)
@setObjective(m, :Min, x + y - z)
@addConstraint(m, x + y >= 5.5)
@addConstraint(m, x >= z)

solve(m)

@assert m.objVal == 4.5
@assert getValue(x) == 1.0
@assert getValue(y) == 4.5
@assert getValue(z) == 1.0

# =======================================
println("Testing solver CPLEX")
# Note this requires a valid email
m = Model(solver=NEOSSolver(solver=:CPLEX, email=TESTING_EMAIL))

@defVar(m, 0 <= x <= 1)
@defVar(m, 0 <= y <= 5)
@defVar(m, z, Bin)
@setObjective(m, :Min, x + y - z)
@addConstraint(m, x + y >= 5.5)
@addConstraint(m, x >= z)

NEOSSolve(m)

@assert m.objVal == 4.5
@assert getValue(x) == 1.0
@assert getValue(y) == 4.5
@assert getValue(z) == 1.0

# =======================================
println("Testing solver XpressMP")
# Note this requires a valid email
m = Model(solver=NEOSSolver(solver=:XpressMP, email=TESTING_EMAIL))

@defVar(m, 0 <= x <= 1)
@defVar(m, 0 <= y <= 5)
@defVar(m, z, Bin)
@setObjective(m, :Min, x + y - z)
@addConstraint(m, x + y >= 5.5)
@addConstraint(m, x >= z)

NEOSSolve(m)

@assert m.objVal == 4.5
@assert getValue(x) == 1.0
@assert getValue(y) == 4.5
@assert getValue(z) == 1.0