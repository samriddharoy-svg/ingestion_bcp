# ===== DATABASE CONFIG =====
$DB_HOST = "equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com"
$PORT = "5432"
$DB_NAME = "equities_first_bcp_db"
$USER = "ef_bcp_admin"
$PASSWORD = "admin@123!"

# ===== S3 BUCKET =====
$S3_BUCKET = "s3://bcp-rds-backups-2026/rds-backups"

# ===== PG_DUMP PATH =====
$PG_DUMP = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"

# ===== FILE NAME =====
$DATE = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$FILE_NAME = "backup_$DATE.dump"

# ===== START BACKUP =====
$env:PGPASSWORD = $PASSWORD

Write-Host "Starting backup..."

& "$PG_DUMP" -h $DB_HOST -U $USER -d $DB_NAME -p $PORT -F c -f $FILE_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ pg_dump failed"
    exit 1
}

Write-Host "Backup created"

# ===== UPLOAD TO S3 =====
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp $FILE_NAME $S3_BUCKET/

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Upload failed"
    exit 1
}

Write-Host "Uploaded to S3"

# ===== CLEANUP =====
Remove-Item $FILE_NAME
Remove-Item Env:PGPASSWORD

Write-Host "✅ DONE"
# ===== DELETE OLD BACKUPS (OLDER THAN 7 DAYS) =====

Write-Host "Cleaning old backups..."

$limit = (Get-Date).AddDays(-7)

$objects = & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 ls $S3_BUCKET --recursive

foreach ($obj in $objects) {

    if ([string]::IsNullOrWhiteSpace($obj)) {
        continue
    }

    $parts = $obj -split "\s+"

    if ($parts.Length -ge 4 -and $parts[3] -ne "") {

        $dateStr = "$($parts[0]) $($parts[1])"
        $fileDate = Get-Date $dateStr

        if ($fileDate -lt $limit) {
            $fileName = $parts[-1]

            Write-Host "Deleting old backup: $fileName"

            & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 rm "$S3_BUCKET/$fileName"
        }
    }
}

Write-Host "Cleanup done"