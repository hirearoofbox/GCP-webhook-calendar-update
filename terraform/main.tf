# terraform/main.tf
provider "google" {
  project     = var.GCP_PROJECT_ID
  region      = var.GCP_REGION
  credentials = file(var.GCP_SA_KEY)
}

provider "google-beta" {
  project     = var.GCP_PROJECT_ID
  region      = var.GCP_REGION
  credentials = file(var.GCP_SA_KEY)
}

resource "google_service_account" "calendar_sa" {
  account_id   = "calendar-sa"
  display_name = "Calendar Service Account"
}

resource "google_secret_manager_secret" "calendar_sa_secret" {
  secret_id = "GCP_GOOGLE_CALENDAR_SERVICE_ACCOUNT_SECRET"
  replication {
    automatic = {}
  }
}

resource "google_secret_manager_secret_version" "calendar_sa_secret_version" {
  secret      = google_secret_manager_secret.calendar_sa_secret.id
  secret_data = google_service_account_key.calendar_sa_key.private_key
}

resource "google_service_account_key" "calendar_sa_key" {
  service_account_id = google_service_account.calendar_sa.name
}

resource "google_cloudfunctions_function" "webhook_function" {
  name        = "webhook-function"
  runtime     = "python39"
  entry_point = "main"
  source_archive_bucket = google_storage_bucket.function_source.bucket
  source_archive_object = google_storage_bucket_object.function_source.name
  trigger_http = true
  environment_variables = {
    GOOGLE_DEFAULT_CALENDAR_ID = var.GOOGLE_DEFAULT_CALENDAR_ID
    HEADER_SOURCE_TO_PASS = var.HEADER_SOURCE_TO_PASS
    GCP_SERVICE_ACCOUNT_SECRET = google_secret_manager_secret_version.calendar_sa_secret_version.secret_data
  }
}

resource "google_storage_bucket" "function_source" {
  name     = "${var.GCP_PROJECT_ID}-function-source"
  location = var.GCP_REGION
}

resource "google_storage_bucket_object" "function_source" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_source.name
  source = "functions/function-source.zip"
}

resource "google_api_gateway_api" "api_gateway" {
  provider = google-beta
  api_id   = "webhook-api"
}

resource "google_api_gateway_api_config" "api_config" {
  provider  = google-beta
  api       = google_api_gateway_api.api_gateway.api_id
  location  = var.GCP_REGION
  openapi_documents {
    document {
      path     = "terraform/openapi.yaml"
      contents = file("terraform/openapi.yaml")
    }
  }
}

resource "google_api_gateway_gateway" "gateway" {
  provider  = google-beta
  api       = google_api_gateway_api.api_gateway.api_id
  location  = var.GCP_REGION
  gateway_id = "webhook-gateway"
}

# Variable Declarations
variable "GCP_PROJECT_ID" {
  description = "The GCP project ID"
  type        = string
}

variable "GCP_REGION" {
  description = "The GCP region"
  type        = string
}

variable "GCP_SA_KEY" {
  description = "The path to the GCP service account key file"
  type        = string
}

variable "GOOGLE_DEFAULT_CALENDAR_ID" {
  description = "The default Google Calendar ID"
  type        = string
}

variable "HEADER_SOURCE_TO_PASS" {
  description = "The header source to pass"
  type        = string
}