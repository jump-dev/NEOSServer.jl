defNEOSSolver(:XpressMP, email=true, sos=true, duals=false)

function add_solver_xml!(::NEOSXpressMPSolver, m::NEOSMathProgModel)
	# Add solution display
	m.xmlmodel = replace(m.xmlmodel, r"(?s)<algorithm>.*</algorithm>", "<algorithm><![CDATA[SIMPLEX]]></algorithm>")

	# Add user options
	param_string = ""
	for key in keys(m.solver.params)
		param_string *= "$(key) \= $(m.solver.params[key])\n"
	end
	# Add user options
	m.xmlmodel = replace(m.xmlmodel, r"(?s)<par>.*</par>", "<par><![CDATA[$(param_string)]]></par>")
end

# Objective function value is     4.500000
#	...
#   Number   Column   At      Value      Input Cost   Reduced Cost
# C      4  VAR1      SB      1.000000      1.000000       .000000
# C      5  VAR2      SB      4.500000      1.000000       .000000
# C      6  VAR3      SB      1.000000     -1.000000       .000000

function parse_status!(::NEOSXpressMPSolver, m::NEOSMathProgModel)
	if contains(m.last_results, "Optimal solution found")
		m.status = OPTIMAL
	elseif contains(m.last_results, "problem is unbounded")
		m.status = UNBOUNDED
	elseif contains(m.last_results, "infeasible")
		m.status = INFEASIBLE
	end
end

function parse_objective!(::NEOSXpressMPSolver, m::NEOSMathProgModel)
	m.objVal = parse(Float64, match(r"Objective function value is\W+?(-?[\d.]+)", m.last_results).captures[1])
end

function parse_solution!(::NEOSXpressMPSolver, m::NEOSMathProgModel)
	for v in matchall(r"V(\d+).+?(-?[\d.]+)", m.last_results)
		regmatch = match(r"V(\d+).+?(-?[\d.]+)", v)
		m.solution[parse(Int64, regmatch.captures[1])] = parse(Float64, regmatch.captures[2])
	end
end
