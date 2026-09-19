# Remote state backend (recommended). Create the storage account once, then run:
#   terraform init \
#     -backend-config="resource_group_name=rg-ai-dlc-tfstate" \
#     -backend-config="storage_account_name=staidlctfstate" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=ai-dlc.<env>.tfstate"
#
# terraform {
#   backend "azurerm" {}
# }
#
# For local evaluation, leave this file as-is and state stays in ./terraform.tfstate.
