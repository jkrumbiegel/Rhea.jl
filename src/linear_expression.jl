const linear_expression = expression{variable{Float64}}

function evaluate(e::linear_expression)
    result = e.constant
    for (var, coeff) in e.terms
        result += value(var) * coeff
    end
    return result
end

# linear_expression(e::linear_expression) = begin
#
# end

import Base: +, -, *, /

+(e::linear_expression, x::Number) = begin
    enew = copy(e)
    add!(enew, x)
    enew
end

+(e1::linear_expression, e2::linear_expression) = begin
    enew = copy(e1)
    add!(enew, e2)
    enew
end

+(e::linear_expression, v::variable{T}) where {T} = begin
    enew = copy(e)
    add!(enew, v)
    enew
end

-(e::linear_expression, x::Number) = begin
    enew = copy(e)
    sub!(enew, x)
    enew
end

-(e1::linear_expression, e2::linear_expression) = begin
    enew = copy(e1)
    sub!(enew, e2)
    enew
end

-(e::linear_expression, v::variable{T}) where {T} = begin
    enew = copy(e)
    sub!(enew, v)
    enew
end



*(v::variable{T}, x::Real) where {T} = linear_expression(v, x)
*(x::Real, v::variable{T}) where {T} = linear_expression(v, x)
# /(v::variable{T}, x::Real) where {T} = variable(v.p / x)
+(v::variable{T}, x::Real) where {T} = linear_expression(v, 1, x)
+(v1::variable{T}, v2::variable{T}) where {T} = begin
    e = linear_expression(v1)
    add!(e, v2)
    return e
end
# +(x::Real, v::variable{T}) where {T} = v + x
-(v::variable{T}, x::Real) where {T} = linear_expression(v, 1, -x)
-(v1::variable{T}, v2::variable{T}) where {T} = begin
    e = linear_expression(v1)
    sub!(e, v2)
    return e
end