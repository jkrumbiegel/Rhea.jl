module Rhea

## include files

include("strength.jl")

include("variable.jl")

include("approx.jl")

include("expression.jl")

include("linearexpression.jl")

include("relation.jl")

include("constraint.jl")

include("symbol.jl")

include("simplex_solver.jl")

## begin exports

# strength
export strength, is_required, required, strong, weak, medium

# variable
export variable, fvariable, is_nil, nil_var, value, int_value, set_value, is

# approx
export expression, add!, sub!, div!, mult!, substitute_out, coefficient

# linearexpression
export LinearExpression, evaluate

# relation
export relation, eq, geq, leq, reverse_inequality

# constraint
export constraint, set_strength, is_required, is_inequality, is_satisfied

# symbol
export symbol, is_nil, is_external, is_slack, is_pivotable, is_restricted,
    is_unrestricted, dummy, slack, errorsym, external

# simplex_solver
export simplex_solver, row, add_constraint, add_constraints,
    update_external_variables, remove_constraint, set_constant,
    add_edit_var, add_edit_vars, suggest_value, remove_edit_var,
    has_edit_var, suggest

end # module
