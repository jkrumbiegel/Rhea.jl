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

@testset "printing" begin
    x = variable(5)
    y = variable(2)
    z = variable(3.37)
    expr = linear_expression(x * 2 - y + 4 * z - 1)
    println(expr)
    n = nil_var()
    println(n)
    c = expr >= 5
    println(c)
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

@testset "symbols" begin
    s1 = symbol(:e)
    @test s1.id == 0
    s2 = symbol(:s)
    @test s2.id == 1
    @test_throws ErrorException s3 = symbol(:k)
    s3 = symbol()
    @test s3.typ == :n
    @test_throws ErrorException s4 = symbol(:s, 4)
end

@testset "constraint 1 test" begin
    x = variable(0)
    s = simplex_solver()
    add_constraint(s, x == 10)
    @test value(x) == 10.0
    # add_constraint(s, x >= 15)
end

@testset "delete 1 test" begin
    x = variable(0)
    solver = simplex_solver()
    init = constraint(x == 100, weak())
    add_constraint(solver, init)
    @test value(x) == 100
    c10 = constraint(x <= 10)
    c20 = constraint(x <= 20)
    add_constraint(solver, c10)
    add_constraint(solver, c20)
    @test value(x) == 10
    remove_constraint(solver, c10)
    @test value(x) == 20
    remove_constraint(solver, c20)
    @test value(x) == 100
    add_constraint(solver, c10)
    @test value(x) == 10
    remove_constraint(solver, c10)
    @test value(x) == 100
    remove_constraint(solver, init)
end

@testset "delete 2 test" begin
    x = variable(0)
    y = variable(0)
    solver = simplex_solver()
    add_constraints(solver, [
        (x == 100) | weak(),
        (y == 120) | strong()
    ])
    @test value(x) == 100
    @test value(y) == 120

    c10 = x <= 10
    c20 = x <= 20

    add_constraint(solver, c10)
    add_constraint(solver, c20)
    @test value(x) == 10
    remove_constraint(solver, c10)
    @test value(x) == 20

    cxy = constraint(x * 2 == y)
    add_constraint(solver, cxy)
    @test value(x) == 20
    @test value(y) == 40

    remove_constraint(solver, c20)
    @test value(x) == 60
    @test value(y) == 120

    remove_constraint(solver, cxy)
    @test value(x) == 100
    @test value(y) == 120
end

@testset "delete 3 test" begin
    x = variable(0)
    solver = simplex_solver()

    add_constraint(solver, (x == 100) | weak())
    @test value(x) == 100

    c10 = x <= 10
    c10b = x <= 10

    add_constraints(solver, [c10, c10b])
    @test value(x) == 10
    remove_constraint(solver, c10)
    @test value(x) == 10
    remove_constraint(solver, c10b)
    @test value(x) == 100
end

@testset "set constant 1 test" begin
    x = variable(0)
    solver = simplex_solver()
    cn = add_constraint(solver, x == 100)
    @test value(x) == 100
    set_constant(solver, cn, 110)
    @test value(x) == 110

    set_constant(solver, cn, 150)
    @test value(x) == 150

    set_constant(solver, cn, -25)
    @test value(x) == -25
end

@testset "set constant 2 test" begin
    x = variable(0)
    solver = simplex_solver()
    cn = add_constraint(solver, (x == 100) | medium())
    @test value(x) == 100
    set_constant(solver, cn, 110)
    @test value(x) == 110

    set_constant(solver, cn, 150)
    @test value(x) == 150

    set_constant(solver, cn, -25)
    @test value(x) == -25
end

@testset "set constant 3 test" begin
    x = variable(0)
    solver = simplex_solver()
    cn = add_constraint(solver, x >= 100)
    @test value(x) == 100
    set_constant(solver, cn, 110)
    @test value(x) == 110

    set_constant(solver, cn, 150)
    @test value(x) == 150

    set_constant(solver, cn, -25)
    @test value(x) == -25
end

@testset "set constant 4 test" begin
    x = variable(0)
    solver = simplex_solver()
    cn = add_constraint(solver, x <= 100)
    @test value(x) == 100
    set_constant(solver, cn, 50)
    @test value(x) == 50

    set_constant(solver, cn, 150)
    @test value(x) == 150

    set_constant(solver, cn, -25)
    @test value(x) == -25
end

