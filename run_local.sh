#!/bin/bash
# Helper script to run fetch scripts locally with proper environment variables

export FMP_API_KEY=iyeAw4PFbtHWXtRCJ8mv6fAJ11RmNPoO
export TIINGO_API_KEY=37ee80c8063abdd83d1bd91311ac3a36cf86e658
export USE_RDS_DIRECT=true
export RDS_HOST=localhost
export RDS_PORT=5433
export RDS_DATABASE=equities_first_dev_db
export RDS_USER=ef_dev_user_rw
export RDS_PASSWORD='ef_dev_user_rw@123!'
export RDS_SSL_MODE=disable

# Run the script passed as argument
python3 "$@"
