import os
import pandas as pd
import requests
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import execute_batch
import json

# Configuration

# API Config
API_CONFIG = {
    'base_url': 'https://nonrecitative-grayce-limicolous.ngrok-free.dev/api/v1',
    'endpoints': {
        'attention_surge': '/attention-surge',
        'influencer_impact': '/influencer-impact'
    },
    'timeout': 30
}

# DB Config — reads from env vars, falls back to dev DB defaults
DB_CONFIG = {
    'host': os.getenv('RDS_HOST', 'equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com'),
    'port': int(os.getenv('RDS_PORT', '5432')),
    'database': os.getenv('RDS_DATABASE', 'equities_first_dev_db'),
    'user': os.getenv('RDS_USER', 'ef_dev_user_rw'),
    'password': os.getenv('RDS_PASSWORD', 'ef_dev_user_rw@123!'),
    'sslmode': os.getenv('RDS_SSL_MODE', 'require')
}

def _fetch_stocks():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
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
        print(f"[fetch_chatroomalert] Loaded {len(result)} stocks from DB")
        return result
    except Exception as e:
        print(f"[fetch_chatroomalert] Warning: Could not fetch stocks from DB: {e}")
        return []

STOCKS = _fetch_stocks()

# Thresholds
CHATROOM_THRESHOLDS = {
    'ATTENTION_SURGE': {
        'HIGH': {
            'message_surge_score': 3.0,
            'surge_frequency_pct': 30,
            'vs_baseline_pct': 200,
            'consecutive_surge_days': 3,
            'engagement_surge_score': 1.0
        },
        'MEDIUM': {
            'message_surge_score': 2.0,
            'surge_frequency_pct': 15,
            'vs_baseline_pct': 100,
            'consecutive_surge_days': 2,
            'engagement_surge_score': 0.5
        },
        'LOW': {
            'message_surge_score': 1.5,
            'surge_frequency_pct': 10,
            'vs_baseline_pct': 50,
            'consecutive_surge_days': 1,
            'engagement_surge_score': 0.0
        }
    },
    'INFLUENCER_IMPACT': {
        'HIGH': {
            'influencer_percentile': 95,
            'min_posts': 3,
            'min_reach': 10000,
            'min_influencers': 3,
            'engagement_rate': 10.0
        },
        'MEDIUM': {
            'influencer_percentile': 80,
            'min_posts': 2,
            'min_reach': 5000,
            'min_influencers': 2,
            'engagement_rate': 5.0
        },
        'LOW': {
            'influencer_percentile': 70,
            'min_posts': 1,
            'min_reach': 1000,
            'min_influencers': 1,
            'engagement_rate': 2.0
        }
    }
}

# API Functions

def call_attention_surge_api(stock_id, start_date, end_date,
                             baseline_days=30, surge_threshold=2.0):
    # Call API
    try:
        url = f"{API_CONFIG['base_url']}{API_CONFIG['endpoints']['attention_surge']}"

        payload = {
            "stock_id": stock_id,
            "start_date": start_date,
            "end_date": end_date,
            "baseline_days": baseline_days,
            "surge_threshold": surge_threshold,
            "platform": None,
            "source_name": None
        }

        print(f"  → Calling Attention Surge API for stock_id {stock_id}...")
        response = requests.post(url, json=payload, timeout=API_CONFIG['timeout'])

        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print(f"    ✓ Received data: {len(data.get('daily_metrics', []))} days, "
                      f"{data.get('summary_metrics', {}).get('surge_days_count', 0)} surge days")
                return data
            else:
                print(f"    ✗ API returned success=false: {data.get('error')}")
                return None
        else:
            print(f"    ✗ API error: {response.status_code} - {response.text}")
            return None

    except Exception as e:
        print(f"    ✗ Exception calling API: {e}")
        return None


