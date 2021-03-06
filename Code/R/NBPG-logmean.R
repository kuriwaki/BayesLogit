## Copyright 2013 Nick Polson, James Scott, and Jesse Windle.

## This file is part of BayesLogit, distributed under the GNU General Public
## License version 3 or later and without ANY warranty, implied or otherwise.


source("NB-Shape.R");

################################################################################
                             ## When Modeling MU ##
################################################################################

draw.beta.PG <- function(X, kappa, d, w, b.0=NULL, B.0=NULL, P.0=NULL)
{
  ## X: N x P design matrix.
  ## b.0: prior mean for beta
  ## B.0: prior variance for beta
  ## P.0: prior precision for beta.
  
  N = nrow(X);
  P = ncol(X);

  if (is.null(b.0)) b.0 = rep(0.0, P);
  if (is.null(P.0)) P.0 = matrix(0.0, P, P);
  if (!is.null(B.0)) P.0 = solve(B.0);

  P.N = t(X) %*% (X * w) + P.0;
  a.L = t(X) %*% (kappa + w * log(d));
  ## S = solve(PC); ## chol2inv works better for larger P?
  S = chol2inv(chol(P.N));
  m = S %*% (a.L + P.0 %*% b.0);
  beta = m + t(chol(S)) %*% rnorm(P);

} ## draw.beta.PG

NB.PG.gibbs <- function(y, X,
                        b.0=NULL, B.0 = NULL, P.0 = NULL,
                        samp=1000, burn=500, verbose=500,
                        beta.true = NULL, w.true = NULL, d.true=NULL)
{
  ## X: n by p matrix
  ## y: n by 1 vector, counts.

  X = as.matrix(X);
  y = as.matrix(y);
  
  P = ncol(X)
  N = nrow(X)
  
  ## Default prior parameters.
  if (is.null(b.0)) b.0 = rep(0.0, P);
  if (is.null(P.0)) P.0 = matrix(0.0, P, P);
  if (!is.null(B.0)) P.0 = solve(B.0);
  
  ## Initialize.
  beta = rep(0.0, P)
  d = 1;

  ## Set known.
  if (!is.null(beta.true)) beta = beta.true;
  if (!is.null(w.true))    w    = w.true;
  if (!is.null(d.true))    d    = d.true;

  ## Preprocess
  ymax = max(y);
  F = cumsum(hist(y, breaks=0:(ymax+1)-0.5, plot=FALSE)$counts)
  G = N - F;
  
  out <- list(w = matrix(nrow=samp, ncol=N),
                 beta = matrix(nrow=samp, ncol=P),
                 d = rep(0, samp)
                 )

  start.time = proc.time()
  
  ## Sample
  for ( j in 1:(samp+burn) )
  {
    if (j==burn+1) start.ess = proc.time()

    ## WARNING: JOINT DRAW.
    ## draw (d, w | beta)
    ## draw (d | beta)
    phi = drop(X%*%beta)
    mu  = exp(phi)
    d = draw.df(y, d, mu, G, ymax);
    ## d = draw.df.real.mean(y, d, mu);
    ## draw (w | d, beta)
    psi = phi - log(d);
    ## w = rpg.devroye(N, y+d, psi);
    w = rpg(N, y+d, psi)
    ## w = rpg.gamma(N, y+d, psi, trunc=200);

    ## draw beta
    kappa = 0.5 * (y-d)
    beta = draw.beta.PG(X, kappa, d, w, b.0=b.0, P.0=P.0);
    
    # Record if we are past burn-in.
    if (j>burn) {
        out$w[j-burn,]    = w
        out$beta[j-burn,] = beta
        out$d[j-burn]     = d
    }

    if (j %% verbose == 0) { print(paste("NBPG-logmean: Iteration", j)); }
  }

  end.time = proc.time()
  out$total.time = end.time - start.time
  out$ess.time   = end.time - start.ess
  
  out
} ## logit.PG.gibbs

################################################################################

if (FALSE) {

  ## source("NBPG-logmean.R")
  source("ManualLoad.R")
  
  N = 400
  P = 4
  X = matrix(rnorm(N*(P-1)), nrow=N, ncol=P-1);
  X = cbind(1, X)

  beta = c(4.0, 0.2, -0.9, -0.2);

  ## Poisson-Gamma mixture.
  phi = X %*% beta;
  mu = exp(phi);
  d  = 4
  p  = (mu / (mu + d));
  alpha = p / (1-p)
  lambda = rgamma(N, d, scale=alpha);
  y = rpois(N, lambda);

  samp = 10000
  burn = 500
  verbose = 1000

  start.time = proc.time()
  out <- NB.PG.gibbs(y, X,
                     samp=samp, burn=burn, verbose=verbose,
                     beta.true = NULL, w.true = NULL, d.true=NULL)
  diff.time = proc.time() - start.time
  
}

#-------------------------------------------------------------------------------

if (FALSE) {

  load("DataSets/NBSynth_N400_P4_I3.RData")

  ## y = pmin(150, y)

  samp = 1000
  burn = 500
  verbose = 500
  
  start.time = proc.time()
  out <- NB.PG.gibbs(y, X,
                     samp=samp, burn=burn, verbose=verbose,
                     beta.true = NULL, w.true = NULL, d.true=NULL)
  diff.time = proc.time() - start.time
  
}


