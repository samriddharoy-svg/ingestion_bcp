# #!/usr/bin/env python3

# import argparse
# import json
# import psycopg2
# from psycopg2.extras import RealDictCursor
# from datetime import datetime, timezone
# from decimal import Decimal
# from openai import OpenAI

# import sys
# from pathlib import Path

# # Add project root to PYTHONPATH
# sys.path.insert(0, str(Path(__file__).parent.parent))


# from config import AWS_RDS, TICKER_MAPPINGS, OPENAI_API_KEY



# MODEL = "gpt-4o-mini"
# PORTFOLIO_ID = 1


# # =============================================================================
# # Database config
# # =============================================================================
# DB_CONFIG = {
#     "host": AWS_RDS["host"],
#     "port": AWS_RDS["port"],
#     "dbname": AWS_RDS["database"],
#     "user": AWS_RDS["user"],
#     "password": AWS_RDS["password"],
#     "sslmode": AWS_RDS["sslmode"],
# }


# # =============================================================================
# # Resolve stock_ids from ticker mappings
# # =============================================================================
# def get_stock_ids():
#     tickers = list(TICKER_MAPPINGS.values())

#     conn = psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)
#     cur = conn.cursor()

#     cur.execute(
#         """
#         SELECT stock_id
#         FROM ingest_db.stocks
#         WHERE ticker = ANY(%s)
#         ORDER BY stock_id
#         """,
#         (tickers,)
#     )

#     rows = cur.fetchall()
#     cur.close()
#     conn.close()

#     return [r["stock_id"] for r in rows]


# STOCK_IDS = get_stock_ids()


# # =============================================================================
# # QUERIES (unchanged)
# # =============================================================================
# QUERIES = {
#     "portfolio_stocks": """
#         SELECT portfolio_id, stock_id, ticker, company_name, sector, quantity,
#                local_currency, last_price_local_curr, last_price_usd,
#                value_local_curr, value_usd,
#                day_price_change_local_curr, day_price_change_usd, day_price_change_pct,
#                volume, volume_30d, sentiment_score, sentiment_label,
#                flag_type, flag_description, price_date
#         FROM semantic_db.vw_portfolio_stocks_details
#         WHERE portfolio_id = 1 AND stock_id = ANY(%s)
#         ORDER BY stock_id
#     """,
#     "company_profile": """
#         SELECT stock_id, stock_symbol, country, ceo, website, sector, industry,
#                full_time_employees, description, beta, financial_score
#         FROM semantic_db.vw_company_profile
#         WHERE stock_id = ANY(%s)
#     """,
#     "price_latest": """
#         SELECT stock_id, local_currency, price_local_curr, price_usd,
#                opening_price_local_curr, closing_price_local_curr,
#                day_price_change_pct, volume, volume_30d,
#                market_cap_local_curr, market_cap_usd, price_date
#         FROM semantic_db.vw_stocks_price_data_latest
#         WHERE stock_id = ANY(%s)
#     """,
#     "revenue_annual": """
#         SELECT DISTINCT stock_id, ticker, revenue, period_label
#         FROM semantic_db.vw_stocks_revenue_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "revenue_quarterly": """
#         SELECT DISTINCT stock_id, ticker, revenue, period_label
#         FROM semantic_db.vw_stocks_revenue_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Quarterly'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "ebitda_annual": """
#         SELECT DISTINCT stock_id, ticker, ebitda, period_label
#         FROM semantic_db.vw_stocks_ebitda_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "eps_annual": """
#         SELECT DISTINCT stock_id, ticker, eps, period_label
#         FROM semantic_db.vw_stocks_eps_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "fcf_annual": """
#         SELECT DISTINCT stock_id, ticker, free_cash_flow, period_label
#         FROM semantic_db.vw_stocks_free_cash_flow_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "cash_debt": """
#         SELECT stock_id, ticker, metric_type, metric_value, period_label
#         FROM semantic_db.vw_stocks_cash_debt_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "return_of_capital": """
#         SELECT stock_id, ticker, metric_type, return_of_capital, period_label
#         FROM semantic_db.vw_stocks_return_of_capital_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "dividend": """
#         SELECT stock_id, ticker, metric_type, dividend_value, period_label
#         FROM semantic_db.vw_stocks_dividend_trend_analysis
#         WHERE stock_id = ANY(%s) AND period_type = 'Annual'
#         ORDER BY stock_id, period_label DESC
#     """,
#     "valuation": """
#         SELECT stock_id, ticker, metric_type, metric_value
#         FROM semantic_db.vw_stocks_fundamentals_valuation
#         WHERE stock_id = ANY(%s)
#     """,
#     "indicators": """
#         SELECT stock_id, ticker, indicator_name, value, recorded_at
#         FROM semantic_db.vw_stocks_indicators
#         WHERE stock_id = ANY(%s)
#         ORDER BY stock_id, recorded_at DESC
#     """,
#     "flags": """
#         SELECT stock_id, flag_type, flag_description, created_at
#         FROM semantic_db.vw_stocks_flags
#         WHERE stock_id = ANY(%s)
#         ORDER BY created_at DESC
#     """,
#     "market_alerts": """
#         SELECT stock_id, stock_symbol, alert_type, description, severity, alert_date, url
#         FROM semantic_db.vw_stocks_market_alerts
#         WHERE stock_id = ANY(%s)
#         ORDER BY alert_date DESC
#         LIMIT 50
#     """,
#     "events": """
#         SELECT stock_id, event_type, event_description, expected_event_time
#         FROM semantic_db.vw_stocks_upcoming_events
#         WHERE stock_id = ANY(%s) AND expected_event_time >= CURRENT_DATE
#         ORDER BY expected_event_time
#     """,
#     "earnings_outlook": """
#         SELECT stock_id, ticker, period, num_estimates, avg_estimate, 
#                low_estimate, high_estimate, metric_type
#         FROM semantic_db.vw_stocks_earnings_outlook
#         WHERE stock_id = ANY(%s)
#         ORDER BY stock_id, recorded_at DESC
#     """,
#     "sentiment": """
#         SELECT stock_id, sentiment_score, sentiment_label, analysis_description,
#                total_messages, positive_count, neutral_count, negative_count,
#                sentiment_reasons
#         FROM semantic_db.vw_stocks_sentiment_latest
#         WHERE stock_id = ANY(%s)
#     """,
#     "driver_analysis": """
#         SELECT stock_id, driver_name, analysis_text, impact_score, analysis_period
#         FROM semantic_db.vw_stocks_driver_analysis
#         WHERE stock_id = ANY(%s)
#         ORDER BY stock_id, analyzed_date DESC
#     """,
#     "margin_growth": """
#         SELECT stock_id, ticker, metric_type, metric_value
#         FROM semantic_db.vw_stocks_fundamentals_margin_growth
#         WHERE stock_id = ANY(%s)
#     """,
# }


# # HELPER FUNCTIONS

# def decimal_to_float(obj):
#     """Convert Decimal objects to float for JSON serialization"""
#     if isinstance(obj, Decimal):
#         return float(obj)
#     elif isinstance(obj, dict):
#         return {k: decimal_to_float(v) for k, v in obj.items()}
#     elif isinstance(obj, list):
#         return [decimal_to_float(i) for i in obj]
#     elif isinstance(obj, datetime):
#         return obj.isoformat()
#     return obj


