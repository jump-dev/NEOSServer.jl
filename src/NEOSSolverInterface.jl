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
	starttime = time()
	job = submitJob(m.solver.server, m.xmlmodel, m.solver.print_level)
	iterations = 0
	pollingperiod = 5.0
	offset = 0
	results_changed = true
	while true
        stat = getJobStatus(m.solver.server, job)
		if results_changed && m.solver.print_level >= 1
			(intermediate_results, new_offset) = getIntermediateResultsNonBlocking(m.solver.server, job; offset=offset)
			results_changed = new_offset != offset
			offset = new_offset
			println(intermediate_results)
		end
        # println("Waiting for results. Status: $(stat)")
        if stat == "Done"
			if time() - starttime > 28_800 # NEOS 8hr limit
				error("""You've reached the NEOS 8hr timelimit. No meaningful
				results can be returned. You should set a timelimit that is less
				than 8 hours using the solver parameters.""")
			end
            break
        else
            sleep(pollingperiod)
        end
		iterations += 1
		if mod(iterations, 10) == 0
			pollingperiod += 10.0
		end

    end
	m.last_results = getFinalResults(m.solver.server, job)
	if m.solver.print_level >= 2 || m.solver.print_results
		 println(m.last_results)
	end
	if m.solver.result_file != ""
		open(m.solver.result_file, "w") do f
			write(f, m.last_results)
		end
	end
	parseresults!(m, job)
	return status(m)
end
