mutable struct Constraint
    expr::LinearExpression
    op::Relation
    str::strength
end

Base.show(io::IO, c::Constraint) = begin
    println(io, c.expr, " ", string(c.op), " ", 0, " | ", c.str)
end

Constraint(e::LinearExpression, op::Relation) = begin
    Constraint(e, op, required())
end

Constraint(lhs::Variable, op::Relation, rhs::LinearExpression, str::strength = required()) = begin
    Constraint(div!(rhs, lhs), op, str)
end

Constraint(lhs::LinearExpression, op::Relation, rhs::LinearExpression, str::strength = required()) = begin
    Constraint(div!(rhs, lhs), op, str)
end

Base.copy(c::Constraint) = begin
    exprcopy = copy(c.expr)
    Constraint(exprcopy, c.op, c.str)
end

Constraint(c::Constraint, s::strength) = begin
    cnew = copy(c)
    cnew.str = s
    cnew
end

Constraint(c::Constraint) = Constraint(c.expr, c.op, c.str) # not sure

set_strength(c::Constraint, s::strength) = begin
    c.str = s
end

is_required(c::Constraint) = is_required(c.str)
is_inequality(c::Constraint) = c.op != eq

is_satisfied(c::Constraint) = begin
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

# linear Expression & linear Expression
==(first::LinearExpression, second::LinearExpression) = Constraint(first - second, eq)
# linear Expression & Variable
==(le::LinearExpression, v::Variable) = le == LinearExpression(v)
==(v::Variable, le::LinearExpression) = le == v
# Variable & constant
==(v::Variable, constant::Number) = LinearExpression(v) == LinearExpression(constant)
==(constant::Number, v::Variable) = LinearExpression(v) == LinearExpression(constant)  # arguments flipped as in src, otherwise x == 100 not the same as 100 == x
# linear Expression & constant
==(le::LinearExpression, constant::Number) = le == LinearExpression(constant)
==(constant::Number, le::LinearExpression) = le == LinearExpression(constant)  # arguments flipped
# Variable & Variable
==(v::Variable{T}, v2::Variable{T}) where {T}  = LinearExpression(v) == LinearExpression(v2)


# linear Expression & linear Expression
<=(first::LinearExpression, second::LinearExpression) = Constraint(first - second, leq)
# linear Expression & Variable
<=(le::LinearExpression, v::Variable) = le <= LinearExpression(v)
<=(v::Variable, le::LinearExpression) = LinearExpression(v) <= le
# Variable & constant
<=(v::Variable, constant::Number) = LinearExpression(v) <= LinearExpression(constant)
<=(constant::Number, v::Variable) = LinearExpression(constant) <= LinearExpression(v)
# linear Expression & constant
<=(le::LinearExpression, constant::Number) = le <= LinearExpression(constant)
<=(constant::Number, le::LinearExpression) = LinearExpression(constant) <= le
# Variable & Variable
<=(v::Variable, v2::Variable) = LinearExpression(v) <= LinearExpression(v2)


# linear Expression & linear Expression
>=(first::LinearExpression, second::LinearExpression) = Constraint(first - second, geq)
# linear Expression & Variable
>=(le::LinearExpression, v::Variable) = le >= LinearExpression(v)
>=(v::Variable, le::LinearExpression) = LinearExpression(v) >= le
# Variable & constant
>=(v::Variable, constant::Number) = LinearExpression(v) >= LinearExpression(constant)
>=(constant::Number, v::Variable) = LinearExpression(constant) >= LinearExpression(v)
# linear Expression & constant
>=(le::LinearExpression, constant::Number) = le >= LinearExpression(constant)
>=(constant::Number, le::LinearExpression) = LinearExpression(constant) >= le
# Variable & Variable
>=(v::Variable, v2::Variable) = LinearExpression(v) >= LinearExpression(v2)

|(c::Constraint, s::strength) = Constraint(c, s)
