#################### Heidelberger and Welch Diagnostic ####################

function heideldiag(x::Vector{<:Real}; alpha::Real=0.05, eps::Real=0.1,
                             etype=:imse, start::Integer=1, args...)
  n = length(x)
  delta = trunc(Int, 0.10 * n)
  y = x[trunc(Int, n / 2):end]
  S0 = length(y) * mcse(y, etype; args...)^2
  i, pvalue, converged, ybar = 1, 1.0, false, NaN
  while i < n / 2
    y = x[i:end]
    m = length(y)
    ybar = mean(y)
    B = cumsum(y) - ybar * collect(1:m)
    Bsq = (B .* B) ./ (m * S0)
    I = sum(Bsq) / m
    pvalue = 1.0 - pcramer(I)
    converged = pvalue > alpha
    if converged
      break
    end
    i += delta
  end
  halfwidth = sqrt(2.0) * erfinv(1.0 - alpha) * mcse(y, etype; args...)
  passed = halfwidth / abs(ybar) <= eps
  [i + start - 2, converged, pvalue, ybar, halfwidth, passed]
end

function heideldiag(chn::Chains;
                    alpha = 0.05,
                    eps = 0.1,
                    etype = :imse,
                    sections::Vector{Symbol}=[:parameters],
                    showall=false,
                    sorted=true,
                    args...
                   )
    c = showall ?
       sorted ? sort(chn) : chn :
       Chains(chn, _clean_sections(chn, sections); sorted=sorted)

    # Preallocate.
    _, p, m = size(c.value)
    vals = [Array{Float64}(undef, p, 6) for i in 1:m]


    # Perform tests.
    for j in 1:p, k in 1:m
        vals[k][j, :] = heideldiag(
                            collect(skipmissing(c.value[:, j, k])),
                            alpha=alpha,
                            eps=eps,
                            etype=etype,
                            start=first(c);
                            args...
                           )
    end

    # Retrieve columns.
    data = [[vals[k][:, i] for i in 1:6] for k in 1:m]

    # Obtain names of parameters.
    names_of_params = names(chn)

    # Compute data frames.
    colnames = (Symbol("Burn-in"), :Stationarity, Symbol("p-value"), :Mean, :Halfwidth,
        :Test)
    vector_of_df = [
        ChainDataFrame(
            "Heidelberger and Welch Diagnostic - Chain $i",
            (parameters = names_of_params, zip(colnames, columns)...)
        )
        for (i, columns) in enumerate(data)
    ]

    return vector_of_df
end
