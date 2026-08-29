output "organization_id" {
  value = aws_organizations_organization.this.id
}

output "management_account_id" {
  value = aws_organizations_organization.this.master_account_id
}

output "ou_id" {
  value = aws_organizations_organizational_unit.inference.id
}

output "account_a_id" {
  value = aws_organizations_account.a.id
}

output "account_b_id" {
  value = aws_organizations_account.b.id
}
