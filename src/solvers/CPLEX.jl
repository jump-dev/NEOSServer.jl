immutable NEOSCPLEXSolver <: AbstractNEOSSolver end

function NEOSCPLEXSolver(s::NEOSServer=NEOSServer();
		email::ASCIIString="",  gzipmodel::Bool=true,
		print_results::Bool=false, result_file::ASCIIString="",
		kwargs...
	)
	NEOSSolver(NEOSCPLEXSolver, true, true, true, getSolverTemplate(s, :MILP, :CPLEX, :MPS), s, email, gzipmodel, print_results, result_file, kwargs...)
end

function add_solver_xml!(::NEOSSolver{NEOSCPLEXSolver}, m::NEOSMathProgModel)
	# Add solution display
	m.xmlmodel = replace(m.xmlmodel, r"<post>.*</post>"s, "<post><![CDATA[disp sol objective\ndisplay solution variables -\ndisplay solution dual -\ndisplay solution reduced -]]></post>")

	# Add user options
	param_string = ""
	for key in keys(m.solver.params)
		param_string *= "set $(key) $(m.solver.params[key])\n"
	end
	m.xmlmodel = replace(m.xmlmodel, r"<options>.*</options>"s, "<options><![CDATA[$(param_string)]]></options>")
end

# CPLEX> MIP - Integer optimal solution:  Objective = -1.6000000000e+01
# CPLEX> Incumbent solution
# Variable Name           Solution Value
# VAR1                          1.000000
# VAR4                          1.000000
# VAR5                          1.000000

function parse_status!(::NEOSSolver{NEOSCPLEXSolver}, m::NEOSMathProgModel)
	if contains(m.last_results, "optimal solution") || contains(m.last_results, "Optimal:")
		m.status = OPTIMAL
	elseif contains(m.last_results, "unbounded") || contains(m.last_results, "Unbounded")
		m.status = UNBOUNDED
	elseif contains(m.last_results, "infeasible") || contains(m.last_results, "Infeasible")
		m.status = INFEASIBLE
	end
end

function parse_objective!(::NEOSSolver{NEOSCPLEXSolver}, m::NEOSMathProgModel)
		sci = match(r"Objective\W+?=\W+?(-?[\d\.]+)e([\+\-]\d+)", m.last_results).captures
		m.objVal = parse(Float64, sci[1]) * 10. ^ parse(Int, sci[2])
end

function parse_solution!(::NEOSSolver{NEOSCPLEXSolver}, m::NEOSMathProgModel)
	try
		parsevalue_helper!(NEOSCPLEXSolver, m, m.solution, r"Solution Value(.+?)CPLEX>"s, r"V(\d+)\s+(-?[\d.]+)")
	catch
		# Check if the null solution returned
		if match(r"All variables in the range (.*?) are 0", m.last_results) == nothing
			println(m.last_results)
			error("Unable to parse the solution correctly. See the returned file above.")
		end
	end
end

function parse_duals!(::NEOSSolver{NEOSCPLEXSolver}, m::NEOSMathProgModel)
	m.duals = zeros(m.nrow)
	parsevalue_helper!(NEOSCPLEXSolver, m, m.duals, r"Dual Price(.+?)CPLEX>"s, r"C(\d+)\s+(-?[\d.]+)")

	m.reducedcosts = zeros(m.ncol)
	parsevalue_helper!(NEOSCPLEXSolver, m, m.reducedcosts, r"Reduced Cost(.+?)CPLEX>"s, r"V(\d+)\s+(-?[\d.]+)")
end

function parsevalue_helper!(::Type{NEOSCPLEXSolver}, m::NEOSMathProgModel, to_vector::Vector, reg1::Regex, reg2::Regex)
	for v in matchall(reg2, match(reg1, m.last_results).captures[1])
		regmatch = match(reg2, v)
		to_vector[parse(Int64, regmatch.captures[1])] = parse(Float64, regmatch.captures[2])
	end
end
