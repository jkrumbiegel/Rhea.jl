using Rhea
using Test

@testset "strength test" begin
    @test is_required(required())
    @test !is_required(strong())
    @test !is_required(medium())
    @test !is_required(weak())

    @test required() > strong()
    @test strong() > medium()
    @test medium() > weak()

    @test required() > strong(999)
    @test strong(100) > strong(10)
    @test strong(1) > medium(999)
    @test medium(1) > weak(999)
end

@testset "variable test" begin
    a = variable()
    m = nil_var()
    n = nil_var()
    x = variable(3.0)
    y = variable(x)
    z = variable(3.0)

    @test is_nil(n)
    n = x
    a = y
    @test is_nil(m)
    @test !is_nil(n)
    @test !is_nil(x)
    @test !is_nil(y)

    @test value(x) == 3
    @test int_value(x) == 3
    @test value(y) == 3
    @test value(a) == 3

    @test is(x, y)
    @test !is(x, z)
    @test is(a, x)

    set_value(y, 3.7)
    @test value(n) == 3.7
    @test value(x) == 3.7
    @test int_value(x) == 4

    set_value(y, -3.7)
    @test int_value(x) == -4
end

@testset "linear expressions 1" begin
    e1 = linear_expression(5)
    @test evaluate(e1) == 5
    mult!(e1, -1)
    @test evaluate(e1) == -5

    x = variable(3.0)
    e2 = linear_expression(x, 2.0, 1.0)
    @test evaluate(e2) == 7
    @test evaluate(e2 + 2.0) == 9
    @test evaluate(e2 - 1.0) == 6

    add!(e2, x)
    @test evaluate(e2) == 10
    sub!(e2, x)
    @test evaluate(e2) == 7

    y = variable(2.0)
    add!(e2, y * 5)
    @test evaluate(e2) == 17

    set_value(y, 1)
    @test evaluate(e2) == 12
    set_value(x, 10)
    @test evaluate(e2) == 26

    mult!(e2, -1)
    @test evaluate(e2) == -26

    div!(e2, 2)
    @test evaluate(e2) == -13

    mult!(e1, e2)
    @test evaluate(e1) == 65
end

# @testset "linear expressions 2" begin
#     x = variable(3)
#     test1 = linear_expression(x, 5, 2)
#     test2 = linear_expression(test1)
#
#     @test evaluate(test1) == 17
#     @test evaluate(test2) == 17
# end

@testset "linear expressions 3" begin
    x = variable(5)
    y = variable(2)

    expr = linear_expression(x * 2 + y - 1)
    @test evaluate(expr) == 11

    set_value(x, 4)
    @test evaluate(x + 3) == 7
    @test evaluate(x - 2) == 2
    @test evaluate(x + y) == 6
    @test evaluate(x - y) == 2
end

@testset "linear equation test" begin
    x = variable(2.0)
    y = variable(3.0)
    @test is_satisfied(x == y - 1)
    @test !is_satisfied(x == y)
    @test is_satisfied(x * 2 == y + 1)
    @test !is_satisfied(x * 3 == y * 4)
end

@testset "linear inequality test" begin
    x = variable(2.0)
    y = variable(3.0)
    x <= y
    @test is_satisfied(x + 1 <= y)
    @test is_satisfied(x * 2 + y >= 4)
    @test is_satisfied(x * 3 >= y * 2)
    @test !is_satisfied(x >= y)
end

@testset "substitute out test" begin
    x = variable()
    y = variable()
    z = variable()
    c1 = linear_expression(x * 4 + y * 2 + z)
    substitute_out(c1, y, z + 3)
    @test c1.constant == 6
    @test coefficient(c1, x) == 4
    @test coefficient(c1, y) == 0
    @test coefficient(c1, z) == 3
end
