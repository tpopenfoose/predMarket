# rm(list=ls())
args <- commandArgs(trailingOnly = TRUE)
numcores <- as.integer(args[1])
message(paste("Number of cores", numcores))

source("main.R")
library(sa)

##############################################################################
## Set up parameters for climate_model to control level of tracing to screen
##############################################################################

SHOW_CLIMATE_PLOTS <- FALSE  # Plot graph of temperature after each year?
TRACE_CLIMATE_MODEL <- FALSE # Show diagnostic traces for stan runs?
STAN_REFRESH <-  0           # Frequency to show stan chain progress. 0 for silent
PARALLEL_STAN <- FALSE       # Run chains in parallel?
WHICH_MODEL <- 'ar1'         # "default", "arma11", or "ar1". "ar1" is recommended for speed and stability.

max_p <- 1                   # Maximum order for AR when running auto_arma
max_q <- 0                   # Maximum order for MA when running auto_arma

plot_final <- TRUE

##############################################################################
## Experiment function
##############################################################################
run_experiment <- function(set, input_values, 
                           file_path = "output/average_convergence_past.Rda",
                           previous_results = NULL,
                           sample_count = 30,
                           burn.in = 51, n.seq = 14, horizon = 6,
                           true_history = FALSE){  
  nyears <- burn.in + n.seq * horizon
  
  if(is.null(previous_results)){
    average_convergence <- data.frame(stringsAsFactors = FALSE)
  } else {
    load(previous_results) # needs to be a char vec specifying a path to a 
    # df called "average_convergence" created by this function before
    stopifnot(exists("average_convergence"))
  }
  
  for(j in set){
    input_values$n.edg <- list(random_function = "qunif",
                               ARGS = list(min = j$n.edg, max = j$n.edg))
    input_values$seg <- list(random_function = "qunif",
                             ARGS = list(min = j$seg, max = j$seg))
    
    # TRUE model is log co2
    input_values$true.model <- list(random_function = "qbinom",
                                    ARGS = list(size = 1, prob = 1))
    input_set <- create_set(input_values = input_values, 
                            input_names = names(input_values), 
                            sample_count = sample_count,
                            constraints = "none",
                            model_data = NULL)
    outcome.evolution <- foreach::`%dopar%`(foreach::foreach(i=seq(nrow(input_set)), .combine='c'), {
      tryCatch(
        main(parameters = as.numeric(input_set[i, ]), 
             out = "fraction_converge",
             burn.in = burn.in,
             n.seq = n.seq,
             horizon = horizon,
             nyears =  nyears,
             iterations = 1,
             record = TRUE,
             trueHistory = true_history),
        error = function(e) rep(NA, n.seq))
    })
    cat(paste("\n", n.seq, "outcome evolutions with LogCO2 and parameters", paste(as.character(j), collapse = ", "), "\n", outcome.evolution))
    average_convergence <- rbind(average_convergence,
                                 data.frame(convergence = outcome.evolution,
                                            trading_seq = rep(seq(n.seq), nrow(input_set)),
                                            true_mod = "LogCo2",
                                            set = paste(as.character(j), collapse = ", "),
                                            stringsAsFactors = FALSE)
    )
    
    # TRUE model is slow TSI
    input_values$true.model <- list(random_function = "qbinom",
                                    ARGS = list(size = 1, prob = 0))
    input_set <- create_set(input_values = input_values, 
                            input_names = names(input_values), 
                            sample_count = sample_count,
                            constraints = "none",
                            model_data = NULL)
    outcome.evolution <- foreach::`%dopar%`(foreach::foreach(i=seq(nrow(input_set)), .combine='c'), {
      tryCatch(
        main(parameters = as.numeric(input_set[i, ]), 
             out = "fraction_converge",
             burn.in = burn.in,
             n.seq = n.seq,
             horizon = horizon,
             nyears =  nyears,
             iterations = 1,
             record = TRUE,
             trueHistory = true_history),
        error = function(e) rep(NA, n.seq))
    })
    cat(paste("\n", n.seq, "outcome evolutions with SlowTSI and parameters", paste(as.character(j), collapse = ", "), "\n", outcome.evolution))
    average_convergence <- rbind(average_convergence,
                                 data.frame(convergence = outcome.evolution, 
                                            trading_seq = rep(seq(n.seq), nrow(input_set)),
                                            true_mod = "SlowTSI",
                                            set = paste(as.character(j), collapse = ", "),
                                            stringsAsFactors = FALSE)
    )
  }
  save(average_convergence, file = file_path)
  invisible(average_convergence)
}


