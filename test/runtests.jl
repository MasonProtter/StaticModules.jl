using StaticModules, Test

using StaticModules

@staticmodule Foo begin
    x = 1
    f(y) = x^2 + 2y
end

@test :x ∈ propertynames(Foo)
@test :f ∈ propertynames(Foo) 

@test Foo.x == 1

@test @with Foo begin
    f(1) == 3x
end

@test @with (;f = x -> x + 1, x = 2) begin
    f(1) == x
end

struct  Bar
    a
    b
end

@test @with Bar(1, 2) begin
    (a^2, b^2) == (1, 4)
end

@const_staticmodule X begin
    @staticmodule X begin
        X = 1
    end
end

@test @with X begin
    @with X begin
        X^2 + 1 == 2
    end
end


macro foo()
    quote
        x = 1
        y = 2
    end |> esc
end

@staticmodule Foo begin
    @foo
end

@test Foo.x == 1
@test Foo.y == 2

macro bar()
    esc(:(y))
end

@test @with Foo begin
     @bar() == 2
end
