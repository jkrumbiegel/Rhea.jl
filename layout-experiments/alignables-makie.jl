using Pkg
pkg"activate ."
using Makie
using Rhea
using Printf
# using Observables

# an Alignable should have an "edges" MyRect and an "aligns" MyRect
# edges are the outer bounding box while aligns are what is used for aligning (usually MyAxis spines)
abstract type Alignable end

struct MyRect{T}
    left::T
    right::T
    top::T
    bottom::T
end

sides(r::MyRect) = (r.left, r.right, r.top, r.bottom)

const VarRect = MyRect{Variable{Float64}}
VarRect() = MyRect((Variable(0.0) for i in 1:4)...)
const FloatRect = MyRect{Float64}
Base.convert(FloatRect, r::VarRect) = begin
    FloatRect(value(r.left), value(r.right), value(r.top), value(r.bottom))
end

width(r::MyRect) = r.right - r.left
height(r::MyRect) = r.top - r.bottom

struct Span
    rows::UnitRange{Int64}
    cols::UnitRange{Int64}
end

struct SpannedAlignable
    al::Alignable
    sp::Span
end

struct Grid <: Alignable
    content::Vector{SpannedAlignable}
    edges::VarRect
    aligns::VarRect
    nrows::Int64
    ncols::Int64
    relwidths::Vector{Float64} # n rows
    relheights::Vector{Float64} # n cols
    rowtops::Vector{FVariable}
    rowbottoms::Vector{FVariable}
    rowgapseps::Vector{FVariable} # the division lines inside row gaps
    collefts::Vector{FVariable}
    colrights::Vector{FVariable}
    colgapseps::Vector{FVariable} # the division lines inside column gaps
    unitwidth::FVariable # what is 1 relative width
    unitheight::FVariable # what is 1 relative height
    colgap::FVariable
    rowgap::FVariable
    colspacing::FVariable
    rowspacing::FVariable
    c_colspacing::Constraint
    c_rowspacing::Constraint
    margins::VarRect
    c_margins::MyRect{Constraint}
end

function Grid(nrows, ncols;
        relwidths = nothing,
        relheights = nothing,
        colspacing = 0.0,
        rowspacing = 0.0,
        margins = FloatRect(0, 0, 0, 0)
    )
    var_colspacing = FVariable(0.0)
    var_rowspacing = FVariable(0.0)
    marginvars = VarRect()
    Grid(
        SpannedAlignable[],
        VarRect(),
        VarRect(),
        nrows,
        ncols,
        isnothing(relwidths) ? ones(ncols) : convert(Vector{Float64}, relwidths),
        isnothing(relheights) ? ones(nrows) : convert(Vector{Float64}, relheights),
        [FVariable(0) for i in 1:nrows],
        [FVariable(0) for i in 1:nrows],
        [FVariable(0) for i in 1:nrows-1],
        [FVariable(0) for i in 1:ncols],
        [FVariable(0) for i in 1:ncols],
        [FVariable(0) for i in 1:ncols-1],
        FVariable(0),
        FVariable(0),
        FVariable(0),
        FVariable(0),
        var_colspacing,
        var_rowspacing,
        var_colspacing == colspacing,
        var_rowspacing == rowspacing,
        marginvars,
        MyRect(
            marginvars.left == margins.left,
            marginvars.right == margins.right,
            marginvars.top == margins.top,
            marginvars.bottom == margins.bottom
        )
    )
end

