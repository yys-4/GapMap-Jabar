# GapMap Jabar

A data-driven infrastructure and facility distribution analysis platform targeting the West Java region. The system ingests, processes, and visualizes geospatial distribution data of public facilities (markets, schools, health centers) to identify gaps and support strategic decision-making.

## Tech Stack

*   **Backend / Serverless**: Azure Functions (Python)
*   **Infrastructure as Code (IaC)**: Azure Bicep
*   **Data Processing & ETL**: Python (Pandas), Jupyter Notebooks
*   **Frontend / Visualization Design**: Next.js, Tailwind CSS, Azure Maps, Recharts (Specs & Wireframes)
*   **Data Versioning**: Git LFS (Large File Storage)

## Key Features

*   **Geospatial Data Ingestion**: Automated pipelines for parsing shapefiles (`.shp`), GeoJSON, and CSV data.
*   **Facility Gap Analysis**: Calculation of regional facility distribution density compared to demographic metrics.
*   **Serverless APIs**: Scalable data retrieval endpoints deployed via Azure Functions.
*   **Infrastructure Automation**: Automated provisioning of Azure resources using Bicep templates.
*   **Interactive Visualizations**: Wireframed dashboard specifications mapping gap indicators using Azure Maps.

## Prerequisites

Ensure the following tools are installed before setting up the project locally:

*   **Python**: Version `3.9` or higher
*   **Node.js**: Version `18.x` or higher (for Next.js frontend setup)
*   **Azure CLI**: For infrastructure deployment and authentication
*   **Azure Functions Core Tools**: `v4` for running the backend locally
*   **Git LFS**: Essential for handling large geospatial datasets

## Setup & Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/yys-4/GapMap-Jabar.git
    cd GapMap-Jabar
    git lfs pull
    ```

2.  **Environment Configuration**
    Copy the example environment files to your local environment.
    ```bash
    cp .env.example .env
    # Update .env with necessary keys and Azure credentials
    ```

3.  **Backend Initialization (Azure Functions)**
    Navigate to the `functions` directory and install Python dependencies.
    ```bash
    cd functions
    python -m venv .venv
    source .venv/bin/activate  # On Windows: .venv\Scripts\activate
    pip install -r requirements.txt
    func start
    ```

4.  **Data Processing Execution**
    Navigate to the `scripts` directory to run the primary ETL jobs.
    ```bash
    cd scripts
    python -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    python process_data.py
    ```

## Architecture

The project is structured to enforce a strict separation between data, serverless APIs, infrastructure, and visualization logic.

*   `/data/` - Contains `/raw`, `/processed`, and large datasets (versioned via LFS).
*   `/functions/` - Serverless backend API implementation using Azure Functions.
*   `/infra/` - Contains Azure Bicep templates (`main.bicep`) for automated deployments.
*   `/notebooks/` - Jupyter notebooks for Exploratory Data Analysis (EDA).
*   `/scripts/` - Python scripts for data auditing, transformation, and blob uploads.
*   `/specs/` & `/wireframe/` - UI/UX specifications, Next.js architecture logic, and HTML wireframes.
*   `/reports/` - Generated data quality and infrastructure validation reports.
