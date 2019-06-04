mutable struct item
    c::constraint
    v::Float64
end

mutable struct stays{T}
    solver::simplex_solver
    stays::IdDict{variable{T},item}
    stays(solver::simplex_solver, T::Type) = new{T}(solver, IdDict{variable{T},item}())
end

function add(s::stays, v::variable)
    if !haskey(s.stays, v)
        c = (v == value(v)) | weak()
        s.stays[v] = item(c, value(v))
        add_constraint(s.solver, c)
    else
        error("Stay variable already exists")
    end
end

function remove(s::stays, v::variable)
    if haskey(s.stays, v)
        remove_constraint(s.solver, s.stays[v].c)
        delete!(s.stays, v)
    else
        error("Stay variable doesn't exist")
    end
end

function update(s::stays)
    for (var, it) in s.stays
        if value(var) != it.v
            println(s.solver)
            println(it.c)
            remove_constraint(s.solver, it.c)
            it.v = value(var)
            it.c = (var == it.v) | weak()
            add_constraint(s.solver, it.c)
        end
    end
end
