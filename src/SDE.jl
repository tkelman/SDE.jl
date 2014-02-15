# http://sdejl.readthedocs.org/en/latest/
module SDE
using Cubature
#using Debug
#using Randm
#using Distributions
#using NumericExtensions

import Base.length
export b, sigma, a, H, r, p, Bstar, Bcirc, Bsharp, euler, euler!, guidedeuler, guidedeuler!,  llikeliXcirc, samplep, lp, linexact, linll
 
export CTPro, CTPath, UvPath, UvLinPro, UvAffPro, MvPath, MvPro, MvWiener, MvLinPro, MvAffPro, Wiener
export diff1, resample!, sample, samplebridge, setv!

export soft, tofs, uofx, xofu, XofU, eulerU, eulerU!, llikeliU, MvLinProInhomog

#%  .. function:: syl(a, b, c)
#%               
#%      Solves the Sylvester equation ``AX + XB = C``, where ``C`` is symmetric and 
#%      ``A`` and ``-B`` have no common eigenvalues using (inefficient)
#%    algebraic approach via the Kronecker product, see http://en.wikipedia.org/wiki/Sylvester_equation
#%  
function issquare(a::Matrix)
     size(a,2) == size(a,1)
end

range(x) = (min(x), max(x))
extendr(R1, mar) = (R1[1] -mar*(R1[2]-R1[1]),R1[2] + mar*(R1[2]-R1[1]))
hrange(x) = extendr(range(x), 1/7)

