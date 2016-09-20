function build_mps(m::NEOSMathProgModel)
    # Max width (8) for names in fixed MPS format
    # TODO: replace names by alpha-numeric
    #   to enable more variables and constraints.
    #   Although to be honest no one should be using
    #   this with that many constraints/variables
    @assert length(m.f) <= 9999999
    @assert length(m.rowub) <= 9999999

    mps = "NAME          NEOSMathProgModel\n"

    rowSense, _hasranged = extract_rowSense(m)

    mps = addROWS(m, mps, rowSense)
    mps = addCOLS(m, mps)
    mps = addRHS(m, mps, rowSense)
    if _hasranged
        mps = addRANGES(m, mps, rowSense)
    end
    mps = addBOUNDS(m, mps)
    mps = addSOS(m, mps)

    mps *= "ENDATA\n"

    if m.solver.gzipmodel
        return gzip(mps)
    else
        return mps
    end
end

function addROWS(m::NEOSMathProgModel, mps::String, rowSense::Vector{Symbol})
    # Objective and constraint names
    mps *= "ROWS\n N  OBJ\n"

    for c in 1:m.nrow
        if rowSense[c] == :(<=)
            senseChar = 'L'
        elseif rowSense[c] == :(==)
            senseChar = 'E'
        elseif rowSense[c] == :(>=)
            senseChar = 'G'
        else
            senseChar = 'E'
        end
        mps *= " $senseChar  C$c\n"
    end
    mps
end

function extract_rowSense(m::NEOSMathProgModel)
    rowSense = Array(Symbol, length(m.rowub))
    _hasranged = false
    for r=1:m.nrow
    	if (m.rowlb[r] == -Inf && m.rowub[r] != Inf) || (m.rowlb[r] == typemin(eltype(m.rowlb)) && m.rowub[r] != typemax(eltype(m.rowub)))
    		rowSense[r] = :(<=) # LE constraint
    	elseif (m.rowlb[r] != -Inf && m.rowub[r] == Inf)  || (m.rowlb[r] != typemin(eltype(m.rowlb)) && m.rowub[r] == typemax(eltype(m.rowub)))
    		rowSense[r] = :(>=) # GE constraint
    	elseif m.rowlb[r] == m.rowub[r]
    		rowSense[r] = :(==) # Eq constraint
    	else
            rowSense[r] = :ranged
            _hasranged = true
    	end
    end
    rowSense, _hasranged
end

function addCOLS(m::NEOSMathProgModel, mps::String)
    A = convert(SparseMatrixCSC{Float64, Int32}, m.A)

    _intgrpOPEN = false

    mps *= "COLUMNS\n"
    for col in 1:m.ncol
    	if m.colcat != :nothing
	        t = m.colcat[col]
	        if t == :SemiCont || t == :SemiInt
                throw(NEOSSolverError("The MPS file writer does not currently support semicontinuous or semi-integer variables"))
            end
	        if (t == :Bin || t == :Int) && !_intgrpOPEN
	            mps *= "    MARKER    'MARKER'                 'INTORG'\n"
	            _intgrpOPEN = true
	        elseif (t == :Cont || t == :Fixed) && _intgrpOPEN
	            mps *= "    MARKER    'MARKER'                 'INTEND'\n"
	            _intgrpOPEN = false
	        end
	    end
    	if abs(m.f[col]) > 1e-10 # Non-zeros
    		# Flip signs for maximisation
            mps *= "    V$(rpad(col, 7))  $(rpad("OBJ", 8))  $((m.sense==:Max?-1:1)*m.f[col])\n"
	    end
        if length(A.colptr) > col
            for ind in A.colptr[col]:(A.colptr[col+1]-1)
            	if abs(A.nzval[ind]) > 1e-10 # Non-zero
    	            mps *= "    V$(rpad(col, 7))  C$(rpad(A.rowval[ind], 7))  $(A.nzval[ind])\n"
    	        end
            end
        end
    end
    if _intgrpOPEN
        mps *= "    MARKER    'MARKER'                 'INTEND'\n"
    end

    return mps
end

function addRHS(m::NEOSMathProgModel, mps::String, rowSense::Vector{Symbol})
    mps *= "RHS\n"
    for c in 1:m.nrow
        mps *= "    rhs       C$(rpad(c, 7))  $(rowSense[c] == :(<=)?m.rowub[c]:m.rowlb[c])\n"
    end
    mps
end

function addRANGES(m::NEOSMathProgModel, mps::String, rowSense::Vector{Symbol})
    mps *= "RANGES\n"
    for r=1:m.nrow
        if rowSense[r] == :ranged
            mps *= "    rhs       C$(rpad(r, 7))  $(m.rowub[r] - m.rowlb[r])\n"
        end
    end
    mps
end

function addBOUNDS(m::NEOSMathProgModel, mps::String)
    mps *= "BOUNDS\n"
    for col in 1:m.ncol
        if m.colub[col] == Inf
            if m.collb[col] == -Inf
                mps *= boundstring("FR", col)
                continue
            else
                mps *= boundstring("PL", col)
            end
        else
            mps *= boundstring("UP", col, m.colub[col])
        end
        if m.collb[col] == -Inf
            mps *= boundstring("MI", col)
        elseif m.collb[col] != 0
            mps *= boundstring("LO", col, m.collb[col])
        end
    end
    mps
end

function boundstring(ty::String, vidx::Integer)
    @assert ty in ["FR", "MI", "PL"]
    " $ty BOUNDS    V$(rpad(vidx, 7))\n"
end
function boundstring(ty::String, vidx::Integer, val)
    @assert ty in ["LO", "UP"]
    " $ty BOUNDS    V$(rpad(vidx, 7))  $(val)\n"
end

function addSOS(m::NEOSMathProgModel, mps::String)
    for (n_sos, sos) in enumerate(m.sos)
        mps *= "SOS\n S$(sos.order) SOS$(n_sos)\n"
        for (i, v) in enumerate(sos.indices)
            mps *= "    V$(rpad(v, 7))  $(sos.weights[i])\n"
        end
    end
    mps
end

function gzip(s::String)
    return "<base64>"*String(encode(Base64, read(s.data |> ZlibDeflateInputStream)))*"</base64>"
end
