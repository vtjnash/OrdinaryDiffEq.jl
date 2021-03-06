## y'' = f(t, y, y')
## y(t₀) = y₀; y'(t₀) = y'₀
## kᵢ' = f(t₀+cᵢh, y₀+cᵢhy'₀+h²∑āᵢⱼk'ⱼ, y'₀+h∑aᵢⱼk'ⱼ)
## y₁ = y₀ + hy'₀ + h²∑b̄ᵢk'ᵢ
## y'₁ = y'₀ + h∑bᵢk'ᵢ

function initialize!(integrator,cache::Nystrom4Cache,f=integrator.f)
  @unpack tmp,fsalfirst,k₂,k₃,k₄,k = cache
  uprev,duprev = integrator.uprev.x

  integrator.fsalfirst = fsalfirst
  integrator.fsallast = k
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  f.f1(integrator.t,uprev,duprev,integrator.k[2].x[1])
  f.f2(integrator.t,uprev,duprev,integrator.k[2].x[2])
end

@muladd function perform_step!(integrator,cache::Nystrom4Cache,f=integrator.f)
  @unpack t,dt = integrator
  u,du = integrator.u.x
  uprev,duprev = integrator.uprev.x
  @unpack tmp,fsalfirst,k₂,k₃,k₄,k = cache
  ku, kdu = integrator.cache.tmp.x[1], integrator.cache.tmp.x[2]
  k₁ = fsalfirst
  halfdt = dt/2
  dtsq = dt^2
  eighth_dtsq = dtsq/8
  half_dtsq = dtsq/2
  ttmp = t+halfdt

  ## y₁ = y₀ + hy'₀ + h²∑b̄ᵢk'ᵢ
  @. ku = uprev + halfdt*duprev + eighth_dtsq*k₁.x[2]
  ## y'₁ = y'₀ + h∑bᵢk'ᵢ
  @. kdu = duprev + halfdt*k₁.x[2]

  f.f2(ttmp,ku,kdu,k₂.x[2])
  @. ku = uprev + halfdt*duprev + eighth_dtsq*k₁.x[2]
  @. kdu = duprev + halfdt*k₂.x[2]

  f.f2(ttmp,ku,kdu,k₃.x[2])
  @. ku = uprev + dt*duprev + half_dtsq*k₃.x[2]
  @. kdu = duprev + dt*k₃.x[2]

  f.f2(t+dt,ku,kdu,k₄.x[2])
  @. u = uprev + (dtsq/6)*(k₁.x[2] + k₂.x[2] + k₃.x[2]) + dt*duprev
  @. du = duprev + (dt/6)*(k₁.x[2] + k₄.x[2] + 2*(k₂.x[2] + k₃.x[2]))

  f.f1(t+dt,u,du,k.x[1])
  f.f2(t+dt,u,du,k.x[2])
end


function initialize!(integrator,cache::Nystrom4VelocityIndependentCache,f=integrator.f)
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k

  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast

  uprev,duprev = integrator.uprev.x
  f.f1(integrator.t,uprev,duprev,integrator.k[2].x[1])
  f.f2(integrator.t,uprev,duprev,integrator.k[2].x[2])
end

@muladd function perform_step!(integrator,cache::Nystrom4VelocityIndependentCache,f=integrator.f)
  @unpack t,dt = integrator
  u,du = integrator.u.x
  uprev,duprev = integrator.uprev.x
  @unpack tmp,fsalfirst,k₂,k₃,k = cache
  ku, kdu = integrator.cache.tmp.x[1], integrator.cache.tmp.x[2]
  k₁ = fsalfirst
  halfdt = dt/2
  dtsq = dt^2
  eighth_dtsq = dtsq/8
  half_dtsq = dtsq/2
  ttmp = t+halfdt

  ## y₁ = y₀ + hy'₀ + h²∑b̄ᵢk'ᵢ
  @. ku = uprev + halfdt*duprev + eighth_dtsq*k₁.x[2]

  f.f2(ttmp,ku,du,k₂.x[2])
  @. ku = uprev + dt*duprev + half_dtsq*k₂.x[2]

  f.f2(t+dt,ku,du,k₃.x[2])
  @. u = uprev + (dtsq/6)*(k₁.x[2] + 2*k₂.x[2]) + dt*duprev
  @. du = duprev + (dt/6)*(k₁.x[2] + k₃.x[2] + 4*k₂.x[2])

  f.f1(t+dt,u,du,k.x[1])
  f.f2(t+dt,u,du,k.x[2])