function syl(a, b, c)
    !(issquare(a) && issquare(b) && issquare(c)) && error("Arguments not square matrices.")

    k = kron(eye(a), a) + kron(b', eye(b))
    xvec=k\vec(c)
    reshape(xvec,size(c))
end

lyap(b, c) = syl(b', b, c)
lyap(b::Float64, mina::Float64) = -0.5a/b

#%  .. currentmodule:: SDE
#%    

#%  SDE
#%  ------- 
#%
#%  
#%  



#%  
#%  Reference 
#%  ~~~~~~~~~
#%

 
diff1(a) = [i > 1 ? a[i] - a[i-1] : a[1] for i=1:length(a) ]
diff0(a) = [i > 1 ? a[i] - a[i-1] : zero(a[1]) for i=1:length(a) ]
eps2 = sqrt(eps())


cumsum!(v::AbstractVector) = Base.cumsum_pairwise(v, v,  zero(v[1]), 1, length(v))

 
function randn!{T,N}(X::StridedArray{T, N})
    i = length(x)
    for i in 1:n
        X[i] = randn()
    end
end


abstract CTPro{Rank} #rank = dim(W) + dim(t) = dim(W) + 1
 

typealias MvPro CTPro{2}
typealias UvPro CTPro{1}

immutable CTPath{Rank}
    tt :: Array{Float64,1}
    yy :: Array{Float64,Rank}
    CTPath(tt, yy) = new(tt, yy)
end       

typealias MvPath CTPath{2}
typealias UvPath CTPath{1}
length(X::CTPath) = length(X.tt)  

getindex(V::UvPath, I) = (V.tt[I], V.yy[I])
getindex(V::MvPath, I) = (V.tt[I], V.yy[:,I])
endof(V::CTPath) = endof(V.tt)

function setindex!(V::MvPath,y, I) 
    V.tt[I],V.yy[:,I] = y 
end
function sub(V::MvPath, I) 
    SubVecProcPath(sub(V.tt,I), sub(V.yy, 1:size(V.yy,1), I)) 
end

  
function setv!(X::MvPath, v)
    X.yy[:, end] = v
    X
end

MvPath(tt::Array{Float64,1}, n::Integer) = MvPath(tt, zeros(n, length(tt)))
UvPath(tt::Array{Float64,1}) = UvPath(tt, zeros(length(tt)))

type Wiener{Rank}  <: CTPro{Rank}
    #dims::NTuple{Rank-1, Int}  #would be nice to do that.
    dims::Tuple
end

Wiener() =  Wiener{1}(())
Wiener(d::Int) =  Wiener{2}((d,))
Wiener(d1::Int, d2::Int) =  Wiener{3}((d1,d2))

Wiener{Dim}(dims::NTuple{Dim,Int}) = Wiener{Dim+1}(dims)


function resample!(W::CTPath, P::Wiener)
    assert(P.dims == size(W.yy)[1:end-1])
    sz = prod(P.dims)
    for i = 2:length(W.tt)
        rootdt = sqrt(W.tt[i]-W.tt[i-1])
        for j = 1:sz
            W.yy[sz*(i-1) + j] = W.yy[sz*(i-2) + j] + rootdt*randn()
        end
    end
end


function resamplebridge!(W::CTPath, T, v, P::Wiener)
    #white noise
    assert(P.dims == size(W.yy)[1:end-1])
    sz = prod(P.dims)
    TT = T - W.tt[1]

    wtotal = zeros(sz)
    for i = 2:length(W.tt) 
        rootdt = sqrt(W.tt[i]-W.tt[i-1])
        for j = 1:sz
            wtotal[j] +=  W.yy[sz*(i-1) + j] = rootdt*randn()
        end
    end

    # noise between tt[end] and T
    rootdt = sqrt(T-W.tt[end])
    for j = 1:sz
            wtotal[j] +=  rootdt*randn() + (W.yy[j] - v[j])
    end

    # cumsum
    for i = 2:length(W.tt)
        dt =  (W.tt[i]-W.tt[i-1]) /TT
        for j = 1:sz
            W.yy[sz*(i-1) + j] = W.yy[sz*(i-2) + j]  +  W.yy[sz*(i-1) + j] - wtotal[j]*dt
        end
    end
   
end

function samplebridge(tt, u, T, v, P::Wiener)
    yy = zeros(P.dims..., length(tt))
    yy[1:prod(P.dims)] = u
   
    W = CTPath{length(P.dims)+1}(copy(tt), yy)
    resamplebridge!(W, T, v, P)
    W
end


function sample(tt, P::Wiener)
    yy = zeros(P.dims..., length(tt))
    W = CTPath{length(P.dims)+1}(copy(tt), yy)
    resample!(W, P)
    W
end

typealias MvWiener Wiener{2}

type MvAffPro <: MvPro
    mu::Vector{Float64}
    Sigma::Matrix{Float64}
    A::Matrix{Float64}
    Gamma::Matrix{Float64}
    detGamma::Float64
    d::Int    
    dr::Int
    
    function MvAffPro(mu, Sigma) 
         d = length(mu)
         size(Sigma, 1) == d || throw(ArgumentError("The dimensions of mu and Sigma are inconsistent."))
         A = Sigma*Sigma'
         Gamma = inv(A)
         new(mu, Sigma, A, Gamma , det(Gamma), d, size(Sigma, 2))
    end
end


type UvLinPro <: UvPro
    B::Float64
    beta::Float64
    betabyB::Float64
    Sigma::Float64
    lambda::Float64
    d::Int
    function UvLinPro(B, beta, Sigma) 
        (norm(B) > eps2) || throw(ArgumentError("norm(B) < $eps2")) 
        new(B, beta, B\beta, Sigma, -0.5*(Sigma*Sigma)/B, 1)
    end
end

type MvLinPro <: MvPro
    B::Matrix{Float64}
    beta::Vector{Float64}
    betabyB::Vector{Float64}
    Sigma::Matrix{Float64}
    A::Matrix{Float64}
    lambda::Matrix{Float64}
    d::Int
    dp :: Int    
    function MvLinPro(B::Matrix{Float64}, beta::Vector{Float64}, Sigma) 
        d = length(beta)
        size(B,2) == size(B,1) == d || throw(ArgumentError("The dimensions of beta and B are inconsistent."))
        size(Sigma,1) == d || throw(ArgumentError("The dimensions of beta and Sigma are inconsistent."))
        dp = size(Sigma,2)
        (norm(B) > eps2) || throw(ArgumentError("norm(B) < $eps2, use MvAffPro")) 
        A = Sigma*Sigma'
        lambda = lyap(B', -A)
     
    
        new(B, beta, B\beta, Sigma, A, lambda, d, dp)
    end
end


type MvLinProInhomog <: MvPro
    B::Matrix{Float64}
    beta::Vector{Float64}
    betabyB::Vector{Float64}
    Sigma::Matrix{Float64}
    A::Matrix{Float64}
    lambda::Matrix{Float64}
    d::Int
    dp :: Int    
    ph
    function MvLinProInhomog(B::Matrix{Float64}, beta::Vector{Float64}, ph,  Sigma) 
        d = length(beta)
        size(B,2) == size(B,1) == d || throw(ArgumentError("The dimensions of beta and B are inconsistent."))
        size(Sigma,1) == d || throw(ArgumentError("The dimensions of beta and Sigma are inconsistent."))
        dp = size(Sigma,2)
        (norm(B) > eps2) || throw(ArgumentError("norm(B) < $eps2, use MvAffPro")) 
        A = Sigma*Sigma'
        lambda = lyap(B', -A)
     
    
        new(B, beta, B\beta, Sigma, A, lambda, d, dp, ph)
    end
end



type MvDiffusion <: MvPro
    b 
    sigma
    d::Int    
end


type UvAffPro <: UvPro
    mu::Float64
    Sigma::Float64
end

typealias AffPro Union(UvAffPro, MvAffPro)

typealias LinPro Union(UvLinPro, MvLinPro)



function a(s, x, P::CTPro)
    sigma(s,x, P)*sigma(s,x, P)'
end


function b(s, x, P::MvDiffusion)
    P.b(s,x)
end

function sigma(s, x, P::MvDiffusion)
    P.sigma(s,x)
end



function b(s, x, P::LinPro)
    P.B*x + P.beta
end

function b(s, x, P::AffPro)
    P.mu
end

function a(s, x, P::Union(MvLinPro, MvAffPro))
    P.A
end

function a(s, x, P::Union(UvLinPro, UvAffPro))
    P.Sigma*P.Sigma'
end


function sigma(s, x, P::LinPro)
    P.Sigma
end

function sigma(s, x, P::AffPro)
    P.Sigma
end


function gamma(P::UvAffPro)
    inv(P.Sigma*P.Sigma)    
end 
function gamma(P::MvAffPro)
    P.Gamma
end 


#%  .. function:: mu(t, x, T, P)
#%           
#%      Expectation :math:`E_(t,x)(X_{T})`
#%      
function mu(t, x, T, P::LinPro)
    phi = expm(h*P.B)
    phi*(x + P.betabyB) - P.betabyB
end    

function mu(t, x, T, P::AffPro)
    x + (T-t) * P.mu
end    

#%  .. function:: K(t, T, P)
#%           
#%      Covariance matrix :math:`Cov(X_{t}, X_{T})`
#%      

function K(t, T, P::LinPro)
    phi = expm((T-t)*P.B)
    P.lambda - phi*P.lambda*phi'
end

function K(t, T, P::AffPro)
     (T-t)*gamma(P)
end



#%  .. function:: r(t, x, T, v, P)
#%           
#%      Returns :math:`r(t,x) = \operatorname{grad}_x \log p(t,x; T, v)` where
#%      ``p`` is the transition density of the process ``P``.
#%  

function r(t, x, T, v, P)
    H(t, T, P, V(t, T, v, P)-x)
end



#%  .. function:: H(t, T, P)
#%           
#%      Negative Hessian of :math:`\log p(t,x; T, v)` as a function of ``x``.
#%      

function Hinv(t, T, P::LinPro)
    phim = expm(-(T-t)*P.B)
    (phim*P.lambda*phim'-P.lambda)
end

Hinv(t, T, P::MvAffPro) = K(t, T, P::MvAffPro)

function H(t, T, P::LinPro, x)
     phim = expm(-(T-t)*P.B)
    (phim*P.lambda*phim'-P.lambda)\x
end

function H(t, T, P::LinPro)
     phim = expm(-(T-t)*P.B)
     inv(phim*P.lambda*phim'-P.lambda)
end

function H(t, T, P::AffPro)
    gamma(P)/(T-t)
end


# cholesky factor of H^{-1}, note that x'inv(K)*x =  norm(chol(K, :L)\x)^2

function L(t,T, P::MvPro)
    chol(Hinv(t, T, P), :L)
end


# technical function

function V(t, T, v, P::LinPro)
    phim = expm(-(T-t)*P.B)
    phim*(v + P.betabyB) - P.betabyB  
end

function V(t, T, v, P::AffPro)
    return v - (T-t)*P.mu
end

#%  .. function:: bstar(t, x, T, v, P::MvPro)
#%           
#%      Returns the drift function of a vector linear process bridge which end at time T in point v.
#%      

function bstar(t, x, T, v, P::CTPro)
    b(t, x,  P) + a(t, x, P) * r(t, x, T, v, P)
end    

#%  .. function:: bcirc(t, x, T, v, Pt::Union(MvLinPro, MvAffPro), P::MvPro)
#%           
#%      Drift for guided proposal derived from a vector linear process bridge which end at time T in point v.
#%      

function bcirc(t, x, T, v, Pt::CTPro, P::CTPro)
    b(t,x, P) + a(t,x, P) * r(t, x, T, v, Pt)
end    




#%  .. function:: lp(t, x, T, y, P)
#%           
#%      Returns :math:`log p(t,x; T, y)`, the log transition density of the process ``P``
#%  
function lp(t, x, T, y, P::MvLinPro)
    z = (x - V(t, T, y, P))
    l = L(t, T, P)
    (-1/2*P.d*log(2pi) -log(apply(*,diag(chol(K(t, T, P))))) - 0.5*norm(l\z)^2) #  - 0.5*log(det(K(h,b, lambda)))
end
function lp(t, x, T, y, P::UvLinPro)
    z = (x - V(t, T, y, P))
    -0.5log(2pi) -log(sqrt(K(t, T, P))) - 0.5*norm(z)^2*H(t, T, P) #  - 0.5*log(det(K(h,b, lambda)))
end



#%  .. function:: samplep(t, x, T, P) 
#%           
#%      Samples from the transition density of the process ``P``.
#%  

function samplep(t, x, T, P::MvLinPro) 
    phi = expm(h*P.B)
    mu = phi*(x + P.betabyB) - P.betabyB 
    k = lambda - phi*lambda*phi'
    l = chol(k)

    z = randn(length(x))
    mu + l*z
end


function samplep(t, x, T, P::MvAffPro) 
        z = randn(length(x))
        return x + chol(P.Gamma)\z*sqrt(T-t) + (T-t)*P.mu
end
function samplep(t, x, T, P::UvAffPro) 
        z = randn(length(x))
        return x + z*sqrt(T-t)/P.Sigma + (T-t)*P.mu
end

#%  .. function:: exact(u, tt, P)
#%           
#%      Simulate process ``P`` starting in `u` on a discrete grid `tt` from its transition probability.
#%  

function exact(u, tt, P::MvPro)
    M = length(tt)
    dt = diff(tt)
    xx = zeros(length(u), M)
    xx[:,1] = u
    for i in 1 : M-1
         xx[:,i+1] = samplep(dt[i], xx[:,i], P) 
    end
    MvPath(tt, xx)
end

#%  .. function:: ll(X,P)
#%           
#%      Compute log likelihood evaluated in `B`, `beta` and Lyapunov matrix `lambda`
#%      for a observed linear process on a discrete grid `dt` from its transition density.
#%  

function ll(X, P::MvPro)
    M = size(X.xx)[end]
    ll = 0.0
    for i in 1 : M-1
        ll += lp(X.tt[i+1]-X.tt[i], X.xx[:,i], X.xx[:,i+1], P) 
    end
    ll
end



#%  .. function:: lp0(h, x, y,  mu, gamma)
#%           
#%      Returns :math:`log p(t,x; T, y)`, the log transition density of a Brownian motion with drift mu and diffusion a=inv(gamma), h = T - t 
#%  
function lp(s, x, t, y, P::MvAffPro)
      -1/2*P.d*log(2pi*(t-s)) + 0.5*log(det(P.Gamma))  -dot(0.5*(y-x-(t-s)*P.mu), P.Gamma*(y-x-(t-s)*P.mu)/(t-s))
     
end
function lp(s, x, t, y, P::UvAffPro)
      -1/2*log(2pi*(t-s)) - log(abs(P.Sigma))  - 0.5*(y-x-(t-s)*P.mu)*(y-x-(t-s)*P.mu)/(P.sigma*P.sigma*(t-s))
     
end

function lp(t, x, T, y, P::MvLinProInhomog)
    ph = P.ph
    B, beta, A = P.B, P.beta, P.A
    a = s -> A
    
     z = (x -  varV(t,T, y, ph, B, t -> beta))
    Q = varQ(t, T, ph,  B, a )
    l = chol(Q, :L)
    K =  expm(ph(T,t)*B)*Q*expm(ph(T,t)*B)'
    (-1/2*length(x)*log(2pi) -log(apply(*,diag(chol(K)))) - 0.5*norm(l\z)^2) #  - 0.5*log(det(K(h,b, lambda)))
end



#%  .. function:: samplep0(h, x, mu, l) 
#%           
#%      Samples from the transition density a affine Brownian motion. Takes the Cholesky
#%      factor as argument. 
#%          l = chol(a)
#%  

function samplep(s, x, t, P::MvAffPro )
    z = randn(P.d)
    x + P.l*z*sqrt(t-s) + h*P.mu
end


#%  .. function:: euler(u, W::CTPath, P::CTPro)
#%  
#%      Multivariate euler scheme for ``U``, starting in ``u`` using the same time grid as the underlying Wiener process ``W``.
#%      

euler(u, W::UvPath, P::UvPro) = euler!(UvPath(copy(W.tt), copy(W.yy)),u, W, P)
 
function euler!(Y::UvPath, u, W::UvPath, P::UvPro)
    
    N = length(W)
    N != length(Y) && error("Y and W differ in length.")
  
    ww = W.yy
    tt = Y.tt  
    yy = Y.yy
    tt[:] = W.tt
  
    y = u
        
    for i in 1:N-1
        yy[i] = y
        y = y +  b(tt[i],y, P)*(tt[i+1]-tt[i]) + sigma(tt[i],y, P)*(ww[i+1]-ww[i])
    end
    yy[N] = y
    Y
end
guidedeuler(u, W::UvPath, T, v, Pt::UvPro,  P::UvPro) = guidedeuler!(UvPath(copy(W.tt), copy(W.yy)), u, W, T, v, Pt,  P)

function guidedeuler!(Y::UvPath, u, W::UvPath, T, v, Pt::UvPro,  P::UvPro)

    N = length(W)
    N != length(Y) && error("Y and W differ in length.")
  
    ww = W.yy
    tt = Y.tt  
    yy = Y.yy
    tt[:] = W.tt
  
    y = u
        
    for i in 1:N-1
        yy[i] = y
        y = y +  bcirc(tt[i], y, T, v, Pt, P)*(tt[i+1]-tt[i]) + sigma(tt[i],y, P)*(ww[i+1]-ww[i])
    end
    yy[N] = v
    Y
end


function euler(u, W::MvPath, P::MvPro)
    ww = W.yy
    tt = copy(W.tt)

    N = length(tt)
   
    yy = zeros(size(u)..., N)

    y = copy(u)
        
    for i in 1:N-1
        yy[:,i] = y
        y[:] = y .+  b(tt[i],y, P)*(tt[i+1]-tt[i]) .+ sigma(tt[i],y, P)*(ww[:, i+1]-ww[:, i])
    end
    yy[:,N] = y
    MvPath(tt,yy)
end

function guidedeuler(u, W::MvPath, T, v, Pt::MvPro,  P::MvPro)
    ww = W.yy
    tt = copy(W.tt)

    N = length(tt)
   
    yy = zeros(size(u)..., N)

    y = copy(u)
        
    for i in 1:N-1
        yy[:,i] = y
        y[:] = y .+  bcirc(tt[i], y, T, v, Pt, P)*(tt[i+1]-tt[i]) .+ sigma(tt[i],y, P)*(ww[:, i+1]-ww[:, i])
    end
    yy[:,N] = v
    MvPath(tt,yy)
end


#%  .. function:: llikeliXcirc(t, T, Xcirc, b, a,  B, beta, lambda)
#%           
#%      Loglikelihood (log weights) of Xcirc with respect to Xstar.
#%  
#%          t, T -- timespan
#%          Xcirc -- bridge proposal (drift Bcirc and diffusion coefficient sigma) 
#%          b, sigma -- diffusion coefficient sigma target
#%          B, beta -- drift b(x) = Bx + beta of Xtilde
#%          lambda -- solution of the lyapunov equation for Xtilde
#%  


function llikeliXcirc(Xcirc::MvPath, Pt::MvPro, P::MvPro)
    tt = Xcirc.tt
    xx = Xcirc.yy
 
    N = length(tt)
    T = tt[N]    
    v = xx[:, N]
    
    som = 0.
    x = similar(v)
    for i in 1:N-1 #skip last value, summing over n-1 elements
      s = tt[i]
      x[:] = xx[:, i]
      R = r(s, x, T, v, Pt) 
      som += (dot(b(s,x, P) - b(s,x, Pt), R) - 0.5 *trace((a(s,x, P) - a(s,x, Pt)) *(H(s, T, Pt) - (R*R')))) * (tt[i+1]-tt[i])
    end
    
    som
end

function llikeliXcirc(Xcirc::UvPath, Pt::UvPro, P::UvPro)
    tt = Xcirc.tt
    xx = Xcirc.yy

    N = length(tt)
    T = tt[N]    
    v = xx[N]
    
    som = 0.
    for i in 1:N-1 #skip last value, summing over n-1 elements
      s = tt[i]
      x = xx[i]
      R = r(s, x, T, v, Pt) 
      som += ((b(s,x, P) - b(s,x, Pt))*R - 0.5 *((a(s,x, P) - a(s,x, Pt)) *(H(s, T, Pt) - (R*R))) ) * (tt[i+1]-tt[i])
    end
    
    som
end


################################################################

#%  .. function:: tofs(s, T)
#%        soft(t, T)
#%  
#%      Time change mapping s in [0, T] (U-time) to t in [t_1, t_2] (X-time), and inverse.
#%      

tofs(s, tmin, T) = tmin .+ s.*(2. .- s/T) # T(1- (1-s/T)^2)
soft(t, tmin, T) = T-sqrt(T*(T + tmin - t))



#%  .. function:: XofU(UU, tmin, T, v, P) 
#%    
#%  U is the scaled and time changed process 
#%      U(s)= exp(s/2.)*(v(s) - X(tofs(s))) 
#%  XofU transforms entire process U sampled at time points ss to X at tt.
#%  
    
# 
xofu(s,u,  T, v,  P) = Vtofs(s, T, v, P)- (T-s)*u

#careful here, s is in U-time
uofx(s,x,  T, v,  P)  = (Vtofs(s, T, v, P)- x)/(T-s)

txofsu(s,u, tmin, T, v, P) = (tofs(s,tmin, T), xofu(s,u,  T, v, P))


#%  .. function:: Vtofs (s, T, v, B, beta)
#%        dotVtofs (s, T, v, B, beta)
#%  
#%      Time changed V and time changed time derivative of V for generation of U
#%      



function Vtofs (s, T, v, P::MvLinPro)
    expm(-P.B*(T - s)^2/T)*( v + P.betabyB) -  P.betabyB
end
function dotVtofs (s, T, v, P::MvLinPro)
    expm(-P.B*(T - s)^2/T)*( P.B*v + P.beta) 
end

function Vtofs (s, T, v, P::MvAffPro)
    return v - (T - s)^2/T*P.mu
end
function dotVtofs (s, T, v,  P::MvAffPro)
    P.mu
end



function XofU!(XX, UU, tmin, T, v, P) 
    ss = UU.tt
    U = UU.yy
    for i in 1:length(ss)
        s = ss[i]
        u = U[:, i]
        XX.tt[i] = tmin + tofs(s,tmin, T)
        XX.yy[:, i] = xofu(s,u,  T, v,  P)
    end
    XX
end

function XofU(UU, tmin, T, v, P) 
    XX = MvPath(copy(UU.tt), copy(UU.yy))
    XofU!(XX, UU, tmin, T, v, P) 
end

#helper functions


function J(s,T, P::MvLinPro, x)
    phim = expm(-(T-s)^2/T*P.B)
    sl = P.lambda*T/(T-s)^2
    ( phim*sl*phim'-sl)\x
end


function J(s,T, P::MvAffPro, x)
    P.Gamma*x
end    

function J(s,T, P::MvLinPro)
    phim = expm(-(T-s)^2/T*P.B)
    sl = P.lambda*T/(T-s)^2
    inv( phim*sl*phim'-sl)
end


function J(s,T, P::MvAffPro)
    P.Gamma
end

function bU(s, u, tmin, T, v, Pt::Union(MvLinPro, MvAffPro), P)
    t, x = txofsu(s, u, tmin, T, v, Pt)
    2./T*dotVtofs(s,T,v, Pt) - 2/T*b(t, x, P) +   1./(T-s)*(u-   2.*a(t, x, P)*J(s, T, Pt, u) )
end



function llikeliU(U, tmin, T, v, Pt::Union(MvLinPro, MvAffPro), P)
    ss = U.tt
    uu = U.yy
    
    N = size(uu,2)
    som = 0. 
    for i in 1:N-1
        s = ss[i]
        u = uu[:, i]
        j = J(s, T, Pt)
        ju = j*u
        t, x = txofsu(s, u, tmin, T, v, Pt)

        z1 = 2*dot(b(t, x, P)  - b(t,x, Pt),ju)
        z2 = -1./(T-s)*trace((a(t,x, P) - a(t,x, Pt)) *( j - T*ju*ju' ))
        som += (z1 + z2)*(ss[i+1]-ss[i])
    end
    som
 
end

function eulerU!(U::MvPath, ustart, W::MvPath, tmin, T, v, Pt::Union(MvLinPro, MvAffPro),  P::MvPro)
    ww = W.yy
    U.tt[:] = W.tt
    ss, uu = U.tt, U.yy

    N = length(ss)

    u = copy(ustart)
        
    for i in 1:N-1
        uu[:,i] = u
        t, x = txofsu(ss[i], u, tmin, T, v, Pt)
    bU = 2/T*dotVtofs(ss[i],T,v, Pt) - 2/T*b(t, x, P) +   1/(T-ss[i])*(u - 2.*a(t, x, P)*J(ss[i], T, Pt, u) )
    sigmaU = -sqrt(2.0/(T*(T-ss[i])))*sigma(t, x, P)
        u[:] = u .+  bU*(ss[i+1]-ss[i]) .+ sigmaU*(ww[:, i+1]-ww[:, i])
    end
    uu[:,N] = 0u
    U
end

function eulerU(ustart, W::MvPath, tmin, T, v, Pt::Union(MvLinPro, MvAffPro),  P::MvPro)

    eulerU!(MvPath(copy(W.tt), zeros(Pt.d, length(W.tt))), ustart, W, tmin, T, v, Pt,  P)

end

#function eulerU(ustart, W::MvPath, tmin, T, v, Pt::MvPro,  P::MvPro)
#    ww = W.yy
#    ss = copy(W.tt)

#    N = length(ss)
#    uu = zeros(size(ustart)..., length(W.tt))
#    u = copy(ustart)
#        
#    for i in 1:N-1
#        uu[:,i] = u
#        t, x = txofsu(ss[i], u, tmin, T, v, Pt)
#    bU = 2/T*dotVtofs(ss[i],T,v, Pt) - 2/T*b(t, x, P) +   1/(T-ss[i])*(u-   2.*a(t, x, P)*J(ss[i], T, Pt, u) )
#    sigmaU = -sqrt(2.0/(T*(T-ss[i])))*sigma(t, x, P)
#        u[:] = u .+  bU*(ss[i+1]-ss[i]) .+ sigmaU*(ww[:, i+1]-ww[:, i])
#    end
#    uu[:,N] = 0u
#    MvPath(ss, uu)
#end

#%  .. function:: stable(Y, d, ep)
#%           
#%     Return real stable `d`-dim matrix with real eigenvalues smaller than `-ep` parametrized with a vector of length `d*d`, 
#%  
#%  
#%      For maximum likelihood estimation we need to search the maximum over all stable matrices.
#%    These are matrices with eigenvalues with strictly negative real parts.
#%    We obtain a dxd stable matrix as difference of a antisymmetric matrix and a positive definite matrix.
#%  


function stable(Y, d, ep)

    # convert first d*(d+1)/2 values of Y into upper triangular matrix
    # positive definite matrix
    x = zeros(d,d)
    k = 1
    for i in 1:d
        for j in i:d
        x[i,j] = Y[k]
        k = k + 1
        end
    end
    # convert next d*(d+1)/2 -d values of Y into anti symmetric matrix
    y = zeros(d,d)
    for i in 1:d
        for j  in i+1:d
        y[i,j] = Y[k]
        y[j,i] = -y[i, j]
        k = k + 1
        end
    end
    assert(k -1 == d*d == length(Y))
    
    # return stable matrix as a sum of a antisymmetric and a positive definite matrix
    y - x'*x - ep*eye(2) 
end


###
 
function varH(t, T, B, a::Function)
    d = size(B,1)
    function f(s, y)
        y[:] = vec(expm(-(s-t)*B)*a(s)*expm(-(s-t)*B)')
    end
    Q = reshape(Cubature.hquadrature(d*d, f, t, T; reltol=1E-15, abstol=1E-15, maxevals=5000)[1], d,d) 
    inv(Q)
end    

#obtaining r via quadrature
function varmu(h, x, B, beta)
    function f(s, y)
        y[:] = expm(-s*B)*beta
    end
    integral = Cubature.hquadrature(length(beta), f, 0, h; reltol=1E-15, abstol=1E-15, maxevals=05000)[1]
    expm(h*B)*(x + integral)
end    


function varr(h, x, v, B, beta, lambda)
    mu = varmu(h, x, B, beta)
    expm(h*B')*inv(LinProc.K(h, B, lambda))*(v - mu) 
end

function varQ(s, T, ph, B, a::Function)
    d = size(B,1)
    
    function f(tau, y)
        y[:] = vec(expm(ph(s,tau)*B)*a(tau)*expm(ph(s,tau)*B)')
    end
    Q = reshape(Cubature.hquadrature(d*d, f, s, T; reltol=1E-15, abstol=1E-15, maxevals=05000)[1], d,d)
    Q
end
 
function varV(s,T, v, ph, B, beta)
    function f(tau, y)
        y[:] = expm(ph(s,tau)*B)*beta(tau)
    end
    expm(-ph(T,s)*B)*v - Cubature.hquadrature(length(v), f, s, T; reltol=1E-15, abstol=1E-15, maxevals=05000)[1]
    
end


function graph(X::MvPath)
    p = FramedPlot()
    if ndims(X.yy) == 1 || (ndims(X.yy) == 2 && size(X.yy,1) == 1)
        setattr(p, "xrange", SDE.hrange(X.tt))
        setattr(p, "yrange", SDE.hrange(X.yy[:]))
        add(p, Curve(X.tt,X.yy[:], "color","black", "linewidth", 0.5))
    
    elseif ndims(X.yy) == 2 && size(X.yy,1) == 2
        setattr(p, "xrange", SDE.hrange(X.yy[1,:]))
        setattr(p, "yrange", SDE.hrange(X.yy[2,:]))
        add(p, Curve(X.yy[1,:],X.yy[2,:], "color","black", "linewidth", 0.5))
    
    end
    p
end
    


end