def call_influencer_impact_api(stock_id, start_date, end_date,
                               engagement_percentile=90, min_message_count=5):
    # Call API
    try:
        url = f"{API_CONFIG['base_url']}{API_CONFIG['endpoints']['influencer_impact']}"

        payload = {
            "stock_id": stock_id,
            "start_date": start_date,
            "end_date": end_date,
            "identification_method": "all",
            "engagement_percentile": engagement_percentile,
            "min_message_count": min_message_count,
            "platform": None,
            "source_name": None
        }

        print(f"  Calling Influencer Impact API for stock_id {stock_id}...")
        response = requests.post(url, json=payload, timeout=API_CONFIG['timeout'])

        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                influencer_count = len(data.get('influencers', []))
                print(f"  Received data: {influencer_count} influencers detected")
                return data
            else:
                print(f"  API returned success=false: {data.get('error')}")
                return None
        else:
            print(f" API error: {response.status_code} - {response.text}")
            return None

    except Exception as e:
        print(f" Exception calling API: {e}")
        return None

# Surge Alerts

def detect_consecutive_surges(surge_detections):
    # Detect consecutive
    if not surge_detections:
        return 0, []

    # Sort
    sorted_surges = sorted(surge_detections, key=lambda x: x['date'])

    consecutive_periods = []
    current_period = [sorted_surges[0]]

    for i in range(1, len(sorted_surges)):
        prev_date = datetime.strptime(sorted_surges[i-1]['date'], '%Y-%m-%d')
        curr_date = datetime.strptime(sorted_surges[i]['date'], '%Y-%m-%d')

        # Check consecutive
        if (curr_date - prev_date).days == 1:
            current_period.append(sorted_surges[i])
        else:
            if len(current_period) > 0:
                consecutive_periods.append(current_period)
            current_period = [sorted_surges[i]]

    # Add last
    if len(current_period) > 0:
        consecutive_periods.append(current_period)

    max_consecutive = max([len(p) for p in consecutive_periods]) if consecutive_periods else 1

    return max_consecutive, consecutive_periods


