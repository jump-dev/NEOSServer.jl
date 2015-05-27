function build_mps(m::NEOSMathProgModel)
    mps = "NAME   MathProgModel\n"

    rowSense, _hasrange = extract_rowSense(m)

    mps = addROWS(m, mps, rowSense)
    mps = addCOLS(m, mps)
    mps = addRHS(m, mps, rowSense)

    if _hasrange
        mps = addRANGES(m, mps)
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

function addROWS(m::NEOSMathProgModel, mps::ASCIIString, rowSense::Vector{Symbol})
    # Objective and constraint names
    mps *= "ROWS\n"
    mps *= " N  OBJ\n"
    for c in 1:length(m.rowub)
        if rowSense[c] == :(<=)
            senseChar = 'L'
        elseif rowSense[c] == :(==)
            senseChar = 'E'
        elseif rowSense[c] == :(>=)
            senseChar = 'G'
        else
            senseChar = 'E'
        end
        mps *= " $senseChar  CON$c\n"
    end
    mps
end

function extract_rowSense(m::NEOSMathProgModel)
    rowSense = Array(Symbol, length(m.rowub))
    _has_range = false
    for r=1:length(m.rowub)
    	if (m.rowlb[r] == -Inf && m.rowub[r] != Inf) || (m.rowlb[r] == typemin(eltype(m.rowlb)) && m.rowub[r] != typemax(eltype(m.rowub)))
    		# LE constraint
    		rowSense[r] = :(<=)
    	elseif (m.rowlb[r] != -Inf && m.rowub[r] == Inf)  || (m.rowlb[r] != typemin(eltype(m.rowlb)) && m.rowub[r] == typemax(eltype(m.rowub)))
    		# GE constraint
    		rowSense[r] = :(>=)
    	elseif m.rowlb[r] == m.rowub[r]
    		# Eq constraint
    		rowSense[r] = :(==)
    	else
    		rowSense[r] = :ranged
            _has_range = true
    	end
    end
    rowSense, _has_range
end


function addCOLS(m::NEOSMathProgModel, mps::ASCIIString)
    A = convert(SparseMatrixCSC{Float64, Int32}, m.A)
    colptr = A.colptr
    rowval = A.rowval
    nzval = A.nzval
    inintegergroup = false
    mps *= "COLUMNS\n"
    for col in 1:length(m.f)
    	if m.colcat != :nothing
	        t = m.colcat[col]
	        if t == :SemiCont || t == :SemiInt
                error("The MPS file writer does not currently support semicontinuous or semi-integer variables")
            end
	        if (t == :Bin || t == :Int) && !inintegergroup
	            mps *= "    MARKER    'MARKER'                 'INTORG'\n"
	            inintegergroup = true
	        elseif (t == :Cont || t == :Fixed) && inintegergroup
	            mps *= "    MARKER    'MARKER'                 'INTEND'\n"
	            inintegergroup = false
	        end
	    end
    	if abs(m.f[col]) > 1e-10
    		if m.sense == :Max
	            mps *= "    VAR$(col)  OBJ  $(-m.f[col])\n"
	        else
	        	mps *= "    VAR$(col)  OBJ  $(m.f[col])\n"
	        end
	    end
        for ind in colptr[col]:(colptr[col+1]-1)
        	if abs(nzval[ind]) > 1e-10
	            mps *= "    VAR$(col)  CON$(rowval[ind])  $(nzval[ind])\n"
	        end
        end
    end
    if inintegergroup
        mps *= "    MARKER    'MARKER'                 'INTEND'\n"
    end
    mps
end

function addRHS(m::NEOSMathProgModel, mps::ASCIIString, rowSense::Vector{Symbol})
    mps *= "RHS\n"
    for c in 1:length(m.rowub)
        mps *= "    rhs    CON$c    "
        if rowSense[c] == :(<=)
            mps *= "$(m.rowub[c])"
        else
            mps *= "$(m.rowlb[c])"
        end
        mps *= "\n"
    end
    mps
end

function addRANGES(m::NEOSMathProgModel, mps::ASCIIString)
    mps *= "RANGES\n"
    for c in 1:length(m.rowub)
        if rowSense[c] == :range
            mps *= "    rhs    CON$c    $(m.rowub - m.rowlb)\n"
        end
    end
    mps
end

function addBOUNDS(m::NEOSMathProgModel, mps::ASCIIString)
    mps *= "BOUNDS\n"
    for col in 1:length(m.f)
        if m.collb[col] == 0
            # Default lowerbound
            if m.colub[col] != Inf
                # Non-default upper bound
                mps *= " UP BOUND VAR$col  $(m.colub[col])\n"
            end
        elseif m.collb[col] == -Inf && m.colub[col] == +Inf
            # Free
            mps *= " FR BOUND VAR$col\n"
        elseif m.collb[col] != -Inf && m.colub[col] == +Inf
            # No upper, but a lower
            if isa(m.solver, NEOSSYMPHONYSolver)
                # Bug in SYMPHONY v4.5.7, Fixed in SYMPHONY v5.5.7
                mps *= " UP BOUND VAR$(col) 9999999.\n LO BOUND VAR$(col) $(m.collb[col])\n"
            else
                mps *= " PL BOUND VAR$(col)\n LO BOUND VAR$(col) $(m.collb[col])\n"
            end
        elseif m.collb[col] == -Inf && m.colub[col] != +Inf
            # No lower, but a upper
            mps *= " MI BOUND VAR$(col)\n UP BOUND VAR$(col) $(m.colub[col])\n"
        else
            # Lower and upper
            mps *= " LO BOUND VAR$(col) $(m.collb[col])\n UP BOUND VAR$(col) $(m.colub[col])\n"
        end
    end
    mps
end

function addSOS(m::NEOSMathProgModel, mps::ASCIIString)
    for (n_sos, sos) in enumerate(m.sos)
        mps *= "SOS\n S$(sos.order) SOS$(n_sos)\n"
        for (i, v) in enumerate(sos.indices)
            mps *= "    VAR$(v)      $(sos.weights[i])\n"
        end
    end
    mps
end

function gzip(s::ASCIIString)
    f = randstring(4) * ".gz"
    GZip.open(f, "w") do fh
        write(fh, s)
    end
    s_gz = bytestring(encode(Base64, open(readbytes, f)))
    rm(f)
    return "<base64>"*s_gz*"</base64>"
end
