# __precompile__()

module MPSWriter

# export writemps, SOS

immutable SOS
    order::Int
    indices::Vector{Int}
    weights::Vector
end

function getrowsense{T1 <: Real, T2<: Real}(rowlb::Vector{T1}, rowub::Vector{T2})
    @assert length(rowlb) == length(rowub)
    row_sense = Array{Symbol}(length(rowub))
    hasranged = false
    for r=1:length(rowlb)
        @assert rowlb[r] <= rowub[r]
    	if (rowlb[r] == -Inf && rowub[r] != Inf) || (rowlb[r] == typemin(eltype(rowlb)) && rowub[r] != typemax(eltype(rowub)))
    		row_sense[r] = :(<=) # LE constraint
    	elseif (rowlb[r] != -Inf && rowub[r] == Inf)  || (rowlb[r] != typemin(eltype(rowlb)) && rowub[r] == typemax(eltype(rowub)))
    		row_sense[r] = :(>=) # GE constraint
    	elseif rowlb[r] == rowub[r]
    		row_sense[r] = :(==) # Eq constraint
        elseif (rowlb[r] == -Inf && rowub[r] == Inf)
            error("Cannot have a constraint with no bounds")
    	else
            row_sense[r] = :ranged
            hasranged = true
    	end
    end
    row_sense, hasranged
end

function writerows!(io::IO, row_sense::Vector{Symbol})
    # Objective and constraint names
    println(io, "ROWS\n N  OBJ")
    sensechar = ' '
    for i in 1:length(row_sense)
        if row_sense[i] == :(<=)
            sensechar = 'L'
        elseif row_sense[i] == :(==)
            sensechar = 'E'
        elseif row_sense[i] == :(>=)
            sensechar = 'G'
        elseif row_sense[i] == :ranged
            sensechar = 'E'
        else
            error("Unknown row sense $(row_sense[i])")
        end
        println(io, " $sensechar  C$i")
    end
end

const SUPPORTEDVARIABLETYPES = [:Bin, :Int, :Cont, :Fixed]

function writecolumns!(io::IO, A::AbstractMatrix, colcat, c::Vector, sense::Symbol)
    @assert sense == :Min || sense == :Max
    @assert length(colcat) == length(c) == size(A)[2]

    integer_group = false

    println(io, "COLUMNS")

    for col in 1:length(c)
        colty = colcat[col]
        if !(colty in SUPPORTEDVARIABLETYPES)
            error("The MPS file writer does not currently support variables of the type $colty")
        end
        if (colty == :Bin || colty == :Int) && !integer_group
            println(io, "    MARKER    'MARKER'                 'INTORG'")
            integer_group = true
        elseif (colty == :Cont || colty == :Fixed) && integer_group
            println(io, "    MARKER    'MARKER'                 'INTEND'")
            integer_group = false
        end
        inconstraint = writecolumn!(io, A, col)
    	if abs(c[col]) > 1e-10 || !inconstraint # Non-zeros
    		# Flip signs for maximisation
            _println(io, "    V$(rpad(col, 7))  $(rpad("OBJ", 8))  ", (sense==:Max?-1:1)*c[col])
	    end
    end
    if integer_group
        println(io, "    MARKER    'MARKER'                 'INTEND'")
    end
end

function _println(io::IO, s::String, x::Number)
    print(io, s)
    print_shortest(io, x)
    println(io)
end

function writecolumn!{T, Ti}(io::IO, A::AbstractSparseArray{T, Ti, 2}, col::Int)
    inconstraint = false
    rows, vals = rowvals(A), nonzeros(A)
    for j in nzrange(A, col)
        _println(io, "    V$(rpad(col, 7))  C$(rpad(rows[j], 7))  ", vals[j])
        inconstraint = true
    end
    inconstraint
end

function writecolumn!{T}(io::IO, A::Array{T, 2}, col::Int)
    inconstraint = false
    for row in 1:size(A)[1]
        if abs(A[row, col]) > 1e-10 # Non-zero
            _println(io, "    V$(rpad(col, 7))  C$(rpad(row, 7))  ", A[row, col])
            inconstraint = true
        end
    end
    inconstraint
end

function writerhs!(io::IO, rowlb, rowub, row_sense::Vector{Symbol})
    @assert length(rowlb) == length(rowub) == length(row_sense)
    println(io, "RHS")
    for c in 1:length(rowlb)
        _println(io, "    rhs       C$(rpad(c, 7))  ", row_sense[c] == :(<=)?rowub[c]:rowlb[c])
    end
end

