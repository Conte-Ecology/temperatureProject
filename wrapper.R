#' @title modelRegionalTemp
#'
#' @description
#' \code{modelRegionalTemp} Linear mixed model in JAGS to model daily stream temperature
#'
#' @param data dataframe created in the 3-statModelPrep.Rmd script
#' @param params Character string of parameters to monitor (return) from the model
#' @param n.burn Integer number of iterations in the burn-in (adapation) phase of the MCMC
#' @param n.it Integer number of iterations per chain to run after the burn-in
#' @param n.thin Integer: save every nth iteration
#' @param n.chains Integer number of chains. One run per cluster so should use <= # cores on computer
#' @param coda Logical if TRUE return coda mcmc.list, if FALSE (default) return jags.samples object
#' 
#' @return Returns the iterations from the Gibbs sampler for each variable in params as either an mcmc.list or jags.samples object
#' @details
#' This function takes daily observed stream temperatures, air temperature, snow-water-equivalent (swe), day of the year, and landscape covariates for a linear mixed effects model with site and year random effects.
#' 
#' @examples
#' 
#' \dontrun{
#' mcmc.out <- modelRegionalTemp(tempDataSyncS, n.burn = 1000, n.it = 1000, n.thin = 3, n.chains = 3)
#' }
#' @export
modelRegionalTemp <- function(data = tempDataSyncS, params = c("sigma", "B.0", "B.site", "rho.B.site", "mu.site", "sigma.b.site", "B.year", "rho.B.year", "mu.year", "sigma.b.year"), n.burn = 5000, n.it = 3000, n.thin = 3, n.chains = 3, coda = FALSE) {
  #  temp.model <- function(){
  sink("code/modelRegionalTemp.txt")
  cat("
      model{
      # Likelihood
      for(i in 1:n){ # n observations
      temp[i] ~ dnorm(stream.mu[i], tau)
      stream.mu[i] <- inprod(B.0[], X.0[i, ]) + inprod(B.site[site[i], ], X.site[i, ]) + inprod(B.year[year[i], ], X.year[i, ]) #  
      }
      
      # prior for model variance
      sigma ~ dunif(0, 100)
      tau <- pow(sigma, -2)
      
      for(k in 1:K.0){
      B.0[k] ~ dnorm(0, 0.001) # priors coefs for fixed effect predictors
      }
      
      # Priors for random effects of site
      for(j in 1:J){ # J sites
      B.site[j, 1:K] ~ dmnorm(mu.site[ ], tau.B.site[ , ])
      }
      mu.site[1] <- 0
      for(k in 2:K){
      mu.site[k] ~ dnorm(0, 0.0001)
      }
      
      # Prior on multivariate normal std deviation
      tau.B.site[1:K, 1:K] ~ dwish(W.site[ , ], df.site)
      df.site <- K + 1
      sigma.B.site[1:K, 1:K] <- inverse(tau.B.site[ , ])
      for(k in 1:K){
      for(k.prime in 1:K){
      rho.B.site[k, k.prime] <- sigma.B.site[k, k.prime]/sqrt(sigma.B.site[k, k]*sigma.B.site[k.prime, k.prime])
      }
      sigma.b.site[k] <- sqrt(sigma.B.site[k, k])
      }
      
      # YEAR EFFECTS
      # Priors for random effects of year
      for(t in 1:Ti){ # Ti years
      B.year[t, 1:L] ~ dmnorm(mu.year[ ], tau.B.year[ , ])
      }
      mu.year[1] <- 0
      for(l in 2:L){
      mu.year[l] ~ dnorm(0, 0.0001)
      }
      
      # Prior on multivariate normal std deviation
      tau.B.year[1:L, 1:L] ~ dwish(W.year[ , ], df.year)
      df.year <- L + 1
      sigma.B.year[1:L, 1:L] <- inverse(tau.B.year[ , ])
      for(l in 1:L){
      for(l.prime in 1:L){
      rho.B.year[l, l.prime] <- sigma.B.year[l, l.prime]/sqrt(sigma.B.year[l, l]*sigma.B.year[l.prime, l.prime])
      }
      sigma.b.year[l] <- sqrt(sigma.B.year[l, l])
      }
      }
      ",fill = TRUE)
  sink()
  
  # Fixed effects
  #variables.fixed <- c("intercept",  
  #"drainage", 
  #"forest",
  #"elevation")
  #K.0 <- length(variables.fixed)
  X.0 <- data.frame(intercept = 1,
                    lat = data$Latitude,
                    lon = data$Longitude)
  variables.fixed <- names(X.0)
  K.0 <- length(variables.fixed)
  
  
  # Random site effects
  #variables.site <- c("Intercept-site",
  #                   "Air Temperature",
  #                  "Air Temp Lag1",
  #                 "Air Temp Lag2",
  #                "Precip",
  #               "Precip Lag1",
  #              "Precip Lag2")
  
  # Slope, Aspect, Dams/Impoundments, Agriculture, Wetland, Coarseness, dayl, srad, swe
  
  X.site <- data.frame(intercept.site = 1, 
                       airTemp = data$airTemp, 
                       airTempLag1 = data$airTempLagged1,
                       airTempLag2 = data$airTempLagged2,
                       precip = data$prcp,
                       precipLag1 = data$prcpLagged1,
                       precipLag2 = data$prcpLagged3,
                       drainage = data$TotDASqKM,
                       forest = data$Forest,
                       elevation = data$ReachElevationM,
                       coarseness = data$SurficialCoarseC,
                       wetland = data$CONUSWetland,
                       impoundments = data$ImpoundmentsAllSqKM,
                       swe = data$swe)
  variables.site <- names(X.site)
  J <- length(unique(data$site))
  K <- length(variables.site)
  n <- dim(data)[1]
  W.site <- diag(K)
  
  # Random Year effects
  #variables.year <- c("Intercept-year",
  #                  "dOY",
  #                 "dOY2",
  #                "dOY3")
  
  X.year <- data.frame(intercept.year = 1, 
                       dOY = data$dOY, 
                       dOY2 = data$dOY^2,
                       dOY3 = data$dOY^3)
  variables.year <- names(X.year)
  Ti <- length(unique(data$year))
  L <- length(variables.year)
  W.year <- diag(L)
  
  data <- list(n = n, 
               J = J, 
               K = K, 
               Ti = Ti,
               L = L,
               K.0 = K.0,
               X.0 = X.0,
               W.site = W.site,
               W.year = W.year,
               temp = data$temp,
               X.site = X.site, #as.matrix(X.site),
               X.year = as.matrix(X.year),
               site = as.factor(data$site),
               year = as.factor(data$year))
  
  inits <- function(){
    list(#B.raw = array(rnorm(J*K), c(J,K)), 
      #mu.site.raw = rnorm(K),
      sigma = runif(1))
    #tau.B.site.raw = rwish(K + 1, diag(K)),)
  }
  
  params <- c("sigma",
              "B.0",
              "B.site",
              "rho.B.site",
              "mu.site",
              "sigma.b.site",
              "B.year",
              "rho.B.year",
              "mu.year",
              "sigma.b.year")#,
  # "stream.mu")
  
  #M1 <- bugs(data, )
  
  # n.burn = 5000
  #  n.it = 3000
  # n.thin = 3
  
  library(parallel)
  library(rjags)
  
  # model.tc <- textConnection(modelstring)
  #filename <- file.path(tempdir(), "tempmodel.txt")
  #write.model(temp.model, filename)
  
  if(coda) {
    CL <- makeCluster(n.chains)
    clusterExport(cl=CL, list("data", "inits", "params", "K", "J", "Ti", "L", "n", "W.site", "W.year", "X.site", "X.year", "n.burn", "n.it", "n.thin"), envir = environment())
    clusterSetRNGStream(cl=CL, iseed = 2345642)
    
    system.time(out <- clusterEvalQ(CL, {
      library(rjags)
      load.module('glm')
      jm <- jags.model("code/modelRegionalTemp.txt", data, inits, n.adapt = n.burn, n.chains=1)
      fm <- coda.samples(jm, params, n.iter = n.it, thin = n.thin)
      return(as.mcmc(fm))
    }))
    
    M3 <- mcmc.list(out)
  } else {
    CL <- makeCluster(n.chains)
    clusterExport(cl=CL, list("data", "inits", "params", "K", "J", "Ti", "L", "n", "W.site", "W.year", "X.site", "X.year", "n.burn", "n.it", "n.thin"), envir = environment())
    clusterSetRNGStream(cl=CL, iseed = 2345642)
    
    system.time(out <- clusterEvalQ(CL, {
      library(rjags)
      load.module('glm')
      jm <- jags.model("code/modelRegionalTemp.txt", data, inits, n.adapt = n.burn, n.chains=1)
      fm <- jags.samples(jm, params, n.iter = n.it, thin = n.thin)
      return(fm)
    }))
    
    M3 <- mcmc.list(out)
  }
  
  stopCluster(CL)
  
  return(M3)
}



write.model <- function (model, con = "model.txt") {
  if (is.R()) {
    model.text <- c("model", replaceScientificNotationR(body(model), digits = digits))
  }
  else {
    model.text <- paste("model", as.character(model))
  }
  model.text <- gsub("%_%", "", model.text)
  writeLines(model.text, con = con)
}


replaceScientificNotationR <- function (bmodel, digits = 5) {
  env <- new.env()
  assign("rSNRidCounter", 0, envir = env)
  replaceID <- function(bmodel, env, digits = 5) {
    for (i in seq_along(bmodel)) {
      if (length(bmodel[[i]]) == 1) {
        if (as.character(bmodel[[i]]) %in% c(":", "[", 
                                             "[[")) 
          return(bmodel)
        if ((typeof(bmodel[[i]]) %in% c("double", "integer")) && 
              ((abs(bmodel[[i]]) < 0.001) || (abs(bmodel[[i]]) > 
                                                10000))) {
          counter <- get("rSNRidCounter", envir = env) + 
            1
          assign("rSNRidCounter", counter, envir = env)
          id <- paste("rSNRid", counter, sep = "")
          assign(id, formatC(bmodel[[i]], digits = 5, 
                             format = "E"), envir = env)
          bmodel[[i]] <- id
        }
      }
      else {
        bmodel[[i]] <- replaceID(bmodel[[i]], env, digits = 5)
      }
    }
    bmodel
  }
  bmodel <- deparse(replaceID(bmodel, env, digits = 5), 
                    control = NULL)
  for (i in ls(env)) {
    bmodel <- gsub(paste("\"", i, "\"", sep = ""), get(i, 
                                                       envir = env), bmodel, fixed = TRUE)
  }
  bmodel
}