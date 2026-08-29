resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  lifecycle {
    prevent_destroy = true
    # Pre-existing org (SCP, trusted access). Do not strip those on apply.
    ignore_changes = [enabled_policy_types, aws_service_access_principals]
  }
}

resource "aws_organizations_organizational_unit" "inference" {
  name      = var.ou_name
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "a" {
  name                       = var.account_a_name
  email                      = var.email_a
  role_name                  = var.role_name
  parent_id                  = aws_organizations_organizational_unit.inference.id
  close_on_deletion          = false
  iam_user_access_to_billing = "ALLOW"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "b" {
  name                       = var.account_b_name
  email                      = var.email_b
  role_name                  = var.role_name
  parent_id                  = aws_organizations_organizational_unit.inference.id
  close_on_deletion          = false
  iam_user_access_to_billing = "ALLOW"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }
}
