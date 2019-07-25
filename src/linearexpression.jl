const LinearExpression = Expression{Variable{Float64}}

function evaluate(e::LinearExpression)
    result = e.constant
    for (var, coeff) in e.terms
        result += value(var) * coeff
    end
    return result
end

import Base: +, -, *, /

+(e::LinearExpression, x::Number) = begin
    enew = copy(e)
    add!(enew, x)
    enew
end

+(e1::LinearExpression, e2::LinearExpression) = begin
    enew = copy(e1)
    add!(enew, e2)
    enew
end

+(e::LinearExpression, v::Variable{T}) where {T} = begin
    enew = copy(e)
    add!(enew, v)
    enew
end

+(v::Variable{T}, e::LinearExpression) where {T} = begin
    enew = LinearExpression(v)
    add!(enew, e)
    enew
end

-(e::LinearExpression, x::Number) = begin
    enew = copy(e)
    sub!(enew, x)
    enew
end

-(e1::LinearExpression, e2::LinearExpression) = begin
    enew = copy(e1)
    sub!(enew, e2)
    enew
end

-(e::LinearExpression, v::Variable{T}) where {T} = begin
    enew = copy(e)
    sub!(enew, v)
    enew
end

-(v::Variable{T}, e::LinearExpression) where {T} = begin
    enew = LinearExpression(v)
    sub!(enew, e)
    enew
end

/(e::LinearExpression, x::Real) = begin
    enew = copy(e)
    div!(enew, x)
    enew
end

/(e::LinearExpression, e2::LinearExpression) = begin
    enew = copy(e)
    div!(enew, e2)
    enew
end

/(v::Variable, e2::LinearExpression) = begin
    enew = LinearExpression(v)
    div!(enew, e2)
    enew
end

*(v1::Variable, v2::Variable) = begin
    enew = LinearExpression(v1)
    mult!(enew, LinearExpression(v2))
    enew
end


*(v::Variable{T}, x::Real) where {T} = LinearExpression(v, x)
*(x::Real, v::Variable{T}) where {T} = LinearExpression(v, x)
/(v::Variable{T}, x::Real) where {T} = LinearExpression(v, 1 / x)
+(v::Variable{T}, x::Real) where {T} = LinearExpression(v, 1, x)
+(v1::Variable{T}, v2::Variable{T}) where {T} = begin
    e = LinearExpression(v1)
    add!(e, v2)
    return e
end

-(v::Variable{T}, x::Real) where {T} = LinearExpression(v, 1, -x)
-(v1::Variable{T}, v2::Variable{T}) where {T} = begin
    e = LinearExpression(v1)
    sub!(e, v2)
    return e
end
