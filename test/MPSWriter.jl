using NEOS.MPSWriter, Base.Test

@testset "getrowsense" begin
    # LE, GE, Eq, Ranged
    row_sense, hasranged = MPSWriter.getrowsense([-Inf, 0.], [0., Inf])
    @test row_sense == [:(<=), :(>=)]
    @test hasranged == false

    row_sense, hasranged = MPSWriter.getrowsense([1., -1.], [1., 1.])
    @test row_sense == [:(==), :ranged]
    @test hasranged == true

    @test_throws Exception MPSWriter.getrowsense([1.], [1., 1.])
    @test_throws Exception MPSWriter.getrowsense([-Inf], [Inf])
end

@testset "writecolumns!" begin
    io = IOBuffer()

    colnames  = ["V$i" for i in 1:2]
    rownames  = ["C$i" for i in 1:2]

    MPSWriter.writecolumns!(io, [0. 0.]', [:Cont], [1.], :Min, colnames, rownames)
    @test String(take!(io)) == "COLUMNS\n    V1        OBJ       1\n"

    MPSWriter.writecolumns!(io, [0. 0.]', [:Cont], [1.], :Max, colnames, rownames)
    @test String(take!(io)) == "COLUMNS\n    V1        OBJ       -1\n"

    MPSWriter.writecolumns!(io, [0. 0.], [:Bin, :Cont], [3., 4.], :Max, colnames, rownames)
    @test String(take!(io)) == "COLUMNS\n    MARKER    'MARKER'                 'INTORG'\n    V1        OBJ       -3\n    MARKER    'MARKER'                 'INTEND'\n    V2        OBJ       -4\n"

    MPSWriter.writecolumns!(io, [0. 0.], [:Fixed, :Int], [3., 4.], :Max, colnames, rownames)
    @test String(take!(io)) == "COLUMNS\n    V1        OBJ       -3\n    MARKER    'MARKER'                 'INTORG'\n    V2        OBJ       -4\n    MARKER    'MARKER'                 'INTEND'\n"

    @test_throws Exception MPSWriter.writecolumns!(io, [0. 0.]', [:Cont], [1.], :badsense, colnames, rownames)
    @test_throws Exception MPSWriter.writecolumns!(io, [0. 0.]', [:badtype], [1.], :Min, colnames, rownames)
    @test_throws Exception MPSWriter.writecolumns!(io, [0. 0.]', [:Cont, :Cont], [1.], :Min, colnames, rownames)

    close(io)
end

@testset "writecolumn!" begin

    colnames  = ["V$i" for i in 1:2]
    rownames  = ["C$i" for i in 1:2]

    for Aty in [SparseMatrixCSC{Float64, Int}, Array{Float64, 2}]
        io = IOBuffer()
        A = convert(Aty, [1. 0.; 1.5 1.4])
        MPSWriter.writecolumn!(io, A, 1, colnames, rownames)
        @test String(take!(io)) == "    V1        C1        1\n    V1        C2        1.5\n"
        MPSWriter.writecolumn!(io, A, 2, colnames, rownames)
        @test String(take!(io)) == "    V2        C2        1.4\n"
        close(io)
    end
end

@testset "writerows!" begin
    rownames  = ["C$i" for i in 1:4]
    io = IOBuffer()
    MPSWriter.writerows!(io, [:(<=), :(>=), :(==), :ranged], rownames)
    s = String(take!(io))
    @test s == "ROWS\n N  OBJ\n L  C1\n G  C2\n E  C3\n E  C4\n"
    @test_throws Exception MPSWriter.writerows!(io, [:badsym], rownames)
    close(io)
end

@testset "writerhs!" begin
    io = IOBuffer()
    rownames  = ["C$i" for i in 1:4]
    MPSWriter.writerhs!(io, [-Inf, -1., 0., 0.], [0., 1., 0., Inf], [:(<=), :ranged, :(==), :(>=)], rownames)
    s = String(take!(io))
    @test s == "RHS\n    rhs       C1        0\n    rhs       C2        -1\n    rhs       C3        0\n    rhs       C4        0\n"
    @test_throws Exception MPSWriter.writeMPS!(io, [-Inf], [0., 1], [:(<=), :(==)], rownames)
    close(io)
end

@testset "writeranges!" begin
    io = IOBuffer()
    rownames  = ["C$i" for i in 1:4]
    MPSWriter.writeranges!(io, [-Inf, -2.5, 0., 1.], [1., 1., 1., 2.], [:(<=), :ranged, :ranged, :ranged], rownames)
    s = String(take!(io))
    @test s == "RANGES\n    rhs       C2        3.5\n    rhs       C3        1\n    rhs       C4        1\n"
    close(io)
end

@testset "writebounds!" begin
    io = IOBuffer()
    colnames  = ["V$i" for i in 1:4]
    # (-Inf, Inf) = FR
    # (  * , Inf) = PL
    # (  * ,  x ) = UP
    # (-Inf,  * ) = MI
    # (  x ,  * ) = LO
    MPSWriter.writebounds!(io, [-Inf, 1., 0., -Inf], [Inf, Inf, Inf, 0.], colnames)

    s = String(take!(io))

    @test s == "BOUNDS\n FR BOUNDS    V1\n PL BOUNDS    V2\n LO BOUNDS    V2        1\n PL BOUNDS    V3\n UP BOUNDS    V4        0\n MI BOUNDS    V4\n"
    @test_throws Exception MPSWriter.writebounds!(io, [-Inf], [Inf, 0.], colnames)
    close(io)
end

@testset "writebound!" begin
    io = IOBuffer()
    colnames  = ["V$i" for i in 1:4]
    MPSWriter. writebound!(io, "FR", 1, colnames[1])
    @test String(take!(io)) == " FR BOUNDS    V1\n"
    MPSWriter. writebound!(io, "MI", 1, colnames[1])
    @test String(take!(io)) == " MI BOUNDS    V1\n"
    MPSWriter. writebound!(io, "PL", 1, colnames[1])
    @test String(take!(io)) == " PL BOUNDS    V1\n"

    @test_throws Exception MPSWriter. writebound!(io, "LO", 1, "BadVar")
    @test_throws Exception MPSWriter. writebound!(io, "UP", 1, "BadVar")
    @test_throws Exception MPSWriter. writebound!(io, "badstring", 1, "BadVar")
    @test_throws Exception MPSWriter. writebound!(io, "FR", 1, 1., "BadVar")
    @test_throws Exception MPSWriter. writebound!(io, "MI", 1, 1., "BadVar")
    @test_throws Exception MPSWriter. writebound!(io, "PL", 1, 1., "BadVar")
    @test_throws Exception MPSWriter. writebound!(io, "badstring", 1, "BadVar")

    MPSWriter. writebound!(io, "LO", 1, 1.0, colnames[1])
    @test String(take!(io)) == " LO BOUNDS    V1        1\n"
    MPSWriter. writebound!(io, "UP", 1, 1.0, colnames[1])
    @test String(take!(io)) == " UP BOUNDS    V1        1\n"
    MPSWriter. writebound!(io, "LO", 100, 1.0, "V100")
    @test String(take!(io)) == " LO BOUNDS    V100      1\n"
    MPSWriter. writebound!(io, "UP", 100, 1.0, "V100")
    @test String(take!(io)) == " UP BOUNDS    V100      1\n"
    close(io)
end

@testset "SOS" begin
    colnames  = ["V$i" for i in 1:4]
    io = IOBuffer()
    MPSWriter.writesos!(io, [(1, [1,2,3], [1.,3.,2.]), (2, [1,2,3], [2.,1.,3.])], 3, colnames)
    s = String(take!(io))
    @test s == "SOS\n S1 SOS1\n    V1        1\n    V2        3\n    V3        2\n S2 SOS2\n    V1        2\n    V2        1\n    V3        3\n"

    @test_throws Exception MPSWriter.writesos!(io, [(1, [1,2,3], [1.,2.,3.])], 2, colnames)
    @test_throws Exception MPSWriter.writesos!(io, [(1, [0,2,3], [1.,2.,3.])], 3, colnames)

    close(io)
end

@testset "Quad" begin
    io = IOBuffer()
    colnames  = ["V$i" for i in 1:4]
    MPSWriter.writequad!(io, sparse([1, 1, 2, 1], [1, 2, 2, 1], [0.5, 1.5, 1, 0.5]), :Min, colnames)
    @test String(take!(io)) == "QMATRIX\n    V1       V1        1\n    V1       V2        1.5\n    V2       V2        1\n"
    MPSWriter.writequad!(io, [1.75 0;1.4 1], :Max, colnames)
    @test String(take!(io)) == "QMATRIX\n    V1       V1        -1.75\n    V2       V1        -1.4\n    V2       V2        -1\n"
    close(io)
end

@testset "write" begin
const MPSFILE = """NAME          TestModel
ROWS
 N  OBJ
 G  CON1
 G  CON2
 E  CON3
 E  CON4
COLUMNS
    V1        CON1      1
    V2        CON2      1
    V3        CON3      1
    MARKER    'MARKER'                 'INTORG'
    V4        OBJ       1
    MARKER    'MARKER'                 'INTEND'
    V5        CON4      1
    V5        OBJ       -1
    V6        CON4      1
    V7        CON4      1
    MARKER    'MARKER'                 'INTORG'
    V8        OBJ       0
    MARKER    'MARKER'                 'INTEND'
RHS
    rhs       CON1      0
    rhs       CON2      2
    rhs       CON3      1
    rhs       CON4      1
RANGES
    rhs       CON3      1.5
BOUNDS
 UP BOUNDS    V1        3
 MI BOUNDS    V1
 UP BOUNDS    V2        3
 MI BOUNDS    V2
 UP BOUNDS    V3        3
 MI BOUNDS    V3
 PL BOUNDS    V4
 LO BOUNDS    V4        5.5
 UP BOUNDS    V5        1
 UP BOUNDS    V6        1
 UP BOUNDS    V7        1
 UP BOUNDS    V8        1
SOS
 S2 SOS1
    V5        1
    V6        2
    V7        3
QMATRIX
    V1       V1        2
    V2       V1        -1.1
    V1       V2        -1.1
    V2       V2        2
ENDATA
"""
    io = IOBuffer()
    MPSWriter.write(io,
    [
    1 0 0 0 0 0 0 0;
    0 1 0 0 0 0 0 0;
    0 0 1 0 0 0 0 0;
    0 0 0 0 1 1 1 0
    ],
    [-Inf, -Inf, -Inf, 5.5, 0, 0, 0, 0],
    [3, 3, 3, Inf, 1, 1, 1, 1],
    [0,0,0,-1,1,0,0,0],
    [0, 2, 1, 1],
    [Inf, Inf, 2.5, 1],
    :Max,
    [:Cont, :Cont, :Cont, :Int, :Cont, :Cont, :Cont, :Bin],
    MPSWriter.SOS[(2, [5,6,7], [1,2,3])],
    sparse([1,1,2,2], [1,2,1,2], [-2,1.1,1.1,-2], 8,8),
    "TestModel",
    ["V$i" for i in 1:8],
    ["CON$i" for i in 1:4]
    )
    @test String(take!(io)) == MPSFILE
    close(io)
end
