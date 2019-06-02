module Rhea

export strength, is_required, required, strong, weak, medium
include("strength.jl")
export variable, is_nil, nil_var, value, int_value, set_value, is
include("variable.jl")

include("approx.jl")
export expression, add!, sub!, div!, mult!, substitute_out, coefficient
include("expression.jl")
export linear_expression, evaluate
include("linear_expression.jl")
export relation, eq, geq, leq, reverse_inequality
include("relation.jl")
export constraint, set_strength, is_required, is_inequality, is_satisfied
include("constraint.jl")
export symbol, is_nil, is_external, is_slack, is_pivotable, is_restricted,
    is_unrestricted, dummy, slack, errorsym, external
include("symbol.jl")
export simplex_solver, row, add_constraint, update_external_variables, remove_constraint
include("simplex_solver.jl")

end # module