# def safe_query(cursor, query_name, query, stock_ids):
#     """Execute query safely and return results as list of dicts"""
#     try:
#         cursor.execute(query, (stock_ids,))
#         rows = cursor.fetchall()
#         return [decimal_to_float(dict(row)) for row in rows]
#     except Exception as e:
#         print(f"⚠️ Query '{query_name}' failed: {e}")
#         # Rollback to continue with next query
#         cursor.connection.rollback()
#         return []


# # MAIN DATA FETCHING

# def fetch_all_portfolio_data():
#     """Fetch all data from semantic_db views for portfolio stocks"""
#     print("\n" + "="*70)
#     print("📊 FETCHING PORTFOLIO DATA FROM DATABASE")
#     print("="*70)
    
#     conn = psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)
#     cursor = conn.cursor()
    
#     print(f"✅ Connected to {DB_CONFIG['dbname']}")
    
#     all_data = {}
    
#     for query_name, query in QUERIES.items():
#         print(f"  📥 Fetching {query_name}...", end=" ")
#         result = safe_query(cursor, query_name, query, STOCK_IDS)
#         all_data[query_name] = result
#         print(f"({len(result)} rows)")
    
#     cursor.close()
#     conn.close()
    
#     return all_data


# def build_portfolio_object(raw_data):
#     """Build structured portfolio object for AI consumption"""
#     print("\n" + "="*70)
#     print("🔧 BUILDING STRUCTURED PORTFOLIO OBJECT")
#     print("="*70)
    
#     # Index data by stock_id
#     portfolio_stocks = {r['stock_id']: r for r in raw_data.get('portfolio_stocks', [])}
#     company_profile = {r['stock_id']: r for r in raw_data.get('company_profile', [])}
#     price_latest = {r['stock_id']: r for r in raw_data.get('price_latest', [])}
#     sentiment = {r['stock_id']: r for r in raw_data.get('sentiment', [])}
    
#     # Group multi-row data by stock
#     def group_by_stock(data):
#         grouped = {}
#         for row in data:
#             sid = row.get('stock_id')
#             if sid not in grouped:
#                 grouped[sid] = []
#             grouped[sid].append(row)
#         return grouped
    
#     revenue_annual = group_by_stock(raw_data.get('revenue_annual', []))
#     revenue_quarterly = group_by_stock(raw_data.get('revenue_quarterly', []))
#     ebitda_annual = group_by_stock(raw_data.get('ebitda_annual', []))
#     eps_annual = group_by_stock(raw_data.get('eps_annual', []))
#     fcf_annual = group_by_stock(raw_data.get('fcf_annual', []))
#     cash_debt = group_by_stock(raw_data.get('cash_debt', []))
#     return_of_capital = group_by_stock(raw_data.get('return_of_capital', []))
#     dividend = group_by_stock(raw_data.get('dividend', []))
#     valuation = group_by_stock(raw_data.get('valuation', []))
#     indicators = group_by_stock(raw_data.get('indicators', []))
#     margin_growth = group_by_stock(raw_data.get('margin_growth', []))
#     flags = group_by_stock(raw_data.get('flags', []))
#     alerts = group_by_stock(raw_data.get('market_alerts', []))
#     events = group_by_stock(raw_data.get('events', []))
#     earnings = group_by_stock(raw_data.get('earnings_outlook', []))
#     drivers = group_by_stock(raw_data.get('driver_analysis', []))
    
#     # Helper to get latest value from grouped data
#     def get_latest(grouped, sid, key='metric_value'):
#         items = grouped.get(sid, [])
#         return items[0].get(key) if items else None
    
#     # Helper to get specific metric from grouped data
#     def get_metric(grouped, sid, metric_type, value_key='metric_value'):
#         items = grouped.get(sid, [])
#         for item in items:
#             if item.get('metric_type') == metric_type:
#                 return item.get(value_key)
#         return None
    
#     # Helper to pivot indicators into dict
#     def get_indicators_dict(grouped, sid):
#         items = grouped.get(sid, [])
#         return {item.get('indicator_name'): item.get('value') for item in items}
    
#     # Helper to pivot valuation/margin metrics
#     def get_metrics_dict(grouped, sid, value_key='metric_value'):
#         items = grouped.get(sid, [])
#         return {item.get('metric_type'): item.get(value_key) for item in items}
    
#     # Build portfolio object
#     portfolio = {
#         "report_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
#         "portfolio_id": PORTFOLIO_ID,
#         "total_stocks": len(STOCK_IDS),
#         "stocks": []
#     }
    
#     # Portfolio-level aggregations
#     total_value_usd = 0
#     positive_day_change = 0
#     negative_day_change = 0
#     positive_sentiment = 0
#     negative_sentiment = 0
    
#     for sid in STOCK_IDS:
#         ps = portfolio_stocks.get(sid, {})
#         cp = company_profile.get(sid, {})
#         pl = price_latest.get(sid, {})
#         sent = sentiment.get(sid, {})
        
#         # Get revenue history (last 3 years)
#         rev_hist = revenue_annual.get(sid, [])[:3]
#         rev_q_hist = revenue_quarterly.get(sid, [])[:4]
        
#         # Get EBITDA history
#         ebitda_hist = ebitda_annual.get(sid, [])[:3]
        
#         # Get EPS history
#         eps_hist = eps_annual.get(sid, [])[:3]
        
#         # Get FCF history
#         fcf_hist = fcf_annual.get(sid, [])[:3]
        
#         # Get indicators
#         ind = get_indicators_dict(indicators, sid)
        
#         # Get valuation metrics
#         val = get_metrics_dict(valuation, sid)
        
#         # Get margin metrics
#         margins = get_metrics_dict(margin_growth, sid)
        
#         # Get cash/debt metrics (latest period)
#         cash_metrics = {}
#         for item in cash_debt.get(sid, []):
#             mt = item.get('metric_type')
#             if mt not in cash_metrics:
#                 cash_metrics[mt] = item.get('metric_value')
        
#         # Get ROE/ROA metrics (latest period)
#         roc_metrics = {}
#         for item in return_of_capital.get(sid, []):
#             mt = item.get('metric_type')
#             if mt not in roc_metrics:
#                 roc_metrics[mt] = item.get('return_of_capital')
        
#         # Build stock object
#         stock_obj = {
#             "stock_id": sid,
#             "ticker": ps.get('ticker', f'STOCK_{sid}'),
#             "name": ps.get('company_name', ''),
#             "sector": ps.get('sector') or cp.get('sector', ''),
#             "industry": cp.get('industry', ''),
#             "country": cp.get('country', ''),
#             "currency": ps.get('local_currency', ''),
#             "description": cp.get('description', '')[:200] if cp.get('description') else '',
            
#             # Portfolio position
#             "position": {
#                 "quantity": ps.get('quantity'),
#                 "value_local": ps.get('value_local_curr'),
#                 "value_usd": ps.get('value_usd'),
#             },
            
#             # Price & Trading (today)
#             "price": {
#                 "current": ps.get('last_price_local_curr'),
#                 "current_usd": ps.get('last_price_usd'),
#                 "change_1d_pct": ps.get('day_price_change_pct'),
#                 "change_1d_local": ps.get('day_price_change_local_curr'),
#                 "volume": ps.get('volume'),
#                 "volume_30d_avg": ps.get('volume_30d'),
#                 "price_date": str(ps.get('price_date')) if ps.get('price_date') else None,
#             },
            
