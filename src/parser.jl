function parse_values!(m::JuMP.Model, results::String)
	status = :UNKNOWN

	if m.solver.solver == :SYMPHONY
		# Solution Cost: 2.0000000000
		# +++++++++++++++++++++++++++++++++++++++++++++++++++
		# Column names and values of nonzeros in the solution
		# +++++++++++++++++++++++++++++++++++++++++++++++++++
		#     VAR1 2.0000000000
		#     VAR2 1.5000000000
		obj_reg = r"Solution Cost: (-?[\d.]+)"
		var_reg = r"VAR(\d+)\W+(-?[\d.]+)"
		if contains(results, "Optimal Solution Found") || contains(results, "Preprocessing found the optimum")
			status = :Optimal
		elseif contains(results, "detected unbounded problem")
			status = :Unbounded
		elseif contains(results, "detected infeasibility")
			status = :Infeasible
		end
	elseif m.solver.solver == :CPLEX
		# CPLEX> MIP - Integer optimal solution:  Objective =  4.5000000000e+00
		# CPLEX> Incumbent solution
		# Variable Name           Solution Value
		# VAR1                          1.000000
		# VAR2                          4.500000
		# VAR3                          1.000000
		# CPLEX> 
		obj_reg = r"Objective =  (-?[\d.]+)e\+(\d+)"
		var_reg = r"VAR(\d+)\W+(-?[\d.]+)"
		if contains(results, "optimal solution")
			status = :Optimal
		elseif contains(results, "unbounded")
			status = :Unbounded
		elseif contains(results, "infeasible")
			status = :Infeasible
		end
	elseif m.solver.solver == :XpressMP
		# Objective function value is     4.500000
		#	...
		#   Number   Column   At      Value      Input Cost   Reduced Cost
		# C      4  VAR1      SB      1.000000      1.000000       .000000
		# C      5  VAR2      SB      4.500000      1.000000       .000000
		# C      6  VAR3      SB      1.000000     -1.000000       .000000
		obj_reg = r"Objective function value is\W+(-?[\d.]+)"
		var_reg = r"VAR(\d+).+?(-?[\d.]+)"
		if contains(results, "Optimal solution found")
			status = :Optimal
		elseif contains(results, "Problem is unbounded")
			status = :Unbounded
		elseif contains(results, "infeasible")
			status = :Infeasible
		end
	end

	if status == :Optimal
		if m.solver.solver == :CPLEX
			# Displays objective in scientific notation
			sci = match(obj_reg, results).captures
			m.objVal = parsefloat(sci[1]) * 10 ^ parseint(sci[2])

		else
			m.objVal = parsefloat(match(obj_reg, results).captures[1])
		end
		if getObjectiveSense(m) == :Max
			# Since MPS does not support Maximisation
			m.objVal = -getObjectiveValue(m)
		end
		for v in matchall(var_reg, results)
			regmatch = match(var_reg, v)
			m.colVal[parseint(regmatch.captures[1])] = parsefloat(regmatch.captures[2])
		end

		# Set zero elements
		for (i, v) in enumerate(m.colVal)
			if isnan(v)
				m.colVal[i] = 0.
			end
		end
	end
	return status
end
