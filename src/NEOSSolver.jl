function deprecatesolver(solver)
	error("""
	NEOS$(solver)Solver(server; kwargs...) has been removed from NEOS.jl

	You should use
		NEOSSolver(server; solver=:$(solver), kwargs...)
	instead. See the README for more details.
	""")
end
NEOSCPLEXSolver(server; kwargs...)    = deprecatesolver("CPLEX")
NEOSMOSEKSolver(server; kwargs...)    = deprecatesolver("MOSEK")
NEOSXpressSolver(server; kwargs...)   = deprecatesolver("Xpress")
NEOSSYMPHONYSolver(server; kwargs...) = deprecatesolver("SYMPHONY")

# NEOSSolver{:Solver, :Format}
mutable struct NEOSSolver{S,F} <: AbstractMathProgSolver
	server::NEOSServer
	requires_email::Bool
	solves_sos::Bool
	provides_duals::Bool
	template::String
	params::Dict{String,Any}
	gzipmodel::Bool
	print_results::Bool
	result_file::String
end

function NEOSSolver(server::NEOSServer=NEOSServer();
		solver::Symbol=:CPLEX, format=:MPS,
		email::String="",  gzipmodel::Bool=true,
		print_results::Bool=false, result_file::String="",
		kwargs...
	)
	if !haskey(TEMPLATES, (solver, format))
		error("Solver $(solver) with format $(format) not supported.")
	end

	if email != ""
		addemail!(server, email)
	end
	params=Dict{String,Any}()
	for (key, value) in kwargs
		params[string(key)] = value
	end
	(template, requires_email, solves_sos, provides_duals) = TEMPLATES[(solver, format)]
	return NEOSSolver{solver, format}(server, requires_email, solves_sos,
		provides_duals, template, params, gzipmodel, print_results, result_file)
end

function addparameter!(s::NEOSSolver, param::String, value)
	s.params[param] = value
end
addparameter!(s::NEOSSolver, param::Symbol, value) = addparameter!(s, string(param), value)

addemail!(s::NEOSSolver, email::String) = addemail!(s.server, email)


# TEMPLATE[(solver, format)] = (template, requireemail, solvesos, provideduals)
const TEMPLATES = Dict{Tuple{Symbol, Symbol}, Tuple{String, Bool, Bool, Bool}}(
    (:CPLEX, :MPS) => ("""
        <document>
        <client>NEOS.jl</client>
        <category>milp</category>
        <solver>CPLEX</solver>
        <inputMethod>MPS</inputMethod>
        <email></email>
        <MPS></MPS>
        <options></options>
        <post></post>
        </document>
        """, true, true, true),
    (:Xpress, :MPS) => ("""
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
    	""", true, true, false),
    (:MOSEK, :MPS) => ("""
    	<document>
    	<client>NEOS.jl</client>
    	<category>milp</category>
    	<solver>MOSEK</solver>
    	<inputMethod>MPS</inputMethod>
    	<email></email>
    	<MPS></MPS>
    	<param></param>
    	<wantsol><![CDATA[yes]]></wantsol>
    	<wantint><![CDATA[yes]]></wantint>
    	</document>
    	""", false, false, true),
    (:SYMPHONY, :MPS) => ("""
    	<document>
    	<client>NEOS.jl</client>
    	<category>milp</category>
    	<solver>SYMPHONY</solver>
    	<inputMethod>MPS</inputMethod>
    	<email></email>
    	<MPS></MPS>
    	<options></options>
    	</document>
    	""", false, false, false),
    (:CPLEX, :NL) => ("""
    	<document>
    	<client>NEOS.jl</client>
    	<category>milp</category>
    	<solver>CPLEX</solver>
    	<inputMethod>NL</inputMethod>
    	<email></email>
    	<model></model>
    	<options></options>
    	</document>
    	""", true, false, false)
)