#             # Technical Indicators
#             "technicals": {
#                 "rsi_14": ind.get('RSI_14') or ind.get('RSI'),
#                 "macd": ind.get('MACD'),
#                 "macd_signal": ind.get('MACD_Signal'),
#                 "sma_50": ind.get('SMA_50'),
#                 "sma_200": ind.get('SMA_200'),
#                 "ema_20": ind.get('EMA_20'),
#                 "beta": cp.get('beta'),
#             },
            
#             # Valuation
#             "valuation": {
#                 "pe_ratio": val.get('P/E Ratio') or val.get('PE Ratio'),
#                 "pb_ratio": val.get('P/B Ratio') or val.get('PB Ratio'),
#                 "ps_ratio": val.get('P/S Ratio') or val.get('PS Ratio'),
#                 "ev_ebitda": val.get('EV/EBITDA'),
#                 "price_to_fcf": val.get('Price to FCF') or val.get('P/FCF'),
#                 "dividend_yield": val.get('Dividend Yield'),
#                 "market_cap": pl.get('market_cap_usd'),
#             },
            
#             # Revenue (history)
#             "revenue": {
#                 "latest_annual": rev_hist[0].get('revenue') if rev_hist else None,
#                 "latest_period": rev_hist[0].get('period_label') if rev_hist else None,
#                 "history": [
#                     {"period": r.get('period_label'), "value": r.get('revenue')}
#                     for r in rev_hist
#                 ],
#                 "latest_quarterly": rev_q_hist[0].get('revenue') if rev_q_hist else None,
#             },
            
#             # Profitability
#             "profitability": {
#                 "ebitda_latest": ebitda_hist[0].get('ebitda') if ebitda_hist else None,
#                 "ebitda_period": ebitda_hist[0].get('period_label') if ebitda_hist else None,
#                 "eps_latest": eps_hist[0].get('eps') if eps_hist else None,
#                 "eps_period": eps_hist[0].get('period_label') if eps_hist else None,
#                 "gross_margin": margins.get('Gross Margin') or margins.get('Gross Profit Margin'),
#                 "operating_margin": margins.get('Operating Margin'),
#                 "net_margin": margins.get('Net Margin') or margins.get('Net Profit Margin'),
#             },
            
#             # Cash Flow
#             "cash_flow": {
#                 "fcf_latest": fcf_hist[0].get('free_cash_flow') if fcf_hist else None,
#                 "fcf_period": fcf_hist[0].get('period_label') if fcf_hist else None,
#                 "fcf_history": [
#                     {"period": f.get('period_label'), "value": f.get('free_cash_flow')}
#                     for f in fcf_hist
#                 ],
#             },
            
#             # Balance Sheet
#             "balance_sheet": {
#                 "cash": cash_metrics.get('Cash and Cash Equivalents') or cash_metrics.get('Cash'),
#                 "total_debt": cash_metrics.get('Total Debt'),
#                 "net_debt": cash_metrics.get('Net Debt'),
#                 "debt_to_equity": cash_metrics.get('Debt to Equity'),
#                 "current_ratio": cash_metrics.get('Current Ratio'),
#             },
            
#             # Return Metrics
#             "returns": {
#                 "roe": roc_metrics.get('ROE') or roc_metrics.get('Return on Equity'),
#                 "roa": roc_metrics.get('ROA') or roc_metrics.get('Return on Assets'),
#                 "roic": roc_metrics.get('ROIC'),
#             },
            
#             # Sentiment
#             "sentiment": {
#                 "score": sent.get('sentiment_score'),
#                 "label": sent.get('sentiment_label'),
#                 "total_messages": sent.get('total_messages'),
#                 "positive_count": sent.get('positive_count'),
#                 "negative_count": sent.get('negative_count'),
#                 "neutral_count": sent.get('neutral_count'),
#             },
            
#             # Flags (from portfolio view)
#             "current_flag": {
#                 "type": ps.get('flag_type'),
#                 "description": ps.get('flag_description'),
#             },
            
#             # Recent flags
#             "flags": [
#                 {"type": f.get('flag_type'), "description": f.get('flag_description')}
#                 for f in flags.get(sid, [])[:5]
#             ],
            
#             # Market alerts (recent)
#             "alerts": [
#                 {
#                     "type": a.get('alert_type'),
#                     "message": a.get('description', '')[:150] if a.get('description') else '',
#                     "severity": a.get('severity'),
#                     "date": str(a.get('alert_date')) if a.get('alert_date') else None,
#                 }
#                 for a in alerts.get(sid, [])[:5]
#             ],
            
#             # Upcoming Events
#             "upcoming_events": [
#                 {
#                     "type": e.get('event_type'),
#                     "description": e.get('event_description', '')[:100] if e.get('event_description') else '',
#                     "date": str(e.get('expected_event_time')) if e.get('expected_event_time') else None,
#                 }
#                 for e in events.get(sid, [])[:3]
#             ],
            
#             # Earnings outlook
#             "earnings_outlook": {
#                 "estimates": [
#                     {
#                         "period": e.get('period'),
#                         "metric": e.get('metric_type'),
#                         "avg_estimate": e.get('avg_estimate'),
#                         "num_analysts": e.get('num_estimates'),
#                     }
#                     for e in earnings.get(sid, [])[:4]
#                 ],
#             },
            
#             # Key Drivers
#             "drivers": [
#                 {
#                     "name": d.get('driver_name'),
#                     "analysis": d.get('analysis_text', '')[:200] if d.get('analysis_text') else '',
#                     "impact_score": d.get('impact_score'),
#                 }
#                 for d in drivers.get(sid, [])[:3]
#             ],
#         }
        
#         portfolio["stocks"].append(stock_obj)
        
#         # Aggregate portfolio metrics
#         if ps.get('value_usd'):
#             total_value_usd += float(ps.get('value_usd', 0) or 0)
#         if ps.get('day_price_change_pct'):
#             if float(ps.get('day_price_change_pct', 0) or 0) > 0:
#                 positive_day_change += 1
#             elif float(ps.get('day_price_change_pct', 0) or 0) < 0:
#                 negative_day_change += 1
#         if sent.get('sentiment_label'):
#             if sent.get('sentiment_label') == 'positive':
#                 positive_sentiment += 1
#             elif sent.get('sentiment_label') == 'negative':
#                 negative_sentiment += 1
    
#     # Add portfolio summary
#     portfolio["portfolio_summary"] = {
#         "total_value_usd": round(total_value_usd, 2),
#         "stocks_up_today": positive_day_change,
#         "stocks_down_today": negative_day_change,
#         "positive_sentiment_stocks": positive_sentiment,
#         "negative_sentiment_stocks": negative_sentiment,
#     }
    
#     print(f"✅ Built portfolio object with {len(portfolio['stocks'])} stocks")
#     print(f"   Total value: ${total_value_usd:,.2f}")
#     print(f"   Stocks up/down today: {positive_day_change}/{negative_day_change}")
    
#     return portfolio


# # AI SUMMARY GENERATION