"""
Calculates the constraints for one SpannedAlignable that is placed within
    a Grid
"""
function constraints_in(g::Grid, spanned::SpannedAlignable)
    al = spanned.al
    sp = spanned.sp
    constraints = [
        # snap aligns to the correct row and column boundaries
        al.aligns.top == g.rowtops[sp.rows.start],
        al.aligns.bottom == g.rowbottoms[sp.rows.stop],
        al.aligns.left == g.collefts[sp.cols.start],
        al.aligns.right == g.colrights[sp.cols.stop],

        # ensure that grid edges always include the alignable's edges
        g.edges.right >= al.edges.right + g.margins.right,
        g.edges.left + g.margins.left <= al.edges.left,
        g.edges.top >= al.edges.top + g.margins.top,
        g.edges.bottom + g.margins.bottom <= al.edges.bottom
    ]

    # make alignable edges push against the separators inside rows and columns
    # that allow them to grow
    # here the column and row spacing is applied as well
    if sp.cols.start > 1 # only when there's a gap left of the alignable
        push!(constraints, g.colgapseps[sp.cols.start - 1] <= al.edges.left - 0.5 * g.colspacing)
    end
    if sp.cols.stop < g.ncols  # only when there's a gap right of the alignable
        push!(constraints, g.colgapseps[sp.cols.stop] >= al.edges.right + 0.5 * g.colspacing)
    end
    if sp.rows.start > 1 # only when there's a gap above the alignable
        push!(constraints, g.rowgapseps[sp.rows.start - 1] >= al.edges.top + 0.5 * g.rowspacing)
    end
    if sp.rows.stop < g.nrows # only when there's a gap below the alignable
        push!(constraints, g.rowgapseps[sp.rows.stop] <= al.edges.bottom - 0.5 * g.rowspacing)
    end

    constraints
end

