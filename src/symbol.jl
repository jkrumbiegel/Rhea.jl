mutable struct counter
    i::Int64
end

const symbolcount = counter(-1)

mutable struct symbol
    typ::Symbol
    id::Int64
    symbol(c) = begin
        if !(c in Set((:n, :e, :s, :d, :v)))
            error("Unsupported symbol type.")
        end
        if c == :n
            new(c, -1)
        else
            symbolcount.i += 1
            new(c, symbolcount.i)
        end
    end
end

Base.show(io::IO, s::symbol) = begin
    if is_nil(s)
        print(io, "--")
    else
        print(io, s.typ, s.id)
    end
end

symbol(typ, id) = error("Not allowed to assign id yourself")
symbol() = symbol(:n)
external() = symbol(:v)
errorsym() = symbol(:e)
slack() = symbol(:s)
dummy() = symbol(:d)

is_nil(s::symbol) = s.typ == :n
is_external(s::symbol) = s.typ == :v
is_slack(s::symbol) = s.typ == :s
is_error(s::symbol) = s.typ == :e
is_dummy(s::symbol) = s.typ == :d

is_restricted(s::symbol) = !is_external(s)
is_unrestricted(s::symbol) = !is_restricted(s)
is_pivotable(s::symbol) = is_slack(s) || is_error(s)

is(s::symbol, s2::symbol) = s.id == s2.id

import Base: ==, !=, <

==(s::symbol, s2::symbol) = s.id == s2.id
!=(s::symbol, s2::symbol) = s.id != s2.id
<(s::symbol, s2::symbol) = s.id < s2.id
