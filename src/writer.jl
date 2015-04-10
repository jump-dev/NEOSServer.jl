function buildMPS(m::NEOSMathProgModel)
    mps = "NAME   MathProgModel\n"

    numRows = length(m.rowub)
    numCols = length(m.f)

    rowSense = Array(Symbol, numRows)
    for r=1:numRows
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
    	end
    end


    # # Objective and constraint names
    mps *= "ROWS\n"
    mps *= " N  OBJ\n"
    hasrange = false
    for c in 1:numRows
        if rowSense[c] == :(<=)
            senseChar = 'L'
        elseif rowSense[c] == :(==)
            senseChar = 'E'
        elseif rowSense[c] == :(>=)
            senseChar = 'G'
        else
            hasrange = true
            senseChar = 'E'
        end
        mps *= " $senseChar  CON$c\n"
    end
    # gc_enable()

    # Output each column
    # gc_disable()

    A = convert(SparseMatrixCSC{Float64, Int32}, m.A)
    colptr = A.colptr
    rowval = A.rowval
    nzval = A.nzval

    inintegergroup = false
    mps *= "COLUMNS\n"
    # print objective
    if m.sense == :Max
		warn("Flipping objective coefficients as MPS requires minimisation problem.")
	end
    for col in 1:numCols
    	if m.colcat != :nothing
	        t = m.colcat[col]
	        (t == :SemiCont || t == :SemiInt) && error("The MPS file writer does not currently support semicontinuous or semi-integer variables")
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
    # gc_enable()

    # RHSs
    mps *= "RHS\n"
    for c in 1:numRows        
        mps *= "    rhs    CON$c    "
        if rowSense[c] == :(<=)
            mps *= "$(m.rowub[c])"
        else
            mps *= "$(m.rowlb[c])"
        end
        mps *= "\n"
    end
    # gc_enable()

    # RANGES
    if hasrange
    #     gc_disable()
        mps *= "RANGES\n"
        for c in 1:numRows
            if rowSense[c] == :range
            	mps *= "    rhs    CON$c    $(m.rowub - m.rowlb)\n"
            end
        end
    end


    # BOUNDS
    # gc_disable()
    mps *= "BOUNDS\n"
    for col in 1:numCols
        if m.collb[col] == 0
        	# Default lowerbound
            if m.colub[col] != Inf
            	# Non-default upper bound
            	mps *= "  UP BOUND VAR$col  $(m.colub[col])\n"
            end
        elseif m.colLower[col] == -Inf && m.colUpper[col] == +Inf
    #         # Free
    		mps *= "  FR BOUND VAR$col\n"
        elseif m.colLower[col] != -Inf && m.colUpper[col] == +Inf
    #         # No upper, but a lower
            mps *= "  PL BOUND VAR$(col)\n  LO BOUND VAR$(col) $(m.collb[col])\n"
        elseif m.colLower[col] == -Inf && m.colUpper[col] != +Inf
    #         # No lower, but a upper
            mps *= "  MI BOUND VAR$(col)\n  UP BOUND VAR$(col) $(m.colub[col])\n"
        else
    #         # Lower and upper
            mps *= "  LO BOUND VAR$(col) $(m.collb[col])\n"
            mps *= "  UP BOUND VAR$(col) $(m.colub[col])\n"
        end
    end
    # gc_enable()

    # TODO support special ordered sets

    mps *= "ENDATA\n"
    # gc_enable()
    # println(mps)
    return mps
end