##############################################################################
## Param distributions to draw from
##############################################################################
input_values <- lapply(list(seg = NA, ideo = NA, risk.tak = NA), 
                       function(x) list(random_function = "qunif",
                                        ARGS = list(min = 0.0001, max = 0.9999)))
input_values$true.model <- list(random_function = "qbinom",
                                ARGS = list(size = 1, prob = 0.5))
input_values$n.edg <- list(random_function = "qunif",
                           ARGS = list(min = 0.0001, max = 0.9999))
input_values$n.traders <- list(random_function = "qunif",
                               ARGS = list(min = 0.0001, max = 0.9999))

set <- list()
set[[1]] <- list(n.edg = 0.95, seg = 0.95)
set[[2]] <- list(n.edg = 0.95, seg = 0.05)
set[[3]] <- list(n.edg = 0.05, seg = 0.95)
set[[4]] <- list(n.edg = 0.05, seg = 0.05)


##############################################################################
## Run experiment
##############################################################################
doParallel::registerDoParallel(cores = numcores)
sample_count <- numcores*6 # numcores*7 takes 8.5 hours to run for past
past <- TRUE
future <- TRUE
true_past <- TRUE

if(future){
  run_experiment(set = set, input_values = input_values, 
                 file_path = "output/convergence_future.Rda",
                 # Add to previous results?
                 # previous_results = "output/convergence_future.Rda",
                 sample_count = sample_count,
                 burn.in = 135,
                 true_history = TRUE)
}

if(true_past){
  run_experiment(set = set, input_values = input_values, 
                 file_path = "output/jg_convergence_true_past.Rda",
                 sample_count = sample_count,
                 burn.in = 51,
                 true_history = TRUE)
  
if(past){
  run_experiment(set = set, input_values = input_values, 
                 file_path = "output/convergence_past.Rda",
                 sample_count = sample_count,
                 burn.in = 51,
                 true_history = FALSE)
}
}

