#!/usr/bin/env python3
"""
Upload data ke Azure Blob Storage.

Usage:
    export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointProtocol=https;..."
    python scripts/upload_data.py
"""

import os
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import AzureError


def get_file_size_kb(file_path: Path) -> float:
    """Hitung ukuran file dalam KB."""
    return file_path.stat().st_size / 1024


def upload_file_to_blob(
    blob_client: BlobServiceClient,
    container_name: str,
    local_file_path: Path,
    blob_name: str,
) -> Dict[str, str | float]:
    """
    Upload file ke Blob Storage dan verifikasi.
    
    Args:
        blob_client: BlobServiceClient instance
        container_name: Target container name
        local_file_path: Path ke file lokal
        blob_name: Nama blob di storage
        
    Returns:
        Dict dengan metadata upload (name, size_kb, blob_url)
    """
    file_size_kb = get_file_size_kb(local_file_path)
    
    try:
        # Upload file
        blob_service_client = blob_client
        container_client = blob_service_client.get_container_client(container_name)
        
        with open(local_file_path, "rb") as data:
            container_client.upload_blob(blob_name, data, overwrite=True)
        
        # Verifikasi dengan download size check
        blob = blob_service_client.get_blob_client(container_name, blob_name)
        downloaded_size_kb = blob.get_blob_properties().size / 1024
        
        if abs(file_size_kb - downloaded_size_kb) > 0.1:
            raise ValueError(
                f"Upload verification failed: local {file_size_kb}KB != "
                f"remote {downloaded_size_kb}KB"
            )
        
        # Build blob URL
        account_name = blob_service_client.account_name
        blob_url = (
            f"https://{account_name}.blob.core.windows.net/"
            f"{container_name}/{blob_name}"
        )
        
        print(f"  Uploading {blob_name}... done ({file_size_kb:.1f} KB)")
        
        return {
            "name": blob_name,
            "size_kb": round(file_size_kb, 2),
            "blob_url": blob_url,
        }
    except AzureError as e:
        print(f"  ✗ Gagal upload {blob_name}: {e}")
        raise
    except Exception as e:
        print(f"  ✗ Error: {e}")
        raise


def main():
    """Main execution."""
    # Validasi connection string
    connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    if not connection_string:
        raise ValueError(
            "AZURE_STORAGE_CONNECTION_STRING env var tidak ditemukan. "
            "Set sebelum menjalankan script."
        )
    
    # Init Blob Storage client
    blob_client = BlobServiceClient.from_connection_string(connection_string)
    
    # Define files to upload
    project_root = Path(__file__).parent.parent
    upload_config = {
        "raw-data": [
            ("data/raw/demografi_kecamatan_jabar.csv", "demografi_kecamatan_jabar.csv"),
            ("data/raw/puskesmas_jabar.csv", "puskesmas_jabar.csv"),
            ("data/raw/sekolah_jabar.csv", "sekolah_jabar.csv"),
            ("data/raw/batas_kecamatan_jabar.geojson", "batas_kecamatan_jabar.geojson"),
        ],
        "processed-data": [
            ("data/processed/master_kecamatan.csv", "master_kecamatan.csv"),
            ("data/processed/top_50_gap_kecamatan.csv", "top_50_gap_kecamatan.csv"),
        ],
    }
    
    manifest = {
        "uploaded_at": datetime.utcnow().isoformat() + "Z",
        "files": [],
    }
    
    # Upload files
    print("🚀 Mulai upload data ke Azure Blob Storage...\n")
    
    for container_name, files in upload_config.items():
        print(f"📦 Container: {container_name}")
        for local_rel_path, blob_name in files:
            local_file_path = project_root / local_rel_path
            
            if not local_file_path.exists():
                print(f"  ✗ File tidak ditemukan: {local_rel_path}")
                continue
            
            upload_info = upload_file_to_blob(
                blob_client,
                container_name,
                local_file_path,
                blob_name,
            )
            manifest["files"].append(upload_info)
        
        print()
    
    # Simpan manifest
    manifest_path = project_root / "infra" / "upload_manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    
    print(f"✅ Upload selesai!")
    print(f"📄 Manifest tersimpan: {manifest_path}")
    print(f"📊 Total files: {len(manifest['files'])}")
    print(f"💾 Total size: {sum(f['size_kb'] for f in manifest['files']):.1f} KB")


if __name__ == "__main__":
    main()
