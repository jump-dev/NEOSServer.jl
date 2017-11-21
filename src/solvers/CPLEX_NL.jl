function add_solver_xml!(::NEOSSolver{:CPLEX, :NL}, m::NEOSNonlinearModel)
	# Add user options
	param_string = ""
	for key in keys(m.solver.params)
		param_string *= "set $(key) $(m.solver.params[key])\n"
	end
	m.xmlmodel = replace(m.xmlmodel, r"<options>.*</options>"s, "<options><![CDATA[$(param_string)]]></options>")
end
