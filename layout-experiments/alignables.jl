using Pkg
pkg"activate ."
using Rhea
using Printf

const fvariable = variable{Float64}

# an Alignable should have an "edges" Rect and an "aligns" Rect
# edges are the outer bounding box while aligns are what is used for aligning (usually axis spines)
abstract type Alignable end

struct Rect{T}
    left::T
    right::T
    top::T
    bottom::T
end

const VarRect = Rect{variable{Float64}}
VarRect() = Rect((variable(0.0) for i in 1:4)...)
const FloatRect = Rect{Float64}
Base.convert(FloatRect, r::VarRect) = begin
    FloatRect(value(r.left), value(r.right), value(r.top), value(r.bottom))
end

width(r::Rect) = r.right - r.left
height(r::Rect) = r.top - r.bottom

struct Span
    rows::UnitRange{Int64}
    cols::UnitRange{Int64}
end

struct Grid <: Alignable
    content::Vector{Pair{Alignable, Span}}
    edges::VarRect
    aligns::VarRect
    nrows::Int64
    ncols::Int64
    relwidths::Vector{Float64} # n rows
    relheights::Vector{Float64} # n cols
    rowtops::Vector{fvariable}
    rowbottoms::Vector{fvariable}
    rowgapseps::Vector{fvariable} # the division lines inside row gaps
    collefts::Vector{fvariable}
    colrights::Vector{fvariable}
    colgapseps::Vector{fvariable} # the division lines inside column gaps
    unitwidth::fvariable # what is 1 relative width
    unitheight::fvariable # what is 1 relative height
    colgap::fvariable
    rowgap::fvariable
end

function Grid(nrows, ncols; relwidths = nothing, relheights = nothing)
    Grid(
        Pair{Alignable, Span}[],
        VarRect(),
        VarRect(),
        nrows,
        ncols,
        isnothing(relwidths) ? ones(ncols) : convert(Vector{Float64}, relwidths),
        isnothing(relheights) ? ones(nrows) : convert(Vector{Float64}, relheights),
        [fvariable(0) for i in 1:nrows],
        [fvariable(0) for i in 1:nrows],
        [fvariable(0) for i in 1:nrows-1],
        [fvariable(0) for i in 1:ncols],
        [fvariable(0) for i in 1:ncols],
        [fvariable(0) for i in 1:ncols-1],
        fvariable(0),
        fvariable(0),
        fvariable(0),
        fvariable(0)
    )
end

function constraints(g::Grid) ::Vector{constraint}

    contentconstraints = constraint[]

    # all the constraints of alignables the grid contains
    for (al, sp) in g.content

        append!(contentconstraints, [
            # snap to the correct row and column boundaries
            al.aligns.top == g.rowtops[sp.rows.start],
            al.aligns.bottom == g.rowbottoms[sp.rows.stop],
            al.aligns.left == g.collefts[sp.cols.start],
            al.aligns.right == g.colrights[sp.cols.stop],

            # ensure that grid edges at least incorporate the alignable's edges
            g.edges.right >= al.edges.right,
            g.edges.left <= al.edges.left,
            g.edges.top >= al.edges.top,
            g.edges.bottom <= al.edges.bottom
        ])

        if sp.cols.start > 1 # only when there's a gap left of it
            push!(contentconstraints, g.colgapseps[sp.cols.start - 1] <= al.edges.left)
        end
        if sp.cols.stop < g.ncols  # only when there's a gap right of it
            push!(contentconstraints, g.colgapseps[sp.cols.stop] >= al.edges.right)
        end
        if sp.rows.start > 1 # only when there's a gap above it
            push!(contentconstraints, g.rowgapseps[sp.rows.start - 1] >= al.edges.top)
        end
        if sp.rows.stop < g.nrows # only when there's a gap below it
            push!(contentconstraints, g.rowgapseps[sp.rows.stop] <= al.edges.bottom)
        end

        # add constraints that the alignable itself brings with it
        append!(contentconstraints, constraints(al))
    end

    relwidths = [g.rowtops[i] - g.rowbottoms[i] == g.relheights[i] * g.unitheight for i in 1:g.nrows]
    relheights = [g.colrights[i] - g.collefts[i] == g.relwidths[i] * g.unitwidth for i in 1:g.ncols]

    boundsalign = [
        g.rowtops[1] == g.aligns.top,
        g.rowbottoms[end] == g.aligns.bottom,
        g.collefts[1] == g.aligns.left,
        g.colrights[end] == g.aligns.right
    ]

    aligns_to_edges = [
        g.edges.top - g.aligns.top >= 0,
        g.edges.bottom - g.aligns.bottom <= 0,
        g.edges.left - g.aligns.left <= 0,
        g.edges.right - g.aligns.right >= 0,
        (g.edges.top - g.aligns.top == 0) | strong(),
        (g.edges.bottom - g.aligns.bottom == 0) | strong(),
        (g.edges.left - g.aligns.left == 0) | strong(),
        (g.edges.right - g.aligns.right == 0) | strong(),
    ]

    equalcolgaps = g.ncols <= 1 ? [] : [g.collefts[i+1] - g.colrights[i] == g.colgap for i in 1:g.ncols-1]
    equalrowgaps = g.nrows <= 1 ? [] : [g.rowbottoms[i] - g.rowtops[i+1] == g.rowgap for i in 1:g.nrows-1]

    # the separators have to be between their associated rows / columns
    # but only if there are more than 1 row / column respectively
    colleftseporder = g.ncols <= 1 ? [] : [g.collefts[i+1] >= g.colgapseps[i] for i in 1:g.ncols-1]
    colrightseporder = g.ncols <= 1 ? [] : [g.colrights[i] <= g.colgapseps[i] for i in 1:g.ncols-1]
    rowtopseporder = g.nrows <= 1 ? [] : [g.rowtops[i+1] <= g.rowgapseps[i] for i in 1:g.nrows-1]
    rowbottomseporder = g.nrows <= 1 ? [] : [g.rowbottoms[i] >= g.rowgapseps[i] for i in 1:g.nrows-1]

    # order of columns and rows, otherwise this happens:
    # Columns:
    # 24.85 - -202.31
    #   | 444.01
    # 479.17 - 24.85
    #   | 706.33
    # 706.33 - 479.17
    colorder = [g.collefts[i] <= g.colrights[i] for i in 1:g.ncols]
    roworder = [g.rowtops[i] >= g.rowbottoms[i] for i in 1:g.nrows]

    vcat(
        #try these out against collapsing rows and columns
        (g.rowgap == 0) | strong(),
        (g.colgap == 0) | strong(),
        g.unitheight >= g.rowgap,
        g.unitwidth >= g.colgap,

        boundsalign,
        aligns_to_edges,
        relwidths,
        relheights,
        equalcolgaps,
        equalrowgaps,
        colleftseporder,
        colrightseporder,
        rowtopseporder,
        rowbottomseporder,
        colorder,
        roworder,

        contentconstraints
    )
