mutable struct constraint
    expr::linear_expression
    op::relation
    str::strength
end

Base.show(io::IO, c::constraint) = begin
    println(io, c.expr, " ", string(c.op), " ", 0, " | ", c.str)
end

constraint(e::linear_expression, op::relation) = begin
    constraint(e, op, required())
end

constraint(lhs::variable, op::relation, rhs::linear_expression, str::strength = required()) = begin
    constraint(div!(rhs, lhs), op, str)
end

constraint(lhs::linear_expression, op::relation, rhs::linear_expression, str::strength = required()) = begin
    constraint(div!(rhs, lhs), op, str)
end

Base.copy(c::constraint) = begin
    exprcopy = copy(c.expr)
    constraint(exprcopy, c.op, c.str)
end

constraint(c::constraint, s::strength) = begin
    cnew = copy(c)
    cnew.str = s
    cnew
end

constraint(c::constraint) = constraint(c.expr, c.op, c.str) # not sure

set_strength(c::constraint, s::strength) = begin
    c.str = s
end

is_required(c::constraint) = is_required(c.str)
is_inequality(c::constraint) = c.op != eq

is_satisfied(c::constraint) = begin
    if c.op == eq
        return evaluate(c.expr) == 0
    elseif c.op == leq
        return evaluate(c.expr) <= 0
    elseif c.op == geq
        return evaluate(c.expr) >= 0
    else
        return false
    end
end

import Base: ==, <=, >=, |

==(first::linear_expression, second::linear_expression) = constraint(first - second, eq)
==(le::linear_expression, v::variable) = le == linear_expression(v)
==(v::variable, le::linear_expression) = le == v
==(constant::Number, v::variable) = linear_expression(constant) == linear_expression(v)
==(constant::Number, le::linear_expression) = linear_expression(constant) == le
==(le::linear_expression, constant::Number) = constant == le
==(v::variable, constant::Number) = linear_expression(v) == linear_expression(constant)
==(v::variable{T}, v2::variable{T}) where {T}  = linear_expression(v) == linear_expression(v2)


<=(first::linear_expression, second::linear_expression) = constraint(first - second, leq)
<=(le::linear_expression, v::variable) = le <= linear_expression(v)
<=(constant::Number, v::variable) = linear_expression(constant) <= linear_expression(v)
<=(constant::Number, le::linear_expression) = linear_expression(constant) <= le
<=(le::linear_expression, constant::Number) = le <= linear_expression(constant)
<=(v::variable, constant::Number) = linear_expression(v) <= linear_expression(constant)
<=(v::variable, v2::variable) = linear_expression(v) <= linear_expression(v2)


>=(first::linear_expression, second::linear_expression) = constraint(first - second, geq)
>=(le::linear_expression, v::variable) = le >= linear_expression(v)
>=(constant::Number, v::variable) = linear_expression(constant) >= linear_expression(v)
>=(v::variable, constant::Number) = linear_expression(v) >= linear_expression(constant)
>=(v::variable, v2::variable) = linear_expression(v) >= linear_expression(v2)
>=(constant::Number, le::linear_expression) = linear_expression(constant) >= le
>=(le::linear_expression, constant::Number) = le >= linear_expression(constant)

|(c::constraint, s::strength) = constraint(c, s)
