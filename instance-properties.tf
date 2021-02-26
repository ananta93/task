module "instance_properties" {
    account-id                      = var.account
    application-feature             = var.tags_application_feature
    application-id                  = var.tags_application_id
    application-role                = var.tags_application_role
    availability-data               = var.tags_availability_data
    compliance-code                 = var.tags_compliance_code
    cost-center                     = var.tags_cost_center
    customer-name                   = var.tags_customer_name
    data-encryption-type            = var.tags_data_encryption_type
    delete-date-time                = var.tags_delete_date_time
    environment                     = var.environment
    integrity-data                  = var.tags_integrity_data
    K8s                             = false
    map-migrated                    = var.tags_map_migrated
    opt-in-out                      = var.tags_opt_in_out
    project-name                    = var.project
    public-facing                   = var.tags_public_facing
    region                          = var.region
    resource-approving-manager      = var.tags_resource_approving_manager
    resource-owner-department       = var.tags_resource_owner_department
    resource-type                   = var.tags_resource_type
    resource-version                = var.tags_resource_version
    rotate-date-time                = var.tags_rotate_date_time
    sensitive-data                  = var.tags_sensitive_data
    sensitive-data-type             = var.tags_sensitive_data_type
    sensitivity-level               = var.tags_sensitivity_level
    silo                            = var.silo_name
    start-date-time                 = var.tags_start_date_time
    stop-date-time                  = var.tags_stop_date_time
    support-team                    = var.tags_support_team
    tenant-id                       = var.tags_tenant_id
}