struct strength
    weight::Float64
end

function check(v)
    if v < 1 || v >= 1000
        error("Bad Weight")
    end
end

Base.show(io::IO, s::strength) = begin
    if is_required(s)
        print(io, "required")
    else
        print(io, s)
    end
end

convert(::Type{Float64}, s::strength) = s.weight

required() = strength(1000 * 1000 * 1000)
strong() = strength(1000 * 1000)
medium() = strength(1000)
weak() = strength(1)

function strong(weight)
    check(weight)
    strength(weight * 1000 * 1000)
end

function medium(weight)
    check(weight)
    strength(weight * 1000)
end

function weak(weight)
    check(weight)
    strength(weight)
end

is_required(s::strength) = s.weight == required().weight

import Base: ==, !=, <=, <, >=, >, -
==(s1::strength, s2::strength) = s1.weight == s2.weight
!=(s1::strength, s2::strength) = s1.weight != s2.weight
<=(s1::strength, s2::strength) = s1.weight <= s2.weight
<(s1::strength, s2::strength) = s1.weight < s2.weight
>=(s1::strength, s2::strength) = s1.weight >= s2.weight
>(s1::strength, s2::strength) = s1.weight > s2.weight

-(s::strength) = -s.weight
