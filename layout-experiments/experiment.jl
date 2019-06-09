using Rhea
using Plots

# Vbox: left and right-most spines match, heights are distributed
# Hbox: top and bottom-most spines match, widths are distributed
# grid: rows and columns aligned

mutable struct Axis
    l::variable{Float64}
    t::variable{Float64}
    r::variable{Float64}
    b::variable{Float64}
    sl::variable{Float64}
    st::variable{Float64}
    sr::variable{Float64}
    sb::variable{Float64}
end
Axis() = Axis((variable() for f in 1:fieldcount(Axis))...)

abstract type Box end

const Boxcontent = Union{Box, Axis}
struct Vbox <: Box
    c::Vector{Boxcontent}
    relheights::Vector{Float64}
    Vbox(c::Vector{S}, relheights::Union{Vector{T}, Nothing} = nothing) where {S<:Boxcontent, T<:Real}= begin
        if length(c) <= 1
            error("$n elements in Vbox not allowed")
        end
        if isnothing(relheights)
            relheights = [1 for i in 1:length(c)]
        end
        if length(relheights) != length(c)
            error("$(length(relheights)) for $(length(c)) elements")
        end
        new(c, convert(Vector{Float64}, relheights))
    end
end

Vbox(n::Int, relheights::Union{Nothing, Vector{T}} = nothing) where {T<:Real} = begin
    Vbox([Axis() for i in 1:n], relheights)
end

struct Hbox <: Box
    c::Vector{Boxcontent}
    relwidths::Vector{Float64}
    Hbox(c::Vector{S}, relwidths::Union{Vector{T}, Nothing} = nothing) where {S<:Boxcontent, T<:Real}= begin
        if length(c) <= 1
            error("$n elements in Hbox not allowed")
        end
        if isnothing(relwidths)
            relwidths = [1 for i in 1:length(c)]
        end
        if length(relwidths) != length(c)
            error("$(length(relwidths)) for $(length(c)) elements")
        end
        new(c, convert(Vector{Float64}, relwidths))
    end
end

Hbox(n::Int, relwidths::Union{Nothing, Vector{T}} = nothing) where {T<:Real} = begin
    Hbox([Axis() for i in 1:n], relwidths)
end


struct Grid <: Box
    c::Matrix{Boxcontent}
    relwidths::Vector{Float64}
    relheights::Vector{Float64}
    Grid(
        c::Matrix{S};
        relwidths::Union{Vector{T}, Nothing} = nothing,
        relheights::Union{Vector{T}, Nothing} = nothing) where {S<:Boxcontent, T<:Real}= begin

        if size(c, 1) < 2 || size(c, 2) < 2
            error("Needs to be at least 2x2 for a grid to make sense")
        end
        if isnothing(relwidths)
            relwidths = ones(size(c, 2))
        end
        if isnothing(relheights)
            relheights = ones(size(c, 1))
        end
        new(c, convert(Vector{Float64}, relwidths), convert(Vector{Float64}, relheights))
    end
end

function Grid(rows::Int, cols::Int; relwidths = nothing, relheights = nothing)
    Grid([Axis() for i in 1:rows, j in 1:cols], relwidths = relwidths, relheights = relheights)
end


rectangle(l, t, r, b) = Plots.Shape([l, l, r, r], [b, t, t, b])

axtoshapes(a::Axis) = begin
    l = value(a.l)
    r = value(a.r)
    t = value(a.t)
    b = value(a.b)
    sl = l - value(a.sl)
    sr = r + value(a.sr)
    st = t + value(a.st)
    sb = b - value(a.sb)
    main = rectangle(l, t, r, b)
    left = rectangle(sl, t, l, b)
    top = rectangle(l, st, r, t)
    right = rectangle(r, t, sr, b)
    bottom = rectangle(l, b, r, sb)
    [main, left, top, right, bottom]
end

import Plots.plot!
function plot!(a::Axis)
    plot!(axtoshapes(a), alpha = [1, 0.5, 0.5, 0.5, 0.5])
end

function plot!(as::Vector{Axis})
    for a in as
        plot!(a)
    end
end

function plot!(b::Box)
    for c in b.c
        plot!(c)
    end
