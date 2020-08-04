import Base.==, Base.<=, Base.>=, Base.<, Base.>
const CONSTANT_CONSTRAINT_TOL = Ref(1e-2)

### Linear equality constraint
mutable struct EqConstraint <: Constraint
    head::Symbol
    id_hash::UInt64
    lhs::AbstractExpr
    rhs::AbstractExpr
    size::Tuple{Int, Int}
    dual::ValueOrNothing

    function EqConstraint(lhs::AbstractExpr, rhs::AbstractExpr)
        if lhs.size == rhs.size || lhs.size == (1, 1)
            sz = rhs.size
        elseif rhs.size == (1, 1)
            sz = lhs.size
        else
            error("Cannot create equality constraint between expressions of size $(lhs.size) and $(rhs.size)")
        end
        id_hash = hash((lhs, rhs, :(==)))
        return new(:(==), id_hash, lhs, rhs, sz, nothing)
    end
end

function vexity(c::EqConstraint)
    vex = vexity(c.lhs) + (-vexity(c.rhs))
    # You can't have equality constraints with concave/convex expressions
    if vex == ConvexVexity() || vex == ConcaveVexity()
        vex = NotDcp()
    end
    return vex
end

function add_constraints_to_context(eq::EqConstraint, context::Context{T}) where T
    f = template(eq.lhs - eq.rhs, context)
    if f isa AbstractVector
        # a trivial constraint without variables like `5 == 0`
        if all(abs.(f) .<= CONSTANT_CONSTRAINT_TOL[])
            return nothing
        else
            error("Constant constraint is violated")
        end
    end
    MOI_add_constraint(context.model, f, MOI.Zeros(MOI.output_dimension(f)))
    return nothing
end


==(lhs::AbstractExpr, rhs::AbstractExpr) = EqConstraint(lhs, rhs)
==(lhs::AbstractExpr, rhs::Value) = ==(lhs, Constant(rhs))
==(lhs::Value, rhs::AbstractExpr) = ==(Constant(lhs), rhs)


### Linear inequality constraints
mutable struct LtConstraint <: Constraint
    head::Symbol
    id_hash::UInt64
    lhs::AbstractExpr
    rhs::AbstractExpr
    size::Tuple{Int, Int}
    dual::ValueOrNothing

    function LtConstraint(lhs::AbstractExpr, rhs::AbstractExpr)
        if sign(lhs) == ComplexSign() || sign(rhs) == ComplexSign()
            error("Cannot create inequality constraint between expressions of sign $(sign(lhs)) and $(sign(rhs))")
        else
            if lhs.size == rhs.size || lhs.size == (1, 1)
                sz = rhs.size
            elseif rhs.size == (1, 1)
                sz = lhs.size
            else
                error("Cannot create inequality constraint between expressions of size $(lhs.size) and $(rhs.size)")
            end
        end
        id_hash = hash((lhs, rhs, :(<=)))
        return new(:(<=), id_hash, lhs, rhs, sz, nothing)
    end
end

function vexity(c::LtConstraint)
    vex = vexity(c.lhs) + (-vexity(c.rhs))
    if vex == ConcaveVexity()
        vex = NotDcp()
    end
    return vex
end

function add_constraints_to_context(lt::LtConstraint, context::Context{T}) where T
    f = template(lt.lhs - lt.rhs, context)
    if f isa AbstractVector
        # a trivial constraint without variables like `5 >= 0`
        if all(f .<= CONSTANT_CONSTRAINT_TOL[])
            return nothing
        else
            error("Constant constraint is violated")
        end
    end
    MOI_add_constraint(context.model, f, MOI.Nonpositives(MOI.output_dimension(f)))
    return nothing
end


<=(lhs::AbstractExpr, rhs::AbstractExpr) = LtConstraint(lhs, rhs)
<=(lhs::AbstractExpr, rhs::Value) = <=(lhs, Constant(rhs))
<=(lhs::Value, rhs::AbstractExpr) = <=(Constant(lhs), rhs)
<(lhs::AbstractExpr, rhs::AbstractExpr) = LtConstraint(lhs, rhs)
<(lhs::AbstractExpr, rhs::Value) = <=(lhs, Constant(rhs))
<(lhs::Value, rhs::AbstractExpr) = <=(Constant(lhs), rhs)


mutable struct GtConstraint <: Constraint
    head::Symbol
    id_hash::UInt64
    lhs::AbstractExpr
    rhs::AbstractExpr
    size::Tuple{Int, Int}
    dual::ValueOrNothing

    function GtConstraint(lhs::AbstractExpr, rhs::AbstractExpr)
        if sign(lhs) == ComplexSign() || sign(rhs) == ComplexSign()
            error("Cannot create inequality constraint between expressions of sign $(sign(lhs)) and $(sign(rhs))")
        else
            if lhs.size == rhs.size || lhs.size == (1, 1)
                sz = rhs.size
            elseif rhs.size == (1, 1)
                sz = lhs.size
            else
                error("Cannot create inequality constraint between expressions of size $(lhs.size) and $(rhs.size)")
            end
        end
        id_hash = hash((lhs, rhs, :(>=)))
        return new(:(>=), id_hash, lhs, rhs, sz, nothing)
    end
end

function vexity(c::GtConstraint)
    vex = -vexity(c.lhs) + (vexity(c.rhs))
    if vex == ConcaveVexity()
        vex = NotDcp()
    end
    return vex
end


function add_constraints_to_context(gt::GtConstraint, context::Context{T}) where T
    f = template(gt.lhs - gt.rhs, context)
    if f isa AbstractVector
        # a trivial constraint without variables like `5 >= 0`
        if all(f  .>= -CONSTANT_CONSTRAINT_TOL[])
            return nothing
        else
            error("Constant constraint is violated")
        end
    end
    MOI_add_constraint(context.model, f, MOI.Nonnegatives(MOI.output_dimension(f)))
    return nothing
end

>=(lhs::AbstractExpr, rhs::AbstractExpr) = GtConstraint(lhs, rhs)
>=(lhs::AbstractExpr, rhs::Value) = >=(lhs, Constant(rhs))
>=(lhs::Value, rhs::AbstractExpr) = >=(Constant(lhs), rhs)
>(lhs::AbstractExpr, rhs::AbstractExpr) = GtConstraint(lhs, rhs)
>(lhs::AbstractExpr, rhs::Value) = >=(lhs, Constant(rhs))
>(lhs::Value, rhs::AbstractExpr) = >=(Constant(lhs), rhs)

function +(constraints_one::Array{<:Constraint}, constraints_two::Array{<:Constraint})
    constraints = append!(Constraint[], constraints_one)
    return append!(constraints, constraints_two)
end
+(constraint_one::Constraint, constraint_two::Constraint) = [constraint_one] + [constraint_two]
+(constraint_one::Constraint, constraints_two::Array{<:Constraint}) =
    [constraint_one] + constraints_two
+(constraints_one::Array{<:Constraint}, constraint_two::Constraint) =
    constraints_one + [constraint_two]
