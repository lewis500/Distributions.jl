# Tests on Multivariate LogNormal distributions

using Distributions,  PDMats
using LinearAlgebra, Random, Test



####### Core testing procedure

function test_mvlognormal(g::MvLogNormal, n_tsamples::Int=10^6)
    d = length(g)
    mn = mean(g)
    md = median(g)
    mo = mode(g)
    S = cov(g)
    s = var(g)
    e = entropy(g)
    @test partype(g) == Float64
    @test isa(mn, Vector{Float64})
    @test isa(md, Vector{Float64})
    @test isa(mo, Vector{Float64})
    @test isa(s, Vector{Float64})
    @test isa(S, Matrix{Float64})
    @test length(mn) == d
    @test length(md) == d
    @test length(mo) == d
    @test length(s) == d
    @test size(S) == (d, d)
    @test s          ≈ diag(S)
    @test md         ≈ exp.(mean(g.normal))
    @test mn         ≈ exp.(mean(g.normal) + var(g.normal)/2)
    @test mo         ≈ exp.(mean(g.normal) - var(g.normal))
    @test entropy(g) ≈ d*(1 + Distributions.log2π)/2 + logdetcov(g.normal)/2 + sum(mean(g.normal))
    gg = typeof(g)(MvNormal(params(g)...))
    @test Vector(g.normal.μ) == Vector(gg.normal.μ)
    @test Matrix(g.normal.Σ) == Matrix(gg.normal.Σ)
    @test insupport(g,ones(d))
    @test !insupport(g,zeros(d))
    @test !insupport(g,-ones(d))

    # sampling
    X = rand(g, n_tsamples)
    emp_mn = vec(mean(X, dims=2))
    emp_md = vec(median(X, dims=2))
    Z = X .- emp_mn
    emp_cov = (Z * Z') ./ n_tsamples
    for i = 1:d
        @test isapprox(emp_mn[i]   , mn[i] , atol=(sqrt(s[i] / n_tsamples) * 8.0))
    end
    for i = 1:d
        @test isapprox(emp_md[i]   , md[i] , atol=(sqrt(s[i] / n_tsamples) * 8.0))
    end
    for i = 1:d, j = 1:d
        @test isapprox(emp_cov[i,j], S[i,j], atol=(sqrt(s[i] * s[j]) * 20.0) / sqrt(n_tsamples))
    end

    # evaluation of logpdf and pdf
    for i = 1:min(100, n_tsamples)
        @test logpdf(g, X[:,i]) ≈ log(pdf(g, X[:,i]))
    end
    @test logpdf(g, X) ≈ log.(pdf(g, X))
    @test isequal(logpdf(g, zeros(d)),-Inf)
    @test isequal(logpdf(g, -mn),-Inf)
    @test isequal(pdf(g, zeros(d)),0.0)
    @test isequal(pdf(g, -mn),0.0)

    # test the location and scale functions
    @test isapprox(location(g), location(MvLogNormal,:meancov,mean(g),cov(g))   , atol=1e-8)
    @test isapprox(location(g), location(MvLogNormal,:mean,mean(g),scale(g))    , atol=1e-8)
    @test isapprox(location(g), location(MvLogNormal,:median,median(g),scale(g)), atol=1e-8)
    @test isapprox(location(g), location(MvLogNormal,:mode,mode(g),scale(g))    , atol=1e-8)
    @test isapprox(scale(g)   , scale(MvLogNormal,:meancov,mean(g),cov(g))      , atol=1e-8)

    @test isapprox(location(g), location!(MvLogNormal,:meancov,mean(g),cov(g),zero(mn))   , atol=1e-8)
    @test isapprox(location(g), location!(MvLogNormal,:mean,mean(g),scale(g),zero(mn))    , atol=1e-8)
    @test isapprox(location(g), location!(MvLogNormal,:median,median(g),scale(g),zero(mn)), atol=1e-8)
    @test isapprox(location(g), location!(MvLogNormal,:mode,mode(g),scale(g),zero(mn))    , atol=1e-8)
    @test isapprox(scale(g)   , Distributions.scale!(MvLogNormal,:meancov,mean(g),cov(g),zero(S)), atol=1e-8)

    lc1,sc1 = params(MvLogNormal,mean(g),cov(g))
    lc2,sc2 = params!(MvLogNormal,mean(g),cov(g),similar(mn),similar(S))
    @test isapprox(location(g), lc1, atol=1e-8)
    @test isapprox(location(g), lc2, atol=1e-8)
    @test isapprox(scale(g)   , sc1, atol=1e-8)
    @test isapprox(scale(g)   , sc2, atol=1e-8)
end

####### Validate results for a single-dimension MvLogNormal by comparing with univariate LogNormal
println("    comparing results from MvLogNormal with univariate LogNormal")
l1 = LogNormal(0.1,0.4)
l2 = MvLogNormal(0.1*ones(1),0.4)
@test [mean(l1)]     ≈ mean(l2)
@test [median(l1)]   ≈ median(l2)
@test [mode(l1)]     ≈ mode(l2)
@test [var(l1)]      ≈ var(l2)
@test  entropy(l1)   ≈ entropy(l2)
@test logpdf(l1,5.0) ≈ logpdf(l2,[5.0])
@test pdf(l1,5.0)    ≈ pdf(l2,[5.0])
@test (Random.seed!(78393) ; [rand(l1)]) == (Random.seed!(78393) ; rand(l2))

###### General Testing

mu = [0.1, 0.2, 0.3]
va = [0.16, 0.25, 0.36]
C = [0.4 -0.2 -0.1; -0.2 0.5 -0.1; -0.1 -0.1 0.6]

for (g, μ, Σ) in [
    (MvLogNormal(mu,PDMats.PDMat(C)), mu, C),
    (MvLogNormal(PDMats.PDiagMat(Vector{Float64}(sqrt.(va)))), zeros(3), Matrix(Diagonal(va))), # Julia 0.4 loses type information so Vector{Float64} can be dropped when we don't support 0.4
    (MvLogNormal(mu, sqrt(0.2)), mu, Matrix(0.2I, 3, 3)),
    (MvLogNormal(3, sqrt(0.2)), zeros(3), Matrix(0.2I, 3, 3)),
    (MvLogNormal(mu, Vector{Float64}(sqrt.(va))), mu, Matrix(Diagonal(va))), # Julia 0.4 loses type information so Vector{Float64} can be dropped when we don't support 0.4
    (MvLogNormal(Vector{Float64}(sqrt.(va))), zeros(3), Matrix(Diagonal(va))), # Julia 0.4 loses type information so Vector{Float64} can be dropped when we don't support 0.4
    (MvLogNormal(mu, C), mu, C),
    (MvLogNormal(C), zeros(3), C) ]

    println("    testing $(typeof(g)) with normal distribution $(Distributions.distrname(g.normal))")

    m,s = params(g)
    @test Vector(m) ≈ μ
    test_mvlognormal(g, 10^4)
end

##### Constructors and conversions
d = MvLogNormal(Array{Float32}(mu), PDMats.PDMat(Array{Float32}(C)))
@test typeof(convert(MvLogNormal{Float64}, d)) == typeof(MvLogNormal(mu, PDMats.PDMat(C)))
@test typeof(convert(MvLogNormal{Float64}, d.normal.μ, d.normal.Σ)) == typeof(MvLogNormal(mu, PDMats.PDMat(C)))
