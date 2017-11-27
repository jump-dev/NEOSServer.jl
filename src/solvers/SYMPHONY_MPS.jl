function add_solver_xml!(::NEOSSolver{:SYMPHONY, :MPS}, m::MPSModel)
	# Add user options
	param_string = ""
	for key in keys(m.solver.params)
		param_string *= "$(key) $(m.solver.params[key])\n"
	end
	m.xmlmodel = replace(m.xmlmodel, r"<options>.*</options>"s, "<options><![CDATA[$(param_string)]]></options>")
end

# Solution Cost: 2.0000000000
# +++++++++++++++++++++++++++++++++++++++++++++++++++
# Column names and values of nonzeros in the solution
# +++++++++++++++++++++++++++++++++++++++++++++++++++
#     VAR1 2.0000000000
#     VAR2 1.5000000000

function parse_status!(::NEOSSolver{:SYMPHONY, :MPS}, m::MPSModel)
	if contains(m.last_results, "Optimal Solution Found") || contains(m.last_results, "Preprocessing found the optimum")
		m.status = OPTIMAL
	elseif contains(m.last_results, "detected unbounded problem") || contains(m.last_results, "Problem Found Unbounded")
		m.status = UNBOUNDED
	elseif contains(m.last_results, "detected infeasibility") || contains(m.last_results, "Problem Infeasible")
		m.status = INFEASIBLE
	end
end

function parse_objective!(::NEOSSolver{:SYMPHONY, :MPS}, m::MPSModel)
	m.objVal = parse(Float64, match(r"Solution Cost:\W+?(-?[\d.]+)", m.last_results).captures[1])
end

function parse_solution!(::NEOSSolver{:SYMPHONY, :MPS}, m::MPSModel)
	for v in matchall(r"V(\d+)\W+(-?[\d.]+)", m.last_results)
		regmatch = match(r"V(\d+)\W+(-?[\d.]+)", v)
		m.solution[parse(Int64, regmatch.captures[1])] = parse(Float64, regmatch.captures[2])
	end
end
