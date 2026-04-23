"""
Azure Function: GET /api/kecamatan

Endpoint untuk retrieve data kecamatan dari Blob Storage dengan opsi sorting dan limiting.

Query Parameters:
  - sort: gap_score_composite | gap_demografi | gap_kesehatan (default: gap_score_composite)
  - limit: int (default: 50)
  - order: asc | desc (default: desc)

Returns:
  JSON array dari kecamatan sorted sesuai parameter dengan CORS header
"""

import os
import json
import io
import logging
from typing import Dict, Any

import azure.functions as func
import pandas as pd
from azure.storage.blob import BlobServiceClient
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential


logger = logging.getLogger(__name__)

# Cache untuk data (refresh per request untuk sekarang)
_blob_client = None
_secret_client = None


def get_blob_client():
    """Lazy-load blob client dari Key Vault credentials."""
    global _blob_client
    
    if _blob_client is None:
        try:
            # Ambil connection string dari Key Vault
            key_vault_url = os.environ.get("KEY_VAULT_URL")
            if not key_vault_url:
                raise ValueError("KEY_VAULT_URL environment variable tidak ditemukan")
            
            credential = DefaultAzureCredential()
            secret_client = SecretClient(vault_url=key_vault_url, credential=credential)
            
            # Ambil storage connection string dari Key Vault
            connection_string = secret_client.get_secret("StorageConnectionString").value
            _blob_client = BlobServiceClient.from_connection_string(connection_string)
            
            logger.info("✅ Blob client initialized dari Key Vault")
        except Exception as e:
            logger.error(f"❌ Error initializing blob client: {e}")
            raise
    
    return _blob_client


def load_master_data() -> pd.DataFrame:
    """Load master_kecamatan.csv dari Blob Storage ke memory."""
    try:
        blob_client = get_blob_client()
        blob = blob_client.get_blob_client("processed-data", "master_kecamatan.csv")
        data = blob.download_blob().readall()
        df = pd.read_csv(io.BytesIO(data))
        logger.info(f"✅ Loaded {len(df)} kecamatan dari blob storage")
        return df
    except Exception as e:
        logger.error(f"❌ Error loading master data: {e}")
        raise


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP trigger untuk GET /api/kecamatan
    """
    try:
        # Parse query parameters
        sort_column = req.params.get("sort", "gap_score_composite")
        limit = int(req.params.get("limit", "50"))
        order = req.params.get("order", "desc").lower()
        
        # Validasi
        valid_sort_cols = [
            "gap_score_composite",
            "gap_demografi",
            "gap_kesehatan",
            "kecamatan_std",
        ]
        if sort_column not in valid_sort_cols:
            return func.HttpResponse(
                json.dumps({
                    "error": f"Invalid sort column. Valid: {', '.join(valid_sort_cols)}"
                }),
                status_code=400,
                headers={"Access-Control-Allow-Origin": "*"},
            )
        
        ascending = order == "asc"
        
        # Load data
        df = load_master_data()
        
        # Sort dan limit
        df_sorted = df.sort_values(
            by=sort_column,
            ascending=ascending,
            na_position="last",
        ).head(limit)
        
        # Convert ke JSON-friendly format
        result = df_sorted.to_dict(orient="records")
        
        # Return dengan CORS header
        return func.HttpResponse(
            json.dumps(result, indent=2),
            status_code=200,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json",
            },
        )
    
    except Exception as e:
        logger.error(f"❌ Error processing request: {e}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Access-Control-Allow-Origin": "*"},
        )
