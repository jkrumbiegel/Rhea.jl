mutable struct Variable{T}
    obs::Observable{T}
    Variable(x) = new{typeof(x)}(Observable(x))
    Variable(x::T) where {T<:Observable} = new{T.parameters[1]}(x)
end

Base.show(io::IO, var::Variable) = print(io, "var($(value(var)))")
Base.show(io::IO, var::Variable{Nothing}) = print(io, "NIL")

nil_var() = Variable(nothing)

const FVariable = Variable{Float64}
FVariable() = Variable(0.0)
FVariable(val::Real) = Variable(Base.convert(Float64, val))
Variable(v::Variable) = v

value(v::Variable) = v.obs[]
int_value(v::Variable)::Int = round(v.obs[])
function set_value(v::Variable, val)
    v.obs[] = val
end

is_nil(v::Variable) = isnothing(v.obs[])

is(v::Variable, v2::Variable) = v === v2