end

topspine(a::Axis) = a.t
topspine(b::Box) = topspine(b.c[1]) # just first element, they will be aligned for hbox
topspine(g::Grid) = topspine(g.c[1, 1])

bottomspine(a::Axis) = a.b
bottomspine(b::Box) = bottomspine(b.c[end])
topspine(g::Grid) = bottomspine(g.c[end, end])

leftspine(a::Axis) = a.l
leftspine(b::Box) = leftspine(b.c[1])
leftspine(g::Grid) = leftspine(g.c[1, 1])

rightspine(a::Axis) = a.r
rightspine(b::Box) = rightspine(b.c[end])
rightspine(g::Grid) = rightspine(g.c[end, end])

axiswidth(a::Axis) = rightspine(a) - leftspine(a)
axisheight(a::Axis) = topspine(a) - bottomspine(a)

axiswidth(b::Box) = rightspine(b) - leftspine(b)
axisheight(b::Box) = topspine(b) - bottomspine(b)

width(o::Union{Box, Axis}) = rightedge(o) - leftedge(o)
height(o::Union{Box, Axis}) = topedge(o) - bottomedge(o)

leftedge(a::Axis) = leftspine(a) - a.sl
leftedge(b::Vbox) = begin
    (_, ax) = leftmostax(b)
    leftedge(ax)
end
leftedge(b::Hbox) = leftedge(b.c[1])
leftedge(g::Grid) = begin
    (_, ax) = leftmostax(g)
    leftedge(ax)
end

rightedge(a::Axis) = rightspine(a) + a.sr
rightedge(b::Vbox) = begin
    (_, ax) = rightmostax(b)
    rightedge(ax)
end
rightedge(b::Hbox) = rightedge(b.c[end])
rightedge(g::Grid) = begin
    (_, ax) = rightmostax(g)
    rightedge(ax)
end

topedge(a::Axis) = topspine(a) + a.st
topedge(b::Vbox) = topedge(b.c[1])
topedge(b::Hbox) = begin
    (_, ax) = topmostax(b)
    topedge(ax)
end
topedge(g::Grid) = begin
    (_, ax) = topmostax(g)
    topedge(ax)
end

bottomedge(a::Axis) = bottomspine(a) - a.sb
bottomedge(b::Vbox) = bottomedge(b.c[end])
bottomedge(b::Hbox) = begin
    (_, ax) = bottommostax(b)
    bottomedge(ax)
end
bottomedge(g::Grid) = begin
    (_, ax) = bottommostax(g)
    bottomedge(ax)
end

leftmostax(a::Axis) = (a.sl, a)
function leftmostax(v::Vbox)
    val = -Inf
    candidate = nothing
    for c in v.c
        (newvar, newcand) = leftmostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end
function leftmostax(h::Hbox)
    leftmostax(h.c[1])
end
function leftmostax(g::Grid)
    val = -Inf
    candidate = nothing
    for c in g.c[:, 1]
        (newvar, newcand) = leftmostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end

rightmostax(a::Axis) = (a.sr, a)
function rightmostax(v::Vbox)
    val = -Inf
    candidate = nothing
    for c in v.c
        (newvar, newcand) = rightmostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end
function rightmostax(h::Hbox)
    rightmostax(h.c[end])
end
function rightmostax(g::Grid)
    val = -Inf
    candidate = nothing
    for c in g.c[:, end]
        (newvar, newcand) = rightmostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end

topmostax(a::Axis) = (a.st, a)
function topmostax(h::Hbox)
    val = -Inf
    candidate = nothing
    for c in h.c
        (newvar, newcand) = topmostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end
function topmostax(v::Vbox)
    topmostax(v.c[1])
end
function topmostax(g::Grid)
    val = -Inf
    candidate = nothing
    for c in g.c[1, :]
        (newvar, newcand) = topmostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end

bottommostax(a::Axis) = (a.sb, a)
function bottommostax(h::Hbox)
    val = -Inf
    candidate = nothing
    for c in h.c
        (newvar, newcand) = bottommostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end
function bottommostax(v::Vbox)
    bottommostax(v.c[end])
