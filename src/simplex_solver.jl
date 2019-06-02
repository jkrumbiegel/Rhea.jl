const row = expression{symbol}

struct constraint_info
    marker::symbol
    other::symbol
    prev_constant::Float64
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

struct suggestion
    v::variable
    suggested_value::Float64
end

 mutable struct expression_result
    r::row
    var1::Union{symbol, Missing}
    var2::Union{symbol, Missing}
    expression_result() = new(row(), symbol(), symbol())
end

mutable struct simplex_solver
    auto_update::Bool
    vars::IdDict{variable, symbol}
    rows::IdDict{symbol, row}
    constraints::IdDict{constraint, constraint_info}
    infeasible_rows::Vector{symbol}
    edits::IdDict{variable, edit_info}
    stays::IdDict{variable, stay_info}
    objective::row
    artificial::row
end

Base.show(io::IO, constraints::IdDict{constraint, constraint_info}) = begin
    println(io, "$(length(constraints)) constraints:")
    i = 1
    for (con, info) in constraints
        println(io, "[$(i)] ", con)
        println(info)
        i += 1
    end
end

Base.show(io::IO, s::simplex_solver) = begin
    println(io, "Variables:")
    for (var, sym) in s.vars
        println(io, var, " : ", sym)
    end
    println(io, "Constraints:")
    for (c, cinfo) in s.constraints
        println(io, cinfo.marker, " : ", c)
    end
    println(io, "Rows:")
    for (sym, r) in s.rows
        println(io, sym, " : ", r)
    end
    println(io, "Infeasible:")
    for sym in s.infeasible_rows
        print(io, sym, "  ")
    end
    println(io, "\nObjective:\n", s.objective)
end

simplex_solver() = simplex_solver(
    true,
    IdDict(),
    IdDict(),
    IdDict(),
    [],
    IdDict(),
    IdDict(),
    row(),
    row()
)

has_variable(s::simplex_solver) = !isempty(s.vars)
has_edit_var(s::simplex_solver) = !isempty(s.edits)
has_constraint(s::simplex_solver, c::constraint) = haskey(s.constraints, c)

function pivotable_symbol(r::row)
    for (sym, coeff) in r.terms
        if is_pivotable(sym)
            return sym
        end
    end
    return symbol()
end

function make_expression(s::simplex_solver, c::constraint)
    result = expression_result()
    r = result.r
    cexpr = c.expr
    set_constant(r, cexpr.constant)

    for (var, coeff) in cexpr.terms
        add(s, r, get_var_symbol(s, var), coeff)
    end

    if is_inequality(c)
        coeff = c.op == leq ? 1.0 : -1.0
        sl = slack()
        result.var1 = sl
        # add!(r, sl * coeff)
        add!(r, row(sl) * coeff) # hopefully this is meant
        if !is_required(c)
            eminus = errorsym()
            result.var2 = eminus
            sub!(r, eminus * coeff)
            add(s.objective, eminus, c.str.weight)
        end
    elseif is_required(c)
        dum = dummy()
        result.var1 = dum
        add!(r, dum)
    else
        eplus = errorsym()
        eminus = errorsym()
        result.var1 = eplus
        result.var2 = eminus
        sub!(r, eplus)
        add!(r, eminus)
        add(s.objective, eplus, c.str.weight)
        add(s.objective, eminus, c.str.weight)
    end

    if r.constant < 0
        mult!(r, -1.0)
    end
    return result
end

function add_constraint_(s::simplex_solver, c::constraint)
    if has_constraint(s, c)
        error("Duplicate constraint")
    end

    expr = make_expression(s, c)
    subject = choose_subject(expr)

    if is_nil(subject) && all_dummies(expr.r)
        if !near_zero(expr.r.constant)
            error("Required failure")
        end
        subject = expr.var1
    end

    if is_nil(subject)
        if !add_with_artificial_variable(s, expr.r)
            error("Required failure")
        end
    else
        solve_for(expr.r, subject)
        substitute_out(s, subject, expr.r)
        s.rows[subject] = expr.r
    end
    s.constraints[c] = constraint_info(expr.var1, expr.var2, -c.expr.constant)
    optimize(s, s.objective)
end

function add_constraint(s::simplex_solver, c::constraint)
    add_constraint_(s, c)
    autoupdate(s)
    return c
end

function autoupdate(s::simplex_solver)
    if s.auto_update
        update_external_variables(s)
    end
end

function update_external_variables(s::simplex_solver)
    for (var, sym) in s.vars
        if haskey(s.rows, sym)
            set_value(var, s.rows[sym].constant)
        end
    end
end