##############################################################################
## Plots
##############################################################################
if(plot_final){
  if (future) {
    
    load("output/convergence_future.Rda")
    library(ggplot2)
    plot_data <- average_convergence
    #plot_data$set <- factor(plot_data$set, levels = gtools::mixedsort(unique(plot_data$set)))
    # n.edg <- round(parameters[5]*100) + 100 # integer in (100, 200)
    plot_data$set <- factor(plot_data$set, levels = c("0.05, 0.05", "0.05, 0.95", "0.95, 0.05", "0.95, 0.95"), 
                            labels = c(paste0(round(8 * 0.05 + 2, 1), " edges/trader, seg = 0.05"), 
                                       paste0(round(8 * 0.05 + 2, 1), " edges/trader, seg = 0.95"), 
                                       paste0(round(8 * 0.95 + 2, 1), " edges/trader, seg = 0.05"), 
                                       paste0(round(8 * 0.95 + 2, 1), " edges/trader, seg = 0.95")))
    pdf("output/timeseries_future.pdf", width=8, height=18)
    ggplot(data=plot_data, aes(x= trading_seq, y=convergence, color = true_mod)) +
      geom_point(position = position_jitter(w = 0.07, h = 0)) + geom_smooth() +
      ggplot2::facet_wrap(~set, ncol = 1) +
      ggtitle("Convergence Over Trading Sequences, Future Scenario (burn.in = 135 years)") +
      xlab("Trading Sequences") + 
      ylab(paste0("Trader Model Convergence (n = ", 
                  length(complete.cases(plot_data$convergence)), ")")) + 
      ylim(-1,1) +
      theme_bw() + theme(legend.justification=c(1,0), legend.position=c(1,0)) + 
      #scale_color_discrete(name="True Model") +
      scale_color_brewer(palette="Dark2", name="True Model")
    dev.off()
  }
  if (true_past) {
    
    load("output/convergence_true_past.Rda")
    library(ggplot2)
    plot_data <- average_convergence
    #plot_data$set <- factor(plot_data$set, levels = gtools::mixedsort(unique(plot_data$set)))
    # n.edg <- round(parameters[5]*100) + 100 # integer in (100, 200)
    plot_data$set <- factor(plot_data$set, levels = c("0.05, 0.05", "0.05, 0.95", "0.95, 0.05", "0.95, 0.95"), 
                            labels = c(paste0(round(8 * 0.05 + 2, 1), " edges/trader, seg = 0.05"), 
                                       paste0(round(8 * 0.05 + 2, 1), " edges/trader, seg = 0.95"), 
                                       paste0(round(8 * 0.95 + 2, 1), " edges/trader, seg = 0.05"), 
                                       paste0(round(8 * 0.95 + 2, 1), " edges/trader, seg = 0.95")))
    pdf("output/timeseries_true_past.pdf", width=8, height=18)
    ggplot(data=plot_data, aes(x= trading_seq, y=convergence, color = true_mod)) +
      geom_point(position = position_jitter(w = 0.07, h = 0)) + geom_smooth() +
      ggplot2::facet_wrap(~set, ncol = 1) +
      ggtitle("Convergence Over Trading Sequences, True Past Scenario (burn.in = 51 years)") +
      xlab("Trading Sequences") + 
      ylab(paste0("Trader Model Convergence (n = ", 
                  length(complete.cases(plot_data$convergence)), ")")) + 
      ylim(-1,1) +
      theme_bw() + theme(legend.justification=c(1,0), legend.position=c(1,0)) + 
      #scale_color_discrete(name="True Model") +
      scale_color_brewer(palette="Dark2", name="True Model")
    dev.off()
  }
  if (past) {
    load("output/convergence_past.Rda")
    library(ggplot2)
    plot_data <- average_convergence
    #plot_data$set <- factor(plot_data$set, levels = gtools::mixedsort(unique(plot_data$set)))
    # n.edg <- round(parameters[5]*100) + 100 # integer in (100, 200)
    plot_data$set <- factor(plot_data$set, levels = c("0.05, 0.05", "0.05, 0.95", "0.95, 0.05", "0.95, 0.95"), 
                            labels = c(paste0(round(8 * 0.05 + 2, 1), " edges/trader, seg = 0.05"), 
                                       paste0(round(8 * 0.05 + 2, 1), " edges/trader, seg = 0.95"), 
                                       paste0(round(8 * 0.95 + 2, 1), " edges/trader, seg = 0.05"), 
                                       paste0(round(8 * 0.95 + 2, 1), " edges/trader, seg = 0.95")))
    pdf("output/timeseries_past.pdf", width=8, height=18)
    ggplot(data=plot_data, aes(x= trading_seq, y=convergence, color = true_mod)) +
      geom_point(position = position_jitter(w = 0.07, h = 0)) + geom_smooth() +
      ggplot2::facet_wrap(~set, ncol = 1) +
      ggtitle("Convergence Over Trading Sequences, Simulated Past Scenario (burn.in = 51 years)") +
      xlab("Trading Sequences") + 
      ylab(paste0("Trader Model Convergence (n = ", 
                  length(complete.cases(plot_data$convergence)), ")")) + 
      ylim(-1,1) +
      theme_bw() + theme(legend.justification=c(1,0), legend.position=c(1,0)) + 
      #scale_color_discrete(name="True Model") +
      scale_color_brewer(palette="Dark2", name="True Model")
    dev.off()
  }
}
