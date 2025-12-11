library(readxl)
xlsx_path <- "~/Downloads/card.xlsx"
raw <- readxl::read_excel(xlsx_path)
clean_money <- function(x) {
x <- as.character(x)
as.numeric(gsub("[^0-9-]", "", x))
}
parse_myddyy <- function(x) {
if (inherits(x, "Date")) return(x)
if (is.numeric(x))      return(as.Date(x, origin = "1899-12-30"))  

out <- as.Date(x, format = "%d/%m/%y")

if (all(is.na(out))) out <- as.Date(x, format = "%d/%m/%Y")
out
}
names(raw) <- tolower(names(raw))

df <- data.frame(
date       = parse_myddyy(raw[["date"]]),
loans      = clean_money(raw[["loans"]]),
chargeoffs = clean_money(raw[["chargeoffs"]]))

 
df <- df[order(df$date),]
 
df$pct_chargeoff    <- 100 * df$chargeoffs / df$loans                
df$d1_pct_chargeoff <- c(NA, diff(df$pct_chargeoff))                  
 
out <- transform(
    df,
    pct_chargeoff    = round(pct_chargeoff, 3),
    d1_pct_chargeoff = round(d1_pct_chargeoff, 3)
    )[, c("date", "loans", "chargeoffs", "pct_chargeoff", "d1_pct_chargeoff")]
 
print(out, row.names = FALSE)


library(quantmod); library(xts); library(dplyr); library(lubridate); library(zoo)


q_mean_ce <- function(x){
  q <- apply.quarterly(x, mean, na.rm = TRUE)
  idx <- as.Date(as.yearqtr(index(q)), frac = 1) 
  xts(coredata(q), order.by = idx)
}

UNRATE_Q   <- q_mean_ce(UNRATE)
BRENTOIL_Q <- q_mean_ce(DCOILBRENTEU)
T10Y2Y_Q   <- q_mean_ce(T10Y2Y)
VIX_Q      <- q_mean_ce(VIXCLS)
GDP_Q      <- GDPC1                                    
idx_ce     <- as.Date(as.yearqtr(index(GDP_Q)), frac=1)
GDP_Q_CE   <- xts(coredata(GDP_Q), order.by = idx_ce)
GDP_GROWTH_Q <- GDP_Q_CE/lag(GDP_Q_CE) - 1
colnames(GDP_GROWTH_Q) <- "GDP_GROWTH"

mac_q <- na.omit(merge(UNRATE_Q, BRENTOIL_Q, T10Y2Y_Q, VIX_Q, GDP_GROWTH_Q))
colnames(mac_q) <- c("UNRATE","DCOILBRENTEU","T10Y2Y","VIXCLS","GDP_GROWTH")

mac_df <- data.frame(date = as.Date(index(mac_q)), coredata(mac_q))


final_tbl <- out %>%
  mutate(date = as.Date(date)) %>%
  left_join(mac_df, by = "date") %>%
  arrange(date)

print(head(final_tbl, 12))
# INI BUAT NGELIAT TIME SERIES CHARGEOFF VS MACROS
library(ggplot2)

zvars <- c("pct_chargeoff","UNRATE","DCOILBRENTEU","T10Y2Y","VIXCLS","GDP_GROWTH")
Z <- scale(final_tbl[, zvars])
long <- cbind(date = final_tbl$date, stack(as.data.frame(Z)))
names(long) <- c("date","z","series")

ggplot(long, aes(date, z, color = series)) +
  geom_line() +
  labs(title = "Standardized time series: pct_chargeoff vs macro drivers",
       y = "z-score (mean=0, sd=1)", x = NULL, color = "Series") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")
# INI VISUALISASI
library(ggplot2); library(dplyr); library(tidyr)


p_levels <- ggplot(final_tbl, aes(date, pct_chargeoff)) +
  geom_line() +
  labs(title="Credit-card Charge-off Rate (%)", y="%", x=NULL) +
  theme_minimal(14)

p_diff <- final_tbl |>
  dplyr::filter(!is.na(d1_pct_chargeoff)) |>
  ggplot(aes(date, d1_pct_chargeoff)) +
  geom_line() +
  labs(title = "Δ Charge-offs (pp)", y = "percentage points", x = NULL) +
  theme_minimal(14)

p_levels; p_diff
# HEATMAP CORRELATION MATRIX

