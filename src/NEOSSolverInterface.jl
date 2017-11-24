const NOTSOLVED = :NotSolved
const SOVLERERROR = :SolverError
const OPTIMAL = :Optimal
const UNBOUNDED = :Unbounded
const INFEASIBLE = :Infeasible
const UNBNDORINF = :UnboundedOrInfeasible

type NEOSSolverError <: Exception
	msg::String
end

abstract type NEOSModel <: AbstractMathProgModel end

addemail!(m::NEOSModel, email::String) = addemail!(m.solver, email)

function optimize!(m::NEOSModel)
	neos_writexmlmodel!(m)
	add_solver_xml!(m.solver, m)
	if m.solver.requires_email && m.solver.server.email==""
		throw(NEOSSolverError("$(typeof(m.solver)) requires that NEOS users supply a valid email"))
	end
	if m.solver.server.email != ""
		if match(r"<email>.*</email>", m.xmlmodel) == nothing
			m.xmlmodel = replace(m.xmlmodel, r"<document>", "<document>\n<email>$(m.solver.server.email)</email>")
		else
			m.xmlmodel = replace(m.xmlmodel, r"<email>.*</email>", "<email>$(m.solver.server.email)</email>")
		end
	end
	# println(m.xmlmodel)
	job = submitJob(m.solver.server, m.xmlmodel)
	while true
        info = getJobInfo(m.solver.server, job)
        println("Waiting for results. Status: $(info[4])")
        if info[4] == "Done"
            break
        else
            sleep(3.0)
        end
    end
	m.last_results = getFinalResults(m.solver.server, job)
	m.solver.print_results && println(m.last_results)
	if m.solver.result_file != ""
		open(m.solver.result_file, "w") do f
			write(f, m.last_results)
		end
	end
	parseresults!(m, job)
	return status(m)
end
