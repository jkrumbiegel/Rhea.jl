mutable struct Expression{T}
    constant::Float64
    terms::IdDict{T, Float64}
    # Expression(c, t::Dict{T, Float64}) where {T} = begin
    #     @show new{T}(c, t)
    # end
end

Base.show(io::IO, e::Expression) = begin
    print(io, e.constant, (" " * coeff_to_str(coeff) * "⋅$term" for (term, coeff) in e.terms)...)
end

function coeff_to_str(coeff)
    coeff >= 0 ? "+ $coeff" : "- $(-coeff)"
end

Expression{T}(constant::Real = 0.0) where {T} = begin
    d = IdDict{T, Float64}()
    Expression(Base.convert(Float64, constant), d)
end

Expression{T}(v::T, coeff::Real = 1.0, constant::Real = 0.0) where {T} = begin
    coeff = Base.convert(Float64, coeff)
    constant = Base.convert(Float64, constant)
    d = IdDict(v => coeff)
    Expression(constant, d)
end

Expression{T}(e::Expression{T}) where {T} = copy(e)

Base.copy(e::Expression{T}) where {T} = begin
    dictcopy = copy(e.terms)
    Expression(e.constant, dictcopy)
end

mutable struct term{T}
    id::T
    coeff::Float64
end

function add(e::Expression{T}, c::Float64) where {T}
     e.constant += c
 end

function add(e::Expression{T}, v::T, coeff::Float64 = 1.0) where {T}
    if haskey(e.terms, v)
        e.terms[v] += coeff
        if near_zero(e.terms[v])
            delete!(e.terms, v)
        end
    else
        e.terms[v] = coeff
    end
end

function erase(e::Expression{T}, v::T) where {T}
    delete!(e.terms, v)
end

function substitute_out(e::Expression{T}, v::T, esub::Expression{T}) where {T}
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
    e::Expression{T},
    old_subj::T,
    new_subj::T
    ) where {T}

    if old_subj == new_subj
        return
    end

    temp = new_subject(new_subj)
    e.terms[old_subj] = tmp
end

function mult!(e::Expression{T}, x::Real) where {T}
    e.constant *= x
    for term in keys(e.terms)
        e.terms[term] *= x
    end
    e
end

# think this might be needed for the add function in simplex solver
Base.:*(e::Expression, x::Real) = begin
    enew = copy(e)
    mult!(enew, x)
end

function mult!(e::Expression{T}, x::Expression{T}) where {T}
    if is_constant(e)
        c = e.constant
        e.constant = x.constant
        e.terms = x.terms
        return mult!(e, c)
    end

    if !is_constant(x)
        error("Nonlinear Expression")
    end
    return mult!(e, x.constant)
end

function div!(e::Expression{T}, x::Real) where {T}
    mult!(e, 1 / x)
    return e
end

function div!(e::Expression{T}, x::Expression{T}) where {T}
    if !is_constant(x)
        error("Nonlinear Expression")
    end
    return div!(e, x.constant)
end

function add!(e::Expression{T}, x::Real) where {T}
    e.constant += x
    return e
end

function add!(e::Expression{T}, x::Expression{T}) where {T}
    e.constant += x.constant
    for (t, coeff) in x.terms
        add!(e, term(t, coeff))
    end
    return e
end

function add!(e::Expression{T}, x::T) where {T}
    return add!(e, term(x, 1.0))
end

function add!(e::Expression{T}, x::term{T}) where {T}
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

function sub!(e::Expression{T}, x::Real) where {T}
    e.constant -= x
    return e
end

function sub!(e::Expression{T}, x::Expression{T}) where {T}
    e.constant -= x.constant
    for (t, coeff) in x.terms
        sub!(e, term(t, coeff))
    end
    return e
end

function sub!(e::Expression{T}, x::term{T}) where {T}
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

function sub!(e::Expression{T}, x::T) where {T}
    return sub!(e, term(x, 1.0))
end


function solve_for(e::Expression{T}, v::T) where {T}
    if !haskey(e.terms, v)
        error("Cannot solve for unknown term $v")
    else
        coeff = -1.0 / e.terms[v]
        erase(e, v)
        mult!(e, coeff)
    end
end

function solve_for(e::Expression{T}, lhs::T, rhs::T) where {T}
    sub!(e, lhs)
    solve_for(e, rhs)
end

function coefficient(e::Expression{T}, v::T) where {T}
    if !haskey(e.terms, v)
        return 0.0
    else
        return e.terms[v]
    end
end

function is_constant(e::Expression{T}) where {T}
    return isempty(e.terms)
end

function set_constant(e::Expression{T}, x::Float64) where {T}
    e.constant = x
end

function empty(e::Expression{T}) where {T}
    is_constant(e) && e.constant == 0
end
