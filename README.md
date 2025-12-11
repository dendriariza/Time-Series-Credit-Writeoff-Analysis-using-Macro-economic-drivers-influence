# Time-Series-Credit-Writeoff-Analysis-using-Macro-economic-drivers-influence

This project uses R to explore and model credit card charge-off rates over time and how they relate to big-picture macro variables like unemployment, GDP growth, oil prices, the yield curve, and market volatility.

The goal is to:
Clean and transform historical credit card portfolio data
Build a time series of charge-off rates
Add macro drivers
Fit and compare several forecasting models (OLS, LASSO, ARIMA with regressors)

I used credit card data which contains quarterly portfolio data such as:
date – quarter end  
loans – outstanding credit card balances  
chargeoffs – charge-off amounts  

From these, the script computes:  
pct_chargeoff = chargeoffs / loans  
d1_pct_chargeoff = first difference of pct_chargeoff  

Secondly, I also used Macro data (imported in the script) from the Federal Reserve Bank economic data (FRED)  

Variables like:  
UNRATE – unemployment rate  
VIXCLS – equity market volatility index  
DCOILBRENTEU – oil price  
T10Y2Y – yield curve slope  
GDP_GROWTH – GDP growth rate  
These are aligned with the charge-off series and standardized so they can be plotted and modeled together.  

<img width="1324" height="1018" alt="image" src="https://github.com/user-attachments/assets/3e76a48f-bded-4b36-8124-795ba27e64c2" />
<img width="1324" height="1018" alt="image" src="https://github.com/user-attachments/assets/27022215-2aac-4cec-ac52-36213aa26eb8" />
<img width="1324" height="1018" alt="image" src="https://github.com/user-attachments/assets/18a9e45e-6011-483d-8be2-2b7d874c728c" />
<img width="1324" height="1018" alt="image" src="https://github.com/user-attachments/assets/648fa338-6d70-4105-b581-6b1ffff90b83" />
<img width="1324" height="1018" alt="image" src="https://github.com/user-attachments/assets/a7d517a2-97af-4373-b616-6636b25f1f03" />



