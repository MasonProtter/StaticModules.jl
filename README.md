# StaticModules.jl

a StaticModule is basically a little namespace you can use for
enclosing julia code and variables without runtime overhead and
useable in either the global or local scopes. `StaticModule`s are
*not* a replacement `module`s, but may be complementary.

```julia
julia> using StaticModules

julia> @staticmodule Foo begin
           x = 1
           f(y) = x^2 + 2y
       end
StaticModule Foo with names
  f = var"#f#6"{Int64}(1)
  x = 1

julia> propertynames(Foo)
(:f, :x)

julia> x
ERROR: UndefVarError: x not defined

julia> Foo.x
1
```
StaticModules.jl also exports a macro `@const_staticmodule` for use in the global scope so that the name of the module is bound as a `cons` rather than a regular variable. 

### Running code in a StaticModule
We can run expressions 'inside' a `StaticModule`'s namespace with the `@with` macro
```julia
julia> @with Foo begin
           f(1) == 3x
       end
true
```
In fact, the `@with` macro will let us use the properties of any object that supports `propertynames` and `getproperty`:
```julia
julia> @with (;f = x -> x + 1, x = 2) begin
           f(1) == x
       end
true

julia> struct Bar
           a
           b
       end

julia> @with Bar(1, 2) begin
           a^2, b^2
       end
(1, 4)
```
and of course, it doesn't allocate or get in the way of constant propagation:
```julia
julia> @const_staticmodule X begin
           @staticmodule X begin
               X = 1
           end
       end
StaticModule X

julia> @btime @with X begin
           @with X begin
               X^2 + 1
           end
       end
  0.030 ns (0 allocations: 0 bytes)
```
