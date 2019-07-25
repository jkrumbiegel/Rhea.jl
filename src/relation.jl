@enum Relation begin
    eq = 0
    leq = 1
    geq = -1
end

reverse_inequality(r::Relation) = Relation(-Int(r))

Base.show(io::IO, r::Relation) = begin
    if r == eq
        print(io, "==")
    elseif r == leq
        print(io, "<=")
    elseif r == geq
        print(io, ">=")
    else
        error()
    end
end

Base.string(r::Relation) = begin
    if r == eq
        return "=="
    elseif r == leq
        return "<="
    elseif r == geq
        return ">="
    else
        error()
    end
end
