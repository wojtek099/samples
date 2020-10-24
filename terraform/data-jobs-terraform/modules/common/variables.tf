variable app {
    type = string
    description = "application name used in resource names"
}

variable ENV {
    type = string
    description = "stage passed as ENV in job definitions"
}

variable ssp_to_s3_image {
    type = string
    description = "ECR repository name for SSP_To_S3 jobs"
}

variable data_utils_image {
    type = string
    description = "ECR repository name for Utils jobs"
}

variable sitedata_image {
    type = string
    description = "ECR repository name for Sitedata jobs"
}