def generate_attention_surge_alerts(api_response, stock_info):
    # Generate alerts
    alerts = []

    if not api_response or not api_response.get('success'):
        return alerts

    daily_metrics = api_response.get('daily_metrics', [])
    surge_detections = api_response.get('surge_detections', [])
    summary_metrics = api_response.get('summary_metrics', {})

    # Metrics
    surge_frequency_pct = summary_metrics.get('surge_frequency_pct', 0)
    max_surge_score = summary_metrics.get('max_surge_score', 0)
    surge_days_count = summary_metrics.get('surge_days_count', 0)

    # Detect consecutive
    max_consecutive, consecutive_periods = detect_consecutive_surges(surge_detections)

    # Summary Alerts

    thresholds = CHATROOM_THRESHOLDS['ATTENTION_SURGE']

    # High Severity
    if (surge_frequency_pct >= thresholds['HIGH']['surge_frequency_pct'] or
        max_consecutive >= thresholds['HIGH']['consecutive_surge_days']):

        description = f"Sustained attention surge: {surge_frequency_pct:.1f}% of days surging"
        if max_consecutive >= 3:
            description += f", {max_consecutive} consecutive surge days detected"

        alerts.append({
            'date': datetime.now().date(),
            'ticker': stock_info['ticker'],
            'company': stock_info['company_name'],
            'severity': 'HIGH',
            'alert_type': 'CHATROOM',
            'description': description,
            'source': 'Attention Surge',
            'url': None,
            'metadata': json.dumps({
                'surge_frequency_pct': surge_frequency_pct,
                'max_consecutive_days': max_consecutive,
                'surge_days_count': surge_days_count,
                'max_surge_score': max_surge_score
            })
        })

    # Medium Severity
    elif (surge_frequency_pct >= thresholds['MEDIUM']['surge_frequency_pct'] or
          max_consecutive >= thresholds['MEDIUM']['consecutive_surge_days']):

        description = f"Notable attention pattern: {surge_frequency_pct:.1f}% surge frequency"
        if max_consecutive >= 2:
            description += f", {max_consecutive} consecutive days"

        alerts.append({
            'date': datetime.now().date(),
            'ticker': stock_info['ticker'],
            'company': stock_info['company_name'],
            'severity': 'MEDIUM',
            'alert_type': 'CHATROOM',
            'description': description,
            'source': 'Attention Surge',
            'url': None,
            'metadata': json.dumps({
                'surge_frequency_pct': surge_frequency_pct,
                'max_consecutive_days': max_consecutive,
                'surge_days_count': surge_days_count
            })
        })

    # Daily Alerts

    for surge in surge_detections:
        surge_date = surge['date']
        message_surge_score = surge['message_surge_score']
        engagement_surge_score = surge['engagement_surge_score']
        vs_baseline = surge['vs_baseline_avg']
        message_increase_pct = vs_baseline['message_count_increase_pct']
        engagement_increase_pct = vs_baseline['engagement_increase_pct']

        # High Severity
        if (message_surge_score >= thresholds['HIGH']['message_surge_score'] or
            message_increase_pct >= thresholds['HIGH']['vs_baseline_pct'] or
            (surge['surge_type'] == 'both')):  # Both message and engagement surge

            description = f"Extreme surge: {message_surge_score:.2f}x score, "
            description += f"{message_increase_pct:.0f}% above baseline"
            if surge['surge_type'] == 'both':
                description += " (messages + engagement)"

            alerts.append({
                'date': datetime.strptime(surge_date, '%Y-%m-%d').date(),
                'ticker': stock_info['ticker'],
                'company': stock_info['company_name'],
                'severity': 'HIGH',
                'alert_type': 'CHATROOM',
                'description': description,
                'source': 'Attention Surge',
                'url': None,
                'metadata': json.dumps({
                    'surge_score': message_surge_score,
                    'message_count': surge['peak_message_count'],
                    'vs_baseline_pct': message_increase_pct,
                    'surge_type': surge['surge_type']
                })
            })

        # Medium Severity
        elif (message_surge_score >= thresholds['MEDIUM']['message_surge_score'] or
              message_increase_pct >= thresholds['MEDIUM']['vs_baseline_pct'] or
              engagement_surge_score >= thresholds['MEDIUM']['engagement_surge_score']):

            description = f"Significant surge: {message_surge_score:.2f}x score, "
            description += f"{message_increase_pct:.0f}% above baseline"

            alerts.append({
                'date': datetime.strptime(surge_date, '%Y-%m-%d').date(),
                'ticker': stock_info['ticker'],
                'company': stock_info['company_name'],
                'severity': 'MEDIUM',
                'alert_type': 'CHATROOM',
                'description': description,
                'source': 'Attention Surge',
                'url': None,
                'metadata': json.dumps({
                    'surge_score': message_surge_score,
                    'message_count': surge['peak_message_count'],
                    'vs_baseline_pct': message_increase_pct
                })
            })

        # Low Severity
        elif (message_surge_score >= thresholds['LOW']['message_surge_score'] or
              message_increase_pct >= thresholds['LOW']['vs_baseline_pct']):

            description = f"Moderate surge: {message_surge_score:.2f}x score, "
            description += f"{message_increase_pct:.0f}% above baseline"

            alerts.append({
                'date': datetime.strptime(surge_date, '%Y-%m-%d').date(),
                'ticker': stock_info['ticker'],
                'company': stock_info['company_name'],
                'severity': 'LOW',
                'alert_type': 'CHATROOM',
                'description': description,
                'source': 'Attention Surge',
                'url': None,
                'metadata': json.dumps({
                    'surge_score': message_surge_score,
                    'message_count': surge['peak_message_count']
                })
            })

    return alerts

# Influencer Alerts

