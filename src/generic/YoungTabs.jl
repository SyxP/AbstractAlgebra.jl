##############################################################################
#
#   Partition type, AbstractVector interface
#
##############################################################################

doc"""
    Partition(part::Vector{Int}, check=true)
> Partition represents integer partition into numbers in non-increasing order.
> It is a thin wrapper over `Vector{Int}`
"""
immutable Partition <: AbstractVector{Int}
   part::Vector{Int}

   function Partition(part::Vector{Int}, check=true)
      if check
         all(diff(part) .<= 0) || throw("Partition must be decreasing!")
         if length(part) > 0
            part[end] >=1 || throw("Found non-positive entry in partition!")
         end
      end
      return new(part)
   end
end

length(p::Partition) = length(p.part)
size(p::Partition) = size(p.part)
linearindexing{T<:Partition}(::Type{T}) = Base.LinearFast()
getindex(p::Partition, i::Int) = p.part[i]
function setindex!(p::Partition, v::Int, i::Int)
   prev = Inf
   nex = 1
   if i == length(p)
      prev = p[i-1]
   elseif i == 1
      nex = p[2]
   elseif 1 < i < length(p)
      prev = p[i-1]
      nex = p[i+1]
   end
   nex <= v <= prev || throw("Partition must be positive and non-increasing")
   p.part[i] = v
   return p
end

==(p::Partition, m::Partition) = p.part == m.part
hash(p::Partition, h::UInt) = hash(p.part, hash(Partition, h))

convert(::Type{Partition}, p::Vector{Int}) = Partition(p)

##############################################################################
#
#   Iterator interface for Integer Partitions
#
##############################################################################

const _noPartsTable = Dict{Int, Int}(0 => 1, 1 => 1, 2 => 2)
const _noPartsTableBig = Dict{Int, BigInt}()

doc"""
    noPartitions(n::Int)
> Returns the number of all distinct integer partitions of `n`. The function
> uses Euler pentagonal number theorem for recursive formula. For more details
> see OEIS sequence [A000041](http://oeis.org/A000041). Note that
> `noPartitions(0) = 1` by convention.
"""
function noPartitions(n::Int)
   if n < 0
      return 0
   end
   if n < 395
      lookuptable = _noPartsTable
      s = 0
   else
      lookuptable = _noPartsTableBig
      s = big(0)
   end

   if !haskey(lookuptable, n)
      for j in 1:floor(Int, (1 + sqrt(1+24n))/6)
         p1 = noPartitions(n - div(j*(3j-1),2))
         p2 = noPartitions(n - div(j*(3j+1),2))
         s += (-1)^(j-1)*(p1 + p2)
      end
      lookuptable[n] = s
   end
   return lookuptable[n]
end

# Implemented following RuleAsc (Algorithm 3.1) from
#    "Generating All Partitions: A Comparison Of Two Encodings"
# by Jerome Kelleher and Barry O’Sullivan, ArXiv:0909.2331

doc"""
   IntPartitions(n::Int)
> Returns an iterator over all integer `Partition`s of `n`. They come in
> ascending order. See also `Combinatorics.partitions(n)`.
"""
immutable IntPartitions
    n::Int
end

function start(parts::IntPartitions)
    if parts.n < 1
        return (Int[], 0)
    elseif parts.n == 1
        return ([1], 0)
    else
        p = zeros(Int, parts.n)
        p[2] = parts.n
        return (p, 2)
    end
end

function nextpart_asc(part, k)
    if k == 0
        return Partition(part, false), (part, 1)
    end
    y = part[k] - 1
    k -= 1
    x = part[k] + 1
    while x <= y
        part[k] = x
        y -= x
        k += 1
    end
    part[k] = x + y
    return Partition(reverse(part[1:k]), false), (part, k)
end

next(parts::IntPartitions, state) = nextpart_asc(state...)
done(parts::IntPartitions, state) = state[2] == 1
eltype(::Type{IntPartitions}) = Partition
length(parts::IntPartitions) = noPartitions(parts.n)

doc"""
    conj(part::Partition)
> Returns the conjugated partition of `part`, i.e. the partition corresponding
> to the Young tableau of `part` reflected through the main diagonal.
"""
function conj(part::Partition)
    p = Int[]
    for i in 1:sum(part)
        n = sum(part .>= i)
        n == 0 && break
        push!(p, n)
    end
    return Partition(p, false)
end

##############################################################################
#
#   YoungTableau type, AbstractVector interface
#
##############################################################################

doc"""
    YoungTableau(part::Partition, fill::Vector{Int}=collect(1:sum(part)))
> Returns the Young tableaux of partition `part`, filled linearly (row-major)
> by `fill` vector.
"""
immutable YoungTableau <: AbstractArray{Int, 2}
   n::Int
   part::Partition
   tab::Array{Int,2}
