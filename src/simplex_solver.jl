const row = expression{symbol}

mutable struct simplex_solver
    auto_update::Bool
    vars::Dict{variable, symbol}
    rows::Dict{symbol, row}
    constraints::Dict{constraint, constraint_info}
    infeasible_rows::Vector{symbol}
    edits::Dict{variable, edit_info}
    stays::Dict{variable, stay_info}
    objective::row
    artificial::row
end

struct stay_info
    c::constraint
    plus::symbol
    minus::symbol
end

struct edit_info
    c::constraint
    plus::symbol
    minus::symbol
    prev_constant::Float64
end

struct constraint_info
    marker::symbol
    other::symbol
    prev_constant::Float64
end

struct suggestion
    v::variable
    suggested_value::Float64
end