end

width(a::Alignable) = width(a.edges)
height(a::Alignable) = height(a.edges)

struct Axis <: Alignable
    edges::VarRect
    aligns::VarRect
    labelsizes::Rect{Float64}
end

constraints(a::Axis) = begin
    edgesaligns = [
        a.edges.top == a.aligns.top + a.labelsizes.top,
        a.edges.bottom == a.aligns.bottom - a.labelsizes.bottom,
        a.edges.left == a.aligns.left - a.labelsizes.left,
        a.edges.right == a.aligns.right + a.labelsizes.right,
        # try adding these
        a.edges.top >= a.edges.bottom,
        a.edges.right >= a.edges.left,
        a.aligns.top >= a.aligns.bottom,
        a.aligns.right >= a.aligns.left
    ]
end

Axis() = Axis(VarRect(), VarRect(), Rect((20 .+ rand(4) * 20)...))

Rhea.add_constraints(s::simplex_solver, a::Alignable) = add_constraints(s, constraints(a))

using Plots

Plots.plot!(r::FloatRect; kwargs...) = begin
    shape = Plots.Shape([r.left, r.left, r.right, r.right], [r.bottom, r.top, r.top, r.bottom])
    plot!(shape; kwargs...)
end
Plots.plot!(r::VarRect; kwargs...) = begin
    frect = convert(FloatRect, r)
    plotrect!(frect; kwargs...)
end
Plots.plot!(g::Grid) = begin
    plotrect!(g.edges, linecolor=:red, color=GrayA(0, 0.3))
    # plotrect!(g.aligns, linecolor=:green, color=GrayA(0, 0.3)
    at = value(g.aligns.top)
    ar = value(g.aligns.right)
    al = value(g.aligns.left)
    ab = value(g.aligns.bottom)
    for c in vcat(g.collefts, g.colrights)
        plot!([value(c), value(c)], [at, ab], color=:black)
    end
    for r in vcat(g.rowtops, g.rowbottoms)
        plot!([al, ar], [value(r), value(r)], color=:black)
    end
end
Plots.plot!(a::Axis) = begin
    plotrect!(a.edges, color=:green, alpha=0.5)
    plotrect!(a.aligns, color=:blue, alpha=0.7)
end

Base.setindex!(g::Grid, a::Alignable, rows::S, cols::T) where {T<:Union{UnitRange,Int,Colon}, S<:Union{UnitRange,Int,Colon}} = begin

    if typeof(rows) <: Int
        rows = rows:rows
    elseif typeof(rows) <: Colon
        rows = 1:g.nrows
    end
    if typeof(cols) <: Int
        cols = cols:cols
    elseif typeof(cols) <: Colon
        cols = 1:g.ncols
    end

    if !((1 <= rows.start <= g.nrows) || (1 <= rows.stop <= g.nrows))
        error("invalid row span $rows for grid with $(g.nrows) rows")
    end
    if !((1 <= cols.start <= g.ncols) || (1 <= cols.stop <= g.ncols))
        error("invalid col span $cols for grid with $(g.ncols) columns")
    end
    push!(g.content, Pair(a, Span(rows, cols)))
end


