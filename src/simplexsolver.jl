const Row = Expression{RSymbol}

mutable struct constraint_info
    marker::RSymbol
    other::RSymbol
    prev_constant::Float64
end

struct stay_info
    c::Constraint
    plus::RSymbol
    minus::RSymbol
end

mutable struct edit_info
    c::Constraint
    plus::RSymbol
    minus::RSymbol
    prev_constant::Float64
end

struct suggestion
    v::Variable
    suggested_value::Float64
end

 mutable struct expression_result
    r::Row
    var1::Union{RSymbol, Missing}
    var2::Union{RSymbol, Missing}
    expression_result() = new(Row(), RSymbol(), RSymbol())
end

mutable struct SimplexSolver
    auto_update::Bool
    vars::IdDict{Variable, RSymbol}
    rows::IdDict{RSymbol, Row}
    constraints::IdDict{Constraint, constraint_info}
    infeasible_rows::Vector{RSymbol}
    edits::IdDict{Variable, edit_info}
    stays::IdDict{Variable, stay_info}
    objective::Row
    artificial::Row
end

Base.show(io::IO, constraints::IdDict{Constraint, constraint_info}) = begin
    println(io, "$(length(constraints)) constraints:")
    i = 1
    for (con, info) in constraints
        println(io, "[$(i)] ", con)
        println(info)
        i += 1
    end
end

Base.show(io::IO, s::SimplexSolver) = begin
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

SimplexSolver(autoupdate=true) = SimplexSolver(
    autoupdate,
    IdDict(),
    IdDict(),
    IdDict(),
    [],
    IdDict(),
    IdDict(),
    Row(),
    Row()
)

has_variable(s::SimplexSolver) = !isempty(s.vars)
has_edit_var(s::SimplexSolver) = !isempty(s.edits)
has_constraint(s::SimplexSolver, c::Constraint) = haskey(s.constraints, c)

function has_edit_var(s::SimplexSolver, v::Variable)
    haskey(s.edits, v)
end

function pivotable_symbol(r::Row)
    for (sym, coeff) in r.terms
        if is_pivotable(sym)
            return sym
        end
    end
    return RSymbol()
end

function make_expression(s::SimplexSolver, c::Constraint)
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
        add!(r, Row(sl) * coeff) # hopefully this is meant
        if !is_required(c)
            eminus = errorsym()
            result.var2 = eminus
            # sub!(r, eminus * coeff)
            sub!(r, Row(eminus) * coeff)  # hopefully this is meant
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

function add_constraint_(s::SimplexSolver, c::Constraint)
    if has_constraint(s, c)
        error("Duplicate Constraint")
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

function add_constraint(s::SimplexSolver, c::Constraint)
    add_constraint_(s, c)
    autoupdate(s)
    return c
end

function add_constraints(s::SimplexSolver, constraints::Vector{Constraint})
    for c in constraints
        add_constraint_(s, c)
    end
    autoupdate(s)
    return constraints
end

function autoupdate(s::SimplexSolver)
    if s.auto_update
        update_external_variables(s)
    end
end

function update_external_variables(s::SimplexSolver)
    for (var, sym) in s.vars
        if haskey(s.rows, sym)
            set_value(var, s.rows[sym].constant)
        end
    end
end

function optimize(s::SimplexSolver, objective::Row)
    while true
        entry = RSymbol()
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
        tmp = Row(s.rows[exit])
        delete!(s.rows, exit)
        solve_for(tmp, exit, entry)
        substitute_out(s, entry, tmp)
        s.rows[entry] = tmp
    end
end

function add_with_artificial_variable(s::SimplexSolver, r::Row)
    av = slack()
    s.rows[av] = r

    #s.artificial = r
    s.artificial = Row(r)
    optimize(s, s.artificial)
    success = near_zero(s.artificial.constant)
    s.artificial = Row()

    if haskey(s.rows, av)
        it = s.rows[av]
        tmp = Row(it)
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

function substitute_out(s::SimplexSolver, sy::RSymbol, r::Row)
    for (sym, ri) in s.rows
        substitute_out(ri, sy, r)
        if is_restricted(sym) && ri.constant < 0
            push!(s.infeasible_rows, sym)
        end
    end
    substitute_out(s.objective, sy, r)
    substitute_out(s.artificial, sy, r)
end

function all_dummies(r::Row)
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
    return RSymbol()
end

function get_var_symbol(s::SimplexSolver, v::Variable)
    if haskey(s.vars, v)
        return s.vars[v]
    end
    s.vars[v] = external()
    return s.vars[v]
end

function add(s::SimplexSolver, r::Row, sym::RSymbol, coeff::Float64)
    if haskey(s.rows, sym)
        add!(r, s.rows[sym] * coeff)
    else
        #add!(r, sym * coeff)
        add!(r, Row(sym, coeff)) # hopefully that is meant
    end
end

function remove_constraint_(s::SimplexSolver, c::Constraint)
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
            error("Failed to find leaving Row")
        end
        tmp = s.rows[leaving]
        delete!(s.rows, leaving)
        solve_for(tmp, leaving, info.marker)
        substitute_out(s, info.marker, tmp)
    end
    optimize(s, s.objective)
