"""
Master orchestrator for running all fetch_loaders scripts
Usage:
    python run_fetch_all.py                    # Run all scripts
    python run_fetch_all.py --dry-run          # Show what would be executed
    python run_fetch_all.py --only stocks      # Run only fetch_stocks.py
    python run_fetch_all.py --skip news        # Skip fetch_news.py
"""
import sys
import subprocess
import argparse
from pathlib import Path

# Script execution order (respects dependencies)
FETCH_ORDER = [
    ("stocks", "fetch_loaders/fetch_stocks.py", "Stocks & Company Profile (FMP)"),
    ("benchmarks", "fetch_loaders/fetch_benchmarks.py", "Benchmarks/Instruments (FMP)"),
    ("mappings", "fetch_loaders/fetch_mappings.py", "Stock-Benchmark Mappings & Flags"),
    ("price_data", "fetch_loaders/fetch_price_data.py", "Historical Stock Prices (FMP)"),
    ("live_prices", "fetch_loaders/fetch_live_prices.py", "Live Stock Prices (FMP)"),
    ("fundamentals", "fetch_loaders/fetch_fundamentals.py", "Stock Fundamentals (FMP)"),
    ("earnings", "fetch_loaders/fetch_earnings.py", "Earnings Data (FMP)"),
    ("news", "fetch_loaders/fetch_news.py", "News Articles (FMP)"),
    ("forex", "fetch_loaders/fetch_forex.py", "Forex Rates (FMP)"),
]


def print_header():
    """Print header banner."""
    print("\n" + "=" * 70)
    print(" " * 15 + "FMP/TIINGO DATA FETCH ORCHESTRATOR")
    print("=" * 70)


def print_summary(results):
    """Print execution summary."""
    print("\n" + "=" * 70)
    print("EXECUTION SUMMARY")
    print("=" * 70)

    success_count = sum(1 for r in results if r['success'])
    failed_count = len(results) - success_count

    for result in results:
        status = "✓ SUCCESS" if result['success'] else "✗ FAILED"
        print(f"{status:12} | {result['name']:30} | {result['script']}")

    print("-" * 70)
    print(f"Total: {len(results)} | Success: {success_count} | Failed: {failed_count}")
    print("=" * 70)


def run_script(script_path, script_name):
    """Run a single fetch script."""
    print(f"\n{'=' * 70}")
    print(f"Running: {script_name}")
    print(f"Script: {script_path}")
    print("=" * 70)

    try:
        result = subprocess.run(
            [sys.executable, script_path],
            check=True,
            capture_output=False,
            text=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n✗ Script failed with exit code {e.returncode}")
        return False
    except Exception as e:
        print(f"\n✗ Error running script: {e}")
        return False


def main():
    """Main orchestration function."""
    parser = argparse.ArgumentParser(description="Run FMP/Tiingo data fetch scripts")
    parser.add_argument('--dry-run', action='store_true', help='Show what would be executed without running')
    parser.add_argument('--only', type=str, help='Run only the specified script (e.g., --only stocks)')
    parser.add_argument('--skip', type=str, help='Skip the specified script (e.g., --skip news)')
    parser.add_argument('--list', action='store_true', help='List all available scripts')

    args = parser.parse_args()

    print_header()

    # List mode
    if args.list:
        print("\nAvailable scripts:")
        for key, script, name in FETCH_ORDER:
            print(f"  {key:15} | {name:35} | {script}")
        print("\n")
        return

    # Build execution list
    scripts_to_run = []

    for key, script, name in FETCH_ORDER:
        # Handle --only flag
        if args.only and key != args.only:
            continue

        # Handle --skip flag
        if args.skip and key == args.skip:
            print(f"⊗ Skipping: {name}")
            continue

        scripts_to_run.append((key, script, name))

    # Dry run mode
    if args.dry_run:
        print("\n[DRY RUN MODE] Would execute the following scripts:\n")
        for i, (key, script, name) in enumerate(scripts_to_run, 1):
            print(f"  {i}. {name:35} | {script}")
        print(f"\nTotal: {len(scripts_to_run)} scripts")
        return

    # Execute scripts
    if not scripts_to_run:
        print("\n✗ No scripts to run. Check your --only or --skip filters.")
        return

    print(f"\nExecuting {len(scripts_to_run)} scripts in order...\n")

    results = []

    for key, script, name in scripts_to_run:
        success = run_script(script, name)
        results.append({
            'key': key,
            'script': script,
            'name': name,
            'success': success
        })

        if not success:
            print(f"\n⚠ Script '{name}' failed. Continue? (y/n): ", end='')
            response = input().strip().lower()
            if response != 'y':
                print("\n⊗ Execution aborted by user.")
                break

    # Print summary
    print_summary(results)

    # Exit with error if any script failed
    if any(not r['success'] for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
