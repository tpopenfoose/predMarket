Behav <- function (
  g,
  ct #current time period
)
{
  # package requirement
  require(igraph)
  
  ######
  ## Useful variables and traders' variable initializations
  ######
  n.secu    <- length((V(g)$secu)[[1]])
  n.traders <- length(V(g))
  #n.approx  <- g$n.approx
    
  #######
  ## Traders pick at random a security that they will try to BUY once on the market
  #######
  V(g)$buy.which <- sample(n.secu, n.traders, replace = TRUE)
  
  #######
  ## Traders set a PRICE to place a BUY order (must be lower OR equal the traders's money stock)
  #######
  for (i in 1:n.traders){
    if (V(g)$approx[i] == 1){
        V(g)$buy.price[i] <-min(
                            g$reserv.tsi[ct,V(g)$buy.which[i]]*(1-V(g)$risk.tak[i]),
                            V(g)$money[i]      
        )
    }
    if (V(g)$approx[i] == 2){
        V(g)$buy.price[i] <-min(
                            g$reserv.co2[ct,V(g)$buy.which[i]]*(1-V(g)$risk.tak[i]),
                            V(g)$money[i]      
      )
    }
  }
  
  #######
  ## Traders pick at random a security they have a positive amount of to place a SELL offer 
  #######
  for (i in 1:n.traders){
    # if trader owns no securities
    if(all(V(g)$secu[[i]]==0)) V(g)$sell.which[i] <- 0
    # if trader owns at least one security, here we intend to sample an INDEX, not the value at that index
    if (any(V(g)$secu[[i]]>0)) V(g)$sell.which[i] <- sample(which(V(g)$secu[[i]] >=1),1)
    # Safeguard
    if(V(g)$secu[[i]][V(g)$sell.which[i]]<1) stop("a seller is trying to sell a security she does not own any unit of")
  }
  
  #######
  ## Traders set a PRICE to place a SELL order
  #######
    for (i in 1:n.traders){
      if (V(g)$approx[i] == 1){
        V(g)$sell.price[i] <-g$reserv.tsi[ct, V(g)$sell.which[i]]*(1+V(g)$risk.tak[i])
      }
      if (V(g)$approx[i] == 2){
        V(g)$sell.price[i] <-g$reserv.co2[ct, V(g)$sell.which[i]]*(1+V(g)$risk.tak[i])
      }
    }

  #######
  ## Return the network
  #######
  g
}




####################################
####################################
####################################
####################################
####################################
####################################


BehavPerfect <- function (
  g,
  ct #current time period
)
{
  
  # package requirement
  require(igraph)
  
  ######
  ## Useful variables and traders' variable initializations
  ######
  
  n.secu    <- length((V(g)$secu)[[1]])
  n.traders <- length(V(g))
  #n.approx  <- g$n.approx
  
  #######
  ## Traders pick at random a security that they will try to BUY once on the market
  #######
  
  V(g)$buy.which <- sample(n.secu, n.traders, replace = TRUE)
  
  #######
  ## Traders set a PRICE to place a BUY order (must be lower than traders's money stock)
  #######
  
  for (i in 1:n.traders){
    if(V(g)$approx[i] == g$true.model){
      V(g)$buy.price[i] <-min(
        g$reserv.best[ct,V(g)$buy.which[i]]*(1-V(g)$risk.tak[i]),
        V(g)$money[i]      
      )
    }
    else {
      if (V(g)$approx[i] == 1){
        V(g)$buy.price[i] <-min(
          g$reserv.tsi[ct,V(g)$buy.which[i]]*(1-V(g)$risk.tak[i]),
          V(g)$money[i]      
        )
      }
      if (V(g)$approx[i] == 2){
        V(g)$buy.price[i] <-min(
          g$reserv.co2[ct,V(g)$buy.which[i]]*(1-V(g)$risk.tak[i]),
          V(g)$money[i]      
        )
      }
    }
  }
  
  
  
  #######
  ## Traders pick at random a security they have a positive amount of to place a SELL offer 
  #######
  for (i in 1:n.traders){
    # if trader owns no securities
    if(all(V(g)$secu[[i]]==0)) V(g)$sell.which[i] <- 0
    # if trader owns at least one security, here we intend to sample an INDEX, not the value at that index
    if (any(V(g)$secu[[i]]>0)) V(g)$sell.which[i] <- sample(which(V(g)$secu[[i]] >=1),1)
    # Safeguard
    if(V(g)$secu[[i]][V(g)$sell.which[i]]<1) stop("a seller is trying to sell a security she does not own any unit of")
  }
  
  #######
  ## Traders set a PRICE to place a SELL order
  #######
  
  for (i in 1:n.traders){
    if (V(g)$approx[i] == g$true.model){
      V(g)$sell.price[i] <-g$reserv.best[ct,V(g)$sell.which[i]]*(1+V(g)$risk.tak[i])
    }
    else {
      if (V(g)$approx[i] == 1){
        V(g)$sell.price[i] <-g$reserv.tsi[ct,V(g)$sell.which[i]]*(1+V(g)$risk.tak[i])
      }
      if (V(g)$approx[i] == 2){
        V(g)$sell.price[i] <-g$reserv.co2[ct,V(g)$sell.which[i]]*(1+V(g)$risk.tak[i])
      }
    }
  }
  
  #######
  ## Return the network
  #######
  g
}
