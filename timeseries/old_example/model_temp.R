## ---- include=FALSE------------------------------------------------------
library(knitr)
opts_chunk$set(cache=TRUE)

## ----load_data-----------------------------------------------------------
library(dplyr)
source('load_giss.R')
source('load_keeling.R')
source('paleo_co2.R')

scinot <- function(x, places, uthreshold = 3, lthreshold = 1-places) {
  lx <- log10(x)
  ex <- floor(lx)
  mx <- lx %% 1
  if (ex >= uthreshold || ex <= lthreshold)
    paste(signif(10^mx,places),' \\times 10^{',ex,'}',sep='')
  else 
    signif(x,places)
}

t <- load_giss_data()$data %>% select(time, t = t.anom)
t <- na.omit(t)

co2 <- get.co2()$keeling %>% select(time = year, co2 = annual) %>% mutate(time = (floor(time * 12) + 0.5)/12)

co2.law <- load_law_dome_co2() %>% select(time = year, co2) %>% mutate(time = time + 0.5)

sunspots <- read.csv('data/SN_ms_tot_V2.0.csv', sep=';', header=F)
names(sunspots) <- c('year','month','frac.year','ss','sd','nobs','def')
sunspots <- sunspots %>% mutate(ss = ifelse(ss >= 0, ss, NA)) %>% mutate(time = year + (month - 0.5)/12) %>% select(time,ss)

tsi <- tsi <- read.table('data/TSI_TIM_Reconstruction.txt', comment.char = ';')
names(tsi) <- c('time','tsi')
tsi$xtsi <- tsi$tsi
for(i in seq_along(tsi)[-1]) tsi$xtsi[i] <- 0.05 * tsi$tsi[i] + 0.95 * tsi$xtsi[i-1]

data <- merge(t, co2, all.x = TRUE)

data.solar <- t %>% mutate(time = floor(time) + 0.5) %>% group_by(time) %>% summarize(t = mean(t)) %>% ungroup()
data.solar <- merge(data.solar, co2.law, all.x = TRUE)
data.solar <- merge(data.solar, sunspots, all.x = TRUE)
data.solar <- merge(data.solar, tsi, all.x = TRUE)

## ---- lin_model, dependson=c("load_data"), cache.extra=c(data)-----------
d <- na.omit(data %>% select(time, t, co2))
co2.lin <- lm(t ~ co2, data = d)
co2.res <- data.frame(time = d$time, r = residuals(co2.lin))

p <- predict(co2.lin)

## ----plot_lin_model, dependson=c("lin_model"), cache.extra=c(d,p)--------
library(ggplot2)

ggplot(cbind(d,predict = p), aes(x = co2, y = t)) + geom_point(size = 2, color = "dark blue", alpha=0.5) + 
  geom_line(aes(y=predict), size=1) +
  labs(x = expression(paste(CO[2]," (ppm)")), 
       y = expression(paste("Temperature anomaly ", (degree * C)))) +
  theme_bw(base_size=20)


## ----test_acf, fig.scap=c('Autocorrelation','Partial autocorrelation'), fig.cap="Compare autocorrelation of fit residuals to AR(1) and ARMA(1,1) models.", dependson=c("lin_model"), cache.extra=c(d,co2.res), warning=FALSE----
library(tseries)
library(nlme)

source('acftest.R')

co2.ar1 <- arma(co2.res$r, order=c(1,0), include.intercept = FALSE, method="BFGS")
co2.arma11 <- arma(co2.res$r, order=c(1,1), include.intercept = FALSE, method="BFGS")

co2.aic <- c(ar1 = summary(co2.ar1)$aic, arma11 = summary(co2.arma11)$aic)
use_arma_co2 <- co2.aic['ar1'] > co2.aic['arma11']

acftest(co2.res, co2.arma11, co2.ar1, ci.type='ma')
acftest(co2.res, co2.arma11, co2.ar1, type='partial', ci.type='ma')

## ----fit_gls, dependson=c("line_model", "test_acf"), cache.extra=c(co2.arma11,d)----
if (use_arma_co2) {
  cs <- corARMA(coef(co2.arma11), p=1, q=1, form=~1)
} else {
  cs <- corAR1(coef(co2.ar1), form = ~1)
}
model.cst <- Initialize(cs, data = d)
model.gls <- gls(t ~ co2, data = d, correlation=model.cst)
p <- predict(model.gls)
d$predicted <- predict(model.gls)