end

@inline function initialize!(integrator,cache::IRKN4Cache,f=integrator.f)
  @unpack tmp,fsalfirst,k₂,k = cache
  uprev,duprev = integrator.uprev.x

  integrator.fsalfirst = fsalfirst
  integrator.fsallast = k
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  f.f1(integrator.t,uprev,duprev,integrator.k[2].x[1])
  f.f2(integrator.t,uprev,duprev,integrator.k[2].x[2])
end

@inline function perform_step!(integrator,cache::IRKN4Cache,f=integrator.f)
  # if there's a discontinuity or the solver is in the first step
  if integrator.iter < 2 && !integrator.u_modified
    perform_step!(integrator,integrator.cache.onestep_cache)
  else
    @unpack t,dt,k,tprev = integrator
    u,du = integrator.u.x
    uprev, duprev  = integrator.uprev.x
    uprev2,duprev2 = integrator.uprev2.x
    uidx = eachindex(integrator.uprev.x[1])
    @unpack tmp,fsalfirst,k₂,k₃,k = cache
    ku, kdu = integrator.cache.tmp.x[1], integrator.cache.tmp.x[2]
    k₁ = fsalfirst
    dtsq = dt^2

    f.f2(t+1//4*dt,    uprev, duprev, k.x[1])
    f.f2(tprev+1//4*dt,uprev2,duprev2,k.x[2])
    @tight_loop_macros for i in uidx
      @inbounds ku[i]  = @muladd uprev[i]  + (1//4*dt)*duprev[i]  + (1//32*dtsq)*k.x[1][i]
      @inbounds kdu[i] = @muladd uprev2[i] + (1//4*dt)*duprev2[i] + (1//32*dtsq)*k.x[2][i]
    end

    f.f2(t+1//4*dt,    ku, duprev, k₂.x[1])
    f.f2(tprev+1//4*dt,kdu,duprev2,k₂.x[2])
    @tight_loop_macros for i in uidx
      @inbounds ku[i]  = @muladd uprev[i]  + (3//4*dt)*duprev[i]  + (9//32*dtsq)*k₂.x[1][i]
      @inbounds kdu[i] = @muladd uprev2[i] + (3//4*dt)*duprev2[i] + (9//32*dtsq)*k₂.x[2][i]
    end

    f.f2(t+3//4*dt,    ku, duprev, k₃.x[1])
    f.f2(tprev+3//4*dt,kdu,duprev2,k₃.x[2])
    @tight_loop_macros for i in uidx
      @inbounds u[i]  = @muladd uprev[i] + (3//2*dt)*duprev[i] + (1//2*-dt)*duprev2[i] + (7//24*dtsq)*(k₂.x[1][i]-k₂.x[2][i]) + (1//8*dtsq)*(k₃.x[1][i]-k₃.x[2][i])
      @inbounds du[i] = @muladd duprev[i] + dt*(19//18*k.x[1][i] - 1//18*k.x[2][i] + (-1//6)*(k₂.x[1][i]-k₂.x[2][i]) + 11//18*(k₃.x[1][i]-k₃.x[2][i]))
    end
    f.f1(t+dt,u,du,k.x[1])
    f.f2(t+dt,u,du,k.x[2])
  end # end if
end

function initialize!(integrator,cache::Nystrom5VelocityIndependentCache,f=integrator.f)
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k

  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast

  uprev,duprev = integrator.uprev.x
  f.f1(integrator.t,uprev,duprev,integrator.k[2].x[1])
  f.f2(integrator.t,uprev,duprev,integrator.k[2].x[2])
end

#=
@muladd function perform_step!(integrator,cache::Nystrom5VelocityIndependentCache,f=integrator.f)
  @unpack t,dt = integrator
  u,du = integrator.u.x
  uprev,duprev = integrator.uprev.x
  @unpack tmp,fsalfirst,k₂,k₃,k₄,k = cache
  ku, kdu = integrator.cache.tmp.x[1], integrator.cache.tmp.x[2]
  k₁ = fsalfirst
  dtsq = dt^2

  f.f2(t+1//5*dt,uprev,duprev,k₁.x[2])
  @. ku = uprev + (1//5*dt)*duprev + (1//50*dtsq)*k₁.x[2]

  f.f2(t+1//5*dt,ku,du,k₂.x[2])
  @. ku = uprev + (2//3*dt)*duprev + (-1//27*dtsq)*k₁.x[2] + (7//27*dtsq)*k₂.x[2]

  f.f2(t+2//3*dt,ku,du,k₃.x[2])
  @. ku = uprev + dt*duprev + (3//10*dtsq)*k₁.x[2] + (-2//35*dtsq)*k₂.x[2] + (9//35*dtsq)*k₃.x[2]

  f.f2(t+dt,ku,du,k₄.x[2])
  @. u  = uprev + dt*duprev + (14//336*dtsq)*k₁.x[2] + (100//336*dtsq)*k₂.x[2] + (54//336*dtsq)*k₃.x[2]
  @. du = duprev[i] + (14//336*dt)*k₁.x[2][i] + (125//336*dt)*k₂.x[2][i] + (162//336*dt)*k₃.x[2][i] + (35//336*dt)*k₄.x[2][i]

  f.f1(t+dt,u,du,k.x[1])
  f.f2(t+dt,u,du,k.x[2])
end
=#

@muladd function perform_step!(integrator,cache::Nystrom5VelocityIndependentCache,f=integrator.f)
  @unpack t,dt = integrator
  u,du = integrator.u.x
  uprev,duprev = integrator.uprev.x
  uidx = eachindex(integrator.uprev.x[1])
  @unpack tmp,fsalfirst,k₂,k₃,k₄,k = cache
  ku, kdu = integrator.cache.tmp.x[1], integrator.cache.tmp.x[2]
  k₁ = fsalfirst
  dtsq = dt^2


  @. ku = uprev + (1//5*dt)*duprev + (1//50*dtsq)*k₁.x[2]

  f.f2(t+1//5*dt,ku,du,k₂.x[2])
  @. ku = uprev + (2//3*dt)*duprev + (-1//27*dtsq)*k₁.x[2] + (7//27*dtsq)*k₂.x[2]

  f.f2(t+2//3*dt,ku,du,k₃.x[2])
  @tight_loop_macros for i in uidx
    @inbounds ku[i] = uprev[i] + dt*duprev[i] + (3//10*dtsq)*k₁.x[2][i] + (-2//35*dtsq)*k₂.x[2][i] + (9//35*dtsq)*k₃.x[2][i]
  end

  f.f2(t+dt,ku,du,k₄.x[2])
  @tight_loop_macros for i in uidx
    @inbounds u[i]  = uprev[i] + dt*duprev[i] + (14//336*dtsq)*k₁.x[2][i] + (100//336*dtsq)*k₂.x[2][i] + (54//336*dtsq)*k₃.x[2][i]
    @inbounds du[i] = duprev[i] + (14//336*dt)*k₁.x[2][i] + (125//336*dt)*k₂.x[2][i] + (162//336*dt)*k₃.x[2][i] + (35//336*dt)*k₄.x[2][i]
  end
  f.f1(t+dt,u,du,k.x[1])
  f.f2(t+dt,u,du,k.x[2])
end
