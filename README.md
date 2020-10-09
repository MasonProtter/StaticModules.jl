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
StaticModule Foo containing
  f = f
  x = 1

julia> propertynames(Foo)
(:f, :x)

julia> x
ERROR: UndefVarError: x not defined

julia> Foo.x
1
```
StaticModules.jl also exports a macro `@const_staticmodule` for use in the global scope so that the name of the module is bound as a `const` rather than a regular variable.

Note, since `StaticModule`s are backed by a `NamedTuple`, the same compiler performance caveats about dealing with large `Tuple`s apply to `StaticModule`s. Be careful about defining hundreds of names in a `StaticModule`.

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
StaticModule X containing
  X = StaticModule X

julia> @btime @with X begin
           @with X begin
               X^2 + 1
           end
       end
  0.030 ns (0 allocations: 0 bytes)
```
If you supply a `Tuple` of objects supporting `getproperty`, then `@with` will use names from all of them, with priority being taken by earlier objects in the list if names collide:
```
julia> @with ((;a=1, b="hi"), (;b=2, c=3)) begin
           a, b, c
       end
(1, "hi", 3)
```
Using two many objects in `@with` may stress the compiler.


### Replacements for `using`
Sometimes you might want to `using` a module into a `StaticModule`, but this will not work the way it works in standard modules. You can 'fake' this behaviour using the `@unpack` macro from [Parameters.jl](https://github.com/mauro3/Parameters.jl) and `import`ing packages into the parent module:
```
julia> using Parameters

julia> import StaticArrays

julia> @staticmodule Foo begin
           @unpack SA, SVector = StaticArrays
           a = SVector((1,2,3))' * SA[4,5,6]
       end
StaticModule Foo containing
  a       = 32
  SVector = SArray{Tuple{S},T,1,S} where T where S
  SA      = SA
  ##253   = StaticArrays

```