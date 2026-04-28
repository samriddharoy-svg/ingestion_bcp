# ---------- Base image with code + deps ----------
FROM python:3.11-slim AS base

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# If you have requirements.txt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the code
COPY . .

# ---------- Image for fetch_benchmarks ----------
FROM base AS fetch-benchmarks
CMD ["python", "fetch_loaders/fetch_benchmarks.py"]



# ---------- Image for fetch_live_prices ----------
FROM base AS fetch-live-prices
CMD ["python", "fetch_loaders/fetch_live_prices.py"]

# ---------- Image for fetch_instrument_prices ----------
FROM base AS fetch-instrument-prices
CMD ["python", "fetch_loaders/fetch_instrument_prices.py"]

# ---------- Image for fetch_valuation ----------
FROM base AS fetch-valuation
CMD ["python", "fetch_loaders/fetch_valuation.py"]

# ---------- Image for fetch_balance ----------
FROM base AS fetch-balance
CMD ["python", "fetch_loaders/fetch_balance.py"]



# ---------- Image for fetch_cashflow ----------
FROM base AS fetch-cashflow
CMD ["python", "fetch_loaders/fetch_cashflow.py"]


# ---------- Image for fetch_margingrowth ----------
FROM base AS fetch-margingrowth
CMD ["python", "fetch_loaders/fetch_margingrowth.py"]



# ---------- Image for fetch_revenue ----------
FROM base AS fetch-revenue
CMD ["python", "fetch_loaders/fetch_revenue.py"]

# ---------- Image for fetch_ebita ----------
FROM base AS fetch-ebita
CMD ["python", "fetch_loaders/fetch_ebita.py"]

# ---------- Image for fetch_netincome ----------
FROM base AS fetch-netincome
CMD ["python", "fetch_loaders/fetch_netincome.py"]

# ---------- Image for fetch_freecashflow ----------
FROM base AS fetch-freecashflow
CMD ["python", "fetch_loaders/fetch_freecashflow.py"]

# ---------- Image for fetch_eps ----------
FROM base AS fetch-eps
CMD ["python", "fetch_loaders/fetch_eps.py"]

# ---------- Image for fetch_cash_and_debt ----------
FROM base AS fetch-cash-debt
CMD ["python", "fetch_loaders/fetch_cashdebt.py"]

# ---------- Image for fetch_return_of_capital ----------
FROM base AS fetch-returnofcapital
CMD ["python", "fetch_loaders/fetch_returnofcapital.py"]

# ---------- Image for fetch_shares_outstanding ----------
FROM base AS fetch-sharesoutstanding
CMD ["python", "fetch_loaders/fetch_sharesoutstanding.py"]

# ---------- Image for fetch_dividend_per_share ----------
FROM base AS fetch-dividend-per-share
CMD ["python", "fetch_loaders/fetch_dividend_per_share.py"]

# ---------- Image for fetch_price_to_earning ----------
FROM base AS fetch-price-to-earning
CMD ["python", "fetch_loaders/fetch_price_to_earning.py"]

# ---------- Image for fetch_outlook_ingestion ----------
FROM base AS fetch-outlookingestion
CMD ["python", "fetch_loaders/fetch_outlookingestion.py"]


# ---------- Image for refresh_materialized_views ----------
FROM base AS refresh-materialized-views
CMD ["python", "fetch_loaders/refresh_materialized_views.py"]


# ---------- Image for refresh_stocks_fundamentals_mviews ----------
FROM base AS refresh-stocks-fundamentals-mviews
CMD ["python", "fetch_loaders/refresh_stocks_fundamentals_mviews.py"]



# ---------- Image for fetch_news ----------
FROM base AS fetch-news
CMD ["python", "fetch_loaders/fetch_news.py"]

# ---------- Image for fetch_flag ----------
FROM base AS fetch-flag
CMD ["python", "fetch_loaders/fetch_flag.py"]


# ---------- Image for fetch_ai_summary_fundamentals ----------
FROM base AS fetch-ai-summary-fundamentals
CMD ["python", "fetch_loaders/fetch_ai_summary_fundamentals.py"]

# ---------- Image for fetch_ai_summary_portfolio ----------
FROM base AS fetch-ai-summary-portfolio
CMD ["python", "fetch_loaders/fetch_ai_summary_portfolio.py"]

# ---------- Image for fetch_correlation_matrix ----------
FROM base AS fetch-correlation-matrix
CMD ["python", "fetch_loaders/fetch_correlation_matrix.py"]

# ---------- Image for fetch_stockalert ----------
FROM base AS fetch-stockalert
CMD ["python", "fetch_loaders/fetch_stockalert.py"]