function Base.show(io::IO, r::VarRect)
    print(io,
        "l: ", @sprintf("%.2f", value(r.left)),
        " r: ", @sprintf("%.2f", value(r.right)),
        " t: ", @sprintf("%.2f", value(r.top)),
        " b: ", @sprintf("%.2f", value(r.bottom)))
end
function Base.show(io::IO, r::FloatRect)
    print(io,
        "l: ", @sprintf("%.2f", r.left),
        " r: ", @sprintf("%.2f", r.right),
        " t: ", @sprintf("%.2f", r.top),
        " b: ", @sprintf("%.2f", r.bottom))
end
function Base.show(io::IO, g::Grid)
    println("Grid $(g.nrows)×$(g.ncols)")
    print(io, "Edges: ")
    println(io, g.edges)
    print(io, "Aligns: ")
    println(io, g.aligns)
    println("Rows:")
    for i in 1:g.nrows
        if i > 1
            @printf("  gap %.2f | sep %.2f\n", value(g.rowbottoms[i-1]) - value(g.rowtops[i]), value(g.rowgapseps[i-1]))
        end
        @printf("%.2f - %.2f | %.2f\n", value(g.rowtops[i]), value(g.rowbottoms[i]), value(g.rowtops[i]) - value(g.rowbottoms[i]))
    end
    println("Columns:")
    for i in 1:g.ncols
        if i > 1
            @printf("  gap %.2f | sep %.2f\n", value(g.collefts[i]) - value(g.colrights[i-1]),  value(g.colgapseps[i-1]))
        end
        @printf("%.2f - %.2f | %.2f\n", value(g.collefts[i]), value(g.colrights[i]), value(g.colrights[i]) - value(g.collefts[i]))
    end
end

function Base.show(io::IO, a::Axis)
    println("Axis")
    print(io, "Edges: ")
    println(io, a.edges)
    print(io, "Aligns: ")
    println(io, a.aligns)
end


function test()
    g = Grid(6, 5)
    a = Axis()
    g[2:3, 2:4] = a
    a2 = Axis()
    g[4:5, 2:3] = a2
    a3 = Axis()
    g[1, 1] = a3
    a4 = Axis()
    g[6, :] = a4
    g2 = Grid(2, 2)
    g[4:5, 4:5] = g2
    a5 = Axis()
    g2[1:2, 1:1] = a5
    a6 = Axis()
    g2[1:2, 2:2] = a6

    s = simplex_solver()

    add_constraints(s,[
        (width(g) == 1200) | strong(),
        (height(g) == 1200) | strong(),
        (g.edges.bottom == 0) | strong(),
        (g.edges.left == 0) | strong()
    ])

    add_constraints(s, g)


    p = plot(legend = false)
    plot!(g)
    plot!(a)
    plot!(a2)
    plot!(a3)
    plot!(a4)
    plot!(g2)
    plot!(a5)
    plot!(a6)
    println(g)
    println("a: ", a)
    println("a2: ", a2)
    # println("a3: ", a3)
    # println("a4: ", a4)
    # println("g2: ", g2)
    p
end

test()

function test2()
    g = Grid(5, 5)
    axes = [Axis() for i in 1:g.nrows, j in 1:g.ncols]
    for i in 1:g.nrows, j in 1:g.ncols
        g[i, j] = axes[i, j]
    end

    s = simplex_solver()

    add_constraints(s,[
        (width(g) == 1200) | strong(),
        (height(g) == 1200) | strong(),
        (g.edges.bottom == 0) | strong(),
        (g.edges.left == 0) | strong()
    ])

    add_constraints(s, g)

    p = plot(legend = false)
    plot!(g)
    for i in 1:g.nrows, j in 1:g.ncols
        plot!(axes[i, j])
    end
    p
end

test2()

function test3()
    g = Grid(6, 6, relwidths = collect(range(2, 1, length=6)), relheights = collect(range(2, 1, length=6)))
    a = Axis()
    b = Axis()
    c = Axis()
    g[1, 1] = a
    g[2:3, 2:3] = b
    g[4:6, 4:6] = c

    s = simplex_solver()

    add_constraints(s,[
        (width(g) == 1200) | strong(),
        (height(g) == 1200) | strong(),
        (g.edges.bottom == 0) | strong(),
        (g.edges.left == 0) | strong()
    ])

    add_constraints(s, g)

    p = plot(legend = false)
    plot!(g)
    plot!(a)
    plot!(b)
    plot!(c)
    # println(g)
    # println("a: ", a)
    # println("b: ", b)
    # println("c: ", c)
    p
end

test3()


function test4()
    g = Grid(4, 4)
    g2 = Grid(4, 4)
    g3 = Grid(4, 4)
    a = Axis()
    g[1:3, 1:3] = g2
    g2[1:3, 1:3] = g3
    g3[1:3, 1:3] = a
    s = simplex_solver()

    add_constraints(s,[
        (width(g) == 1000) | strong(),
        (height(g) == 1000) | strong(),
        (g.edges.bottom == 0) | strong(),
        (g.edges.left == 0) | strong()
    ])

    add_constraints(s, g)

    p = plot(legend = false)
    plot!(g)
    plot!(g2)
    plot!(g3)
    plot!(a)
    p
end

test4()