function constraints(g::Grid)::Vector{Constraint}

    contentconstraints = Constraint[]

    # all the constraints of alignables the grid contains
    for spanned in g.content
        # constraints of alignable in the grid
        append!(contentconstraints, constraints_in(g, spanned))
        # constraints of the alignable itself
        append!(contentconstraints, constraints(spanned.al))
    end

    relwidths = [g.rowtops[i] - g.rowbottoms[i] == g.relheights[i] * g.unitheight for i in 1:g.nrows]
    relheights = [g.colrights[i] - g.collefts[i] == g.relwidths[i] * g.unitwidth for i in 1:g.ncols]

    # align first and last row / column with grid aligns
    boundsalign = [
        g.rowtops[1] == g.aligns.top,
        g.rowbottoms[end] == g.aligns.bottom,
        g.collefts[1] == g.aligns.left,
        g.colrights[end] == g.aligns.right
    ]

    aligns_to_edges = [
        # edges have to be outside of or coincide with the aligns
        g.edges.top >= g.aligns.top + g.margins.top,
        g.edges.bottom + g.margins.bottom <= g.aligns.bottom,
        g.edges.left + g.margins.left <= g.aligns.left,
        g.edges.right >= g.aligns.right + g.margins.right,
        # make the aligns go as far to the edges as possible / span out the grid cells
        (g.edges.top == g.aligns.top) | strong(),
        (g.edges.bottom == g.aligns.bottom) | strong(),
        (g.edges.left == g.aligns.left) | strong(),
        (g.edges.right == g.aligns.right) | strong(),
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
        g.c_colspacing,
        g.c_rowspacing,
        g.c_margins.left,
        g.c_margins.right,
        g.c_margins.top,
        g.c_margins.bottom,
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

struct MyAxis <: Alignable
    edges::VarRect
    aligns::VarRect
    labelsizes::MyRect{Float64}
end

constraints(a::MyAxis) = begin
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

MyAxis() = MyAxis(VarRect(), VarRect(), MyRect((20 .+ rand(4) * 20)...))

Rhea.add_constraints(s::SimplexSolver, a::Alignable) = add_constraints(s, constraints(a))

# using Plots
#
# Plots.plot!(r::FloatRect; kwargs...) = begin
#     shape = Plots.Shape([r.left, r.left, r.right, r.right], [r.bottom, r.top, r.top, r.bottom])
#     plot!(shape; kwargs...)
# end
# Plots.plot!(r::VarRect; kwargs...) = begin
#     frect = convert(FloatRect, r)
#     plot!(frect; kwargs...)
# end
# Plots.plot!(g::Grid) = begin
#     plot!(g.edges, linecolor=RGB(1, 0, 0), color=GrayA(0, 0))
#     # plotrect!(g.aligns, linecolor=:green, color=GrayA(0, 0.3)
#     at = value(g.aligns.top)
#     ar = value(g.aligns.right)
#     al = value(g.aligns.left)
#     ab = value(g.aligns.bottom)
#     for c in vcat(g.collefts, g.colrights)
#         plot!([value(c), value(c)], [at, ab], color=RGB(0, 0, 1))
#     end
#     for r in vcat(g.rowtops, g.rowbottoms)
#         plot!([al, ar], [value(r), value(r)], color=RGB(0, 0, 1))
#     end
# end
# Plots.plot!(a::MyAxis) = begin
#     plot!(a.edges, color=Gray(0.7), alpha=0.5)
#     plot!(a.aligns, color=Gray(0.25), alpha=0.5)
# end

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
    push!(g.content, SpannedAlignable(a, Span(rows, cols)))
end

function Base.setindex!(g::Grid, a::Alignable, index::Int, direction::Symbol=:down)
    if index < 1 || index > g.ncols * g.nrows
        error("Invalid index $index for $(g.nrows) × $(g.ncols) grid")
    end

    if direction == :down
        (j, i) = divrem(index, g.nrows)
        j += 1
        if i == 0
            j -= 1
            i = g.nrows
        end
        g[i, j] = a
    elseif direction == :right
        (i, j) = divrem(index, g.ncols)
        i += 1
        if j == 0
            i -= 1
            j = g.ncols
        end
        g[i, j] = a
    else
        error("Invalid direction symbol $direction. Only :down or :right")
    end
end

# function Base.setindex!(g::Grid, as::Alignables)

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

function Base.show(io::IO, a::MyAxis)
    println("MyAxis")
    print(io, "Edges: ")
    println(io, a.edges)
    print(io, "Aligns: ")
    println(io, a.aligns)
end

function rectlines(l, r, t, b)
    x = [l, l, r, r, l]
    y = [b, t, t, b, b]
    hcat(x, y)
end

function observables(r::VarRect)
    (r.left.p, r.right.p, r.top.p, r.bottom.p)
end

function test()
    g = Grid(6, 5)
    a = MyAxis()
    g[2:3, 2:4] = a
    a2 = MyAxis()
    g[4:5, 2:3] = a2
    a3 = MyAxis()
    g[1, 1] = a3
    a4 = MyAxis()
    g[6, :] = a4
    a5 = MyAxis()
    g[1:5, 5] = a5
    a6 = MyAxis()
    g[4:5, 4] = a6
    a7 = MyAxis()
    g[2:5, 1] = a7
    a8 = MyAxis()
    g[1, 2:4] = a8

    s = SimplexSolver()

    widthc, heightc, _, _ = add_constraints(s,[
        (width(g) == 1200) | strong(),
        (height(g) == 1200) | strong(),
        (g.edges.bottom == 0) | strong(),
        (g.edges.left == 0) | strong()
    ])

    add_constraints(s, g)
    sc = lines(
        # [1, 2, 3], [1, 2, 3]
        lift(rectlines, observables(a.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a2.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a3.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a4.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a5.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a6.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a7.aligns)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(g.edges)...)
    )
    lines!(
        sc,
        lift(rectlines, observables(a8.aligns)...)
    )
    sl1 = slider(LinRange(600, 1200, 300), raw = true, camera = campixel!)
    sl2 = slider(LinRange(0, 100, 100), raw = true, camera = campixel!)
    sl3 = slider(LinRange(0, 100, 100), raw = true, camera = campixel!)

    lift(sl1[end][:value]) do v
        set_constant(s, widthc, v)
    end
    lift(sl2[end][:value]) do v
        set_constant(s, g.c_colspacing, v)
    end
    lift(sl3[end][:value]) do v
        set_constant(s, g.c_rowspacing, v)
    end
    sc2 = hbox(vbox(sl1, sl2, sl3), sc)
    display(AbstractPlotting.PlotDisplay(), sc2)
end

test()
#
# function test2()
#     g = Grid(5, 5, rowspacing = 20, colspacing = 20)
#     axes = [MyAxis() for i in 1:g.nrows, j in 1:g.ncols]
#     for i in 1:g.nrows, j in 1:g.ncols
#         g[i, j] = axes[i, j]
#     end
#
#     s = SimplexSolver()
#
#     add_constraints(s,[
#         (width(g) == 1000) | strong(),
#         (height(g) == 1000) | strong(),
#         (g.edges.bottom == 0) | strong(),
#         (g.edges.left == 0) | strong()
#     ])
#
#     add_constraints(s, g)
#
#     p = plot(legend = false)
#     plot!(g)
#     for i in 1:g.nrows, j in 1:g.ncols
#         plot!(axes[i, j])
#     end
#     p
# end
#
# test2()
#
# function test3()
#     g = Grid(6, 6, relwidths = collect(range(2, 1, length=6)), relheights = collect(range(2, 1, length=6)))
#     a = MyAxis()
#     b = MyAxis()
#     c = MyAxis()
#     g[1, 1] = a
#     g[2:3, 2:3] = b
#     g[4:6, 4:6] = c
#
#     s = SimplexSolver()
#
#     add_constraints(s,[
#         (width(g) == 1200) | strong(),
#         (height(g) == 1200) | strong(),
#         (g.edges.bottom == 0) | strong(),
#         (g.edges.left == 0) | strong()
#     ])
#
#     add_constraints(s, g)
#
#     p = plot(legend = false)
#     plot!(g)
#     plot!(a)
#     plot!(b)
#     plot!(c)
#     # println(g)
#     # println("a: ", a)
#     # println("b: ", b)
#     # println("c: ", c)
#     p
# end
#
# test3()
#
#
# function test4()
#     g = Grid(4, 4)
#     g2 = Grid(4, 4)
#     g3 = Grid(4, 4)
#     a = MyAxis()
#     g[1:3, 1:3] = g2
#     g2[1:3, 1:3] = g3
#     g3[1:3, 1:3] = a
#     s = SimplexSolver()
#
#     add_constraints(s,[
#         (width(g) == 1000) | strong(),
#         (height(g) == 1000) | strong(),
#         (g.edges.bottom == 0) | strong(),
#         (g.edges.left == 0) | strong()
#     ])
#
#     add_constraints(s, g)
#
#     p = plot(legend = false)
#     plot!(g)
#     plot!(g2)
#     plot!(g3)
#     plot!(a)
#     p
# end
#
# test4()
#
# function test5()
#     g = Grid(2, 1, rowspacing = 30)
#     g2 = Grid(1, 3, relwidths = [5, 5, 1], colspacing = 30)
#     g[2, 1] = g2
#     a = MyAxis()
#     g[1, 1] = a
#     b = MyAxis()
#     c = MyAxis()
#     l = MyAxis()
#     g2[1, 1] = b
#     g2[1, 2] = c
#     g2[1, 3] = l
#
#     s = SimplexSolver()
#     add_constraints(s,[
#         (width(g) == 1000) | strong(),
#         (height(g) == 1000) | strong(),
#         (g.edges.bottom == 0) | strong(),
#         (g.edges.left == 0) | strong()
#     ])
#
#     add_constraints(s, g)
#
#     p = plot(legend = false)
#     plot!(a)
#     plot!(b)
#     plot!(c)
#     plot!(l)
#     plot!(g)
#     plot!(g2)
#     println(g)
#     println(g.margins)
#     println(g.c_margins)
#     p
# end
#
# test5()
#
# function test6()
#     g = Grid(2, 1, relheights = [3, 2])
#     gtop = Grid(3, 4, relwidths = [3/11, 3/11, 3/11, 1/11])
#     gbottom = Grid(1, 3, relwidths = [1/11, 5/11, 5/11])
#     g[1] = gtop
#     g[2] = gbottom
#
#     topaxes = [MyAxis() for i in 1:9]
#     toplegend = MyAxis()
#     bottomaxes = [MyAxis() for i in 1:2]
#     bottomlegend = MyAxis()
#
#     for (i, a) in enumerate(topaxes)
#         gtop[i, :down] = a
#     end
#     for (i, a) in enumerate(bottomaxes)
#         gbottom[i+1] = a
#     end
#     gtop[:, 4] = toplegend
#     gbottom[1] = bottomlegend
#
#     s = SimplexSolver()
#
#     (widthc, heightc, _, _) = add_constraints(s,[
#         (width(g) == 1000) | strong(),
#         (height(g) == 1000) | strong(),
#         (g.edges.bottom == 0) | strong(),
#         (g.edges.left == 0) | strong()
#     ])
#
#     add_constraints(s, g)
#
#     anim = @animate for w in range(1000, 500, length=45)
#         set_constant(s, widthc, w)
#         p = plot(legend = false, xlim=(0, 1000))
#         plot!.(topaxes)
#         plot!.(bottomaxes)
#         plot!(toplegend)
#         plot!(bottomlegend)
#         plot!(g)
#         plot!(gtop)
#         plot!(gbottom)
#     end
#     gif(anim, fps=15)
# end
#
# test6()