def generate_influencer_impact_alerts(api_response, stock_info):
    # Generate alerts
    alerts = []

    if not api_response or not api_response.get('success'):
        return alerts

    influencers = api_response.get('influencers', [])

    if not influencers:
        return alerts

    thresholds = CHATROOM_THRESHOLDS['INFLUENCER_IMPACT']
    total_count = len(influencers)

    # Process data
    processed_influencers = []
    for rank, item in enumerate(influencers):
        # Map keys
        username = item.get('author', 'Unknown')
        posts = item.get('message_count', 0)

        # Fallback reach
        reach = item.get('reach_score', 0)
        if reach == 0:
            reach = item.get('total_engagement', 0)

        # Calculate percentile
        # Rank 0 is top (100th percentile)
        percentile = 100 * (1 - (rank / total_count))

        processed_influencers.append({
            'username': username,
            'posts': posts,
            'reach': reach,
            'percentile': percentile
        })

    # Filter valid
    valid_influencers = [
        i for i in processed_influencers
        if i['username'] != 'Unknown' and (i['posts'] > 0 or i['reach'] > 0)
    ]

    # Calculate totals
    top_tier_count = sum(1 for inf in valid_influencers if inf['percentile'] >= 90)
    total_reach_sum = sum(inf['reach'] for inf in valid_influencers)
    total_posts_sum = sum(inf['posts'] for inf in valid_influencers)

    # Summary Alerts
    if len(valid_influencers) >= 3:
        severity = 'HIGH' if top_tier_count >= 3 or total_reach_sum > 5000 else 'MEDIUM'

        desc = f"Influencer Activity: {len(valid_influencers)} active voices. "
        desc += f"Total Engagement: {total_reach_sum:,}, Total Posts: {total_posts_sum}."

        alerts.append({
            'date': datetime.now().date(),
            'ticker': stock_info['ticker'],
            'company': stock_info['company_name'],
            'severity': severity,
            'alert_type': 'CHATROOM',
            'description': desc,
            'source': 'Influencer Impact',
            'url': None,
            'metadata': json.dumps({'influencer_count': len(valid_influencers), 'total_engagement': total_reach_sum})
        })

    # Individual Alerts

    for inf in valid_influencers[:5]:  # Limit to top 5 most impactful
        username = inf['username']
        percentile = inf['percentile']
        posts = inf['posts']
        reach = inf['reach']

        # High Severity
        if percentile >= thresholds['HIGH']['influencer_percentile']:
            desc = f"Top Influencer '{username}': {reach:,} engagement, {posts} posts"
            alerts.append({
                'date': datetime.now().date(),
                'ticker': stock_info['ticker'],
                'company': stock_info['company_name'],
                'severity': 'HIGH',
                'alert_type': 'CHATROOM',
                'description': desc,
                'source': 'Influencer Impact',
                'url': None
            })

        # Medium Severity
        elif percentile >= thresholds['MEDIUM']['influencer_percentile']:
            desc = f"Key Voice '{username}': {reach:,} engagement, {posts} posts"
            alerts.append({
                'date': datetime.now().date(),
                'ticker': stock_info['ticker'],
                'company': stock_info['company_name'],
                'severity': 'MEDIUM',
                'alert_type': 'CHATROOM',
                'description': desc,
                'source': 'Influencer Impact',
                'url': None
            })

        # Low Severity
        elif reach > 100 or posts >= 3:
            desc = f"Active User '{username}': {reach:,} engagement"
            alerts.append({
                'date': datetime.now().date(),
                'ticker': stock_info['ticker'],
                'company': stock_info['company_name'],
                'severity': 'LOW',
                'alert_type': 'CHATROOM',
                'description': desc,
                'source': 'Influencer Impact',
                'url': None
            })

    return alerts

# Main Processing

def process_stock_chatroom_alerts(stock_info, lookback_days=30):
    # Process stock
    ticker = stock_info['ticker']
    company = stock_info['company_name']
    stock_id = stock_info['stock_id']

    print(f"\n{'='*80}")
    print(f"Processing Chatroom Alerts: {company} ({ticker})")
    print(f"{'='*80}")

    all_alerts = []

    # Date range
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=lookback_days)

    # Attention Surge
    print("→ Fetching Attention Surge data...")
    surge_response = call_attention_surge_api(
        stock_id=stock_id,
        start_date=start_date.strftime('%Y-%m-%d'),
        end_date=end_date.strftime('%Y-%m-%d'),
        baseline_days=30,
        surge_threshold=2.0
    )

    if surge_response:
        surge_alerts = generate_attention_surge_alerts(surge_response, stock_info)
        all_alerts.extend(surge_alerts)
        print(f" Generated {len(surge_alerts)} attention surge alerts")
    else:
        print("  No attention surge data available")

    # Influencer Impact
    print(" Fetching Influencer Impact data...")
    influencer_response = call_influencer_impact_api(
        stock_id=stock_id,
        start_date=start_date.strftime('%Y-%m-%d'),
        end_date=end_date.strftime('%Y-%m-%d'),
        engagement_percentile=90,
        min_message_count=5
    )

    if influencer_response:
        influencer_alerts = generate_influencer_impact_alerts(influencer_response, stock_info)
        all_alerts.extend(influencer_alerts)
        print(f"  Generated {len(influencer_alerts)} influencer impact alerts")
    else:
        print("  No influencer impact data available")

    return pd.DataFrame(all_alerts)