# SYSTEM_PROMPT = """You are a professional buy-side equity analyst writing a daily portfolio brief for institutional investors.

# Your analysis must be:
# - Data-driven: Reference specific numbers, percentages, and metrics from the provided data
# - Balanced: Present both opportunities and risks objectively
# - Actionable: Highlight key items requiring attention
# - Professional: Use formal financial language, no marketing speak

# Output format must be EXACTLY as specified - do not deviate from the structure."""


# USER_PROMPT_TEMPLATE = """
# Analyze this 10-stock global portfolio and generate a structured brief.

# PORTFOLIO DATA (JSON):
# {portfolio_json}

# ═══════════════════════════════════════════════════════════════════════════════
# REQUIRED OUTPUT FORMAT - Follow this EXACTLY:
# ═══════════════════════════════════════════════════════════════════════════════

# ### — Portfolio Qualities

# **Structural Strengths**
# - [2-3 bullet points about portfolio composition, diversification, sector mix]

# **Positive Momentum & Technical Signals**
# - [2-3 bullet points about stocks with positive trends, above moving averages, good RSI]
# - Include specific tickers and percentage changes

# **Strong Fundamentals**
# - [2-3 bullet points about revenue growth, margins, cash flow, ROE/ROA]
# - Cite specific metrics with numbers

# **Favorable Valuations**
# - [1-2 bullet points about attractively valued stocks]
# - Reference P/E, EV/EBITDA, or other valuation metrics

# **Beneficial Developments**
# - [1-2 bullet points about positive news, upcoming catalysts, sentiment]

# **Key Takeaway:** [One sentence summary of portfolio strengths]

# ---

# ### — Portfolio Risks

# **Weak Momentum & Technical Warnings**
# - [2-3 bullet points about stocks below moving averages, negative trends, poor RSI]
# - Include specific tickers and percentage declines

# **Fundamental Concerns**
# - [2-3 bullet points about declining revenue, margin compression, weak cash flow]
# - Cite specific metrics with numbers

# **Valuation Risks**
# - [1-2 bullet points about overvalued stocks or stretched multiples]

# **Balance Sheet Issues**
# - [1-2 bullet points about high debt, low liquidity, deteriorating ratios]

# **Negative Developments**
# - [1-2 bullet points about concerning news, regulatory risks, sentiment issues]

# **Concentration & Macro Risks**
# - [1-2 bullet points about sector concentration, geographic risks, macro factors]

# **Key Takeaway:** [One sentence summary of portfolio risks]

# ═══════════════════════════════════════════════════════════════════════════════
# RULES:
# ═══════════════════════════════════════════════════════════════════════════════
# 1. Use ONLY the data provided - do NOT invent facts or numbers
# 2. Each section must have substantive content based on actual data
# 3. If data is missing for a metric, skip that point - do not guess
# 4. Reference specific stock tickers when discussing individual holdings
# 5. Include actual numbers: "JD.com up 12.5% MTD" not "stock showed gains"
# 6. Keep total response under 1500 words
# 7. Maintain professional, analytical tone throughout
# 8. Do NOT use emojis or casual language
# 9. Do NOT mention data sources, APIs, or technical implementation
# """


# def generate_ai_summary(portfolio_obj):
#     """Generate AI summary using OpenAI"""
#     print("\n" + "="*70)
#     print("🤖 GENERATING AI SUMMARY")
#     print("="*70)
    
#     client = OpenAI(api_key=OPENAI_API_KEY)
    
#     # Prepare portfolio JSON (compact for token efficiency)
#     portfolio_json = json.dumps(portfolio_obj, indent=2, default=str)
    
#     print(f"📝 Portfolio data size: {len(portfolio_json):,} characters")
    
#     user_prompt = USER_PROMPT_TEMPLATE.format(portfolio_json=portfolio_json)
    
#     print("🔄 Calling OpenAI API...")
    
#     response = client.chat.completions.create(
#         model=MODEL,
#         messages=[
#             {"role": "system", "content": SYSTEM_PROMPT},
#             {"role": "user", "content": user_prompt}
#         ],
#         temperature=0.3,
#         max_tokens=3000
#     )
    
#     summary_text = response.choices[0].message.content
    
#     print(f"✅ Generated summary: {len(summary_text):,} characters")
    
#     return summary_text


# def split_sections(text):
#     """Split AI output into Quality and Risk sections"""
#     # Look for section markers
#     quality_markers = ["Portfolio Qualities", "— Portfolio Qualities"]
#     risk_markers = ["Portfolio Risks", "— Portfolio Risks"]
    
#     quality_start = -1
#     risk_start = -1
    
#     for marker in quality_markers:
#         idx = text.find(marker)
#         if idx != -1:
#             quality_start = idx
#             break
    
#     for marker in risk_markers:
#         idx = text.find(marker)
#         if idx != -1:
#             risk_start = idx
#             break
    
#     if quality_start == -1 or risk_start == -1:
#         raise ValueError("Could not find Quality/Risk sections in AI output")
    
#     # Extract sections
#     quality_text = text[quality_start:risk_start].strip()
#     risk_text = text[risk_start:].strip()
    
#     # Clean up section headers
#     for marker in quality_markers:
#         quality_text = quality_text.replace(f"### {marker}", "").replace(marker, "").strip()
#     for marker in risk_markers:
#         risk_text = risk_text.replace(f"### {marker}", "").replace(marker, "").strip()
    
#     # Remove leading "---" dividers
#     quality_text = quality_text.lstrip('-').strip()
#     risk_text = risk_text.lstrip('-').strip()
    
#     return quality_text, risk_text


# def insert_to_database(quality_text, risk_text, dry_run=False):
#     """Insert AI summaries to transform_db.portfolio_ai_analysis"""
#     print("\n" + "="*70)
#     print("💾 INSERTING TO DATABASE")
#     print("="*70)
    
#     if dry_run:
#         print("🔍 DRY RUN - Skipping database insert")
#         print("\n--- QUALITY SECTION ---")
#         print(quality_text[:500] + "..." if len(quality_text) > 500 else quality_text)
#         print("\n--- RISK SECTION ---")
#         print(risk_text[:500] + "..." if len(risk_text) > 500 else risk_text)
#         return
    
#     conn = psycopg2.connect(**DB_CONFIG)
#     conn.autocommit = True
#     cursor = conn.cursor()
    
#     cursor.execute("""
#         DELETE FROM transform_db.portfolio_ai_analysis
#         WHERE portfolio_id = %s
#           AND DATE(created_at) = CURRENT_DATE
#     """, (PORTFOLIO_ID,))
    
#     try:
#         cursor.execute("""
#             INSERT INTO transform_db.portfolio_ai_analysis
#             (portfolio_id, analysis_category, analysis_text, generated_by)
#             VALUES (%s, %s, %s, %s)
#         """, (PORTFOLIO_ID, "Quality", quality_text, MODEL))

#         cursor.execute("""
#             INSERT INTO transform_db.portfolio_ai_analysis
#             (portfolio_id, analysis_category, analysis_text, generated_by)
#             VALUES (%s, %s, %s, %s)
#         """, (PORTFOLIO_ID, "Risk", risk_text, MODEL))
#     except Exception as e:
#         print(f"❌ Error inserting: {e}")
#         raise
#     finally:
#         cursor.close()
#         conn.close()