@testset "set constant 5 test" begin
    x = variable(0)
    solver = simplex_solver()
    cn = add_constraint(solver, (x >= 100) | medium())
    @test value(x) == 100
    set_constant(solver, cn, 110)
    @test value(x) == 110

    set_constant(solver, cn, 150)
    @test value(x) == 150
end

@testset "set constant 6 test" begin
    x = variable()
    solver = simplex_solver()
    cn = add_constraint(solver, (x <= 100) | medium())
    @test value(x) == 100
    set_constant(solver, cn, 50)
    @test value(x) == 50

    set_constant(solver, cn, -10)
    @test value(x) == -10
end

@testset "casso 1 test" begin
    x = variable()
    y = variable()
    solver = simplex_solver()
    add_constraints(solver, [
        x <= y,
        y == x + 3,
        (x == 10) | weak(),
        (y == 10) | weak()
    ])
    @test (value(x) == 10 && value(y) == 13) || (value(x) == 7 && value(y) == 10)
end

@testset "casso 1 test" begin
    x = variable()
    y = variable()
    solver = simplex_solver()
    add_constraints(solver, [
        x <= y,
        y == x + 3,
        x == 10
    ])
    @test value(x) == 10
    @test value(y) == 13
end

@testset "inconsistent 1 test" begin
    x = variable()
    solver = simplex_solver()
    add_constraint(solver, x == 10)
    @test_throws ErrorException add_constraint(solver, x == 5)
end

@testset "inconsistent 2 test" begin
    x = variable()
    solver = simplex_solver()
    @test_throws ErrorException add_constraints(solver, [x >= 10, x <= 5])
end

@testset "inconsistent 3 test" begin
    x = variable()
    v = variable()
    w = variable()
    y = variable()
    solver = simplex_solver()
    add_constraints(solver, [v >= 10, w >= v, x >= w, y >= x])
    @test_throws ErrorException add_constraint(solver, y <= 5)
end

@testset "bug 0 test" begin
    x = variable()
    y = variable()
    z = variable()
    solver = simplex_solver()

    add_edit_vars(solver, [x, y, z])
    suggest_value(solver, x, 1)
    suggest_value(solver, z, 2)
    remove_edit_var(solver, y)
    suggest_value(solver, x, 3)
    suggest_value(solver, z, 4)

    @test has_edit_var(solver, x)
    @test !has_edit_var(solver, y)

    update_external_variables(solver)
    @test value(x) == 3
end

@testset "bad strength" begin
    v = variable(0)
    solver = simplex_solver()
    @test_throws ErrorException add_edit_var(solver, v, strong(0))
    @test_throws ErrorException add_edit_var(solver, v, required())
end

@testset "bug 16" begin
    a = variable(1)
    b = variable(2)
    solver = simplex_solver()

    add_constraints(solver, [a == b])
    suggest(solver, a, 3)

    @test value(a) == 3
    @test value(b) == 3
end

@testset "bug 16b" begin
    a = variable()
    b = variable()
    c = variable()
    solver = simplex_solver()

    add_constraints(solver, [a == 10, b == c])
    suggest(solver, c, 100)

    @test value(a) == 10
    @test value(b) == 100
    @test value(c) == 100

    suggest(solver, c, 90)
    @test value(a) == 10
    @test value(b) == 90
    @test value(c) == 90
end

@testset "nonlinear" begin
    x = variable()
    y = variable()
    solver = simplex_solver()

    @test_throws MethodError add_constraint(solver, x == 5 / y)
    @test_throws ErrorException add_constraint(solver, x == y * y)

    const2 = linear_expression(2)
    add_constraint(solver, x == y / const2)
end

@testset "layout" begin
    cont_w = variable()
    cont_h = variable()
    inner_w = variable()
    inner_h = variable()
    inner_t = variable()
    inner_b = variable()
    inner_l = variable()
    inner_r = variable()
    solver = simplex_solver()

    add_constraints(solver, [
        cont_w == 1000,
        cont_h == 800,
        inner_w == 2 * inner_h,
        inner_t == inner_b,
        inner_t >= 60,
        inner_l >= 30,
        cont_w == inner_l + inner_r + inner_w,
        cont_h == inner_t + inner_b + inner_h,
        inner_l == inner_r
    ])
    # suggest(solver, inner_t, 70)
    @test value(cont_w) == 1000
    @test value(cont_h) == 800
end
