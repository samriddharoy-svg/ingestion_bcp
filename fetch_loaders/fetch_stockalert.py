# -*- coding: utf-8 -*-


import pandas as pd
import numpy as np
import requests
import yfinance as yf
from datetime import datetime, timedelta
import warnings
import feedparser
import argparse
import psycopg2
from psycopg2.extras import execute_batch
import sys
from pathlib import Path

# Add project root to PYTHONPATH
sys.path.insert(0, str(Path(__file__).parent.parent))
from config import TICKER_MAPPINGS, OPENAI_API_KEY, FMP_API_KEY
from utils import get_connection


warnings.filterwarnings('ignore')
pd.set_option("display.max_colwidth", 200)



BASE_URL = "https://financialmodelingprep.com/stable"
EPSILON = 1e-8


def _fetch_stocks():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT stock_id, ticker, company_name
            FROM ingest_db.stocks
            WHERE is_peer = false
            ORDER BY stock_id
        """)
        result = [{"stock_id": row[0], "ticker": row[1], "company_name": row[2]} for row in cur.fetchall()]
        cur.close()
        conn.close()
        print(f"[fetch_stockalert] Loaded {len(result)} stocks from DB")
        return result
    except Exception as e:
        print(f"[fetch_stockalert] Warning: Could not fetch stocks from DB: {e}")
        return []

STOCKS = _fetch_stocks()


THRESHOLDS = {
    'HIGH': {
        'price_change_pct': 0.10,
        'gap_pct': 0.05,
        'mad_z': 3.5,
        'consecutive_days': 5,
        'volume_z': 4.0
    },
    'MEDIUM': {
        'price_change_pct': 0.05,
        'gap_pct': 0.03,
        'mad_z': 2.5,
        'consecutive_days': 3,
        'volume_z': 2.5,
        'volatility_percentile': 0.85
    },
    'LOW': {
        'price_change_pct': 0.02,
        'gap_pct': 0.02,
        'mad_z': 2.0,
        'volume_z': 1.5,
        'range_expansion': 2.0
    }
}


NEWS_KEYWORDS = {
    'HIGH': [
        'bankrupt', 'bankruptcy', 'fraud', 'fraudulent', 'scandal', 'investigation',
        'lawsuit', 'sued', 'sues', 'litigation', 'settle', 'settlement',
        'delisted', 'delist', 'regulatory action', 'regulator', 'violation',
        'suspended', 'suspension', 'halt', 'halted', 'trading halt',
        'emergency', 'crisis', 'collapse', 'collapsed', 'default', 'defaulted',
        'criminal', 'probe', 'raid', 'raided', 'seizure', 'seized',
        'breach', 'breached', 'hack', 'hacked', 'cyberattack',
        'merger', 'merge', 'merging', 'acquisition', 'acquire', 'acquired',
        'takeover', 'buyout', 'bid',
        'ceo resigns', 'cfo resigns', 'chairman resigns', 'executive fired',
        'founder leaves', 'management shakeup',
        'writedown', 'write-down', 'impairment', 'restructuring charge',
        'going concern', 'liquidity crisis', 'cash crunch',
        'recall', 'recalled', 'safety issue', 'defect', 'contamination',
        'fda warning', 'clinical hold'
    ],
    'MEDIUM': [
        'earnings', 'revenue', 'profit', 'loss', 'ebitda', 'eps',
        'guidance', 'forecast', 'outlook', 'estimates', 'beat', 'miss',
        'quarterly results', 'annual results', 'financial results',
        'downgrade', 'upgrade', 'rating', 'analyst', 'target', 'price target',
        'buy rating', 'sell rating', 'outperform', 'underperform',
        'overweight', 'underweight', 'neutral',
        'expansion', 'expands', 'partnership', 'partner', 'partners',
        'contract', 'deal', 'agreement', 'signs', 'signed',
        'launch', 'launches', 'product', 'new product', 'unveils',
        'opens', 'closes', 'facility', 'plant', 'factory',
        'ceo', 'cfo', 'coo', 'chairman', 'executive', 'director',
        'appointed', 'appoints', 'hire', 'hires', 'joins',
        'promotion', 'promoted',
        'restructuring', 'reorganization', 'spinoff', 'spin-off',
        'divestiture', 'divest', 'sell', 'selling unit',
        'strategic review', 'strategic plan', 'transformation',
        'approval', 'approved', 'approves', 'fda approval',
        'clearance', 'authorization', 'permit', 'license',
        'filing', 'filed', 'submission',
        'ipo', 'offering', 'secondary offering', 'stock sale',
        'buyback', 'share repurchase', 'dividend', 'payout'
    ],
    'LOW': [
        'announce', 'announces', 'announced', 'announcement',
        'report', 'reports', 'reported', 'update', 'updates',
        'statement', 'comment', 'comments', 'says', 'said',
        'plans', 'planning', 'expects', 'expecting',
        'seeks', 'seeking', 'considers', 'considering', 'explores',
        'may', 'could', 'might', 'potential', 'possible',
        'shares', 'stock', 'trading', 'market', 'investors',
        'wall street', 'analysts say', 'watch', 'monitor'
    ]
}



class NewsClassifier:
    """FinBERT-based news sentiment and severity classifier"""

    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = None

    def load_model(self):
        """Load FinBERT model"""
        try:
            from transformers import AutoTokenizer, AutoModelForSequenceClassification
            import torch

            print("\n" + "="*80)
            print("LOADING FINBERT MODEL")
            print("="*80)

            self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
            print(f"Using device: {self.device}")
            if torch.cuda.is_available():
                print(f"GPU: {torch.cuda.get_device_name(0)}")

            model_name = "ProsusAI/finbert"
            print(f"\nLoading tokenizer from {model_name}...")
            self.tokenizer = AutoTokenizer.from_pretrained(model_name)

            print(f"Loading model from {model_name}...")
            self.model = AutoModelForSequenceClassification.from_pretrained(model_name)
            self.model.to(self.device)
            self.model.eval()

            print("✓ FinBERT loaded successfully!\n")
            return True

        except Exception as e:
            print(f"✗ Failed to load FinBERT: {e}")
            print("Will use keyword-based classification only")
            return False

    def get_sentiment(self, text):
        """Get sentiment from FinBERT"""
        if self.model is None:
            return "neutral", 0.5

        try:
            import torch

            inputs = self.tokenizer(text, return_tensors="pt",
                                   truncation=True, max_length=512,
                                   padding=True)
            inputs = {k: v.to(self.device) for k, v in inputs.items()}

            with torch.no_grad():
                outputs = self.model(**inputs)
                predictions = torch.nn.functional.softmax(outputs.logits, dim=-1)

            sentiment_idx = predictions.argmax().item()
            confidence = predictions.max().item()

            sentiment_map = {0: "positive", 1: "negative", 2: "neutral"}
            sentiment = sentiment_map[sentiment_idx]

            return sentiment, confidence

        except Exception as e:
            print(f"Sentiment analysis error: {e}")
            return "neutral", 0.5

    def classify_news_severity(self, headline, sentiment=None, confidence=None):
        """Classify news severity"""
        headline_lower = headline.lower()

        # Check HIGH severity keywords
        for keyword in NEWS_KEYWORDS['HIGH']:
            if keyword in headline_lower:
                return 'HIGH', f"Critical: {keyword}", keyword

        # Sentiment-based HIGH severity
        if sentiment == "negative" and confidence and confidence > 0.90:
            return 'HIGH', f"Very negative sentiment ({confidence:.1%})", None

        # Check MEDIUM severity keywords
        for keyword in NEWS_KEYWORDS['MEDIUM']:
            if keyword in headline_lower:
                return 'MEDIUM', f"Important: {keyword}", keyword

        # Sentiment-based MEDIUM severity
        if sentiment and confidence and confidence > 0.80:
            if sentiment in ["positive", "negative"]:
                return 'MEDIUM', f"Strong {sentiment} ({confidence:.1%})", None

        # Check LOW severity keywords
        for keyword in NEWS_KEYWORDS['LOW']:
            if keyword in headline_lower:
                return 'LOW', f"General: {keyword}", keyword

        return 'LOW', "General mention", None


# Global classifier instance
news_classifier = NewsClassifier()



def fetch_eod_prices_fmp(symbol):
    """Fetch from FMP API"""
    try:
        url = f"{BASE_URL}/historical-price-eod/full"
        r = requests.get(url, params={"symbol": symbol, "apikey": FMP_API_KEY}, timeout=10)

        if r.status_code != 200:
            return pd.DataFrame()

        data = r.json()
        if not isinstance(data, list) or len(data) == 0:
            return pd.DataFrame()

        df = pd.DataFrame(data)
        df["date"] = pd.to_datetime(df["date"])
        df = df.sort_values("date").reset_index(drop=True)

        required_cols = ["date", "open", "high", "low", "close", "volume"]
        if all(col in df.columns for col in required_cols):
            return df[required_cols]

        return pd.DataFrame()

    except Exception as e:
        return pd.DataFrame()


def fetch_eod_prices_yfinance(symbol):
    """Fetch from yfinance as fallback"""
    try:
        ticker = yf.Ticker(symbol)
        df = ticker.history(period="2y")

        if df.empty:
            return pd.DataFrame()

        df = df.reset_index()
        df.columns = df.columns.str.lower()

        column_mapping = {
            'date': 'date',
            'open': 'open',
            'high': 'high',
            'low': 'low',
            'close': 'close',
            'volume': 'volume'
        }

        df = df.rename(columns=column_mapping)
        df["date"] = pd.to_datetime(df["date"])

        if df["date"].dt.tz is not None:
            df["date"] = df["date"].dt.tz_localize(None)

        df = df.sort_values("date").reset_index(drop=True)

        required_cols = ["date", "open", "high", "low", "close", "volume"]
        df = df[[col for col in required_cols if col in df.columns]]

        return df

    except Exception as e:
        return pd.DataFrame()


def fetch_eod_prices(symbol):
    """Fetch EOD prices with automatic fallback"""
    df = fetch_eod_prices_fmp(symbol)
    if not df.empty:
        return df

    df = fetch_eod_prices_yfinance(symbol)
    return df


def enrich_prices(df):
    """Add calculated metrics to price dataframe"""
    if df.empty:
        return df

    df = df.copy()
    df = df.sort_values("date").reset_index(drop=True)

    df["prev_close"] = df["close"].shift(1)
    df["price_change"] = df["close"] - df["prev_close"]
    df["price_change_pct"] = df["price_change"] / (df["prev_close"] + EPSILON)
    df["return"] = df["price_change_pct"]

    df["realized_vol"] = df["return"].rolling(20).std()

    rolling_median = df["return"].rolling(60).median()
    mad = (df["return"] - rolling_median).abs().rolling(60).median()
    df["mad_z"] = (df["return"] - rolling_median) / (1.4826 * mad + EPSILON)

    if "volume" in df.columns:
        vol_mean = df["volume"].rolling(60).mean()
        vol_std = df["volume"].rolling(60).std()
        df["volume_z"] = (df["volume"] - vol_mean) / (vol_std + EPSILON)
    else:
        df["volume_z"] = 0.0

    range1 = df["high"] - df["low"]
    range2 = (df["high"] - df["prev_close"]).abs()
    range3 = (df["low"] - df["prev_close"]).abs()

    df["true_range"] = pd.concat([range1, range2, range3], axis=1).max(axis=1)
    df["atr"] = df["true_range"].rolling(20).mean()
    df["range_ratio"] = df["true_range"] / (df["atr"] + EPSILON)

    df["sign"] = df["return"].apply(lambda x: np.sign(x) if pd.notna(x) else 0)

    return df



def generate_alerts_for_day(df, idx):
    """Generate price alerts for a specific day"""
    row = df.iloc[idx]
    hist = df.iloc[:idx].dropna()

    if len(hist) < 30:
        return []

    alerts = []

    # HIGH SEVERITY
    if pd.notna(row["price_change_pct"]):
        abs_change = abs(row["price_change_pct"])

        if abs_change >= THRESHOLDS['HIGH']['price_change_pct']:
            direction = "surged" if row["price_change_pct"] > 0 else "plunged"
            alerts.append(('HIGH', 'PRICE_MOVEMENT', f"Price {direction} {abs_change:.1%} in single day"))

        if pd.notna(row["open"]) and pd.notna(row["prev_close"]) and row["prev_close"] > 0:
            gap = (row["open"] - row["prev_close"]) / row["prev_close"]
            if abs(gap) >= THRESHOLDS['HIGH']['gap_pct']:
                direction = "up" if gap > 0 else "down"
                alerts.append(('HIGH', 'GAP', f"Gapped {direction} {abs(gap):.1%} at market open"))

    if pd.notna(row["volume_z"]) and row["volume_z"] >= THRESHOLDS['HIGH']['volume_z']:
        alerts.append(('HIGH', 'VOLUME', f"Volume spike: {row['volume_z']:.1f}x above average"))

    if len(hist) >= 5:
        recent_returns = df["sign"].iloc[max(0, idx-6):idx+1]
        if len(recent_returns) >= 5:
            if all(recent_returns.iloc[-5:] > 0):
                alerts.append(('HIGH', 'TREND', "Rising for 5+ consecutive days"))
            elif all(recent_returns.iloc[-5:] < 0):
                alerts.append(('HIGH', 'TREND', "Falling for 5+ consecutive days"))

    # MEDIUM SEVERITY
    if pd.notna(row["price_change_pct"]):
        abs_change = abs(row["price_change_pct"])

        if THRESHOLDS['MEDIUM']['price_change_pct'] <= abs_change < THRESHOLDS['HIGH']['price_change_pct']:
            direction = "up" if row["price_change_pct"] > 0 else "down"
            alerts.append(('MEDIUM', 'PRICE_MOVEMENT', f"Price moved {direction} {abs_change:.1%}"))

        if pd.notna(row["open"]) and pd.notna(row["prev_close"]) and row["prev_close"] > 0:
            gap = (row["open"] - row["prev_close"]) / row["prev_close"]
            if THRESHOLDS['MEDIUM']['gap_pct'] <= abs(gap) < THRESHOLDS['HIGH']['gap_pct']:
                direction = "up" if gap > 0 else "down"
                alerts.append(('MEDIUM', 'GAP', f"Opened {abs(gap):.1%} {direction} from previous close"))

    if pd.notna(row["realized_vol"]) and len(hist["realized_vol"].dropna()) > 20:
        vol_percentile = (hist["realized_vol"].dropna() < row["realized_vol"]).sum() / len(hist["realized_vol"].dropna())
        if vol_percentile >= THRESHOLDS['MEDIUM']['volatility_percentile']:
            alerts.append(('MEDIUM', 'VOLATILITY_REGIME', f"Volatility increased to {vol_percentile:.0%} percentile"))

    if pd.notna(row["volume_z"]) and THRESHOLDS['MEDIUM']['volume_z'] <= row["volume_z"] < THRESHOLDS['HIGH']['volume_z']:
        alerts.append(('MEDIUM', 'VOLUME', f"Volume elevated: {row['volume_z']:.1f}x above average"))

    if len(hist) >= 3:
        recent_returns = df["sign"].iloc[max(0, idx-3):idx+1]
        if len(recent_returns) >= 3:
            if all(recent_returns.iloc[-3:] > 0) and not all(recent_returns.iloc[-5:] > 0):
                alerts.append(('MEDIUM', 'TREND', "Rising for 3 consecutive days"))
            elif all(recent_returns.iloc[-3:] < 0) and not all(recent_returns.iloc[-5:] < 0):
                alerts.append(('MEDIUM', 'TREND', "Falling for 3 consecutive days"))

    # LOW SEVERITY
    if pd.notna(row["price_change_pct"]):
        abs_change = abs(row["price_change_pct"])

        if THRESHOLDS['LOW']['price_change_pct'] <= abs_change < THRESHOLDS['MEDIUM']['price_change_pct']:
            direction = "up" if row["price_change_pct"] > 0 else "down"
            alerts.append(('LOW', 'PRICE_MOVEMENT', f"Daily movement: {direction} {abs_change:.1%}"))

    if pd.notna(row["volume_z"]) and THRESHOLDS['LOW']['volume_z'] <= abs(row["volume_z"]) < THRESHOLDS['MEDIUM']['volume_z']:
        if row["volume_z"] > 0:
            alerts.append(('LOW', 'VOLUME', f"Volume above average by {row['volume_z']:.1f}x"))
        else:
            alerts.append(('LOW', 'VOLUME', f"Volume below average by {abs(row['volume_z']):.1f}x"))

    if pd.notna(row["range_ratio"]) and row["range_ratio"] >= THRESHOLDS['LOW']['range_expansion']:
        alerts.append(('LOW', 'VOLATILITY', f"Trading range expanded {row['range_ratio']:.1f}x"))

    # Baseline if nothing triggered
    if not alerts and pd.notna(row["price_change_pct"]):
        change = row["price_change_pct"]
        if change > 0:
            alerts.append(('LOW', 'PRICE_MOVEMENT', f"Closed {change:.2%} higher"))
        elif change < 0:
            alerts.append(('LOW', 'PRICE_MOVEMENT', f"Closed {abs(change):.2%} lower"))
        else:
            alerts.append(('LOW', 'PRICE_MOVEMENT', "Closed unchanged"))

    return alerts



def fetch_news_for_stock(company_name, lookback_days=120):
    """Fetch news from Google RSS feed"""
    try:
        query = company_name.replace(" ", "%20")
        url = f"https://news.google.com/rss/search?q={query}&hl=en-US&gl=US&ceid=US:en"

        feed = feedparser.parse(url)

        if not feed.entries:
            return []

        news_items = []
        cutoff_date = datetime.now() - timedelta(days=lookback_days)

        for entry in feed.entries:
            try:
                pub_date = datetime(*entry.published_parsed[:6])

                if pub_date < cutoff_date:
                    continue

                title = entry.title
                source = "Unknown"
                if " - " in title:
                    title, source = title.rsplit(" - ", 1)

                news_items.append({
                    'title': title.strip(),
                    'link': entry.link,
                    'pub_date': pub_date,
                    'source': source.strip()
                })

            except Exception:
                continue

        return news_items

    except Exception as e:
        print(f"  Error fetching news: {e}")
        return []


def generate_news_alerts(company_name, ticker, news_items, min_severity='LOW'):
    """Generate alerts from news"""
    alerts = []

    severity_rank = {'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}
    min_rank = severity_rank.get(min_severity, 1)

    severity_counts = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}

    for item in news_items:
        title = item['title']

        # Get sentiment from FinBERT
        sentiment, confidence = news_classifier.get_sentiment(title)

        # Classify severity
        severity, reason, keyword = news_classifier.classify_news_severity(
            title, sentiment, confidence
        )

        severity_counts[severity] += 1

        # Filter by minimum severity
        if severity_rank[severity] < min_rank:
            continue

        # Truncate for database
        clean_title = title[:497] + "..." if len(title) > 500 else title

        alerts.append((
            severity,
            'NEWS',
            clean_title,
            item['pub_date'],
            item['source'],
            item['link'],
            keyword
        ))

    print(f"  → Classification: HIGH={severity_counts['HIGH']}, "
          f"MEDIUM={severity_counts['MEDIUM']}, LOW={severity_counts['LOW']}")
    print(f"  → Keeping {len(alerts)} articles (min_severity={min_severity})")

    return alerts



def process_stock(stock_info, lookback_days=120, include_news=True,
                  news_lookback_days=120, min_news_severity='LOW'):
    """Process a single stock"""
    ticker = stock_info['ticker']
    company = stock_info['company_name']
    stock_id = stock_info.get('stock_id')

    print(f"\n{'='*80}")
    print(f"Processing: {company} ({ticker}) [stock_id: {stock_id}]")
    print(f"{'='*80}")

    all_alerts = []

    # PRICE ALERTS
    print("→ Fetching price data...")
    df = fetch_eod_prices(ticker)

    if df.empty:
        print("  ✗ No price data available")
    else:
        print(f"  ✓ Fetched {len(df)} days of data")
        df = enrich_prices(df)

        cutoff_date = pd.Timestamp(datetime.now() - timedelta(days=lookback_days)).tz_localize(None)
        if df['date'].dt.tz is not None:
            df['date'] = df['date'].dt.tz_localize(None)

        print(f"→ Generating price alerts for last {lookback_days} days...")

        for i in range(len(df)):
            if df.iloc[i]['date'] < cutoff_date:
                continue

            day_alerts = generate_alerts_for_day(df, i)

            for severity, alert_type, description in day_alerts:
                all_alerts.append({
                    'date': df.iloc[i]['date'],
                    'ticker': ticker,
                    'stock_id': stock_id,
                    'company': company,
                    'severity': severity,
                    'alert_type': alert_type,
                    'description': description,
                    'close': df.iloc[i]['close'],
                    'source': 'PRICE_SYSTEM',
                    'url': None,
                    'keyword': None
                })

        print(f"  ✓ Generated {len([a for a in all_alerts if a['source'] == 'PRICE_SYSTEM'])} price alerts")

    # NEWS ALERTS
    if include_news:
        print(f"→ Fetching news for {company} (last {news_lookback_days} days)...")
        news_items = fetch_news_for_stock(company, lookback_days=news_lookback_days)

        if not news_items:
            print("  ℹ No recent news found")
        else:
            print(f"  ✓ Found {len(news_items)} news articles")
            print("→ Classifying news severity...")

            news_alerts = generate_news_alerts(
                company, ticker, news_items, min_severity=min_news_severity
            )

            for severity, alert_type, description, pub_date, source, url, keyword in news_alerts:
                if hasattr(pub_date, 'tz_localize'):
                    pub_date = pub_date.tz_localize(None) if pub_date.tz is None else pub_date.tz_convert(None)
                elif isinstance(pub_date, datetime):
                    pub_date = pub_date.replace(tzinfo=None)

                all_alerts.append({
                    'date': pub_date,
                    'ticker': ticker,
                    'stock_id': stock_id,
                    'company': company,
                    'severity': severity,
                    'alert_type': alert_type,
                    'description': description,
                    'close': None,
                    'source': source,
                    'url': url,
                    'keyword': keyword
                })

            print(f"  ✓ Prepared {len(news_alerts)} news alerts for database")

    return pd.DataFrame(all_alerts)


def run_all_stocks(lookback_days=120, include_news=True,
                   news_lookback_days=120, min_news_severity='LOW'):
    """Run alert system for all stocks from DB"""
    print("\n" + "="*80)
    print("STOCK ALERT SYSTEM v3.0")
    print("="*80)
    print(f"Stocks: {len(STOCKS)}")
    print(f"Price lookback: {lookback_days} days")
    print(f"News lookback: {news_lookback_days} days")
    print(f"Min news severity: {min_news_severity}")
    print("="*80)

    all_stock_alerts = []

    for i, stock in enumerate(STOCKS, 1):
        print(f"\n[{i}/{len(STOCKS)}]", end=" ")

        try:
            alerts_df = process_stock(
                stock,
                lookback_days=lookback_days,
                include_news=include_news,
                news_lookback_days=news_lookback_days,
                min_news_severity=min_news_severity
            )
            if not alerts_df.empty:
                all_stock_alerts.append(alerts_df)
        except Exception as e:
            print(f"  ✗ Error: {e}")
            continue

    if all_stock_alerts:
        combined = pd.concat(all_stock_alerts, ignore_index=True)
        combined = combined.sort_values(['date', 'severity'], ascending=[False, True])
        return combined
    else:
        return pd.DataFrame()



def get_existing_alerts(cursor, stock_ids):
    """Get existing alerts to prevent duplicates"""
    if not stock_ids:
        return set()
    
    placeholders = ','.join(['%s'] * len(stock_ids))
    cursor.execute(f"""
        SELECT stock_id, alert_date, alert_type, 
               LEFT(description, 100) as desc_prefix
        FROM ingest_db.stocks_market_alerts
        WHERE stock_id IN ({placeholders})
    """, tuple(stock_ids))
    
    existing = set()
    for row in cursor.fetchall():
        # Create a unique key for each alert
        key = (row[0], str(row[1]), row[2], row[3])
        existing.add(key)
    
    return existing


def push_alerts_to_database(alerts_df, dry_run=False):
    """Push alerts to PostgreSQL with duplicate prevention"""
    if alerts_df.empty:
        print("\n✗ No alerts to push")
        return

    print("\n" + "="*80)
    print("DATABASE PUSH" + (" (DRY RUN)" if dry_run else ""))
    print("="*80)
    print(f"Total alerts to push: {len(alerts_df)}")

    if dry_run:
        print("\n⚠ DRY RUN MODE - No data will be inserted")
        print("\nSample alerts that would be inserted:")
        print(alerts_df[['date', 'ticker', 'severity', 'alert_type', 'description']].head(10).to_string(index=False))

        print("\n--- Severity Breakdown ---")
        severity_counts = alerts_df['severity'].value_counts()
        for severity in ['HIGH', 'MEDIUM', 'LOW']:
            count = severity_counts.get(severity, 0)
            print(f"  {severity:8s}: {count:4d} alerts")

        print("\n💡 To actually insert, run with --no-dry-run")
        return

    conn = None
    try:
        print("\n→ Connecting to database...")
        conn = get_connection()
        cursor = conn.cursor()
        print("  ✓ Connected")

        # Get stock_ids from dataframe
        stock_ids = alerts_df['stock_id'].dropna().unique().tolist()
        
        # Get existing alerts to prevent duplicates
        print("\n→ Checking for existing alerts...")
        existing_alerts = get_existing_alerts(cursor, stock_ids)
        print(f"  ✓ Found {len(existing_alerts)} existing alerts")

        print("\n→ Preparing alerts for insertion...")
        records = []
        skipped_no_id = 0
        skipped_duplicate = 0
        truncated_count = 0

        MAX_LENGTHS = {
            'stock_symbol': 20,
            'alert_type': 50,
            'description': 500,
            'source': 500,
            'url': 500,
            'severity': 20
        }

        for _, row in alerts_df.iterrows():
            stock_id = row.get('stock_id')
            if not stock_id:
                skipped_no_id += 1
                continue

            alert_date = row['date'].date() if hasattr(row['date'], 'date') else row['date']

            description = str(row['description'])
            if len(description) > MAX_LENGTHS['description']:
                description = description[:MAX_LENGTHS['description']-3] + "..."
                truncated_count += 1

            # Check for duplicate
            desc_prefix = description[:100]
            alert_key = (stock_id, str(alert_date), row['alert_type'], desc_prefix)
            if alert_key in existing_alerts:
                skipped_duplicate += 1
                continue

            source = str(row['source'])
            if len(source) > MAX_LENGTHS['source']:
                source = source[:MAX_LENGTHS['source']-3] + "..."
                truncated_count += 1

            url = row.get('url', None)
            if url and len(str(url)) > MAX_LENGTHS['url']:
                url = str(url)[:MAX_LENGTHS['url']-3] + "..."
                truncated_count += 1

            alert_type = str(row['alert_type'])
            if len(alert_type) > MAX_LENGTHS['alert_type']:
                alert_type = alert_type[:MAX_LENGTHS['alert_type']]

            ticker = str(row['ticker'])
            if len(ticker) > MAX_LENGTHS['stock_symbol']:
                ticker = ticker[:MAX_LENGTHS['stock_symbol']]

            records.append((
                stock_id,
                ticker,
                alert_type,
                description,
                source,
                alert_date,
                row['severity'],
                url,
                'ACTIVE'
            ))
            
            # Add to existing set to prevent duplicates within this batch
            existing_alerts.add(alert_key)

        print(f"  ✓ Prepared {len(records)} records")
        print(f"  ℹ Skipped {skipped_no_id} records (missing stock_id)")
        print(f"  ℹ Skipped {skipped_duplicate} duplicates")
        if truncated_count > 0:
            print(f"  ⚠ Truncated {truncated_count} fields to fit database limits")

        if not records:
            print("\n✗ No new records to insert")
            return

        print("\n→ Inserting alerts...")
        insert_query = """
            INSERT INTO ingest_db.stocks_market_alerts (
                stock_id, stock_symbol, alert_type, description,
                source, alert_date, severity, url, status
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """

        execute_batch(cursor, insert_query, records, page_size=100)
        conn.commit()

        print(f"  ✓ Successfully inserted {len(records)} alerts")

        print("\n" + "="*80)
        print("DATABASE INSERTION COMPLETE")
        print("="*80)
        print(f"Total processed: {len(alerts_df)}")
        print(f"Successfully inserted: {len(records)}")
        print(f"Skipped (no stock_id): {skipped_no_id}")
        print(f"Skipped (duplicates): {skipped_duplicate}")
        if truncated_count > 0:
            print(f"Fields truncated: {truncated_count}")
        print("="*80)

    except Exception as e:
        print(f"\nDatabase error: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()
            print("  Connection closed")



def print_alert_summary(alerts_df):
    """Print formatted summary of all alerts"""
    if alerts_df.empty:
        print("\n✓ No alerts generated")
        return

    print("\n" + "="*80)
    print("ALERT SUMMARY")
    print("="*80)

    print(f"\nTotal Alerts: {len(alerts_df)}")
    print(f"Date Range: {alerts_df['date'].min().date()} to {alerts_df['date'].max().date()}")
    print(f"Stocks with Alerts: {alerts_df['ticker'].nunique()}")

    print("\n--- Severity Breakdown ---")
    severity_counts = alerts_df['severity'].value_counts()
    for severity in ['HIGH', 'MEDIUM', 'LOW']:
        count = severity_counts.get(severity, 0)
        pct = (count / len(alerts_df) * 100) if len(alerts_df) > 0 else 0
        print(f"  {severity:8s}: {count:4d} ({pct:5.1f}%)")

    print("\n--- Alert Type Breakdown ---")
    type_counts = alerts_df['alert_type'].value_counts()
    for alert_type, count in type_counts.items():
        print(f"  {alert_type:20s}: {count:4d}")

    print("\n--- Alerts by Stock ---")
    stock_summary = alerts_df.groupby(['ticker', 'company']).agg({
        'severity': lambda x: (x == 'HIGH').sum(),
        'alert_type': 'count'
    }).rename(columns={'severity': 'high_alerts', 'alert_type': 'total_alerts'})
    stock_summary = stock_summary.sort_values('high_alerts', ascending=False)

    for (ticker, company), row in stock_summary.iterrows():
        company_short = company[:35] + "..." if len(company) > 35 else company
        print(f"  {ticker:12s} {company_short:38s}: {row['total_alerts']:3d} alerts ({row['high_alerts']:2d} HIGH)")

    print("\n" + "="*80)
    print("RECENT HIGH SEVERITY ALERTS (Last 10)")
    print("="*80)
    high_alerts = alerts_df[alerts_df['severity'] == 'HIGH'].sort_values('date', ascending=False)

    if high_alerts.empty:
        print("\nNo HIGH severity alerts")
    else:
        for _, alert in high_alerts.head(10).iterrows():
            date_str = alert['date'].strftime('%Y-%m-%d') if hasattr(alert['date'], 'strftime') else str(alert['date'])
            print(f"\n{date_str} | {alert['ticker']} | {alert['company'][:30]}")
            print(f"  🚨 {alert['description']}")
            print(f"     Type: {alert['alert_type']} | Source: {alert['source']}")



def main():
    parser = argparse.ArgumentParser(
        description='Stock Alert System - Generate and push alerts to database',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--lookback', '-l', type=int, default=120,
                       help='Days of price data to analyze (default: 120)')
    parser.add_argument('--news-lookback', type=int, default=120,
                       help='Days of news to fetch (default: 120)')
    parser.add_argument('--no-news', action='store_true',
                       help='Skip news alerts')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be inserted without inserting')
    parser.add_argument('--min-severity', choices=['HIGH', 'MEDIUM', 'LOW'], default='LOW',
                       help='Minimum news severity to keep (default: LOW = keep all)')
    
    args = parser.parse_args()

    print("\n" + "="*80)
    print("STOCK ALERT SYSTEM v3.0")
    print("="*80)
    print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Lookback: {args.lookback} days")
    print(f"News Lookback: {args.news_lookback} days")
    print(f"Include News: {not args.no_news}")
    print(f"Min Severity: {args.min_severity}")
    print(f"Dry Run: {args.dry_run}")
    print("="*80)

    # Load FinBERT
    if not args.no_news:
        news_classifier.load_model()

    # Run Alert System
    print("\n" + "="*80)
    print("RUNNING ALERT SYSTEM")
    print("="*80)

    alerts_df = run_all_stocks(
        lookback_days=args.lookback,
        include_news=not args.no_news,
        news_lookback_days=args.news_lookback,
        min_news_severity=args.min_severity
    )

    # Display Results
    print_alert_summary(alerts_df)

    # Database Push
    print("\n" + "="*80)
    print("DATABASE OPERATIONS")
    print("="*80)

    push_alerts_to_database(alerts_df, dry_run=args.dry_run)

    print("\n" + "="*80)
    print("EXECUTION COMPLETE")
    print("="*80)
    print(f"End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*80)


if __name__ == "__main__":
    main()
 