# # MAIN

# def main():
#     parser = argparse.ArgumentParser(description='Generate AI Portfolio Summary')
#     parser.add_argument('--dry-run', action='store_true', 
#                         help='Preview without inserting to database')
#     parser.add_argument('--save-json', type=str, 
#                         help='Save portfolio data to JSON file')
#     args = parser.parse_args()
    
#     print("\n" + "="*70)
#     print(f"🚀 AI PORTFOLIO SUMMARY GENERATOR v2")
#     print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
#     print("="*70)
    
#     # Step 1: Fetch all data from database
#     raw_data = fetch_all_portfolio_data()
    
#     # Step 2: Build structured portfolio object
#     portfolio = build_portfolio_object(raw_data)
    
#     # Optional: Save portfolio JSON
#     if args.save_json:
#         with open(args.save_json, 'w') as f:
#             json.dump(portfolio, f, indent=2, default=str)
#         print(f"💾 Saved portfolio data to {args.save_json}")
    
#     # Step 3: Generate AI summary
#     summary_text = generate_ai_summary(portfolio)
    
#     # Step 4: Split into sections
#     quality_text, risk_text = split_sections(summary_text)
    
#     # Step 5: Insert to database
#     insert_to_database(quality_text, risk_text, dry_run=args.dry_run)
    
#     print("\n" + "="*70)
#     print("✅ COMPLETED SUCCESSFULLY")
#     print("="*70)
    
#     # Print full summary
#     print("\n" + "="*70)
#     print("📄 FULL AI SUMMARY")
#     print("="*70)
#     print(summary_text)


# if __name__ == '__main__':
#     main()



"""
Generate AI Portfolio Summary (Quality + Risk sections) — PER PORTFOLIO.
Populates: transform_db.portfolio_ai_analysis

Iterates ALL portfolios in ingest_db.portfolio, resolves each portfolio's
stocks via ingest_db.portfolio_stocks (only non-peer stocks from ingest_db.stocks),
and generates per-portfolio Quality + Risk AI summaries via OpenAI.

STANDARDS:
- sys.path.insert BEFORE all project imports
- Uses get_connection() from utils.py
- No module-level DB calls
"""

from __future__ import annotations

import sys
import os
import json
import logging
import argparse
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
from openai import OpenAI
from psycopg2.extras import RealDictCursor

sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection
from config import OPENAI_API_KEY

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger(__name__)

MODEL = "gpt-4o-mini"


# ─────────────────────────────────────────────────────────
# PORTFOLIO & STOCK RESOLUTION
# ─────────────────────────────────────────────────────────

def get_all_portfolio_ids() -> list[int]:
    """Fetch all portfolio_ids from ingest_db.portfolio."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT portfolio_id FROM ingest_db.portfolio ORDER BY portfolio_id")
    ids = [r[0] for r in cur.fetchall()]
    cur.close()
    conn.close()
    log.info(f"Found {len(ids)} portfolios: {ids}")
    return ids


def get_portfolio_user_id(portfolio_id: int) -> int | None:
    """Fetch the user_id that owns the given portfolio."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT user_id FROM ingest_db.portfolio WHERE portfolio_id = %s",
        (portfolio_id,),
    )
    row = cur.fetchone()
    cur.close()
    conn.close()
    return row[0] if row else None


def get_portfolio_name(portfolio_id: int) -> str:
    """Fetch portfolio_name for a given portfolio_id."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT portfolio_name FROM ingest_db.portfolio WHERE portfolio_id = %s",
        (portfolio_id,),
    )
    row = cur.fetchone()
    cur.close()
    conn.close()
    return row[0] if row else f"Portfolio_{portfolio_id}"


def get_stock_ids_for_portfolio(portfolio_id: int) -> list[int]:
    """Get stock_ids belonging to a portfolio (only non-peer stocks)."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT ps.stock_id
        FROM ingest_db.portfolio_stocks ps
        JOIN ingest_db.stocks s ON s.stock_id = ps.stock_id
        WHERE ps.portfolio_id = %s AND s.is_peer = false
        ORDER BY ps.stock_id
        """,
        (portfolio_id,),
    )
    ids = [r[0] for r in cur.fetchall()]
    cur.close()
    conn.close()
    return ids


# ─────────────────────────────────────────────────────────
# QUERIES
# ─────────────────────────────────────────────────────────

QUERIES = {
    "portfolio_stocks": """
        SELECT portfolio_id, stock_id, ticker, company_name, sector, quantity,
               local_currency, last_price_local_curr, last_price_usd,
               value_local_curr, value_usd,
               day_price_change_local_curr, day_price_change_usd, day_price_change_pct,
               volume, volume_30d, sentiment_score, sentiment_label,
               flag_type, flag_description, price_date
        FROM semantic_db.vw_portfolio_stocks_details
        WHERE portfolio_id = %s AND stock_id = ANY(%s)
        ORDER BY stock_id
    """,
    "company_profile": """
        SELECT stock_id, stock_symbol, country, ceo, website, sector, industry,
               full_time_employees, description, beta, financial_score
        FROM semantic_db.vw_company_profile
        WHERE stock_id = ANY(%s)
    """,
    "price_latest": """
        SELECT stock_id, local_currency, price_local_curr, price_usd,
               opening_price_local_curr, closing_price_local_curr,
               day_price_change_pct, volume, volume_30d,
               market_cap_local_curr, market_cap_usd, price_date
        FROM semantic_db.vw_stocks_price_data_latest
        WHERE stock_id = ANY(%s)
    """,
    "revenue_annual": """
        SELECT DISTINCT stock_id, ticker, revenue, period_label
        FROM semantic_db.vw_stocks_revenue_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "revenue_quarterly": """
        SELECT DISTINCT stock_id, ticker, revenue, period_label
        FROM semantic_db.vw_stocks_revenue_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Quarterly'
        ORDER BY stock_id, period_label DESC
    """,
    "ebitda_annual": """
        SELECT DISTINCT stock_id, ticker, ebitda, period_label
        FROM semantic_db.vw_stocks_ebitda_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "eps_annual": """
        SELECT DISTINCT stock_id, ticker, eps, period_label
        FROM semantic_db.vw_stocks_eps_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "fcf_annual": """
        SELECT DISTINCT stock_id, ticker, free_cash_flow, period_label
        FROM semantic_db.vw_stocks_free_cash_flow_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "cash_debt": """
        SELECT stock_id, ticker, metric_type, metric_value, period_label
        FROM semantic_db.vw_stocks_cash_debt_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "return_of_capital": """
        SELECT stock_id, ticker, metric_type, return_of_capital, period_label
        FROM semantic_db.vw_stocks_return_of_capital_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "dividend": """
        SELECT stock_id, ticker, metric_type, dividend_value, period_label
        FROM semantic_db.vw_stocks_dividend_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "valuation": """
        SELECT stock_id, ticker, metric_type, metric_value
        FROM semantic_db.vw_stocks_fundamentals_valuation
        WHERE stock_id = ANY(%s)
    """,
    "indicators": """
        SELECT stock_id, ticker, indicator_name, value, recorded_at
        FROM semantic_db.vw_stocks_indicators
        WHERE stock_id = ANY(%s)
        ORDER BY stock_id, recorded_at DESC
    """,
    "flags": """
        SELECT stock_id, flag_type, flag_description, created_at
        FROM semantic_db.vw_stocks_flags
        WHERE stock_id = ANY(%s)
        ORDER BY created_at DESC
    """,
    "market_alerts": """
        SELECT stock_id, stock_symbol, alert_type, description, severity, alert_date, url
        FROM semantic_db.vw_stocks_market_alerts
        WHERE stock_id = ANY(%s)
        ORDER BY alert_date DESC
        LIMIT 50
    """,
    "events": """
        SELECT stock_id, event_type, event_description, expected_event_time
        FROM semantic_db.vw_stocks_upcoming_events
        WHERE stock_id = ANY(%s) AND expected_event_time >= CURRENT_DATE
        ORDER BY expected_event_time
    """,
    "earnings_outlook": """
        SELECT stock_id, ticker, period, num_estimates, avg_estimate,
               low_estimate, high_estimate, metric_type
        FROM semantic_db.vw_stocks_earnings_outlook
        WHERE stock_id = ANY(%s)
        ORDER BY stock_id, recorded_at DESC
    """,
    "sentiment": """
        SELECT stock_id, sentiment_score, sentiment_label, analysis_description,
               total_messages, positive_count, neutral_count, negative_count,
               sentiment_reasons
        FROM semantic_db.vw_stocks_sentiment_latest
        WHERE stock_id = ANY(%s)
    """,
    "driver_analysis": """
        SELECT stock_id, driver_name, analysis_text, impact_score, analysis_period
        FROM semantic_db.vw_stocks_driver_analysis
        WHERE stock_id = ANY(%s)
        ORDER BY stock_id, analyzed_date DESC
    """,
    "margin_growth": """
        SELECT stock_id, ticker, metric_type, metric_value
        FROM semantic_db.vw_stocks_fundamentals_margin_growth
        WHERE stock_id = ANY(%s)
    """,
}