end

function remove_constraint(s::SimplexSolver, c::Constraint)
    remove_constraint_(s, c)
    autoupdate(s)
end

function get_marker_leaving_row(s::SimplexSolver, marker::RSymbol)
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

function set_constant_(s::SimplexSolver, c::Constraint, constant::Real)
    if !haskey(s.constraints, c)
        error("Constraint not found")
    end
    evs = s.constraints[c]
    delta = -(constant - evs.prev_constant)
    evs.prev_constant = constant

    if is_slack(evs.marker) || is_required(c)
        if c.op == geq
            delta = -delta
        end
        for (sym, r) in s.rows
            add(r, coefficient(r, evs.marker) * delta)
            if !is_external(sym) && r.constant < 0
                push!(s.infeasible_rows, sym)
            end
        end
    else
        if haskey(s.rows, evs.marker)
            if add(s.rows[evs.marker], -delta) < 0
                push!(s.infeasible_rows, evs.marker)
            end
            return
        end
        if haskey(s.rows, evs.other)
            if add(s.rows[evs.other], delta) < 0
                push!(s.infeasible_rows, evs.other)
            end
            return
        end
        for (sym, r) in s.rows
            add(r, coefficient(r, evs.other) * delta)
            if !is_external(sym) && r.constant < 0
                push!(s.infeasible_rows, sym)
            end
        end
    end
end

function set_constant(s::SimplexSolver, c::Constraint, constant::Real)
    set_constant_(s, c, constant)
    dual_optimize(s)
    autoupdate(s)
end

function dual_optimize(s::SimplexSolver)
    while !isempty(s.infeasible_rows)
        leaving = pop!(s.infeasible_rows)
        if !haskey(s.rows, leaving) || s.rows[leaving].constant >= 0
            continue
        end
        r = s.rows[leaving]
        entering = RSymbol()
        min_ratio = prevfloat(Inf)
        for (sym, coeff) in r.terms
            if coeff > 0 && !is_dummy(sym)
                coeff2 = coefficient(s.objective, sym)
                r = coeff2 / coeff
                if r < min_ratio
                    min_ratio = r
                    entering = sym
                end
            end
        end

        if is_nil(entering)
            error("Dual optimize failed")
        end

        tmp = s.rows[leaving]
        delete!(s.rows, leaving)
        solve_for(tmp, leaving, entering)
        substitute_out(s, entering, tmp)
        s.rows[entering] = tmp
    end
end

function add_edit_var(s::SimplexSolver, v::Variable, str::strength = strong())
    if has_edit_var(s, v)
        error("Duplicate edit Variable")
    end
    if is_required(str)
        error("Bad required strength")
    end
    cn = Constraint(LinearExpression(v), eq, str)
    add_constraint(s, cn)
    ev = s.constraints[cn]
    s.edits[v] = edit_info(cn, ev.marker, ev.other, 0)
    return s
end

function add_edit_vars(s::SimplexSolver, vs::Vector{Variable{T}}, str::strength = strong()) where {T}
    for v in vs
        add_edit_var(s, v, str)
    end
end

function suggest_value_(s::SimplexSolver, v::Variable, value::Real)
    if !haskey(s.edits, v)
        error("Unkown edit Variable")
    end

    info = s.edits[v]
    delta = value - info.prev_constant
    info.prev_constant = value

    if haskey(s.rows, info.plus)
        if add(s.rows[info.plus], -delta) < 0
            push!(s.infeasible_rows, info.plus)
        end
        dual_optimize(s)
        return
    end

    if haskey(s.rows, info.minus)
        if add(s.rows[info.minus], delta) < 0
            push!(s.infeasible_rows, info.minus)
        end
        dual_optimize(s)
        return
    end

    for (sym, ro) in s.rows
        add(ro, coefficient(ro, info.plus) * delta)
        if !is_external(sym) && ro.constant < 0
            push!(s.infeasible_rows, sym)
        end
    end
end

function suggest_value(s::SimplexSolver, v::Variable, x::Real)
    suggest_value_(s, v, x)
    dual_optimize(s)
    return s
end

function remove_edit_var(s::SimplexSolver, v::Variable)
    if !haskey(s.edits, v)
        error("Unknown edit Variable")
    end
    remove_constraint(s, s.edits[v].c)
    delete!(s.edits, v)
end

function remove_edit_vars(s::SimplexSolver, vs::Vector{Variable{T}}) where {T}
    for v in vs
        remove_edit_var(s, v)
    end
end

function suggest(s::SimplexSolver, v::Variable, value::Real)
    if !has_edit_var(s, v)
        add_edit_var(s, v)
    end
    suggest_value(s, v, value)
    autoupdate(s)
end

function suggest(s::SimplexSolver, sugs::Vector{suggestion})
    for sug in sugs
        if !has_edit_var(s, sug.v)
            add_edit_var(s, sug.v)
        end
        suggest_value_(s, sug.v, sug.suggested_value)
    end
    dual_optimize(s)
    auto_update(s)
end
