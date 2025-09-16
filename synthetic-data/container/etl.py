#!/usr/bin/env python3
import argparse
import os
import sys
import time
import mysql.connector
from azure.storage.blob import BlobServiceClient
import pandas as pd

OPENEMR_PATIENT_INSERT = """
INSERT INTO patient_data (
  pubpid, fname, lname, DOB, sex, status, created_at, updated_at
) VALUES (%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(),UTC_TIMESTAMP())
"""

def get_mysql_connection():
    host = os.environ.get('MYSQL_HOST')
    db = os.environ.get('MYSQL_DB', 'openemr')
    user = os.environ.get('MYSQL_USER')
    password = os.environ.get('MYSQL_PASSWORD')
    if not all([host, db, user, password]):
        print('Missing MySQL environment variables', file=sys.stderr)
        sys.exit(2)
    for attempt in range(10):
        try:
            return mysql.connector.connect(host=host, database=db, user=user, password=password, connection_timeout=10)
        except Exception as e:
            print(f'MySQL connection failed (attempt {attempt+1}): {e}', file=sys.stderr)
            time.sleep(5)
    print('Could not connect to MySQL after retries', file=sys.stderr)
    sys.exit(3)

def upload_raw_blobs(source_dir: str, workdir: str):
    account = os.environ.get('STORAGE_ACCOUNT')
    container = os.environ.get('BLOB_CONTAINER')
    if not (account and container):
        print('Blob upload skipped, STORAGE_ACCOUNT or BLOB_CONTAINER missing', file=sys.stderr)
        return
    conn_str = os.environ.get('AZURE_STORAGE_CONNECTION_STRING')
    if not conn_str:
        print('No AZURE_STORAGE_CONNECTION_STRING provided; skipping blob upload (todo: use MSI).', file=sys.stderr)
        return
    bsc = BlobServiceClient.from_connection_string(conn_str)
    for fname in os.listdir(source_dir):
        fp = os.path.join(source_dir, fname)
        if not os.path.isfile(fp):
            continue
        blob_name = f'run-{int(time.time())}/{fname}'
        print(f'Uploading {fname} -> {blob_name}')
        with open(fp, 'rb') as f:
            bsc.get_blob_client(container=container, blob=blob_name).upload_blob(f, overwrite=True)

def load_patients(csv_dir: str, conn):
    patients_csv = os.path.join(csv_dir, 'patients.csv')
    if not os.path.isfile(patients_csv):
        print('patients.csv not found', file=sys.stderr)
        return 0
    df = pd.read_csv(patients_csv)
    inserted = 0
    cursor = conn.cursor()
    for _, row in df.iterrows():
        pubpid = row['Id']
        fname = row.get('FIRST')
        lname = row.get('LAST')
        dob = row.get('BIRTHDATE')
        gender = row.get('GENDER')
        status = 'active'
        try:
            cursor.execute(OPENEMR_PATIENT_INSERT, [pubpid, fname, lname, dob, gender, status])
            inserted += 1
        except Exception as e:
            print(f'Insert failed for {pubpid}: {e}', file=sys.stderr)
    conn.commit()
    cursor.close()
    return inserted

def ensure_patient_table(conn):
    ddl = """
    CREATE TABLE IF NOT EXISTS patient_data (
      id INT AUTO_INCREMENT PRIMARY KEY,
      pubpid VARCHAR(64) UNIQUE,
      fname VARCHAR(100),
      lname VARCHAR(100),
      DOB DATE,
      sex VARCHAR(10),
      status VARCHAR(20),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    """
    cursor = conn.cursor()
    cursor.execute(ddl)
    conn.commit()
    cursor.close()

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--source', required=True)
    p.add_argument('--workdir', required=True)
    return p.parse_args()

def main():
    args = parse_args()
    conn = get_mysql_connection()
    ensure_patient_table(conn)
    inserted = load_patients(args.source, conn)
    print(f'Inserted {inserted} patients')
    upload_raw_blobs(args.source, args.workdir)
    conn.close()

if __name__ == '__main__':
    main()