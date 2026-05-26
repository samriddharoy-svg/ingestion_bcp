"""
Lambda Function: AggregateStockResults
Purpose: Aggregate results from parallel stock processing
Runtime: Python 3.11
Timeout: 60 seconds
Memory: 512 MB
"""

import json
from datetime import datetime

def lambda_handler(event, context):
    """
    Aggregate results from Map state.

    Args:
        event: {
            'stockResults': [
                {'status': 'SUCCESS', 'ticker': '0853.HK', ...},
                {'status': 'FAILED', 'ticker': '9618.HK', ...},
                ...
            ]
        }

    Returns:
        dict: Aggregated statistics
    """
    print(f"=== Aggregating results from {len(event.get('stockResults', []))} stocks ===")

    stock_results = event.get('stockResults', [])

    successful = []
    failed = []
    total_stocks_count = 0
    total_prices_count = 0
    total_execution_time = 0

    for result in stock_results:
        # Each result has structure: {'fetchResult': {...}, 'status': {...}}
        fetch_result = result.get('fetchResult', {})
        ticker = fetch_result.get('ticker', 'unknown')
        name = fetch_result.get('name', ticker)
        status = fetch_result.get('status', 'UNKNOWN')

        if status == 'SUCCESS':
            successful.append(f"{ticker} ({name})")
            total_stocks_count += fetch_result.get('stocks_count', 0)
            total_prices_count += fetch_result.get('prices_count', 0)
            total_execution_time += fetch_result.get('execution_time', 0)
        else:
            error = fetch_result.get('error', 'Unknown error')
            failed.append(f"{ticker} ({name}): {error}")

    successful_count = len(successful)
    failed_count = len(failed)
    total_stocks = successful_count + failed_count

    # Determine overall status
    if successful_count == 0:
        overall_status = 'FAILED'
    elif failed_count == 0:
        overall_status = 'SUCCESS'
    else:
        overall_status = 'PARTIAL_SUCCESS'

    print(f"\n{'='*60}")
    print(f"Aggregation Summary:")
    print(f"  Total stocks: {total_stocks}")
    print(f"  Successful: {successful_count}")
    print(f"  Failed: {failed_count}")
    print(f"  Overall status: {overall_status}")
    print(f"{'='*60}\n")

    return {
        'status': overall_status,
        'total_stocks': total_stocks,
        'successful_count': successful_count,
        'failed_count': failed_count,
        'total_stocks_inserted': total_stocks_count,
        'total_prices_inserted': total_prices_count,
        'execution_time': total_execution_time / max(successful_count, 1),  # Average
        'successful_stocks': '\n'.join(successful) if successful else 'None',
        'failed_stocks': '\n'.join(failed) if failed else 'None',
        'timestamp': datetime.utcnow().isoformat()
    }
