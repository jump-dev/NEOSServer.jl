immutable NEOSXpressSolver <: AbstractNEOSMPSSolver
NEOSXpressSolver(s::NEOSServer=NEOSServer();
		email::String="",  gzipmodel::Bool=true,
		print_results::Bool=false, result_file::String="",
		kwargs...
	) = NEOSSolver(NEOSXpressSolver, true, true, false,
	"""
	<document>
	<client>NEOS.jl</client>
	<category>lp</category>
	<solver>FICO-Xpress</solver>
	<inputMethod>MPS</inputMethod>
	<email></email>
	<MPS></MPS>
	<algorithm></algorithm>
	<par></par>
	</document>
	""", s, email, gzipmodel, print_results, result_file, kwargs...)
end

function add_solver_xml!(::NEOSSolver{NEOSXpressSolver}, m::NEOSMathProgModel)
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

function parse_status!(::NEOSSolver{NEOSXpressSolver}, m::NEOSMathProgModel)
	if contains(m.last_results, "Optimal solution found")
		m.status = OPTIMAL
	elseif contains(m.last_results, "problem is unbounded")
		m.status = UNBOUNDED
	elseif contains(m.last_results, "infeasible")
		m.status = INFEASIBLE
	end
end

function parse_objective!(::NEOSSolver{NEOSXpressSolver}, m::NEOSMathProgModel)
	m.objVal = parse(Float64, match(r"Objective function value is\W+?(-?[\d.]+)", m.last_results).captures[1])
end

function parse_solution!(::NEOSSolver{NEOSXpressSolver}, m::NEOSMathProgModel)
	for v in matchall(r"V(\d+).+?(-?[\d.]+)", m.last_results)
		regmatch = match(r"V(\d+).+?(-?[\d.]+)", v)
		m.solution[parse(Int64, regmatch.captures[1])] = parse(Float64, regmatch.captures[2])
	end
end