function writeranges!(io::IO, rowlb, rowub, row_sense::Vector{Symbol})
    @assert length(rowlb) == length(rowub) == length(row_sense)
    println(io, "RANGES")
    for r=1:length(row_sense)
        if row_sense[r] == :ranged
            _println(io, "    rhs       C$(rpad(r, 7))  ", rowub[r] - rowlb[r])
        end
    end
end

function writebounds!(io::IO, collb, colub)
    @assert length(collb) == length(colub)
    println(io, "BOUNDS")
    for col in 1:length(collb)
        if colub[col] == Inf
            if collb[col] == -Inf
                writebound!(io, "FR", col)
                continue
            else
                writebound!(io, "PL", col)
            end
        else
            writebound!(io, "UP", col, colub[col])
        end
        if collb[col] == -Inf
            writebound!(io, "MI", col)
        elseif collb[col] != 0
            writebound!(io, "LO", col, collb[col])
        end
    end
end

function writebound!(io::IO, ty::String, vidx::Int)
    @assert ty in ["FR", "MI", "PL"]
    println(io, " $ty BOUNDS    V$vidx")
end

function writebound!(io::IO, ty::String, vidx::Int, val::Real)
    @assert ty in ["LO", "UP"]
    _println(io, " $ty BOUNDS    V$(rpad(vidx, 7))  ", val)
end

function writesos!(io::IO, sos::Vector{SOS}, maxvarindex::Int)
    println(io, "SOS")
    for i=1:length(sos)
        @assert length(sos[i].indices) == length(sos[i].weights)
        println(io, " S$(sos[i].order) SOS$i")
        for j=1:length(sos[i].indices)
            @assert sos[i].indices[j] > 0 && sos[i].indices[j] <= maxvarindex
            _println(io, "    V$(rpad(sos[i].indices[j], 7))  ", sos[i].weights[j])
        end
    end
end

function writequad!{T, Ti}(io::IO, Q::AbstractSparseArray{T, Ti, 2}, sense::Symbol)
    @assert sense == :Min || sense == :Max
    println(io, "QMATRIX")
    rows = rowvals(Q)
    vals = nonzeros(Q)
    if sense == :Max
        vals *= -1
    end
    for i = 1:size(Q)[2]
        for j in nzrange(Q, i)
            _println(io, "    V$(rpad(rows[j],7)) V$(rpad(i,7))  ", vals[j])
        end
    end
end

function writequad!(io::IO, Q::AbstractMatrix, sense::Symbol)
    @assert sense == :Min || sense == :Max
    sgn = (sense == :Max?-1:1)
    println(io, "QMATRIX")
    for i = 1:size(Q)[2]
        for j in 1:size(Q)[1]
            if abs(Q[j, i]) > 1e-10
                _println(io, "    V$(rpad(j,7)) V$(rpad(i,7))  ", sgn*Q[j, i])
            end
        end
    end
end

function writemps(io::IO,
    A::AbstractMatrix,       # the constraint matrix
    collb::Vector,  # vector of variable lower bounds
    colub::Vector,  # vector of variable upper bounds
    c::Vector,      # vector containing variable objective coefficients
    rowlb::Vector,  # constraint lower bounds
    rowub::Vector,  # constraint upper bounds
    sense::Symbol,           # model sense
    colcat::Vector{Symbol},  # constraint types
    sos::Vector{SOS},        # SOS information
    Q::AbstractMatrix,      #  Quadratic objectives 0.5 * x' Q x
    modelname::AbstractString="MPSWriter_jl"  # MPS model name
)
    # Max width (8) for names in fixed MPS format
    # TODO: replace names by alpha-numeric
    #   to enable more variables and constraints.
    #   Although to be honest no one should be using
    #   this with that many constraints/variables
    @assert length(c) <= 9999999
    @assert length(rowub) <= 9999999

    # Sanity checks
    @assert length(rowlb) == length(rowub)
    @assert length(collb) == length(colub) == length(c) == length(colcat)
    @assert sense == :Min || sense == :Max

    println(io, "NAME          $modelname")
    row_sense, hasranged = getrowsense(rowlb, rowub)
    writerows!(io, row_sense)
    writecolumns!(io, A, colcat, c, sense)
    writerhs!(io, rowlb, rowub, row_sense)
    if hasranged
        writeranges!(io, rowlb, rowub, row_sense)
    end
    writebounds!(io, collb, colub)
    if length(sos) > 0
        writesos!(io, sos, length(collb))
    end
    if length(Q) > 0
        writequad!(io, Q, sense)
    end
    println(io, "ENDATA")
end

end # module
