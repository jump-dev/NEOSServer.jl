# __precompile__()

module MPSWriter

# order, indices, weights
const SOS = Tuple{Int, Vector{Int}, Vector{Float64}}

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

function writerows!(io::IO, row_sense::Vector{Symbol}, rownames::Vector{String})
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
        println(io, " $sensechar  $(rownames[i])")
    end
end

const SUPPORTEDVARIABLETYPES = [:Bin, :Int, :Cont, :Fixed]

function writecolumns!(io::IO, A::AbstractMatrix, colcat, c::Vector, sense::Symbol, colnames::Vector{String}, rownames::Vector{String})
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
        inconstraint = writecolumn!(io, A, col, colnames, rownames)
    	if abs(c[col]) > 1e-10 || !inconstraint # Non-zeros
    		# Flip signs for maximisation
            _println(io, "    $(rpad(colnames[col], 8))  $(rpad("OBJ", 8))  ", (sense==:Max?-1:1)*c[col])
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

function writecolumn!{T, Ti}(io::IO, A::AbstractSparseArray{T, Ti, 2}, col::Int, colnames::Vector{String}, rownames::Vector{String})
    inconstraint = false
    rows, vals = rowvals(A), nonzeros(A)
    for j in nzrange(A, col)
        _println(io, "    $(rpad(colnames[col], 8))  $(rpad(rownames[rows[j]], 8))  ", vals[j])
        inconstraint = true
    end
    inconstraint
end

function writecolumn!{T}(io::IO, A::Array{T, 2}, col::Int, colnames::Vector{String}, rownames::Vector{String})
    inconstraint = false
    for row in 1:size(A)[1]
        if abs(A[row, col]) > 1e-10 # Non-zero
            _println(io, "    $(rpad(colnames[col], 8))  $(rpad(rownames[row], 8))  ", A[row, col])
            inconstraint = true
        end
    end
    inconstraint
end

function writerhs!(io::IO, rowlb, rowub, row_sense::Vector{Symbol}, rownames::Vector{String})
    @assert length(rowlb) == length(rowub) == length(row_sense)
    println(io, "RHS")
    for row in 1:length(rowlb)
        _println(io, "    rhs       $(rpad(rownames[row], 8))  ", row_sense[row] == :(<=)?rowub[row]:rowlb[row])
    end
end

function writeranges!(io::IO, rowlb, rowub, row_sense::Vector{Symbol}, rownames::Vector{String})
    @assert length(rowlb) == length(rowub) == length(row_sense)
    println(io, "RANGES")
    for row=1:length(row_sense)
        if row_sense[row] == :ranged
            _println(io, "    rhs       $(rpad(rownames[row], 8))  ", rowub[row] - rowlb[row])
        end
    end
end

function writebounds!(io::IO, collb, colub, colnames::Vector{String})
    @assert length(collb) == length(colub)
    println(io, "BOUNDS")
    for col in 1:length(collb)
        if colub[col] == Inf
            if collb[col] == -Inf
                writebound!(io, "FR", col, colnames[col])
                continue
            else
                writebound!(io, "PL", col, colnames[col])
            end
        else
            writebound!(io, "UP", col, colub[col], colnames[col])
        end
        if collb[col] == -Inf
            writebound!(io, "MI", col, colnames[col])
        elseif collb[col] != 0
            writebound!(io, "LO", col, collb[col], colnames[col])
        end
    end
end

function writebound!(io::IO, ty::String, vidx::Int, colname::String)
    @assert ty in ["FR", "MI", "PL"]
    println(io, " $ty BOUNDS    $colname")
end

function writebound!(io::IO, ty::String, vidx::Int, val::Real, colname::String)
    @assert ty in ["LO", "UP"]
    _println(io, " $ty BOUNDS    $(rpad(colname, 8))  ", val)
end

function writesos!(io::IO, sos::Vector{SOS}, maxvarindex::Int, colnames::Vector{String})
    println(io, "SOS")
    for i=1:length(sos)
        order   = sos[i][1]
        indices = sos[i][2]
        weights = sos[i][3]
        @assert length(indices) == length(weights)
        println(io, " S$(order) SOS$i")
        for (idx, weight) in zip(indices, weights)
            @assert idx > 0 && idx <= maxvarindex
            _println(io, "    $(rpad(colnames[idx], 8))  ", weight)
        end
    end
end

function writequad!{T, Ti}(io::IO, Q::AbstractSparseArray{T, Ti, 2}, sense::Symbol, colnames::Vector{String})
    @assert sense == :Min || sense == :Max
    println(io, "QMATRIX")
    rows = rowvals(Q)
    vals = nonzeros(Q)
    if sense == :Max
        vals *= -1
    end
    for i = 1:size(Q)[2]
        for j in nzrange(Q, i)
            _println(io, "    $(rpad(colnames[rows[j]],8)) $(rpad(colnames[i],8))  ", vals[j])
        end
    end
end

function writequad!(io::IO, Q::AbstractMatrix, sense::Symbol, colnames::Vector{String})
    @assert sense == :Min || sense == :Max
    sgn = (sense == :Max?-1:1)
    println(io, "QMATRIX")
    for i = 1:size(Q)[2]
        for j in 1:size(Q)[1]
            if abs(Q[j, i]) > 1e-10
                _println(io, "    $(rpad(colnames[j],8)) $(rpad(colnames[i],8))  ", sgn*Q[j, i])
            end
        end
    end
end

function write(io::IO,
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
    modelname::AbstractString ="MPSWriter_jl",  # MPS model name
    colnames::Vector{String}  = ["V$i" for i in 1:length(c)],
    rownames::Vector{String}  = ["C$i" for i in 1:length(rowub)]
)
    # Max width (8) for names in fixed MPS format
    # TODO: replace names by alpha-numeric
    #   to enable more variables and constraints.
    #   Although to be honest no one should be using
    #   this with that many constraints/variables
    # @assert length(c) <= 9999999
    # @assert length(rowub) <= 9999999

    # Sanity checks
    @assert length(rowlb) == length(rowub)
    @assert length(collb) == length(colub) == length(c) == length(colcat)
    @assert sense == :Min || sense == :Max
    @assert size(Q) == (0,0) || size(Q) == (length(collb), length(collb))

    println(io, "NAME          $modelname")
    row_sense, hasranged = getrowsense(rowlb, rowub)
    writerows!(io, row_sense, rownames)
    writecolumns!(io, A, colcat, c, sense, colnames, rownames)
    writerhs!(io, rowlb, rowub, row_sense, rownames)
    if hasranged
        writeranges!(io, rowlb, rowub, row_sense, rownames)
    end
    writebounds!(io, collb, colub, colnames)
    if length(sos) > 0
        writesos!(io, sos, length(collb), colnames)
    end
    if length(Q) > 0
        writequad!(io, Q, sense, colnames)
    end
    println(io, "ENDATA")
end

end # module
