mutable struct expression{T}
    constant::Float64
    terms::Dict{T, Float64}
    # expression(c, t::Dict{T, Float64}) where {T} = begin
    #     @show new{T}(c, t)
    # end
end

expression{T}(constant::Real) where {T} = begin
    d = Dict{T, Float64}()
    expression(Base.convert(Float64, constant), d)
end

expression{T}(v::T, coeff::Real = 1.0, constant::Real = 0.0) where {T} = begin
    coeff = Base.convert(Float64, coeff)
    constant = Base.convert(Float64, constant)
    d = Dict(v => coeff)
    expression(constant, d)
end

expression{T}(e::expression{T}) where {T} = copy(e)

Base.copy(e::expression{T}) where {T} = begin
    expression(e.constant, e.terms)
end

mutable struct term{T}
    id::T
    coeff::Float64
end

function add(e::expression{T}, c::Float64) where {T}
     e.constant += c
 end

function add(e::expression{T}, v::T, coeff::Float64 = 1.0) where {T}
    if near_zero(e.terms[v] + coeff)
        delete!(e.terms, v)
    else
        e.terms[v] += coeff
    end
end

function erase(e::expression{T}, v::T) where {T}
    delete!(e.terms, v)
end

function substitute_out(e::expression{T}, v::T, esub::expression{T}) where {T}
    if !haskey(e.terms, v)
        return false
    else
        multiplier = e.terms[v]
        delete!(e.terms, v)

        e.constant += multiplier * esub.constant

        for (term, coeff) in esub.terms
            add(e, term, multiplier * coeff)
        end
        return true
    end
end


function change_subject(
    e::expression{T},
    old_subj::T,
    new_subj::T
    ) where {T}

    if old_subj == new_subj
        return
    end

    temp = new_subject(new_subj)
    e.terms[old_subj] = tmp
end

function mult!(e::expression{T}, x::Real) where {T}
    e.constant *= x
    for term in keys(e.terms)
        e.terms[term] *= x
    end
    e
end

function mult!(e::expression{T}, x::expression{T}) where {T}
    if is_constant(e)
        c = e.constant
        e.constant = x.constant
        e.terms = x.terms
        return mult!(e, c)
    end

    if !is_constant(x)
        error("Nonlinear expression")
    end
    return mult!(e, x.constant)
end

function div!(e::expression{T}, x::Real) where {T}
    mult!(e, 1 / x)
    return e
end

function div!(e::expression{T}, x::expression{T}) where {T}
    if !is_constant(x)
        error("Nonlinear expression")
    end
    return div!(e, x.constant)
end

function add!(e::expression{T}, x::Real) where {T}
    e.constant += x
    return e
end

function add!(e::expression{T}, x::expression{T}) where {T}
    e.constant += x.constant
    for (t, coeff) in x.terms
        add!(e, term(t, coeff))
    end
    return e
end

function add!(e::expression{T}, x::T) where {T}
    return add!(e, term(x, 1.0))
end

function add!(e::expression{T}, x::term{T}) where {T}
    if haskey(e.terms, x.id)
        e.terms[x.id] += x.coeff
        if near_zero(e.terms[x.id])
            erase(e, x.id)
        end
    else
        e.terms[x.id] = x.coeff
    end
    return e
end

function sub!(e::expression{T}, x::Real) where {T}
    e.constant -= x
    return e
end

function sub!(e::expression{T}, x::expression{T}) where {T}
    e.constant -= x.constant
    for (t, coeff) in x.terms
        sub!(e, term(t, coeff))
    end
    return e
end

function sub!(e::expression{T}, x::term{T}) where {T}
    if haskey(e.terms, x.id)
        e.terms[x.id] -= x.coeff
        if near_zero(e.terms[x.id])
            erase(e, x.id)
        end
    else
        e.terms[x.id] = -x.coeff
    end
    return e
end

function sub!(e::expression{T}, x::T) where {T}
    return sub!(e, term(x, 1.0))
end


function solve_for(e::expression{T}, v::T) where {T}
    if !haskey(e.terms, v)
        error("Cannot solve for unknown term $v")
    else
        coeff = -1.0 / e.terms[v]
        erase(e, v)
        mult!(e, coeff)
    end
end

function solve_for(e::expression{T}, lhs::T, rhs::T) where {T}
    sub!(e, lhs)
    solve_for(e, rhs)
end

function coefficient(e::expression{T}, v::T) where {T}
    if !haskey(e.terms, v)
        return 0.0
    else
        return e.terms[v]
    end
end

function is_constant(e::expression{T}) where {T}
    return isempty(e.terms)
end

function set_constant(e::expression{T}, x::Float64) where {T}
    e.constant = x
end

function empty(e::expression{T}) where {T}
    is_constant(e) && e.constant == 0
end