def run_chatroom_alerts_for_all_stocks(lookback_days=30):
    # Run all
    print("\n" + "="*80)
    print("CHATROOM ALERT SYSTEM")
    print("="*80)
    print(f"Stocks: {len(STOCKS)}")
    print(f"Lookback period: {lookback_days} days (1 month)")
    print(f"API Base URL: {API_CONFIG['base_url']}")
    print("="*80)

    all_alerts = []

    for i, stock in enumerate(STOCKS, 1):
        print(f"\n[{i}/{len(STOCKS)}]", end=" ")

        try:
            alerts_df = process_stock_chatroom_alerts(stock, lookback_days)
            if not alerts_df.empty:
                all_alerts.append(alerts_df)
        except Exception as e:
            print(f"  ✗ Error: {e}")
            import traceback
            traceback.print_exc()
            continue

    if all_alerts:
        combined = pd.concat(all_alerts, ignore_index=True)
        combined = combined.sort_values(['date', 'severity'], ascending=[False, True])
        return combined
    else:
        return pd.DataFrame()

# DB Operations

def push_chatroom_alerts_to_db(alerts_df, dry_run=True):
    # Push DB
    if alerts_df.empty:
        print("\n No chatroom alerts to push")
        return

    print("\n" + "="*80)
    print("DATABASE PUSH" + (" (DRY RUN)" if dry_run else " (LIVE)"))
    print("="*80)
    print(f"Total alerts to process: {len(alerts_df)}")

    # Connect DB
    conn = None
    try:
        print("\n Connecting to database...")
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("  Connected")

        unique_tickers = alerts_df['ticker'].unique()
        ticker_to_stock_id = {}

        print(f"\n Verifying {len(unique_tickers)} tickers against database...")
        for ticker in unique_tickers:
            cursor.execute("SELECT stock_id FROM ingest_db.stocks WHERE ticker = %s", (ticker,))
            result = cursor.fetchone()
            if result:
                ticker_to_stock_id[ticker] = result[0]
            else:
                print(f"  WARNING: Ticker {ticker} not found in DB - alerts will be skipped")

        # Prepare records
        records = []
        skipped = 0
        truncated = 0

        MAX_LENGTHS = {'stock_symbol': 20, 'alert_type': 50, 'description': 500, 'source': 500, 'severity': 20}

        for _, row in alerts_df.iterrows():
            if row['ticker'] not in ticker_to_stock_id:
                skipped += 1
                continue

            desc = str(row['description'])
            if len(desc) > MAX_LENGTHS['description']:
                desc = desc[:497] + "..."
                truncated += 1

            src = str(row['source'])
            if len(src) > MAX_LENGTHS['source']:
                src = src[:497] + "..."
                truncated += 1

            records.append((
                ticker_to_stock_id[row['ticker']],
                row['ticker'],
                'CHATROOM',
                desc,
                src,
                row['date'],
                row['severity'],
                row.get('url', None),
                'ACTIVE'
            ))

        # Dry run
        if dry_run:
            print(f"\n[DRY RUN SUMMARY]")
            print(f"  Prepared Records: {len(records)}")
            print(f"  Skipped Records:  {skipped} (Invalid Ticker)")
            print(f"  Truncated Fields: {truncated}")

            if records:
                print("\n[SAMPLE DATA - FIRST 5 RECORDS]")
                for i, rec in enumerate(records[:5]):
                    print(f"  {i+1}. {rec[1]} | {rec[6]} | {rec[3][:60]}...")

            print("\n DRY RUN COMPLETE - NO DATA INSERTED")
            conn.rollback()
            return

        if not records:
            print("\n No valid records to insert")
            return

        # Check duplicates
        print(" Checking for existing records...")
        cursor.execute("""
            SELECT stock_id, alert_type, description, alert_date, severity 
            FROM ingest_db.stocks_market_alerts
        """)
        existing_keys = set(cursor.fetchall())
        print(f"Found {len(existing_keys)} existing alert records")

        # Filter duplicates
        records_to_insert = []
        duplicates = 0
        for r in records:
            key = (r[0], r[2], r[3], r[5], r[6])
            if key not in existing_keys:
                records_to_insert.append(r)
            else:
                duplicates += 1

        print(f" Inserting {len(records_to_insert)} new alerts (skipping {duplicates} duplicates)...")

        if records_to_insert:
            insert_query = """
                INSERT INTO ingest_db.stocks_market_alerts (
                    stock_id, stock_symbol, alert_type, description,
                    source, alert_date, severity, url, status
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """

            execute_batch(cursor, insert_query, records_to_insert, page_size=100)
            conn.commit()
            
            print(f" Alert ingestion completed")
            print(f"  - Total records prepared: {len(records)}")
            print(f"  - New records inserted: {len(records_to_insert)}")
            print(f"  - Duplicates skipped: {duplicates}")
        else:
            print(" No new records to insert (all duplicates)")
            print(f"  - Total records prepared: {len(records)}")
            print(f"  - Duplicates skipped: {duplicates}")

    except Exception as e:
        print(f"\n✗ Database error: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()
            print("   Connection closed")

def print_alert_summary(alerts_df):
    # Print summary
    if alerts_df.empty:
        print("\n No alerts generated")
        return

    print("\n" + "="*80)
    print("CHATROOM ALERT SUMMARY")
    print("="*80)
    print(f"Total Alerts: {len(alerts_df)}")
    print(f"Date Range: {alerts_df['date'].min()} to {alerts_df['date'].max()}")
    print(f"Stocks with Alerts: {alerts_df['ticker'].nunique()}")

    print("\n--- Severity Breakdown ---")
    severity_counts = alerts_df['severity'].value_counts()
    for severity in ['HIGH', 'MEDIUM', 'LOW']:
        count = severity_counts.get(severity, 0)
        print(f"  {severity:8s}: {count:4d}")

    print("\n--- Alerts by Stock (Top 5) ---")
    stock_counts = alerts_df.groupby('company')['severity'].count().sort_values(ascending=False).head(5)
    for company, count in stock_counts.items():
        print(f"  {company[:35]:35s}: {count:3d}")

if __name__ == "__main__":
    print("\n" + "="*80)
    print("CHATROOM ALERT SYSTEM v1.2")
    print("="*80)
    print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Config
    DRY_RUN = True
    LOOKBACK_DAYS = 90

    # Run generation
    print(f"\nLookback Period: {LOOKBACK_DAYS} days (1 month)")
    print(f"Mode: {'DRY RUN' if DRY_RUN else 'LIVE INSERTION'}")
    
    alerts_df = run_chatroom_alerts_for_all_stocks(lookback_days=LOOKBACK_DAYS)

    if not alerts_df.empty:
        # Summary
        print_alert_summary(alerts_df)

        # DB Push
        push_chatroom_alerts_to_db(alerts_df, dry_run=DRY_RUN)

        if DRY_RUN:
            print("\n" + "="*80)
            print("  DRY RUN MODE ACTIVE")
            print("="*80)
            print("To actually insert data into the database:")
            print("1. Set DRY_RUN = False in the __main__ section")
            print("2. Run the script again")
            print("="*80)
    else:
        print("\nNo alerts generated. Skipping database operations.")

    print("\n" + "="*80)
    print("EXECUTION COMPLETE")
    print("="*80)

