#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type    = string
}

variable "location" {
  type    = string
  default = "australiaeast"
}

variable "managed_identity"{
    type = string
}

variable "storage_account_name" {
    type    = string
}

variable "storage_queue_name" {
    type    = string
}

variable "virtual_network_subnet_ids"{
    type = list
}