function optimize(s::simplex_solver, objective::row)
    i = 0
    while i < 5
        entry = symbol()
        for (sy, coeff) in objective.terms
            if !is_dummy(sy) && coeff < 0
                entry = sy
                break
            end
        end

        if is_nil(entry)
            return
        end

        exit = nothing
        min_ratio = prevfloat(Inf)
        r = 0.0
        for (var, expr) in s.rows
            if is_pivotable(var)
                coeff = coefficient(expr, entry)
                if coeff >= 0
                    continue
                end
                r = -expr.constant / coeff
                if r < min_ratio || (approx(r, min_ratio) && var < exit)
                    min_ratio = r
                    exit = var
                    # not correct yet
                end
            end
        end

        if isnothing(exit) # not correct
            error("objective function is unbounded.")
        end
        tmp = row(s.rows[exit])
        delete!(s.rows, exit)
        solve_for(tmp, exit, entry)
        substitute_out(s, entry, tmp)
        s.rows[entry] = tmp
        i += 1
    end
end

function add_with_artificial_variable(s::simplex_solver, r::row)
    av = slack()
    s.rows[av] = r

    #s.artificial = r
    s.artificial = row(r)
    optimize(s, s.artificial)
    success = near_zero(s.artificial.constant)
    s.artificial = row()

    if haskey(s.rows, av)
        it = s.rows[av]
        tmp = row(it)
        delete!(s.rows, av)
        if is_constant(tmp)
            return success
        end
        entering = pivotable_symbol(tmp)
        @assert !is_nil(entering)
        if is_nil(entering)
            return false
        end

        solve_for(tmp, av, entering)
        substitute_out(s, entering, tmp)
        s.rows[entering] = tmp
    end

    for ro in values(s.rows)
        erase(ro, av)
    end
    erase(s.objective, av)
    return success
end

function substitute_out(s::simplex_solver, sy::symbol, r::row)
    for (sym, ri) in s.rows
        substitute_out(ri, sy, r)
        if is_restricted(sym) && ri.constant < 0
            append!(s.infeasible_rows, sym)
        end
    end
    substitute_out(s.objective, sy, r)
    substitute_out(s.artificial, sy, r)
end

function all_dummies(r::row)
    all(is_dummy, keys(r.terms))
end

function choose_subject(expr::expression_result)
    for (var, coeff) in expr.r.terms
        if is_external(var)
            return var
        end
    end

    if is_pivotable(expr.var1)
        if coefficient(expr.r, expr.var1) < 0
            return expr.var1
        end
    end
    if is_pivotable(expr.var2)
        if coefficient(expr.r, expr.var2) < 0
            return expr.var2
        end
    end
    return symbol()
end

function get_var_symbol(s::simplex_solver, v::variable)
    if haskey(s.vars, v)
        return s.vars[v]
    end
    s.vars[v] = external()
    return s.vars[v]
end

function add(s::simplex_solver, r::row, sym::symbol, coeff::Float64)
    if haskey(s.rows, sym)
        add!(r, s.rows[sym] * coeff)
    else
        #add!(r, sym * coeff)
        add!(r, row(sym, coeff)) # hopefully that is meant
    end
end

function remove_constraint_(s::simplex_solver, c::constraint)
    if !haskey(s.constraints, c)
        error("Constraint not found")
    end

    info = s.constraints[c]
    delete!(s.constraints, c)

    if is_error(info.marker)
        add(s.objective, info.marker, -c.str)
    end
    if is_error(info.other)
        add(s.objective, info.other, -c.str)
    end

    if haskey(s.rows, info.marker)
        delete!(s.rows, info.marker)
    else
        leaving = get_marker_leaving_row(s, info.marker)
        if isnothing(leaving)
            error("Failed to find leaving row")
        end
        tmp = s.rows[leaving]
        delete!(s.rows, leaving)
        solve_for(tmp, leaving, info.marker)
        substitute_out(s, info.marker, tmp)
    end
    optimize(s, s.objective)
end

function remove_constraint(s::simplex_solver, c::constraint)
    remove_constraint_(s, c)
    autoupdate(s)
end

function get_marker_leaving_row(s::simplex_solver, marker::symbol)
    dmax = prevfloat(Inf)
    r1 = dmax
    r2 = dmax
    en = length(s.rows) + 1
    first = en
    second = en
    third = en
    syms = collect(keys(s.rows))
    for (i, sym) in enumerate(syms)
        c = coefficient(s.rows[sym], marker)
        if c == 0
            continue
        end
        if is_external(sym)
            third = i
        elseif c < 0
            r = -s.rows[sym].constant / c
            if r < r1
                r1 = r
                first = i
            end
        else
            r = s.rows[sym].constant / c
            if r < r2
                r2 = r
                second = i
            end
        end
    end
    if first != en
        return syms[first]
    end
    if second != en
        return syms[second]
    end
    return third < en ? syms[third] : nothing
end