end
function bottommostax(g::Grid)
    val = -Inf
    candidate = nothing
    for c in g.c[end, :]
        (newvar, newcand) = bottommostax(c)
        newval = newvar
        if typeof(newval) <: variable
            newval = value(newval)
        end
        if newval > val
            candidate = newcand
            val = newval
        end
    end
    (val, candidate)
end

import Rhea.add_constraints
function add_constraints(s::simplex_solver, v::Vbox)
    for c in v.c
        # go depth first, so that the constraints specifying the
        # decoration sizes get set up before functions trying
        # to find the biggest ones
        add_constraints(s, c)
    end

    closegaps = [bottomedge(v.c[i]) == topedge(v.c[i + 1]) for i in 1:length(v.c)-1]

    relheights = [
        axisheight(v.c[i]) * v.relheights[i+1] == axisheight(v.c[i+1]) * v.relheights[i]
            for i in 1:length(v.c)-1
    ]

    leftalignments = [
        leftspine(v.c[i]) == leftspine(v.c[i+1])
            for i in 1:length(v.c)-1
    ]
    rightalignments = [
        rightspine(v.c[i]) == rightspine(v.c[i+1])
            for i in 1:length(v.c)-1
    ]

    add_constraints(s, closegaps)
    add_constraints(s, relheights)
    add_constraints(s, leftalignments)
    add_constraints(s, rightalignments)
end

function add_constraints(s::simplex_solver, h::Hbox)
    for c in h.c
        add_constraints(s, c)
    end

    closegaps = [leftedge(h.c[i+1]) == rightedge(h.c[i]) for i in 1:length(h.c)-1]

    relwidths = [
        axiswidth(h.c[i]) * h.relwidths[i+1] == axiswidth(h.c[i+1]) * h.relwidths[i]
            for i in 1:length(h.c)-1
    ]

    topalignments = [
        topspine(h.c[i]) == topspine(h.c[i+1])
            for i in 1:length(h.c)-1
    ]

    bottomalignments = [
        bottomspine(h.c[i]) == bottomspine(h.c[i+1])
            for i in 1:length(h.c)-1
    ]

    add_constraints(s, closegaps)
    add_constraints(s, relwidths)
    add_constraints(s, topalignments)
    add_constraints(s, bottomalignments)
end

rrange(lo, hi) = rand() * (hi - lo) + lo
function add_constraints(s::simplex_solver, a::Axis)
    constraints = [
        leftspine(a) <= rightspine(a),
        topspine(a) >= bottomspine(a),
        a.sl == rrange(10, 30),
        a.sr == rrange(10, 30),
        a.st == rrange(10, 30),
        a.sb == rrange(10, 30)
    ]
    add_constraints(s, constraints)
end

function largest_hgap(g::Grid)
    val = -Inf
    cand = nothing
    for i in 1:size(g.c, 1), j in 1:size(g.c, 2)-1
        (rvar, rcand) = rightmostax(g.c[i, j])
        (lvar, lcand) = leftmostax(g.c[i, j+1])
        newval = (typeof(rvar) <: variable ? rvar.p : rvar) + (typeof(lvar) <: variable ? lvar.p : lvar)
        if newval > val
            cand = leftspine(g.c[i, j+1]) - rightspine(g.c[i, j])
            val = newval
        end
    end
    println("hval", val)
    (cand, val)
end

function largest_vgap(g::Grid)
    val = -Inf
    cand = nothing
    for i in 1:size(g.c, 1)-1, j in 1:size(g.c, 2)
        (tvar, rcand) = topmostax(g.c[i+1, j])
        (bvar, lcand) = bottommostax(g.c[i, j])
        newval = (typeof(tvar) <: variable ? tvar.p : tvar) + (typeof(bvar) <: variable ? bvar.p : bvar)
        if newval > val
            cand = bottomspine(g.c[i, j]) - topspine(g.c[i+1, j])
            val = newval
        end
    end
    println("vval", val)
    (cand, val)
end

