module ExClark
using SDE
using Lyap
using LinProc
include(joinpath("..",  "src","misc.jl"))

srand(4)

si = 0.1; include("excoeff2.jl")
 
#T = 1.2
T = 4
N = 1201 #design points
K = 100000 #samples
subsample = 100
res = zeros(int(K/subsample)+1, 11)

# if v=re() is distributed with log density le()
# and yy is a path with drift LinProc.Bcirc(T, v, b, sigma, B, beta, lambda) and diffusion sigma
# (lambda has to be computed for B(T, v) and a(T,v)!)
# then the expectation of llikelicirc(... yy, ...) is 1/pbar
# where pbar = exp(lp(..., B, beta, lambda) - le(v0)))

v0max = [NaN, NaN]

 
function rare(K, N, E, re, pe)

	println("Compute P(X in E), K=$K")
 
	llmax = [Inf,-Inf]
	lplambdamax = [Inf,-Inf]

	L = L2 = 0.0
	V = 0.0
	V2 = 0.0
 	# avoid cancellation 
	V0 = BigFloat(0.0)
	V02 = BigFloat(0.0)
	
	Dt = diff(linspace(0., T, N))
	dt = Dt[1]
	Smax = LinProc.taui(T-dt,T)
	S = linspace(0.,Smax, N)
	Ds = diff(S)
	ds = Ds[1]

	for k in 1:K
	
		if (OS_NAME != :Windows) print("$k $V\r") end

 		DW = randn(2, N-1) .* sqrt(dt)
	 	yy = LinProc.eulerv(0.0, u, b, sigma, Dt, DW)


	 	
		v = yy[1:2, N]

		v0 = re()

		
 		# find lambda at the endpoint
		lambda = Lyap.lyap(B', -a(T,v0))
		lplambda = LinProc.lp(T, u, v0, B, beta, lambda)
		
 		#yy = LinProc.eulerv(0.0, u, v0, LinProc.Bcirc(T, v0, b, sigma, B, beta, lambda), sigma, Dt, DW)
	 	#ll = LinProc.llikelixcirc(0, T, yy, b, a, B, beta, lambda)
		DW = randn(2, N-1) .* sqrt(ds)
		u0 =  LinProc.UofX(0,u,  T, v0,  B, beta)
		yy = LinProc.eulerv(0.0, u0, LinProc.bU(T, v0, b, a, B, beta, lambda),  (s,x) -> sqrt(T)*sigma(LinProc.ddd(s,x, 0.0, T, v0,  B, beta)...), Ds, DW)
		
		ll = LinProc.llikeliU(S, yy, T, v0, b, a,  B, beta, lambda)
	
 

		l =  exp(lplambda + ll)/pe(v0)
		
 		# running mean and sum of squares
 		if (ll > llmax[2]) vmax = v0 end
		llmax = [min(llmax[1], ll), max(llmax[2], ll)]
		lplambdamax = [min(lplambdamax[1], lplambda), max(lplambdamax[2], lplambda)]
		 
		L += l
		L2 += l^2		
		V0 += E(v0) * l
		V02 += (E(v0) * l).^2
		V += 1.*E(v)
		V2 += E(v).^2
		#println("$L $V0 $V")    
		if (0 == k % subsample)
			print("$k:")
		  
			p =  mc2(k, L, L2)
			res[:,k] = [k mc2(k, V, V2) mc2(k,float64(V0), float64(V02)) round(llmax, 1) round(lplambdamax,1)  round(vmax,2)]
			println(" v ", mc2(k, V, V2)," v0 ", mc2(k,float64(V0), float64(V02)), " < p $p max's ll ", round(llmax, 1), " lp ", round(lplambdamax,1),", v0max ", round(vmax,2)," >" )
	 
		end	
	end
end

function dens(K, N, v0, t, T, B, A)

	println("Compute P(XT in dv), K=$K, T=$T, t=$t")
	println("E ~p(t, Xt)  =  ~p(0,u) * E exp(D(X°)(t)) ")
 
	llmax = [Inf,-Inf]
	llxmax = [Inf,-Inf]

	
	# avoid cancellation 
	Lx = BigFloat(0.0)
	Lx2 = BigFloat(0.0) 
	Lo = BigFloat(0.0)
	Lo2 = BigFloat(0.0) 

	
	Dt = diff(linspace(0., t, N))
	dt = Dt[1]
	Smax = LinProc.taui(t,T)
	S = linspace(0.,Smax, N)
	Ds = diff(S)
	ds = Ds[1]
	lambda = Lyap.lyap(B', -A)
	lplambda = LinProc.lp(t, u, v0, B, beta, lambda) #
	gamma = inv(A)	
	for k in 1:K
	
		if (OS_NAME != :Windows) print("$k \r") end

		DW = randn(2, N-1) .* sqrt(dt)
	 	X = LinProc.eulerv(0.0, u, b, sigma, Dt, DW)
		x = X[1:2, N]
		if (T-t) > 0.01 #if T-t too small, lp becomes too unstable for
			llx = LinProc.lp(T-t, x, v0, B, beta, lambda)  
		else
			llx = LinProc.lp0(T-t, x, v0, B*v0 + beta, gamma)
		end
		 
 		DW = randn(2, N-1) .* sqrt(ds)
		u0 =  LinProc.UofX(0,u,  T, v0,  B, beta)
		yy = LinProc.eulerv(0.0, u0, LinProc.bU(T, v0, b, a, B, beta, lambda),  (s,z) -> sqrt(T)*sigma(LinProc.ddd(s,z, 0.0, T, v0,  B, beta)...),  Ds, DW)
		
		ll = LinProc.llikeliU(S, yy, T, v0, b, a,  B, beta, lambda)
	
		lo =  exp(lplambda + ll)
		
		# running mean and sum of squares
		llmax = [min(llmax[1], ll), max(llmax[2], ll)]
		llxmax = [min(llxmax[1], llx), max(llxmax[2], llx)]

		Lo += lo
		Lo2 += lo^2		
		Lx += exp(llx)
		Lx2 += exp(2*llx)
	 
		if (0 == k % subsample)
			print("$k:")
			res[k/subsample,:] = [k mc3(k, float64(Lx), float64(Lx2))... mc3(k,float64(Lo), float64(Lo2))... round(llmax, 3)... round(llxmax,3)...]
	  
			println(" ", mc3(k, float64(Lx), float64(Lx2)), " ~ ", mc3(k,float64(Lo), float64(Lo2)), " < max's llo ", round(llmax, 1), " llx ", round(llxmax,1)," >" )
	 
		end	
	end
	res
 
end







#v = 1.4*LinProc.mu(T, u, B, beta) # point not to far away from the mean

v= [-0.323933,  0.494032] #same as A->B in Example 2

##### proposal distribution to explore rare event E

#test, whether X(T) in E
ep = 0.05
function E(x)
 max(abs(x - v)) <= ep
end

# a density, supported on E
function pe(x)
 E(x) / (2*ep)^2
end

# sampling from pe
function re()
  v + 2*ep*rand(2)-ep
end

#rare(K, N, E, re, pe)
println("try ExClark.D()\n\t (= dens(K, N, v, t, T, B, a(T,v)))")

function D()
 dens(K, N, v, 0.999*T, T, exp(-0.2*T)*bB, a(T,v))
end	


end