# ─────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────

def decimal_to_float(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, dict):
        return {k: decimal_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [decimal_to_float(i) for i in obj]
    elif isinstance(obj, datetime):
        return obj.isoformat()
    return obj


def safe_query(cursor, query_name: str, query: str, params: tuple) -> list:
    try:
        cursor.execute(query, params)
        return [decimal_to_float(dict(row)) for row in cursor.fetchall()]
    except Exception as e:
        log.warning(f"Query '{query_name}' failed: {e}")
        cursor.connection.rollback()
        return []


# ─────────────────────────────────────────────────────────
# DATA FETCHING + PORTFOLIO BUILDER
# ─────────────────────────────────────────────────────────

def fetch_all_portfolio_data(stock_ids: list[int], portfolio_id: int) -> dict:
    log.info(f"Fetching portfolio data for portfolio_id={portfolio_id} ({len(stock_ids)} stocks)...")
    conn   = get_connection()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    all_data = {}

    for query_name, query in QUERIES.items():
        if query_name == "portfolio_stocks":
            # This query needs portfolio_id + stock_ids
            result = safe_query(cursor, query_name, query, (portfolio_id, stock_ids))
        else:
            # All other queries only need stock_ids
            result = safe_query(cursor, query_name, query, (stock_ids,))
        all_data[query_name] = result
        log.info(f"  {query_name}: {len(result)} rows")

    cursor.close()
    conn.close()
    return all_data


def build_portfolio_object(raw_data: dict, stock_ids: list[int], portfolio_id: int) -> dict:
    log.info(f"Building portfolio object for portfolio_id={portfolio_id}...")

    portfolio_stocks = {r["stock_id"]: r for r in raw_data.get("portfolio_stocks", [])}
    company_profile  = {r["stock_id"]: r for r in raw_data.get("company_profile", [])}
    price_latest     = {r["stock_id"]: r for r in raw_data.get("price_latest", [])}
    sentiment        = {r["stock_id"]: r for r in raw_data.get("sentiment", [])}

    def group_by_stock(data):
        grouped = {}
        for row in data:
            sid = row.get("stock_id")
            grouped.setdefault(sid, []).append(row)
        return grouped

    revenue_annual    = group_by_stock(raw_data.get("revenue_annual", []))
    revenue_quarterly = group_by_stock(raw_data.get("revenue_quarterly", []))
    ebitda_annual     = group_by_stock(raw_data.get("ebitda_annual", []))
    eps_annual        = group_by_stock(raw_data.get("eps_annual", []))
    fcf_annual        = group_by_stock(raw_data.get("fcf_annual", []))
    cash_debt         = group_by_stock(raw_data.get("cash_debt", []))
    return_of_capital = group_by_stock(raw_data.get("return_of_capital", []))
    valuation         = group_by_stock(raw_data.get("valuation", []))
    indicators        = group_by_stock(raw_data.get("indicators", []))
    margin_growth     = group_by_stock(raw_data.get("margin_growth", []))
    flags             = group_by_stock(raw_data.get("flags", []))
    alerts            = group_by_stock(raw_data.get("market_alerts", []))
    events            = group_by_stock(raw_data.get("events", []))
    earnings          = group_by_stock(raw_data.get("earnings_outlook", []))
    drivers           = group_by_stock(raw_data.get("driver_analysis", []))

    def get_indicators_dict(grouped, sid):
        return {item.get("indicator_name"): item.get("value") for item in grouped.get(sid, [])}

    def get_metrics_dict(grouped, sid, value_key="metric_value"):
        return {item.get("metric_type"): item.get(value_key) for item in grouped.get(sid, [])}

    portfolio = {
        "report_date":  datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "portfolio_id": portfolio_id,
        "total_stocks": len(stock_ids),
        "stocks":       [],
    }

    total_value_usd      = 0
    positive_day_change  = 0
    negative_day_change  = 0
    positive_sentiment   = 0
    negative_sentiment   = 0

    for sid in stock_ids:
        ps   = portfolio_stocks.get(sid, {})
        cp   = company_profile.get(sid, {})
        pl   = price_latest.get(sid, {})
        sent = sentiment.get(sid, {})

        rev_hist   = revenue_annual.get(sid, [])[:3]
        rev_q_hist = revenue_quarterly.get(sid, [])[:4]
        ebitda_hist= ebitda_annual.get(sid, [])[:3]
        eps_hist   = eps_annual.get(sid, [])[:3]
        fcf_hist   = fcf_annual.get(sid, [])[:3]

        ind     = get_indicators_dict(indicators, sid)
        val     = get_metrics_dict(valuation, sid)
        margins = get_metrics_dict(margin_growth, sid)

        cash_metrics = {}
        for item in cash_debt.get(sid, []):
            mt = item.get("metric_type")
            if mt not in cash_metrics:
                cash_metrics[mt] = item.get("metric_value")

        roc_metrics = {}
        for item in return_of_capital.get(sid, []):
            mt = item.get("metric_type")
            if mt not in roc_metrics:
                roc_metrics[mt] = item.get("return_of_capital")

        stock_obj = {
            "stock_id": sid,
            "ticker":   ps.get("ticker", f"STOCK_{sid}"),
            "name":     ps.get("company_name", ""),
            "sector":   ps.get("sector") or cp.get("sector", ""),
            "industry": cp.get("industry", ""),
            "country":  cp.get("country", ""),
            "currency": ps.get("local_currency", ""),
            "description": (cp.get("description", "") or "")[:200],

            "position": {
                "quantity":    ps.get("quantity"),
                "value_local": ps.get("value_local_curr"),
                "value_usd":   ps.get("value_usd"),
            },
            "price": {
                "current":       ps.get("last_price_local_curr"),
                "current_usd":   ps.get("last_price_usd"),
                "change_1d_pct": ps.get("day_price_change_pct"),
                "volume":        ps.get("volume"),
                "volume_30d_avg":ps.get("volume_30d"),
                "price_date":    str(ps.get("price_date")) if ps.get("price_date") else None,
            },
            "technicals": {
                "rsi_14":     ind.get("RSI_14") or ind.get("RSI"),
                "macd":       ind.get("MACD"),
                "sma_50":     ind.get("SMA_50"),
                "sma_200":    ind.get("SMA_200"),
                "beta":       cp.get("beta"),
            },
            "valuation": {
                "pe_ratio":     val.get("P/E Ratio"),
                "pb_ratio":     val.get("P/B Ratio"),
                "ps_ratio":     val.get("P/S Ratio"),
                "ev_ebitda":    val.get("EV/EBITDA"),
                "market_cap":   pl.get("market_cap_usd"),
            },
            "revenue": {
                "latest_annual":    rev_hist[0].get("revenue") if rev_hist else None,
                "latest_period":    rev_hist[0].get("period_label") if rev_hist else None,
                "history":          [{"period": r.get("period_label"), "value": r.get("revenue")} for r in rev_hist],
                "latest_quarterly": rev_q_hist[0].get("revenue") if rev_q_hist else None,
            },
            "profitability": {
                "ebitda_latest": ebitda_hist[0].get("ebitda") if ebitda_hist else None,
                "eps_latest":    eps_hist[0].get("eps") if eps_hist else None,
                "gross_margin":  margins.get("Gross Margin"),
                "operating_margin": margins.get("Operating Margin"),
                "net_margin":    margins.get("Net Margin"),
            },
            "cash_flow": {
                "fcf_latest": fcf_hist[0].get("free_cash_flow") if fcf_hist else None,
                "fcf_history": [{"period": f.get("period_label"), "value": f.get("free_cash_flow")} for f in fcf_hist],
            },
            "balance_sheet": {
                "cash":          cash_metrics.get("Cash"),
                "total_debt":    cash_metrics.get("Total Debt"),
                "net_debt":      cash_metrics.get("Net Debt"),
            },
            "returns": {
                "roe":  roc_metrics.get("ROE"),
                "roa":  roc_metrics.get("ROA"),
                "roic": roc_metrics.get("ROIC"),
            },
            "sentiment": {
                "score":          sent.get("sentiment_score"),
                "label":          sent.get("sentiment_label"),
                "total_messages": sent.get("total_messages"),
            },
            "current_flag": {
                "type":        ps.get("flag_type"),
                "description": ps.get("flag_description"),
            },
            "flags":   [{"type": f.get("flag_type"), "description": f.get("flag_description")} for f in flags.get(sid, [])[:5]],
            "alerts":  [{"type": a.get("alert_type"), "message": (a.get("description", "") or "")[:150], "severity": a.get("severity"), "date": str(a.get("alert_date")) if a.get("alert_date") else None} for a in alerts.get(sid, [])[:5]],
            "upcoming_events": [{"type": e.get("event_type"), "description": (e.get("event_description", "") or "")[:100], "date": str(e.get("expected_event_time")) if e.get("expected_event_time") else None} for e in events.get(sid, [])[:3]],
            "earnings_outlook": {"estimates": [{"period": e.get("period"), "metric": e.get("metric_type"), "avg_estimate": e.get("avg_estimate"), "num_analysts": e.get("num_estimates")} for e in earnings.get(sid, [])[:4]]},
            "drivers": [{"name": d.get("driver_name"), "analysis": (d.get("analysis_text", "") or "")[:200], "impact_score": d.get("impact_score")} for d in drivers.get(sid, [])[:3]],
        }

        portfolio["stocks"].append(stock_obj)

        if ps.get("value_usd"):
            total_value_usd += float(ps.get("value_usd", 0) or 0)
        change = float(ps.get("day_price_change_pct", 0) or 0)
        if change > 0: positive_day_change += 1
        elif change < 0: negative_day_change += 1
        if sent.get("sentiment_label") == "positive": positive_sentiment += 1
        elif sent.get("sentiment_label") == "negative": negative_sentiment += 1

    portfolio["portfolio_summary"] = {
        "total_value_usd":           round(total_value_usd, 2),
        "stocks_up_today":           positive_day_change,
        "stocks_down_today":         negative_day_change,
        "positive_sentiment_stocks": positive_sentiment,
        "negative_sentiment_stocks": negative_sentiment,
    }

    log.info(f"  Built portfolio {portfolio_id} with {len(portfolio['stocks'])} stocks, total value ${total_value_usd:,.2f}")
    return portfolio


# ─────────────────────────────────────────────────────────
# AI SUMMARY
# ─────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are a professional buy-side equity analyst writing a daily portfolio brief for institutional investors.

Your analysis must be:
- Data-driven: Reference specific numbers, percentages, and metrics from the provided data
- Balanced: Present both opportunities and risks objectively
- Actionable: Highlight key items requiring attention
- Professional: Use formal financial language, no marketing speak

Output format must be EXACTLY as specified - do not deviate from the structure."""


USER_PROMPT_TEMPLATE = """
Analyze this global portfolio and generate a structured brief.

PORTFOLIO DATA (JSON):
{portfolio_json}

═══════════════════════════════════════════════════════════════════════════════
REQUIRED OUTPUT FORMAT - Follow this EXACTLY:
═══════════════════════════════════════════════════════════════════════════════

### — Portfolio Qualities

**Structural Strengths**
- [2-3 bullet points about portfolio composition, diversification, sector mix]

**Positive Momentum & Technical Signals**
- [2-3 bullet points about stocks with positive trends, above moving averages, good RSI]

**Strong Fundamentals**
- [2-3 bullet points about revenue growth, margins, cash flow, ROE/ROA]

**Favorable Valuations**
- [1-2 bullet points about attractively valued stocks]

**Beneficial Developments**
- [1-2 bullet points about positive news, upcoming catalysts, sentiment]

**Key Takeaway:** [One sentence summary of portfolio strengths]

---

### — Portfolio Risks

**Weak Momentum & Technical Warnings**
- [2-3 bullet points about stocks below moving averages, negative trends]

**Fundamental Concerns**
- [2-3 bullet points about declining revenue, margin compression, weak cash flow]

**Valuation Risks**
- [1-2 bullet points about overvalued stocks or stretched multiples]

**Balance Sheet Issues**
- [1-2 bullet points about high debt, low liquidity]

**Negative Developments**
- [1-2 bullet points about concerning news, regulatory risks]

**Concentration & Macro Risks**
- [1-2 bullet points about sector concentration, geographic risks, macro factors]

**Key Takeaway:** [One sentence summary of portfolio risks]

═══════════════════════════════════════════════════════════════════════════════
RULES:
1. Use ONLY the data provided - do NOT invent facts or numbers
2. Reference specific stock tickers when discussing individual holdings
3. Include actual numbers: "JD.com up 12.5% MTD" not "stock showed gains"
4. Keep total response under 1500 words
5. Maintain professional, analytical tone throughout
6. Do NOT use emojis or casual language
"""


def generate_ai_summary(portfolio: dict) -> str:
    log.info(f"Calling OpenAI for portfolio {portfolio['portfolio_id']} summary...")
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    portfolio_json = json.dumps(portfolio, indent=2, default=str)
    user_prompt    = USER_PROMPT_TEMPLATE.format(portfolio_json=portfolio_json)
    client         = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": user_prompt},
        ],
        temperature=0.3,
        max_tokens=3000,
    )
    return response.choices[0].message.content


def split_sections(text: str):
    quality_markers = ["Portfolio Qualities", "— Portfolio Qualities"]
    risk_markers    = ["Portfolio Risks",    "— Portfolio Risks"]

    quality_start = next((text.find(m) for m in quality_markers if text.find(m) != -1), -1)
    risk_start    = next((text.find(m) for m in risk_markers    if text.find(m) != -1), -1)

    if quality_start == -1 or risk_start == -1:
        raise ValueError("Could not find Quality/Risk sections in AI output")

    quality_text = text[quality_start:risk_start].strip()
    risk_text    = text[risk_start:].strip()

    for m in quality_markers:
        quality_text = quality_text.replace(f"### {m}", "").replace(m, "").strip()
    for m in risk_markers:
        risk_text = risk_text.replace(f"### {m}", "").replace(m, "").strip()

    return quality_text.lstrip("-").strip(), risk_text.lstrip("-").strip()


def insert_to_database(quality_text: str, risk_text: str, portfolio_id: int, user_id: int, dry_run: bool = False):
    if dry_run:
        log.info(f"[DRY RUN] Portfolio {portfolio_id} — Quality section preview:")
        log.info(quality_text[:300])
        log.info(f"[DRY RUN] Portfolio {portfolio_id} — Risk section preview:")
        log.info(risk_text[:300])
        return

    conn = get_connection()
    conn.autocommit = True
    cursor = conn.cursor()

    try:
        cursor.execute(
            "DELETE FROM transform_db.portfolio_ai_analysis WHERE portfolio_id = %s AND analysis_category IN ('Quality', 'Risk') AND DATE(created_at) = CURRENT_DATE",
            (portfolio_id,),
        )
        cursor.execute(
            "INSERT INTO transform_db.portfolio_ai_analysis (portfolio_id, analysis_category, analysis_text, generated_by, user_id) VALUES (%s,%s,%s,%s,%s)",
            (portfolio_id, "Quality", quality_text, MODEL, user_id),
        )
        cursor.execute(
            "INSERT INTO transform_db.portfolio_ai_analysis (portfolio_id, analysis_category, analysis_text, generated_by, user_id) VALUES (%s,%s,%s,%s,%s)",
            (portfolio_id, "Risk", risk_text, MODEL, user_id),
        )
        log.info(f"Portfolio {portfolio_id} AI analysis saved to DB (Quality + Risk)")
    except Exception as e:
        log.error(f"DB insert failed for portfolio {portfolio_id}: {e}", exc_info=True)
        raise
    finally:
        cursor.close()
        conn.close()


import concurrent.futures

# ─────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────

def process_single_portfolio(pid, args):
    log.info("-" * 40)
    log.info(f"Processing portfolio_id={pid}")

    user_id = get_portfolio_user_id(pid)
    if user_id is None:
        log.warning(f"Portfolio {pid}: no user_id found, skipping")
        return False

    stock_ids = get_stock_ids_for_portfolio(pid)
    if not stock_ids:
        log.warning(f"Portfolio {pid}: no non-peer stocks found, skipping")
        return False

    log.info(f"Portfolio {pid}: {len(stock_ids)} stocks → {stock_ids}")

    raw_data  = fetch_all_portfolio_data(stock_ids, pid)
    portfolio = build_portfolio_object(raw_data, stock_ids, pid)

    summary_text = generate_ai_summary(portfolio)
    quality_text, risk_text = split_sections(summary_text)
    insert_to_database(quality_text, risk_text, pid, user_id, dry_run=args.dry_run)

    log.info(f"Portfolio {pid} DONE")
    return True


def main():
    parser = argparse.ArgumentParser(description="Generate AI Portfolio Summary (per-portfolio)")
    parser.add_argument("--dry-run",      action="store_true", help="Preview without inserting")
    parser.add_argument("--save-json",    type=str,            help="Save portfolio data to JSON file (only first portfolio)")
    parser.add_argument("--portfolio-id", type=int,            help="Process only this portfolio_id (default: all)")
    args = parser.parse_args()

    log.info("=" * 60)
    log.info("FETCHING: AI Portfolio Summary (Concurrent per-portfolio)")
    log.info("=" * 60)

    # Determine which portfolios to process
    if args.portfolio_id:
        portfolio_ids = [args.portfolio_id]
        log.info(f"Processing single portfolio: {args.portfolio_id}")
    else:
        portfolio_ids = get_all_portfolio_ids()

    total_processed = 0

    if args.save_json and len(portfolio_ids) == 1:
        # If we just invoked 1 locally with save_json, do it synchronously
        stock_ids = get_stock_ids_for_portfolio(portfolio_ids[0])
        if stock_ids:
            raw_data  = fetch_all_portfolio_data(stock_ids, portfolio_ids[0])
            portfolio = build_portfolio_object(raw_data, stock_ids, portfolio_ids[0])
            with open(args.save_json, "w") as f:
                json.dump(portfolio, f, indent=2, default=str)
            log.info(f"Saved portfolio data to {args.save_json}")

    # Use ThreadPoolExecutor to run up to 5 OpenAI calls concurrently
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(process_single_portfolio, pid, args): pid for pid in portfolio_ids}
        for future in concurrent.futures.as_completed(futures):
            pid = futures[future]
            try:
                success = future.result()
                if success:
                    total_processed += 1
            except Exception as exc:
                log.error(f"Portfolio {pid} generated an exception: {exc}", exc_info=True)

    log.info("=" * 60)
    log.info(f"COMPLETED: AI Portfolio Summary — {total_processed}/{len(portfolio_ids)} portfolios processed")
    log.info("=" * 60)

    return {"status": "success", "portfolios_processed": total_processed}


if __name__ == "__main__":
    main()


# ─────────────────────────────────────────────────────────
# LAMBDA HANDLER
# ─────────────────────────────────────────────────────────

def lambda_handler(event, context):
    """
    Lambda entry point.
    event may contain:
      - portfolio_id (int): process only this portfolio; omit to process all
      - job_id (str): optional job tracking ID
      - tickers (list): pass through
    """
    portfolio_id = event.get("portfolio_id")
    tickers = event.get("tickers")

    # Build sys.argv for argparse in main()
    sys.argv = ["fetch_ai_summary_portfolio.py"]
    if portfolio_id:
        sys.argv.extend(["--portfolio-id", str(portfolio_id)])

    job_id = event.get("job_id")
    if job_id:
        os.environ["JOB_ID"] = str(job_id)

    result = main()

    return {
        **(result or {}),
        "portfolio_id": portfolio_id,
        "job_id":       job_id,
        "tickers":      tickers
    }