function add_constraints(s::simplex_solver, g::Grid)
    for c in g.c
        add_constraints(s, c)
    end
    (largest_h_spinegap, hval) = largest_hgap(g)
    # add_constraint(s, largest_h_spinegap == hval)
    add_constraints(s, [leftspine(g.c[1, j+1]) - rightspine(g.c[1, j]) == hval for j in 1:size(g.c, 2)-1])
    (largest_v_spinegap, vval) = largest_vgap(g)
    add_constraints(s, [bottomspine(g.c[i, 1]) - topspine(g.c[i+1, 1]) == vval for i in 1:size(g.c, 1)-1])
    # closegaps_h = [leftedge(g.c[i, j+1]) - rightedge(g.c[i, j]) >= largest_h for i in 1:size(g.c, 1), j in 1:size(g.c, 2)-1]
    # closegaps_v = [topedge(g.c[i+1, j]) + 50 == bottomedge(g.c[i, j]) for i in 1:size(g.c, 1)-1, j in 1:size(g.c, 2)]
    # equal_gaps_h = [leftedge(g.c[i, j+1]) - rightedge(g.c[i, j]) == leftedge(g.c[i, j+2]) - rightedge(g.c[i, j+1]) for i in 1:size(g.c, 1), j in 1:size(g.c, 2)-2]
    # equal_gaps_v = [bottomedge(g.c[i, j]) - topedge(g.c[i+1, j]) == bottomedge(g.c[i+1, j]) - topedge(g.c[i+2, j]) for i in 1:size(g.c, 1)-2, j in 1:size(g.c, 2)]
    println(g.relwidths)
    relwidths = [
        axiswidth(g.c[i, j]) * g.relwidths[j+1] == axiswidth(g.c[i, j+1]) * g.relwidths[j]
            for i in 1:size(g.c, 1), j in 1:size(g.c, 2)-1
    ]
    relheights = [
        axisheight(g.c[i, j]) * g.relheights[i+1] == axisheight(g.c[i+1, j]) * g.relheights[i]
            for i in 1:size(g.c, 1)-1, j in 1:size(g.c, 2)
    ]
    leftalignments = [
        leftspine(g.c[i, j]) == leftspine(g.c[i+1, j])
            for i in 1:size(g.c, 1)-1, j in 1:size(g.c, 2)
    ]
    rightalignments = [
        rightspine(g.c[i, j]) == rightspine(g.c[i+1, j])
            for i in 1:size(g.c, 1)-1, j in 1:size(g.c, 2)
    ]
    topalignments = [
        topspine(g.c[i, j]) == topspine(g.c[i, j+1])
            for i in 1:size(g.c, 1), j in 1:size(g.c, 2)-1
    ]
    bottomalignments = [
        bottomspine(g.c[i, j]) == bottomspine(g.c[i, j+1])
            for i in 1:size(g.c, 1), j in 1:size(g.c, 2)-1
    ]

    add_constraints(s, relwidths[:])
    add_constraints(s, relheights[:])
    add_constraints(s, leftalignments[:])
    add_constraints(s, rightalignments[:])
    add_constraints(s, topalignments[:])
    add_constraints(s, bottomalignments[:])
end


function test_constraint_layout()
    h1 = Hbox(3, [1, 2, 1])
    v1 = Vbox(2)
    h2 = Hbox([h1, v1], [2, 1])
    v2 = Vbox(2)
    v3 = Vbox([h2, v2])
    v4 = Vbox(3, [2, 3, 4])
    h3 = Hbox([v3, v4], [3, 2])

    s = simplex_solver()
    # recursively add all constraints of objects in the top box
    add_constraints(s, h3)

    # add specific constraints for plot size and position
    add_constraints(s, [
        width(h3) == 800,
        height(h3) == 400,
        leftedge(h3) == 0,
        bottomedge(h3) == 0
    ])

    p = plot(legend = false)
    plot!(h3)
    p
end

# test_constraint_layout()

function test_grid()
    g = Grid(3, 3, relwidths = [1, 2, 3], relheights = [2, 1, 1])
    g.c[1, 1] = Vbox(2)
    g.c[2, 3] = Hbox(2)
    s = simplex_solver()
    add_constraints(s, g)

    add_constraints(s, [
        width(g) == 800,
        height(g) == 400,
        leftedge(g) == 0,
        bottomedge(g) == 0
    ])

    p = plot(legend = false)
    plot!(g)
    p
end

test_grid()
