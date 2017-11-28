function add_solver_xml!(::NEOSSolver{:MOSEK, :MPS}, m::MPSModel)
	# Add solution display
	if !anyints(m)
		m.xmlmodel = replace(m.xmlmodel, r"(?s)<wantint><![CDATA[yes]]></wantint>", "<wantint><![CDATA[no]]></wantint>")
		# Lets hack this here. Maybe if we get fancy and offer other categories we should break this out a bit more
		m.xmlmodel = replace(m.xmlmodel, r"(?s)<category>milp</category>", "<category>lp</category>")
	end
	# Add user options
	param_string = ""
	for key in keys(m.solver.params)
		param_string *= "$(key) $(m.solver.params[key])\n"
	end
	# Add user options
	m.xmlmodel = replace(m.xmlmodel, r"(?s)<param>.*</param>", "<param><![CDATA[$(param_string)]]></param>")
end

function solution_status(m, args...)
	for s in args
		if match(Regex("SOLUTION STATUS\\W+?:\\W+?$s"), m.last_results) != nothing
			return true
		end
	end
	return false
end

function parse_status!(::NEOSSolver{:MOSEK, :MPS}, m::MPSModel)
	if solution_status(m, "INTEGER_OPTIMAL", "OPTIMAL")
		m.status = OPTIMAL
	elseif solution_status(m, "PRIMAL_UNBOUNDED", "UNBOUNDED")
		m.status = UNBOUNDED
	elseif solution_status(m, "DUAL_INFEASIBLE")
		m.status = UNBNDORINF
	elseif solution_status(m, "DUAL_UNBOUNDED", "PRIMAL_INFEASIBLE", "INFEASIBLE")
		m.status = INFEASIBLE
	end
end

function parse_objective!(::NEOSSolver{:MOSEK, :MPS}, m::MPSModel)
	sci = match(r"PRIMAL\W+?OBJECTIVE\W+?:\W+?(-?[\d\.]+e[\+\-]\d+)", m.last_results).captures
	m.objVal = parse(Float64, sci[1])
end

function parse_solution!(::NEOSSolver{:MOSEK, :MPS}, m::MPSModel)
	for v in matchall(r"V(\d+).+?(-?[\d\.]+e[\+\-]\d+)", m.last_results)
		regmatch = match(r"V(\d+).+?(-?[\d\.]+e[\+\-]\d+)", v)
		m.solution[parse(Int, regmatch.captures[1])] = parse(Float64, regmatch.captures[2])
	end
end

function parse_duals!(::NEOSSolver{:MOSEK, :MPS}, m::MPSModel)
	m.duals = zeros(m.nrow)
	for v in matchall(r"\d+\W+C(\d+).+?\n", m.last_results)
		s = split(v)
		d_lb = parse(Float64, s[7])
		d_ub = -parse(Float64, s[8])
		m.duals[parse(Int, s[2][2:end])] = abs(d_lb) > abs(d_ub)?d_lb:d_ub
	end

	m.reducedcosts = zeros(m.ncol)
	for v in matchall(r"\d+\W+V(\d+).+?\n", m.last_results)
		s = split(v)
		d_lb = parse(Float64, s[7])
		d_ub = -parse(Float64, s[8])
		m.reducedcosts[parse(Int, s[2][2:end])] = abs(d_lb) > abs(d_ub)?d_lb:d_ub
	end

end