eda_df <- final_tbl |>
  select(pct_chargeoff, UNRATE, DCOILBRENTEU, T10Y2Y, VIXCLS, GDP_GROWTH) |>
  tidyr::drop_na()
cmat <- cor(eda_df)
corr <- as.data.frame(as.table(cmat)); names(corr) <- c("x","y","r")

ggplot(corr, aes(x, y, fill = r)) +
  geom_tile() + geom_text(aes(label=sprintf("%.2f", r)), size=3) +
  scale_fill_gradient2(limits=c(-1,1)) + coord_fixed() +
  labs(title="Correlation matrix", x=NULL, y=NULL) +
  theme_minimal(13)

# MODELINGNYA OLS, MAE

library(dplyr); library(tidyr); library(ggplot2)


dat <- final_tbl |>
  transmute(
    date,
    CRE = d1_pct_chargeoff,
    UNRATE, DCOILBRENTEU, T10Y2Y, VIXCLS, GDP_GROWTH
  ) |>
  drop_na()


make_lags <- function(df, cols, L=4){
  out <- df
  for(nm in cols){
    for(l in 0:L){
      out[[paste0(nm,"_L",l)]] <- dplyr::lag(out[[nm]], l)
    }
  }
  out
}
XCOLS <- c("UNRATE","DCOILBRENTEU","T10Y2Y","VIXCLS","GDP_GROWTH")
dlag  <- make_lags(dat, XCOLS, L=4) |>
  drop_na()

split_date <- as.Date("2016-01-01")
train <- dlag |> filter(date < split_date)
test  <- dlag |> filter(date >= split_date)

ols <- lm(CRE ~ . - date, data = train)
summary(ols)

ols_pred <- predict(ols, newdata = test)
ols_rmse <- sqrt(mean((test$CRE - ols_pred)^2))
ols_mae  <- mean(abs(test$CRE - ols_pred))
c(OLS_RMSE = ols_rmse, OLS_MAE = ols_mae)

# MODELING LASSO
library(glmnet)

X_tr <- as.matrix(select(train, -date, -CRE))
y_tr <- train$CRE
X_te <- as.matrix(select(test,  -date, -CRE))
y_te <- test$CRE

set.seed(42)
cv <- cv.glmnet(X_tr, y_tr, alpha=1, nfolds=5)
lasso <- glmnet(X_tr, y_tr, alpha=1, lambda=cv$lambda.min)

pred_lasso <- as.numeric(predict(lasso, X_te))
lasso_rmse <- sqrt(mean((y_te - pred_lasso)^2))
lasso_mae  <- mean(abs(y_te - pred_lasso))
c(LASSO_RMSE = lasso_rmse, LASSO_MAE = lasso_mae)


nz <- coef(lasso)
nz[nz != 0]

#MODELING NYA YANG INI ARIMA
library(forecast)

xreg_tr <- as.matrix(select(train, UNRATE_L0, VIXCLS_L0, GDP_GROWTH_L1))
xreg_te <- as.matrix(select(test,  UNRATE_L0, VIXCLS_L0, GDP_GROWTH_L1))

fit_arimax <- auto.arima(y_tr, xreg = xreg_tr, stepwise=FALSE, approximation=FALSE)
fc <- forecast(fit_arimax, xreg = xreg_te, h = nrow(test))

arimax_rmse <- sqrt(mean((y_te - as.numeric(fc$mean))^2))
arimax_mae  <- mean(abs(y_te - as.numeric(fc$mean)))
c(ARIMAX_RMSE = arimax_rmse, ARIMAX_MAE = arimax_mae)

# HASIL OLS, ARIMA, LASSO

library(dplyr)
library(tidyr)
library(ggplot2)

actual_df <- tibble(date = test$date, truth = y_te)

pred_df <- tibble(
  date   = test$date,
  OLS    = ols_pred,
  LASSO  = pred_lasso,
  ARIMAX = as.numeric(fc$mean)
) |>
  pivot_longer(cols = c(OLS, LASSO, ARIMAX),
               names_to = "series", values_to = "value")

# VISUALISASI MODEL VS ACTUAL
ggplot() +
  geom_line(data = pred_df, aes(date, value, color = series), linewidth = 1) +
  geom_line(data = actual_df, aes(date, truth), color = "black", linewidth = 1.2) +
  labs(title = "One-quarter-ahead forecasts",
       y = "Δ charge-offs (pp)", x = NULL,
       caption = "Black = actual; colors = model predictions") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")