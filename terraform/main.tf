# terraform/main.tf

provider "google" {
  project     = var.GCP_PROJECT_ID
  region      = var.GCP_REGION
}

provider "google-beta" {
  project     = var.GCP_PROJECT_ID
  region      = var.GCP_REGION
}

resource "google_cloudfunctions_function" "webhook_function" {
  name        = "webhook-function"
  runtime     = "python39"
  entry_point = "main"
  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_source.name
  trigger_http = true
  environment_variables = {
    GOOGLE_DEFAULT_CALENDAR_ID = var.GOOGLE_DEFAULT_CALENDAR_ID
    HEADER_SOURCE_TO_PASS = var.HEADER_SOURCE_TO_PASS
    GCP_SERVICE_ACCOUNT_SECRET = var.GOOGLE_CREDENTIALS
  }
}

resource "google_storage_bucket" "function_source" {
  name     = "${var.GCP_PROJECT_ID}-function-source"
  location = var.GCP_REGION
}

resource "google_storage_bucket_object" "function_source" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_source.name
  source = "functions/*"
}

resource "google_api_gateway_api" "api_gateway" {
  provider = google-beta
  api_id   = "webhook-api"
}

resource "google_api_gateway_api_config" "api_config" {
  provider  = google-beta
  api       = google_api_gateway_api.api_gateway.api_id
  openapi_documents {
    document {
      path     = "${path.module}/openapi.yaml"
      contents = filebase64("${path.module}/openapi.yaml")
    }
  }
}

resource "google_api_gateway_gateway" "gateway" {
  provider  = google-beta
  api_config = google_api_gateway_api_config.api_config.id
  gateway_id = "webhook-gateway"
  region     = var.GCP_REGION
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

# Variable Declarations
variable "GOOGLE_CREDENTIALS" {
  description = "The GCP credentials JSON object"
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
