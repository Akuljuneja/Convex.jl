export ecos_solve

# Calls the ECOS C solver
#
# Input
# n: is the number of variables,
# m: is the number of inequality constraints (dimension 1 of the matrix G and the
# length of the vector h),
# p: is the number of equality constraints (can be 0)
# l: is the dimension of the positive orthant, i.e. in Gx+s=h, s in K, the first l
# elements of s are >=0
# ncones: is the number of second-order cones present in K
# q: is an array of integers of length ncones, where each element defines the dimension
# of the cone
# c is an array of type float of size n
# h is an array of type float of size m
# b is an array of type float of size p (can be nothing if no equalities are present)
#
# Returns:
# A dictionary 'solution' of type:
# {:x => x, :y => y, :z => z, :s => s, :status => status, :ret_val => ret_val}
# where x are the primal variables, y are the multipliers for the equality constraints
# z are the multipliers for the conic inequalities
#
# TODO: I should specify their types
function ecos_solve(;n=nothing, m=nothing, p=nothing, l=nothing, ncones=nothing,
    q=nothing, G=nothing, A=nothing, c=nothing, h=nothing, b=nothing, debug=false)

  @assert n != nothing
  @assert m != nothing
  @assert p != nothing

  @assert c != nothing
  @assert h != nothing

  @assert G != nothing

  if l == nothing
    l = m
    print_debug(debug, "Value of l=nothing, setting it to the same as m=$m");
  end

  if ncones == nothing
    ncones = 0
  end

  if q == nothing
    q = convert(Ptr{Int64}, C_NULL)
  end

  if A == nothing
    Apr = convert(Ptr{Float64}, C_NULL)
    Ajc = convert(Ptr{Int64}, C_NULL)
    Air = convert(Ptr{Int64}, C_NULL)
  else
    sparseA = sparse(A)
    # TODO: hack to make it float, find a better way
    Apr = sparseA.nzval * 1.0
    # -1 since C is 0 indexed
    Ajc = sparseA.colptr - 1
    Air = sparseA.rowval - 1
  end

  sparseG = sparse(G)
  # TODO: hack to make it float, find a better way
  Gpr = sparseG.nzval * 1.0
  # -1 since C is 0 indexed
  Gjc = sparseG.colptr - 1
  Gir = sparseG.rowval - 1

  if b == nothing
    b = convert(Ptr{Float64}, C_NULL)
  end

  # Call ECOS to setup the problem
  pwork = ccall((:ECOS_setup, "../ecos/ecos.so"), Ptr{Void},
      (Int64, Int64, Int64, Int64, Int64, Ptr{Int64}, Ptr{Float64}, Ptr{Int64}, Ptr{Int64},
      Ptr{Float64}, Ptr{Int64}, Ptr{Int64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}),
      n, m, p, l, ncones, q, Gpr, Gjc, Gir, Apr, Ajc, Air, c, h, b)

  # Solve the problem
  ret_val = ccall((:ECOS_solve, "../ecos/ecos.so"), Int64, (Ptr{Void},), pwork)

  solution = get_ecos_solution(pwork, n, p, m, ret_val)

  # TODO: Check how many we need to keep
  # 4 means we keep x,y,z,s, 3 means x,y,z and so on
  num_vars_to_keep = 4
  # ccall((:ECOS_cleanup, "../ecos/ecos.so"), Void, (Ptr{Void}, Int64), pwork, num_vars_to_keep)
  return solution
end


# Given the arguments, returns a dictionary with variables x, y, z, s and status
function get_ecos_solution(pwork, n, p, m, ret_val)
  double_ptr = convert(Ptr{Ptr{Float64}}, pwork)
  # TODO: Worry about freeing memory?

  # x is the 5th
  x_ptr = unsafe_load(double_ptr, 5)
  x = pointer_to_array(x_ptr, n)

  y_ptr = unsafe_load(double_ptr, 6)
  y = pointer_to_array(y_ptr, p)

  z_ptr = unsafe_load(double_ptr, 7)
  z = pointer_to_array(z_ptr, m)

  s_ptr = unsafe_load(double_ptr, 8)
  s = pointer_to_array(s_ptr, m)

  if ret_val == 0
    status = "solved"
  elseif ret_val == 1
    status = "primal infeasible"
  elseif ret_val == 2
    status = "dual infeasible"
  elseif ret_val == -1
    status = "max iterations reached"
  elseif ret_val == -2 || ret_val == -3
    status = "numerical problems in solver"
  else
    status = "unknown problem in solver"
  end

  return {:x => x, :y => y, :z => z, :s => s, :status => status, :ret_val => ret_val}
end