end

function YoungTableau(part::Partition, fill=collect(1:sum(part)))
   sum(part) == length(fill) || throw("Can't fill Young digaram of $part with $fill: different number of elemnets.")
   n = sum(part)
   tab = zeros(Int, length(part), maximum(part))
   k=1
   for (idx, p) in enumerate(part)
      tab[idx, 1:p] = fill[k:k+p-1]
      k += p
   end
   return YoungTableau(n, part, tab)
end

YoungTableau(p::Vector{Int}) = YoungTableau(Partition(p))

size(Y::YoungTableau) = size(Y.tab)
linearindexing{T<:YoungTableau}(::Type{T}) = Base.LinearFast()
getindex(Y::YoungTableau, i::Int) = Y.tab[i]

function ==(Y1::YoungTableau,Y2::YoungTableau)
   Y1.n == Y2.n || return false
   Y1.part == Y2.part || return false
   Y1.tab == Y2.tab || return false
   return true
end

hash(Y::YoungTableau, h::UInt) = hash(Y.n, hash(Y.part, hash(Y.tab, hash(YoungTableau, h))))

doc"""
    conj(Y::YoungTableau)
> Returns the conjugated tableau, i.e. the tableau reflected through the main
> diagonal.
"""
conj(Y::YoungTableau) = YoungTableau(Y.n, conj(Y.part), transpose(Y.tab))

##############################################################################
#
#   Misc functions for YoungTableaux
#
##############################################################################

rowlen(Y::YoungTableau, i, j) = sum(Y[i, j:end] .> 0)
collen(Y::YoungTableau, i, j) = sum(Y[i:end, j] .> 0)

doc"""
    hooklength(Y::YoungTableau, i, j)
> Returns the hooklength of an element in `Y` at position `(i,j)`. `hooklength`
> will return `0` for `(i,j)` not in the tableau `Y`.
"""
function hooklength(Y::YoungTableau, i, j)
   if Y[i,j] == 0
      return 0
   else
      return rowlen(Y, i, j) + collen(Y, i, j) - 1
   end
end

doc"""
    dimension(Y::YoungTableau)
> Returns the dimension of the irreducible representation of
> `PermutationGroup(sum(Y))` associated to `Y`.
"""
function dimension(Y::YoungTableau)
   n, m = size(Y)
   num = factorial(maximum(Y))
   den = reduce(*, 1, hooklength(Y,i,j) for i in 1:n, j in 1:m if j <= Y.part[i])
   return Int(num/den)
end

##############################################################################
#
#   SkewDiagrams
#
##############################################################################

doc"""
    SkewDiagram(λ::Partition, μ::Partition)
> Implements a skew diagram, i.e. a difference of two Young diagrams
> represented by partitions `λ` and `μ`.
"""
immutable SkewDiagram
   λ::Partition
   μ::Partition

   function SkewDiagram(λ, μ)
      sum(λ) >= sum(μ) || throw("Can't create SkewDiagram: μ is partition of  $(sum(μ)) > $(sum(λ)).")
      length(λ) >= length(μ) || throw("Can't create SkewDiagram: $μ is longer than $(λ)!")
      for (l,m) in zip(λ, μ)
         l >= m || throw("a row of $μ is longer than a row of $λ")
      end
      return new(λ, μ)
   end
end

SkewDiagram(λ::Vector{Int}, μ::Vector{Int}) = SkewDiagram(Partition(λ), Partition(μ))

/(λ::Partition, μ::Partition) = SkewDiagram(λ, μ)

==(ξ::SkewDiagram, ψ::SkewDiagram) = ξ.λ == ψ.λ && ξ.μ == ψ.μ
hash(ξ::SkewDiagram, h::UInt) = hash(ξ.λ, hash(ξ.μ, hash(SkewDiagram, h)))

###############################################################################
#
#   String I/O
#
###############################################################################

doc"""
    matrix_repr(ξ::SkewDiagram)
> Returns a binary representation of the diagram `ξ`, i.e. a binary array `A`
> where `A[i,j] == 1` if and only if `(i,j)` is in `ξ.λ` but not in `ξ.μ`.
"""
function matrix_repr(ξ::SkewDiagram)
   ydiag = zeros(Int,length(ξ.λ), maximum(ξ.λ))
   for i in 1:length(ξ.μ)
      ydiag[i, ξ.μ[i]+1:ξ.λ[i]] .= 1
   end
   for i in length(ξ.μ)+1:length(ξ.λ)
      ydiag[i,1:ξ.λ[i]] .= 1
   end
   return ydiag
end

show(io::IO, ξ::SkewDiagram) = show(io, MIME("text/plain"), matrix_repr(ξ))