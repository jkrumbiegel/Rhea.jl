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
bottomspine(a::Axis) = a.b
bottomspine(b::Box) = bottomspine(b.c[end])
leftspine(a::Axis) = a.l
leftspine(b::Box) = leftspine(b.c[1])
rightspine(a::Axis) = a.r
rightspine(b::Box) = rightspine(b.c[end])

axiswidth(a::Axis) = rightspine(a) - leftspine(a)
axisheight(a::Axis) = topspine(a) - bottomspine(a)
axiswidth(b::Box) = rightspine(b) - leftspine(b)
axisheight(b::Box) = topspine(b) - bottomspine(b)

width(o::Union{Box, Axis}) = rightedge(o) - leftedge(o)
height(o::Union{Box, Axis}) = topedge(o) - bottomedge(o)

leftedge(a::Axis) = leftspine(a) - a.sl
rightedge(a::Axis) = rightspine(a) + a.sr
topedge(a::Axis) = topspine(a) + a.st
bottomedge(a::Axis) = bottomspine(a) - a.sb



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

leftedge(b::Vbox) = begin
    (_, ax) = leftmostax(b)
    leftedge(ax)
end
rightedge(b::Vbox) = begin
    (_, ax) = rightmostax(b)
    rightedge(ax)
end
topedge(b::Vbox) = topedge(b.c[1])
bottomedge(b::Vbox) = bottomedge(b.c[end])

leftedge(b::Hbox) = leftedge(b.c[1])
rightedge(b::Hbox) = rightedge(b.c[end])
topedge(b::Hbox) = begin
    (_, ax) = topmostax(b)
    topedge(ax)
end
bottomedge(b::Hbox) = begin
    (_, ax) = bottommostax(b)
    bottomedge(ax)
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

test_constraint_layout()
