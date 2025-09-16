#!/usr/bin/env bash
set -euo pipefail
echo "[Synthea Job] Starting"
PATIENT_COUNT=${PATIENT_COUNT:-100}
OUTPUT_DIR=/data/output
mkdir -p "$OUTPUT_DIR"
echo "[Synthea Job] Generating $PATIENT_COUNT patients"
cd /opt/synthea
./run_synthea -p "$PATIENT_COUNT" || { echo "Synthea generation failed" >&2; exit 1; }
echo "[Synthea Job] Files generated, starting ETL"
python3 /app/etl.py --source /opt/synthea/output/csv --workdir /data/output
echo "[Synthea Job] Completed"