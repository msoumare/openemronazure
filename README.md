# OpenEMRonAzure

## Overview
Deploy a production-ready OpenEMR stack on Microsoft Azure using containerization, infrastructure as code, and secure defaults.

## Architecture (tentative)
- Azure Resource Group
- Azure Container Apps or AKS (pluggable)
- Azure Database for MySQL (Flexible Server)
- Azure Storage (File Share for documents, Blob for backups)
- Azure Key Vault (secrets, certificates)
- Azure Application Gateway or Front Door (TLS + WAF)
- Azure Monitor (logs, metrics, alerts)
- Optional: Entra ID for SSO

## Features (tentative)
- IaC-first (Bicep)
- Automated SSL/TLS
- Minimal/zero downtime rolling updates
- Daily encrypted backups
- Horizontal scale of web tier
- Least-privilege secrets flow

## Prerequisites
- Azure subscription + Owner or sufficient RBAC
- az CLI (latest)
- Docker + Compose (local dev)
- Bicep
