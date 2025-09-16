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

## Dev Setup

### Prerequisites
- Azure subscription + Owner or sufficient RBAC
- Azure CLI
- Docker + Compose (local dev)
- Git CLI

### Local dev with Docker

- Clone the project repo.

    ```sh
    git clone https://github.com/dkirby-ms/
    ```

- Make a copy of the .env.example file. Make changes to the default values if desired by opening the new file and editing it.

    ```sh
    cp ./infra/.env.example ./infra/.env
    ```

- Navigate to the [./infra](infra) folder and run docker compose up.

    ```sh
    cd ./infra
    docker compose up -d
    ```
- Confirm the OpenEMR container is up and running by checking the logs.

    ```sh
    docker logs infra-openemr-1
    ```

    ![alt text](./docs/img/image.png)

- Open a browser and navigate to [http://localhost:8080](http://localhost:8080)

    ![alt text](./docs/img/image-1.png)

- Use docker compose down to tear down (with -v to remove volumes).

    ```sh
    docker compose down -v
    ```