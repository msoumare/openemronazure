#!/usr/bin/env bash
set -euo pipefail
echo "[Synthea Job] Starting"
PATIENT_COUNT=${PATIENT_COUNT:-100}
OUTPUT_DIR=/data/output
mkdir -p "$OUTPUT_DIR"
echo "[Synthea Job] Generating $PATIENT_COUNT patients"
cd /opt/synthea
if [ -f ./run_synthea ]; then
	# Use custom properties enabling CSV exporter
	./run_synthea -p "$PATIENT_COUNT" -c synthea-local.properties || { echo "Synthea generation failed" >&2; exit 1; }
else
	echo "run_synthea script not found" >&2; exit 1
fi

# Verify expected CSV exists
if [ ! -f /opt/synthea/output/csv/patients.csv ]; then
	echo "patients.csv not generated (check synthea properties)" >&2
	ls -l /opt/synthea/output || true
	exit 4
fi
echo "[Synthea Job] Files generated, starting ETL"
python3 /app/etl.py --source /opt/synthea/output/csv --workdir /data/output
echo "[Synthea Job] Completed"