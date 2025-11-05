# Canvas Logs Automation

Export Canvas activity logs and submissions from PostgreSQL to Excel with timezone conversion and IP geolocation, and generates a Word summary.

## Features

- **Dual Query Export**: Activity logs and assignment submissions
- **Timezone Handling**: Automatic UTC → EST/EDT conversion with DST support
- **IP Geolocation**: Adds country, region, city, and ISP/org columns for each IP address
- **Fast Processing**: Optimized with pandas for efficient data handling
- **Excel Output**: Clean, formatted spreadsheets ready for analysis
- **Word Summary Report**: Auto-generated .docx report grouped by course with assignment bullets

## Setup

```sh
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Configuration

### PostgreSQL Connection

Option A - Individual environment variables:
```sh
export PGHOST="your-host"
export PGDATABASE="canvas_data"
export PGUSER="your-user"
export PGPASSWORD="your-password"
export PGPORT="5432"           # optional, defaults to 5432
export PGSSLMODE="require"     # optional, recommended for security
```

Option B - Connection string (DSN):
```sh
export POSTGRES_DSN="host=your-host port=5432 dbname=canvas_data user=your-user password=your-password sslmode=require"
```

## Usage

```sh
python canvas-logs.py \
  --username student@example.edu \
  --start "2025-08-26 00:00:00" \
  --end "2025-10-31 00:00:00" \
  --output-dir results
```

### Arguments

- `--username`: Canvas login/unique_id to filter (required)
- `--start`: Start timestamp in EST/EDT format (required, inclusive)
- `--end`: End timestamp in EST/EDT format (required, exclusive)
- `--output-dir`: Output directory (optional). If omitted, a folder named exactly as `--username` will be created and used.

### Output

Creates the specified folder with:
- `{output-dir-name}-activity.xlsx` — Web activity logs with IP geolocation
- `{output-dir-name}-submissions.xlsx` — Assignment submissions with forensics and IP geolocation
- `{output-dir-name}-summary.docx` — Word report: "<username> logs summary report", grouped by course with assignment bullets

Each file includes:
- Timestamps converted to EST/EDT
- IP address with country, region, city, and ISP columns
- Relevant Canvas data fields

## Notes

**Timezone Handling:**
- Input times (`--start` and `--end`) are interpreted as EST/EDT
- Database timestamps (UTC) are automatically converted to EST/EDT for output

**IP Geolocation:**
- Uses ipinfo.io (primary) and ipwho.is (fallback)
- Free tier limits: ~50k requests/month (ipinfo); ipwho.is is keyless with fair‑use limits
- Results are cached to minimize API calls
- Only unique IPs are looked up

**Word Summary (.docx):**
- Requires `python-docx` (included in `requirements.txt`)
- If the package isn’t installed, the script will skip generating the Word report and continue

