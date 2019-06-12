using Pkg
pkg"activate ."
using Rhea

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

    vcat(
        contentconstraints,
        relwidths,
        relheights,
        boundsalign,
        aligns_to_edges,
        equalcolgaps,
        equalrowgaps,
        colleftseporder,
        colrightseporder,
        rowtopseporder,
        rowbottomseporder,
        g.rowgap >= 0,
        g.colgap >= 0
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
        a.edges.right == a.aligns.right + a.labelsizes.right
    ]
end

Axis() = Axis(VarRect(), VarRect(), Rect((20 .+ rand(4) * 20)...))

Rhea.add_constraints(s::simplex_solver, a::Alignable) = add_constraints(s, constraints(a))

using Plots

Plots.plot!(r::FloatRect; kwargs...) = begin
    shape = Plots.Shape([r.left, r.left, r.right, r.right], [r.bottom, r.top, r.top, r.bottom])
    plot!(shape, alpha=0.7, kwargs...)
end
Plots.plot!(r::VarRect; kwargs...) = begin
    frect = convert(FloatRect, r)
    plot!(frect, kwargs...)
end
Plots.plot!(g::Grid) = begin
    plot!(g.aligns)
    plot!(g.edges)
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
    plot!(a.edges)
    plot!(a.aligns)
end


function test()
    g = Grid(6, 5, relwidths = [1, 2, 1, 2, 1], relheights = [3, 1, 1, 1, 1, 1])
    a = Axis()
    push!(g.content, Pair(a, Span(2:3, 2:4)))
    a2 = Axis()
    push!(g.content, Pair(a2, Span(4:5, 2:3)))
    a3 = Axis()
    push!(g.content, Pair(a3, Span(1:1, 1:1)))
    a4 = Axis()
    push!(g.content, Pair(a4, Span(6:6, 1:5)))
    g2 = Grid(2, 2)
    push!(g.content, Pair(g2, Span(4:5, 4:5)))
    # a5 = Axis()
    # push!(g2.content, Pair(a5, Span(1:2, 1:1)))
    # a6 = Axis()
    # push!(g2.content, Pair(a6, Span(1:2, 2:2)))

    s = simplex_solver()
    add_constraints(s, g)

    add_constraints(s,[
        width(g) == 1200,
        height(g) == 1200,
        g.edges.bottom == 0,
        g.edges.left == 0
    ])
    p = plot(legend = false)
    plot!(g)
    plot!(a)
    plot!(a2)
    plot!(a3)
    plot!(a4)
    plot!(g2)
    # plot!(a5)
    # plot!(a6)
    p
end

test()