## ----plot_gls, dependson=c('fit_gls'), cache.extra=c(model.gls, data)----
ggplot(d, aes(x = co2, y = t)) + geom_point(color = "dark blue", size=2, alpha = 0.5) +
  geom_line(aes(y = predicted), size=1) + 
  labs(x = expression(paste(CO[2]," (ppm)")), 
       y = expression(paste("Temperature anomaly ", (degree * C)))) +
  theme_bw(base_size = 20)

ggplot(d, aes(x = time, y = t)) + geom_point(color = "dark blue", size=2, alpha = 0.5) +
  geom_line(aes(y = predicted), size=1) + 
  labs(x = "Year",
       y = expression(paste("Temperature anomaly ", (degree * C)))) +
  theme_bw(base_size = 20)

## ----lin_model_tsi, dependson=c("load_data"), cache.extra=c(data)--------
d.tsi <- na.omit(data.solar %>% select(time, t, tsi = xtsi))
tsi.lin <- lm(t ~ tsi, data = d.tsi)
tsi.res <- data.frame(time = d.tsi$time, r = residuals(tsi.lin))

p.tsi <- predict(tsi.lin)

## ----plot_lin_model_tsi, dependson=c("lin_model_tsi"), cache.extra=c(tsi.lin, d.tsi, p.tsi)----
library(ggplot2)

ggplot(cbind(d.tsi,predict = p.tsi), aes(x = tsi, y = t)) + geom_point(size = 2, color = "dark blue", alpha=0.5) + 
  geom_line(aes(y=predict), size=1) +
  labs(x = expression(paste("Total Solar Irradiance ", W / m^2)),
       y = expression(paste("Temperature anomaly ", (degree * C)))) +
  theme_bw(base_size=20)


## ----test_acf_tsi, fig.scap=c('Autocorrelation','Partial autocorrelation'), fig.cap="Compare autocorrelation of fit residuals to AR(1) and ARMA(1,1) models.", dependson=c("lin_model_tsi"), warning=FALSE----

tsi.ar1 <- arma(tsi.res$r, order=c(1,0), include.intercept = FALSE, method="BFGS")
tsi.arma11 <- arma(tsi.res$r, order=c(1,1), include.intercept = FALSE, method="BFGS")

tsi.aic <- c(ar1 = summary(tsi.ar1)$aic, arma11 = summary(tsi.arma11)$aic)
use_arma_tsi <- tsi.aic['ar1'] > tsi.aic['arma11']

acftest(tsi.res, tsi.arma11, tsi.ar1, ci.type='ma')
acftest(tsi.res, tsi.arma11, tsi.ar1, type='partial', ci.type='ma')

## ----fit_gls_tsi, dependson=c("line_model", "test_acf")------------------
if (use_arma_tsi) {
  cs.tsi <- corARMA(coef(tsi.arma11), p = 1, q = 1, form = ~1)
} else {
  cs.tsi <- corAR1(coef(tsi.ar1), form=~1)
}
model.cst.tsi <- Initialize(cs.tsi, data = d.tsi)
model.gls.tsi <- gls(t ~ tsi, data = d.tsi, correlation=model.cst.tsi)
d.tsi$predicted.tsi <- predict(model.gls.tsi)

## ----plot_gls_tsi, dependson=c("fit_gls_tsi")----------------------------
ggplot(d.tsi, aes(x = tsi, y = t)) + geom_point(color = "dark blue", size=2, alpha = 0.5) +
  geom_line(aes(y = predicted.tsi), size=1) + 
  labs(x = expression(paste("Total Solar Irradiance ", W / m^2)),
       y = expression(paste("Temperature anomaly ", (degree * C)))) +
  theme_bw(base_size = 20)

ggplot(d.tsi, aes(x = time, y = t)) + geom_point(color = "dark blue", size=2, alpha = 0.5) +
  geom_line(aes(y = predicted.tsi), size=1) + 
  labs(x = "Year",
       y = expression(paste("Temperature anomaly ", (degree * C)))) +
  theme_bw(base_size = 20)

