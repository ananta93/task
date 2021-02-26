terraform {
required_version = "~> 0.12.24"
# remote backend
backend "s3" {
}
}
#account initalization
provider "aws" {
profile = var.silo_name
access_key = var.aws_access_key
secret_key = var.aws_secret_key
region = var.region
version = "~> 3.14"
assume_role {
role_arn = var.role
}
}
#provider "aws" {
# alias = "crosssilo"
# profile = "crosssilo-${var.environment}"
# access_key = var.aws_access_key
# secret_key = var.aws_secret_key
# region = var.region
#
# assume_role {
# role_arn = var.project == "aws-silo-chn-beta0006" ? "arn:awscn:
iam::${var.account_crosssilo}:role/SILO-${upper(var.environment)}-AUTOMATION"
: "arn:aws:iam::${var.account_crosssilo}:role/SILO-${upper(var.environment)}-
AUTOMATION"
# }
#}
data "aws_vpc" "this_vpc" {
state = "available"
tags = {
Service = "SILO"
}
}
data "aws_subnet_ids" "private_subnets" {
vpc_id = data.aws_vpc.this_vpc.id
tags = {
Service = "SILO"
Name = "*private*"
}
}
data "aws_subnet_ids" "public_subnets" {
vpc_id = data.aws_vpc.this_vpc.id
tags = {
Service = "SILO"
Name = "*public*"
}
}
data "aws_subnet" "private_subnet_list" {
for_each = data.aws_subnet_ids.private_subnets.ids
id = each.value
}
data "aws_subnet" "public_subnet_list" {
for_each = data.aws_subnet_ids.public_subnets.ids
id = each.value
}
data "aws_route53_zone" "xsilo_route53_zone" {
name = "xsilo-${var.environment}.gameloft.com"
private_zone = false
}
data "aws_iam_role" "rds_monitoring" {
name = "RDS-MONITORING-ROLE"
}
locals {
common_tags = "${map(
"account-id", "${var.account}",
"application-feature", "${var.tags_application_feature}",
"application-id", "${var.tags_application_id}",
"application-role", "${var.tags_application_role}",
"availability-data", "${var.tags_availability_data}",
"compliance-code", "${var.tags_compliance_code}",
"cost-center", "${var.tags_cost_center}",
"customer-name", "${var.tags_customer_name}",
"data-encryption-type", "${var.tags_data_encryption_type}",
"delete-date-time", "${var.tags_delete_date_time}",
"environment", "${var.environment}",
"integrity-data", "${var.tags_integrity_data}",
"K8s", "false",
"map-migrated", "${var.tags_map_migrated}",
"opt-in-out", "${var.tags_opt_in_out}",
"project-name", "${var.project}",
"public-facing", "${var.tags_public_facing}",
"region", "${var.region}",
"resource-approving-manager", "${var.tags_resource_approving_manager}",
"resource-owner-department", "${var.tags_resource_owner_department}",
"resource-type", "${var.tags_resource_type}",
"resource-version", "${var.tags_resource_version}",
"rotate-date-time", "${var.tags_rotate_date_time}",
"sensitive-data", "${var.tags_sensitive_data}",
"sensitive-data-type", "${var.tags_sensitive_data_type}",
"sensitivity-level", "${var.tags_sensitivity_level}",
"silo", "${var.silo_name}",
"start-date-time", "${var.tags_start_date_time}",
"stop-date-time", "${var.tags_stop_date_time}",
"support-team", "${var.tags_support_team}",
"tenant-id", "${var.tags_tenant_id}"
)}"
}
module "keypairs" {
source = "./modules/keypairs"
}
module "security" {
source = "./modules/security"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
public_subnets_ip = [for s in data.aws_subnet.public_subnet_list :
s.cidr_block]
}
module "anubiscontrol-store" {
source = "./modules/anubiscontrol-store"
silo_name = var.silo_name
environment = var.environment
region = var.region
tags = merge(local.common_tags, map(
"Name", "anubiscontrol-store",
"Role", "anubiscontrol-store",
"map-migrated", var.tags_map_migrated_anubiscontrol-store,
))
}
module "facts" {
source = "./modules/facts"
account = var.account
consul_dc = var.consul_dc
shared_silo_region = var.shared_silo_region
environment = var.environment
monitor_pass = var.monitor_pass
monitor_user = var.monitor_user
project = var.project
region = var.region
shared_silo_type = var.shared_silo_type
silo_name = var.silo_name
}
module "eve-dns-private-zone" {
source = "./modules/dns-private-zone"
route53_zone_name = "eve-${var.region}.${var.domain}"
vpc_id = data.aws_vpc.this_vpc.id
tags = merge(local.common_tags, map(
"Name", "eve-${var.region}.${var.domain}",
"Role", "dns-zone",
))
}
module "harbor" {
source = "./modules/harbor"
silo_name = var.silo_name
environment = var.environment
region = var.region
tags = local.common_tags
}
module "cores" {
source = "./modules/cores"
account = var.account
environment = var.environment
silo_name = var.silo_name
region = var.region
core_expiration = var.core_expiration
}
module "eve-db" {
source = "./modules/eve-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_anubis_gs_id = module.security.sg_anubis_gs_id
sg_wop_db_access_id = module.security.sg_wop_db_access_id
account_id = var.account
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
route53_zone_id = data.aws_route53_zone.xsilo_route53_zone.zone_id
route53_zone_name = data.aws_route53_zone.xsilo_route53_zone.name
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_eve
instance_storage = var.instance_storage_rds_eve
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_eve
apply_immediately = var.rds_apply_immediately
storage_type = var.storage_type_rds_eve
rds_iops_amount = var.rds_iops_amount_eve
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_primary_region = var.rds_primary_region_eve
rds_pg_parameters = var.rds_pg_eve_parameters
tags = merge(local.common_tags, map(
"Name", "eve-db",
"Role", "eve-db",
"map-migrated", var.tags_map_migrated_evedb,
))
}
module "sfs-db" {
source = "./modules/sfs-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_anubis_gs_id = module.security.sg_anubis_gs_id
sg_wop_db_access_id = module.security.sg_wop_db_access_id
account_id = var.account
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
route53_zone_id = data.aws_route53_zone.xsilo_route53_zone.zone_id
route53_zone_name = data.aws_route53_zone.xsilo_route53_zone.name
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_sfs
instance_storage = var.instance_storage_rds_sfs
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_sfs
apply_immediately = var.rds_apply_immediately
storage_type = var.storage_type_rds_sfs
rds_iops_amount = var.rds_iops_amount_sfs
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_primary_region = var.rds_primary_region_sfs
rds_replica_count = var.rds_replica_count_sfs
rds_pg_parameters = var.rds_pg_sfs_parameters
tags = merge(local.common_tags, map(
"Name", "sfs-db",
"Role", "sfs-db",
"map-migrated", var.tags_map_migrated_sfsdb,
))
}
module "fed-db" {
source = "./modules/fed-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_anubis_gs_id = module.security.sg_anubis_gs_id
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
instance_storage = var.instance_storage_rds_fed
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_type = var.storage_type_rds_fed
rds_iops_amount = var.rds_iops_amount_fed
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_fed_parameters
tags = merge(local.common_tags, map(
"Name", "fed-db",
"Role", "fed-db",
"map-migrated", var.tags_map_migrated_feddb,
))
}
module "anubis-db" {
source = "./modules/anubis-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_anubis_gs_id = module.security.sg_anubis_gs_id
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_anubis
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_anubis_parameters
tags = merge(local.common_tags, map(
"Name", "anubis-db",
"Role", "anubis-db",
"map-migrated", var.tags_map_migrated_anubisdb,
))
}
module "arion-db" {
source = "./modules/arion-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_arion
instance_storage = var.instance_storage_rds_arion
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_arion
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_arion_parameters
}
module "chronos-db" {
source = "./modules/chronos-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_chronos_parameters
tags = merge(local.common_tags, map(
"Name", "chronos-db",
"Role", "chronos-db",
"map-migrated", var.tags_map_migrated_chronosdb,
))
}
module "demeter-db" {
source = "./modules/demeter-db"
sg_ogi = module.security.sg_ogi
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_demeter
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
instance_storage = var.instance_storage_rds_demeter
max_allocated_storage = var.max_instance_storage_rds_demeter
apply_immediately = var.rds_apply_immediately
storage_type = var.storage_type_rds_demeter
rds_iops_amount = var.rds_iops_amount_demeter
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_demeter_parameters
tags = merge(local.common_tags, map(
"Name", "demeter-db",
"Role", "demeter-db",
"map-migrated", var.tags_map_migrated_demeterdb,
))
}
module "mercury-db" {
source = "./modules/mercury-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_mercury_parameters
tags = merge(local.common_tags, map(
"Name", "mercury-db",
"Role", "mercury-db",
"map-migrated", var.tags_map_migrated_mercurydb,
))
}
#module "fedstats" {
# source = "./modules/elk"
# vpc = data.aws_vpc.this_vpc.id
# private_subnet_id = data.aws_subnet_ids.private_subnets.ids
# public_subnet_id = data.aws_subnet_ids.public_subnets.ids
# silo_name = var.silo_name
# silo_env = var.environment
# region = var.region
# cloud_provider = var.cloud_provider
# elk_role = "SILOELKPROFILE"
# es_cluster = "fedstats"
# es_version = var.version_fedstats
# es_dnsname = "fedstats"
# environment = var.environment
# #ami = "${var.ami}"
# key_name = module.keypairs.ssh_key
# sg_ogi = module.security.sg_ogi
# sg_k8_db_access_id = module.security.sg_k8_db_access
# ldap_address = var.ldap_address
# ldap_group = var.ldap_group
#
# master_instance_type = var.instance_type_fedstats_master
# master-client_instance_type = var.instance_type_fedstats_master_client
# client_instance_type = var.instance_type_fedstats_client
# data_instance_type = var.instance_type_fedstats_data
#
# masters_count = var.num_instances_fedstats_master
# masters-clients_count = var.num_instances_fedstats_master_client
# clients_count = var.num_instances_fedstats_client
# datas_count = var.num_instances_fedstats_data
#
# master_heap_size = var.heap_size_fedstats_master
# master-client_heap_size = var.heap_size_fedstats_master_client
# client_heap_size = var.heap_size_fedstats_client
# data_heap_size = var.heap_size_fedstats_data
#
# bucket_name = "fedstats-${lower(var.project)}-${lower(var.region)}"
#}
module "fortuna-db" {
source = "./modules/fortuna-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_fortuna_parameters
tags = merge(local.common_tags, map(
"Name", "fortuna-db",
"Role", "fortuna-db",
"map-migrated", var.tags_map_migrated_fortunadb,
))
}
module "groot-db" {
source = "./modules/groot-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_prometheus_ts_id = module.security.sg_prometheus_ts
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_groot_parameters
tags = merge(local.common_tags, map(
"Name", "groot-db",
"Role", "groot-db",
"map-migrated", var.tags_map_migrated_grootdb,
))
}
module "hermes-db" {
source = "./modules/hermes-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_hermes
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_hermes
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_hermes_parameters
}
module "hestia-db" {
source = "./modules/hestia-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_hestia
instance_storage = var.instance_storage_rds_hestia
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_hestia_parameters
tags = merge(local.common_tags, map(
"Name", "hestia-db",
"Role", "hestia-db",
"map-migrated", var.tags_map_migrated_hestiadb,
))
}
module "iris-db" {
source = "./modules/iris-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_iris
instance_storage = var.instance_storage_rds_iris
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_iris_parameters
tags = merge(local.common_tags, map(
"Name", "iris-db",
"Role", "iris-db",
"map-migrated", var.tags_map_migrated_irisdb,
))
}
module "bastion" {
source = "./modules/bastion"
vpc_id = data.aws_vpc.this_vpc.id
region = var.region
private_subnet_id = data.aws_subnet_ids.private_subnets.ids
public_subnet_id = data.aws_subnet_ids.public_subnets.ids
instance_type_bastion = var.instance_type_bastion
disk_size_bastion = var.disk_size_bastion
asg_min_size = var.min_instances_bastion
asg_max_size = var.max_instances_bastion
sg_ogi = module.security.sg_ogi
silo_name = var.silo_name
ssh_key = module.keypairs.ssh_key
environment = var.environment
route53_zone_id = data.aws_route53_zone.xsilo_route53_zone.zone_id
route53_zone_name = data.aws_route53_zone.xsilo_route53_zone.name
}
module "notus-db" {
source = "./modules/notus-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_notus_parameters
tags = merge(local.common_tags, map(
"Name", "notus-db",
"Role", "notus-db",
"map-migrated", var.tags_map_migrated_notusdb,
))
}
module "olympus-db" {
source = "./modules/olympus-db"
sg_ogi = module.security.sg_ogi
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_olympus
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
instance_storage = var.instance_storage_rds_olympus
max_allocated_storage = var.max_instance_storage_rds_olympus
apply_immediately = var.rds_apply_immediately
storage_type = var.storage_type_rds_olympus
rds_iops_amount = var.rds_iops_amount_olympus
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_olympus_parameters
tags = merge(local.common_tags, map(
"Name", "olympus-db",
"Role", "olympus-db",
"map-migrated", var.tags_map_migrated_olympusdb,
))
}
module "pandora-db" {
source = "./modules/pandora-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_pandora_parameters
tags = merge(local.common_tags, map(
"Name", "pandora-db",
"Role", "pandora-db",
"map-migrated", var.tags_map_migrated_pandoradb,
))
}
module "ploutos-db" {
source = "./modules/ploutos-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_ploutos_parameters
}
#module "portal" {
# source = "./modules/portal"
# sg_portal_ws = module.security.sg_portal_ws
# region = var.region
# sg_ogi = module.security.sg_ogi
# sg_portal_lb = module.security.sg_portal_lb
# sg_logorama_es = module.elk.elasticsearch_security_group
# silo_name = var.silo_name
# ami = var.ami
# public_subnet_id = data.aws_subnet_ids.public_subnets.ids
# private_subnet_id = data.aws_subnet_ids.private_subnets.ids
# ssh_key = module.keypairs.ssh_key
# environment = var.environment
# instance_type = var.instance_type_portal
# asg_min_size = var.min_instances_portal
# asg_max_size = var.max_instances_portal
# vpc_id = data.aws_vpc.this_vpc.id
#}
module "datastorage-db" {
source = "./modules/datastorage-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_prometheus_ts_id = module.security.sg_prometheus_ts
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_postgres_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_datastorage_parameters
tags = merge(local.common_tags, map(
"Name", "datastorage-db",
"Role", "datastorage-db",
"map-migrated", var.tags_map_migrated_datastoragedb,
))
}
module "zeus-db" {
source = "./modules/zeus-db"
sg_k8_db_access_id = module.security.sg_k8_db_access
sg_wop_db_access_id = module.security.sg_wop_db_access_id
vpc_id = data.aws_vpc.this_vpc.id
sg_ogi = module.security.sg_ogi
subnet_ids = data.aws_subnet_ids.private_subnets.ids
silo_name = var.silo_name
region = var.region
environment = var.environment
monitoring_role_arn = data.aws_iam_role.rds_monitoring.arn
dbadmin_user = var.dbadmin_user
dbadmin_pass = var.dbadmin_pass
instance_type = var.instance_type_rds_fed
instance_storage = var.instance_storage_rds_fed
backup_retention_period = var.rds_backup_retention_period
engine_version = var.rds_mysql_engine_version
max_allocated_storage = var.max_instance_storage_rds_fed
apply_immediately = var.rds_apply_immediately
storage_encrypted = var.rds_storage_encrypted
deletion_protection = var.rds_deletion_protection
rds_backup_window = var.rds_backup_window
rds_pg_parameters = var.rds_pg_zeus_parameters
tags = merge(local.common_tags, map(
"Name", "zeus-db",
"Role", "zeus-db",
"map-migrated", var.tags_map_migrated_zeusdb,
))
}
module "dlm-janus-cb" {
source = "./modules/dlm"
cluster_name = "janus-cb"
tags = merge(local.common_tags, map(
"Name", "janus-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_janus_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-profile-cb" {
source = "./modules/dlm"
cluster_name = "profile-cb"
tags = merge(local.common_tags, map(
"Name", "profile-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_profile_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-player-cb" {
source = "./modules/dlm"
cluster_name = "player-cb"
tags = merge(local.common_tags, map(
"Name", "player-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_player_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-osiris-cb" {
source = "./modules/dlm"
cluster_name = "osiris-cb"
tags = merge(local.common_tags, map(
"Name", "osiris-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_osiris_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-hermes-cb" {
source = "./modules/dlm"
cluster_name = "hermes-cb"
tags = merge(local.common_tags, map(
"Name", "hermes-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_hermes_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-hapi-cb" {
source = "./modules/dlm"
cluster_name = "hapi-cb"
tags = merge(local.common_tags, map(
"Name", "hapi-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_hapi_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-mercury-cb" {
source = "./modules/dlm"
cluster_name = "mercury-cb"
tags = merge(local.common_tags, map(
"Name", "mercury-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_mercury_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-anubis-cb" {
source = "./modules/dlm"
cluster_name = "anubis-cb"
tags = merge(local.common_tags, map(
"Name", "anubis-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_anubis_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-fed-cb" {
source = "./modules/dlm"
cluster_name = "fed-cb"
tags = merge(local.common_tags, map(
"Name", "fed-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_fed_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "dlm-seshat-cb" {
source = "./modules/dlm"
cluster_name = "seshat-cb"
tags = merge(local.common_tags, map(
"Name", "seshat-cb",
"Role", "snapshot",
"map-migrated", var.tags_map_migrated_seshat_cb,
))
retain_rule_count = var.retain_rule_count_cb_snapshot
}
module "anubis-cb" {
source = "./modules/anubis-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
public_subnets_ip = [for s in data.aws_subnet.public_subnet_list :
s.cidr_block]
}
module "fed-cb" {
source = "./modules/fed-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
public_subnets_ip = [for s in data.aws_subnet.public_subnet_list :
s.cidr_block]
sg_k8_id = module.security.sg_k8
}
module "hapi-cb" {
source = "./modules/hapi-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "hermes-cb" {
source = "./modules/hermes-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "janus-cb" {
source = "./modules/janus-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "mercury-cb" {
source = "./modules/mercury-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "osiris-cb" {
source = "./modules/osiris-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "player-cb" {
source = "./modules/player-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "profile-cb" {
source = "./modules/profile-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "seshat-cb" {
source = "./modules/seshat-cb"
vpc_id = data.aws_vpc.this_vpc.id
private_subnets_ip = [for s in data.aws_subnet.private_subnet_list :
s.cidr_block]
}
module "consul-ts" {
source = "./modules/consul-ts"
consul_dc = var.consul_dc
consul_wan = var.consul_wan
dns_zone = var.dns_zone
environment = var.environment
# TODO: what should be the value for iam_profile ?
iam_profile = var.iam_profile_consul
instance_type = var.instance_type_consul
min_instances = var.min_instances_consul
desired_instances = var.desired_instances_consul
max_instances = var.max_instances_consul
private_subnet_ids = data.aws_subnet_ids.private_subnets.ids
region = var.region
ami = var.region == "cn-northwest-1" ? var.ami_buster :
var.ami_stretch
sg_consul_ts = module.security.sg_consul_ts
sg_ogi = module.security.sg_ogi
#sg_consul_lb = module.security.sg_consul_lb
silo_name = var.silo_name
ssh_key = module.keypairs.ssh_key
tags = merge(local.common_tags, map(
"Role", "consul-ts"
))
vpc_id = data.aws_vpc.this_vpc.id
}
module "prometheus-ts" {
source = "./modules/prometheus-ts"
environment = var.environment
region = var.region
silo_name = var.silo_name
tags = local.common_tags
}
output "anubis-db" {
value = module.anubis-db.dbhost
sensitive = true
}
output "arion-db" {
value = module.arion-db.dbhost
sensitive = true
}
output "chronos-db" {
value = module.chronos-db.dbhost
sensitive = true
}
output "demeter-db" {
value = module.demeter-db.dbhost
sensitive = true
}
output "eve-db" {
value = module.eve-db.dbhost
sensitive = true
}
output "fed-db" {
value = module.fed-db.dbhost
sensitive = true
}
output "fortuna-db" {
value = module.fortuna-db.dbhost
sensitive = true
}
output "groot-db" {
value = module.groot-db.dbhost
sensitive = true
}
output "hermes-db" {
value = module.hermes-db.dbhost
sensitive = true
}
output "hestia-db" {
value = module.hestia-db.dbhost
sensitive = true
}
output "iris-db" {
value = module.iris-db.dbhost
sensitive = true
}
output "mercury-db" {
value = module.mercury-db.dbhost
sensitive = true
}
output "notus-db" {
value = module.notus-db.dbhost
sensitive = true
}
output "olympus-db" {
value = module.olympus-db.dbhost
sensitive = true
}
output "pandora-db" {
value = module.pandora-db.dbhost
sensitive = true
}
output "ploutos-db" {
value = module.ploutos-db.dbhost
sensitive = true
}
output "datastorage-db" {
value = module.datastorage-db.dbhost
sensitive = true
}
output "zeus-db" {
value = module.zeus-db.dbhost
sensitive = true
}
output "public_subnet_ids" {
value = data.aws_subnet_ids.public_subnets.ids
sensitive = true
}
output "tags_account_id" {
value = var.account
sensitive = true
}
output "tags_application_id" {
value = var.tags_application_id
sensitive = true
}
output "tags_application_feature" {
value = var.tags_application_feature
sensitive = true
}
output "tags_application_role" {
value = var.tags_application_role
sensitive = true
}
output "tags_availability_data" {
value = var.tags_availability_data
sensitive = true
}
output "tags_compliance_code" {
value = var.tags_compliance_code
sensitive = true
}
output "tags_cost_center" {
value = var.tags_cost_center
sensitive = true
}
output "tags_customer_name" {
value = var.tags_customer_name
sensitive = true
}
output "tags_data_encryption_type" {
value = var.tags_data_encryption_type
sensitive = true
}
output "tags_delete_date_time" {
value = var.tags_delete_date_time
sensitive = true
}
output "tags_integrity_data" {
value = var.tags_integrity_data
sensitive = true
}
output "tags_map_migrated" {
value = var.tags_map_migrated
sensitive = true
}
output "tags_map_migrated_anubisgs" {
value = var.tags_map_migrated_anubisgs
sensitive = true
}
output "tags_map_migrated_demeterdb" {
value = var.tags_map_migrated_demeterdb
sensitive = true
}
output "tags_map_migrated_feddb" {
value = var.tags_map_migrated_feddb
sensitive = true
}
output "tags_map_migrated_olympusdb" {
value = var.tags_map_migrated_olympusdb
sensitive = true
}
output "tags_opt_in_out" {
value = var.tags_opt_in_out
sensitive = true
}
output "tags_project_name" {
value = var.tags_project_name
sensitive = true
}
output "tags_public_facing" {
value = var.tags_public_facing
sensitive = true
}
output "tags_resource_approving_manager" {
value = var.tags_resource_approving_manager
sensitive = true
}
output "tags_resource_owner_department" {
value = var.tags_resource_owner_department
sensitive = true
}
output "tags_resource_type" {
value = var.tags_resource_type
sensitive = true
}
output "tags_resource_version" {
value = var.tags_resource_version
sensitive = true
}
output "tags_rotate_date_time" {
value = var.tags_rotate_date_time
sensitive = true
}
output "tags_sensitive_data" {
value = var.tags_sensitive_data
sensitive = true
}
output "tags_sensitive_data_type" {
value = var.tags_sensitive_data_type
sensitive = true
}
output "tags_sensitivity_level" {
value = var.tags_sensitivity_level
sensitive = true
}
output "tags_start_date_time" {
value = var.tags_start_date_time
sensitive = true
}
output "tags_stop_date_time" {
value = var.tags_stop_date_time
sensitive = true
}
output "tags_support_team" {
value = var.tags_support_team
sensitive = true
}
output "tags_tenant_id" {
value = var.tags_tenant_id
sensitive = true
}