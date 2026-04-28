"""
Date utility functions for data ingestion
Ensures data is only captured up to yesterday (not today)
"""
from datetime import datetime, timedelta


def get_yesterday_date():
    """Get yesterday's date in YYYY-MM-DD format."""
    yesterday = datetime.now() - timedelta(days=1)
    return yesterday.strftime('%Y-%m-%d')


def get_yesterday_datetime():
    """Get yesterday's end datetime (23:59:59)."""
    yesterday = datetime.now() - timedelta(days=1)
    return yesterday.replace(hour=23, minute=59, second=59)


def is_date_valid_for_ingestion(date_str):
    """
    Check if a date is valid for ingestion (not today or future).

    Args:
        date_str: Date string in YYYY-MM-DD format

    Returns:
        bool: True if date is yesterday or earlier, False otherwise
    """
    try:
        date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
        yesterday = (datetime.now() - timedelta(days=1)).date()
        return date_obj <= yesterday
    except ValueError:
        return False


def filter_data_by_max_date(data, date_field='date'):
    """
    Filter data to include only dates up to yesterday.

    Args:
        data: List of dictionaries containing price/market data
        date_field: Field name containing the date

    Returns:
        Filtered list with only yesterday or earlier dates
    """
    yesterday = (datetime.now() - timedelta(days=1)).date()

    filtered_data = []
    for record in data:
        try:
            date_str = record.get(date_field, '')
            if not date_str:
                continue

            # Parse date (handle both YYYY-MM-DD and datetime formats)
            if isinstance(date_str, str):
                date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
            else:
                date_obj = date_str.date() if hasattr(date_str, 'date') else date_str

            # Only include if date is yesterday or earlier
            if date_obj <= yesterday:
                filtered_data.append(record)
        except (ValueError, AttributeError):
            continue

    return filtered_data


def get_cutoff_datetime_string():
    """Get yesterday's end datetime as string for database queries."""
    return get_yesterday_datetime().strftime('%Y-%m-%d %H:%M:%S')


if __name__ == '__main__':
    # Test functions
    print(f"Today: {datetime.now().strftime('%Y-%m-%d')}")
    print(f"Yesterday: {get_yesterday_date()}")
    print(f"Yesterday datetime: {get_yesterday_datetime()}")
    print(f"Cutoff datetime string: {get_cutoff_datetime_string()}")

    # Test date validation
    print(f"\nDate validation tests:")
    print(f"  2025-12-15 valid? {is_date_valid_for_ingestion('2025-12-15')}")  # Should be True (yesterday)
    print(f"  2025-12-16 valid? {is_date_valid_for_ingestion('2025-12-16')}")  # Should be False (today)
    print(f"  2025-12-17 valid? {is_date_valid_for_ingestion('2025-12-17')}")  # Should be False (future)

    # Test data filtering
    test_data = [
        {'date': '2025-12-14', 'price': 100},
        {'date': '2025-12-15', 'price': 101},
        {'date': '2025-12-16', 'price': 102},  # Today - should be filtered out
        {'date': '2025-12-17', 'price': 103},  # Future - should be filtered out
    ]
    filtered = filter_data_by_max_date(test_data)
    print(f"\nFiltered data (should exclude today and future):")
    for item in filtered:
        print(f"  {item}")
