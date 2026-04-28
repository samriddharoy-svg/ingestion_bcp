"""
Master Ingestion Runner
Run all ingestion scripts in the correct order with proper dependencies.
"""
import sys
import subprocess
from pathlib import Path
from datetime import datetime

# Script execution order (respecting foreign key dependencies)
INGESTION_ORDER = [
    # Level 1: Base tables (no dependencies)
    "01_portfolio/ingest_portfolio.py",
    "01_portfolio/ingest_stocks.py",
    "02_prices/ingest_instruments.py",
    "03_forex/ingest_forex_rates.py",
    
    # Level 2: Tables with FK to level 1
    "01_portfolio/ingest_portfolio_stocks.py",
    "02_prices/ingest_stocks_price_data.py",
    "02_prices/ingest_instrument_prices.py",
    
    # Level 3: Tables with FK to stocks
    "04_news_events/ingest_news.py",
    "04_news_events/ingest_earnings_calendar.py",
    "04_news_events/ingest_stock_alerts.py",
]


def run_script(script_path: Path) -> bool:
    """Run a single ingestion script."""
    print(f"\n{'=' * 70}")
    print(f"RUNNING: {script_path.name}")
    print(f"{'=' * 70}")
    
    try:
        result = subprocess.run(
            [sys.executable, str(script_path)],
            capture_output=True,
            text=True,
            cwd=script_path.parent
        )
        
        print(result.stdout)
        
        if result.returncode != 0:
            print(f"ERROR: {result.stderr}")
            return False
        
        return True
    
    except Exception as e:
        print(f"Exception: {e}")
        return False


def main():
    """Main runner function."""
    print("=" * 70)
    print("AWS RDS DATA INGESTION - MASTER RUNNER")
    print(f"Started: {datetime.now().isoformat()}")
    print("=" * 70)
    
    base_path = Path(__file__).parent
    
    # Track results
    results = {
        'success': [],
        'failed': [],
        'skipped': []
    }
    
    # Parse command line args
    if len(sys.argv) > 1:
        if sys.argv[1] == '--dry-run':
            print("\nDRY RUN MODE - Scripts will not be executed")
            for script in INGESTION_ORDER:
                script_path = base_path / script
                exists = "✓" if script_path.exists() else "✗"
                print(f"  {exists} {script}")
            return
        
        if sys.argv[1] == '--list':
            print("\nIngestion scripts in execution order:")
            for i, script in enumerate(INGESTION_ORDER, 1):
                print(f"  {i}. {script}")
            return
    
    # Run each script
    for script in INGESTION_ORDER:
        script_path = base_path / script
        
        if not script_path.exists():
            print(f"\n⚠️  Script not found: {script}")
            results['skipped'].append(script)
            continue
        
        success = run_script(script_path)
        
        if success:
            results['success'].append(script)
        else:
            results['failed'].append(script)
            # Ask whether to continue on failure
            response = input("\nScript failed. Continue with next? (y/n): ")
            if response.lower() != 'y':
                print("Stopping ingestion.")
                break
    
    # Summary
    print("\n" + "=" * 70)
    print("INGESTION SUMMARY")
    print("=" * 70)
    print(f"Completed: {datetime.now().isoformat()}")
    print(f"\n✓ Successful: {len(results['success'])}")
    for s in results['success']:
        print(f"    {s}")
    
    print(f"\n✗ Failed: {len(results['failed'])}")
    for s in results['failed']:
        print(f"    {s}")
    
    print(f"\n⚠️  Skipped: {len(results['skipped'])}")
    for s in results['skipped']:
        print(f"    {s}")
    
    print("=" * 70)


if __name__ == "__main__":
    main()
