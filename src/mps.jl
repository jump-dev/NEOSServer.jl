struct SOS
	order::Int
	indices::Vector{Int}
	weights::Vector{Float64}
	SOS(order, indices, weights) = new(order, indices, weights)
end

mutable struct MPSModel <: NEOSModel
	solver::NEOSSolver
	xmlmodel::String
	last_results::String
	ncol::Int
	nrow::Int
	A::SparseMatrixCSC{Float64, Int}
	collb::Vector{Float64}
	colub::Vector{Float64}
	f::Vector{Float64}
	rowlb::Vector{Float64}
	rowub::Vector{Float64}
	sense::Symbol
	colcat::Vector{Symbol}
	sos::Vector{SOS}
	objVal::Float64
	reducedcosts::Vector{Float64}
	duals::Vector{Float64}
	solution::Vector{Float64}
	status::Symbol

	MPSModel(solver) = new(solver, "", "", 0, 0, sparse(Int[], Int[], Float64[]), Float64[], Float64[], Float64[], Float64[], Float64[], :Min, Symbol[], SOS[], 0.0, Float64[], Float64[], Float64[], NOTSOLVED)
end

LinearQuadraticModel{S}(s::NEOSSolver{S, :MPS}) = MPSModel(s)

function neos_writexmlmodel!(m::MPSModel)
    io = IOBuffer()
    print(io, "<MPS>")
    mps_writer_sos = [(s.order, s.indices, s.weights) for s in m.sos]
    MPSWriter.write(io, m.A, m.collb, m.colub, m.f, m.rowlb, m.rowub, m.sense, m.colcat, mps_writer_sos, Array{Float64}(0,0))
    print(io, "</MPS>")
    # Convert the model to MPS and add
    m.xmlmodel = replace(m.solver.template, r"<MPS>.*</MPS>"is, String(take!(io)))
end

function loadproblem!(m::MPSModel, A, collb, colub, f, rowlb, rowub, sense)
	# @assert length(collb) == length(colub) == length(f)
	m.ncol = length(f)
	m.nrow = length(rowlb)
	m.A = sparse(A)
	m.collb = collb
	m.colub = colub
	m.colcat = fill(:Cont, m.ncol)
	m.f = f
	m.rowlb = rowlb
	m.rowub = rowub
	m.sense = sense
end


function anyints(m::MPSModel)
	for i in m.colcat
		if i == :Int || i==:Bin
			return true
		end
	end
	return false
end

function parseresults!(m::MPSModel, job)
	m.status = SOVLERERROR
	parse_status!(m.solver, m)
	if m.status == OPTIMAL
		parse_objective!(m.solver, m)
		m.solution = zeros(m.ncol)
		parse_solution!(m.solver, m)
		if m.solver.provides_duals && length(m.sos) == 0 && !anyints(m)
			parse_duals!(m.solver, m)
		end
		if m.sense == :Max
			# Since MPS does not support Maximisation
			m.objVal = -m.objVal
		end
	end
end

function addsos1!(m::MPSModel, indices::Vector, weights::Vector)
	if !m.solver.solves_sos
		throw(NEOSSolverError("Special Ordered Sets of type I are not supported by $(typeof(m.solver)). Try a different solver instead"))
	end
	push!(m.sos, SOS(1, indices, weights))
end
function addsos2!(m::MPSModel, indices::Vector, weights::Vector)
	if !m.solver.solves_sos
		throw(NEOSSolverError("Special Ordered Sets of type II are not supported by $(typeof(m.solver)). Try a different solver instead"))
	end
	push!(m.sos, SOS(2, indices, weights))
end

function status(m::MPSModel)
	m.status
end

function getobjval(m::MPSModel)
	m.objVal
end

function getsolution(m::MPSModel)
	m.solution
end

function getreducedcosts(m::MPSModel)
	if m.solver.provides_duals
		return m.reducedcosts
	else
		warn("Reduced costs are not available from $(typeof(m.solver)). Try a different solver instead")
		return fill(NaN, m.ncol)
	end
end

function getconstrduals(m::MPSModel)
	if m.solver.provides_duals
		return 	m.duals
	else
		warn("Constraint duals are not available from $(typeof(m.solver)). Try a different solver instead")
		return fill(NaN, m.nrow)
	end
end

function getsense(m::MPSModel)
	m.sense
end

function setsense!(m::MPSModel, sense::Symbol)
	m.sense = sense
end

function setvartype!(m::MPSModel, t::Vector{Symbol})
	m.colcat = t
end
