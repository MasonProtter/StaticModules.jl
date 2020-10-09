module StaticModules

export StaticModule, @staticmodule, @with, @const_staticmodule

using JuliaVariables, MLStyle

struct StaticModule{Name, names, T <: Tuple}
    nt::NamedTuple{names, T}
    StaticModule{Name}(nt::NamedTuple{names, T}) where {Name, names, T} = begin
        @assert Name isa Symbol
        new{Name, names, T}(nt)
    end
end
Base.propertynames(::StaticModule{Name, names}) where {Name, names} = names
Base.getproperty(sm::StaticModule, s::Symbol) = getproperty(getfield(sm, :nt), s)
function Base.show(io::IO, sm::StaticModule{Name}) where {Name}
    nt = getfield(sm, :nt)
    n = !isempty(nt) ? maximum(s -> length(String(s)), keys(nt)) : 0
    print(io, "StaticModule $Name")
    if !get(io, :compact, false)
        print(io, " containing")
        foreach(keys(nt)) do k
            pad = mapreduce(_ -> " ", *, 1:(n - length(String(k))), init="")
            print(io, "\n  $pad$k = $(repr(nt[k]; context=:compact => true))")
        end
    end
end

function get_let_locals(ex::Expr)
    vars = (solve_from_local! ∘ simplify_ex)(ex).args[1].bounds
    map(x -> x.name, vars)
end

macro staticmodule(name, blck::Expr)
    blck = macroexpand(__module__, blck)
    @assert blck.head == :block
    locals = map(get_let_locals(blck)) do s
        :($s = $s)
    end 
    push!(blck.args, :((; $(locals...) )))
    quote
        $name = let; $StaticModule{$(QuoteNode(name))}($blck) end
    end |> esc
end

macro const_staticmodule(name, blck::Expr)
    @assert blck.head == :block
    locals = map(get_let_locals(blck)) do s
        :($s = $s)
    end 
    push!(blck.args, :((; $(locals...) )))
    quote
        const $name = let; $StaticModule{$(QuoteNode(name))}($blck) end
    end |> esc
end

_get_outers(_) = Symbol[]
_get_outers(x::Var) = x.is_global ? [x.name] : Symbol[]
function _get_outers(ex::Expr)
    @match ex begin
        Expr(:(=), _, rhs) => _get_outers(rhs)
        Expr(:tuple, _..., Expr(:(=), _, rhs)) => _get_outers(rhs)
        Expr(_, args...) => mapreduce(_get_outers, vcat, args)
    end
end

get_outers(ex) = (unique! ∘ _get_outers ∘ solve_from_local! ∘ simplify_ex)(ex)

macro with(sm, blck::Expr)
    blck = macroexpand(__module__, blck)
    outers = get_outers(blck)
    if sm isa Expr && sm.head == :tuple
        sms = sm.args
    else
        sms = [sm]
    end
    defs = map(outers) do s
        switch = foldr(sms, init=s) do M, ex
            :(($(QuoteNode(s)) ∈ $propertynames($M)) ? $M.$s : $ex)
        end
        :($s = $switch)
    end
    quote
        let $(defs...)
            $blck
        end
    end |> esc
end


end # module
