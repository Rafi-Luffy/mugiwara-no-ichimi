from datetime import datetime

def parse_date(date_str: str) -> datetime:
    """Parse date string in various formats"""
    try:
        # Try ISO format first
        return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    except:
        try:
            # Try other common formats
            return datetime.strptime(date_str, '%Y-%m-%d %H:%M:%S')
        except:
            # If all else fails, return current time
            return datetime.utcnow()