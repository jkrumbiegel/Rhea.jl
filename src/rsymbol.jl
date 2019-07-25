mutable struct counter
    i::Int64
end

const symbolcount = counter(-1)

mutable struct RSymbol
    typ::Symbol
    id::Int64
    RSymbol(c) = begin
        if !(c in Set((:n, :e, :s, :d, :v)))
            error("Unsupported RSymbol type.")
        end
        if c == :n
            new(c, -1)
        else
            symbolcount.i += 1
            new(c, symbolcount.i)
        end
    end
end

Base.show(io::IO, s::RSymbol) = begin
    if is_nil(s)
        print(io, "--")
    else
        print(io, s.typ, s.id)
    end
end

RSymbol(typ, id) = error("Not allowed to assign id yourself")
RSymbol() = RSymbol(:n)
external() = RSymbol(:v)
errorsym() = RSymbol(:e)
slack() = RSymbol(:s)
dummy() = RSymbol(:d)

is_nil(s::RSymbol) = s.typ == :n
is_external(s::RSymbol) = s.typ == :v
is_slack(s::RSymbol) = s.typ == :s
is_error(s::RSymbol) = s.typ == :e
is_dummy(s::RSymbol) = s.typ == :d

is_restricted(s::RSymbol) = !is_external(s)
is_unrestricted(s::RSymbol) = !is_restricted(s)
is_pivotable(s::RSymbol) = is_slack(s) || is_error(s)

is(s::RSymbol, s2::RSymbol) = s.id == s2.id

import Base: ==, !=, <

==(s::RSymbol, s2::RSymbol) = s.id == s2.id
!=(s::RSymbol, s2::RSymbol) = s.id != s2.id
<(s::RSymbol, s2::RSymbol) = s.id < s2.id
