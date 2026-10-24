# Rebuild the property lab through HCP Terraform

Prepared against infrastructure main `6848174c0219c3a4964a740df380b9892f1244b8`
and application `aws-deployment` `e1136e60a91a43061b5f77556b7bd676e61dc8d7`.

This is a staged migration. It does not authorize an immediate destruction of
the running lab. Review the HCP plan and run the isolated rehearsal first.

## What the change automates

| Part | Management |
|---|---|
| VPC, routes, application/DB SGs, EC2, RDS and EIP association | Disposable `module.lab[0]` |
| EIP allocation, ECR/images, application secret, S3 backups, IAM/OIDC, SNS/log group and HCP state | Retained foundation outside that module |
| Host installation | Compressed EC2 user data; Docker/Compose, AWS CLI, SSM, Caddy, CloudWatch Agent, deployment/backup/restore helpers |
| Runtime configuration | EC2 retrieves the existing raw-dotenv application secret and substitutes the actual new RDS endpoint |
| New DB password | Terraform ephemeral secret read into `password_wo`; neither the value nor the secret payload enters state |
| New empty SQL database | RDS creates `propertyapp`; guarded first startup initializes the empty schema and then disables synchronization |
| Restored SQL database | RDS restores the selected snapshot, resets its password to the retained application secret, and does not synchronize its schema |
| Deployment target | `/property-app/dev/deployment/instance-id` in Parameter Store; GitHub resolves it on each deployment/rollback |
| Upload recovery | Optional first-boot restore or a separate SSM restore into a new Docker volume; former volume retained |

AWS provider `6.69.1`, VPC module `5.19.0`, the existing AMI/key-pair inputs and
the existing Vite development runtime are retained. Terraform 1.11+ is required
for ephemeral/write-only arguments; validation uses 1.16.6.

## 1. Adopt the changes without rebuilding

Keep these defaults in HCP workspace `tecerotech/property-app-dev`:

```hcl
lab_enabled                           = true
rebuild_mode                          = "existing"
adopt_legacy_database_security_group   = true
database_deletion_protection          = true
rehearsal_enabled                     = false
deployment_existing_ec2_role_name      = "instanceRole"
```

Do not change the current network variables or AMI/key pair when adopting this
PR. The `moved` blocks relocate the original resources into the module without
replacing their AWS objects. Keep those blocks for older state versions.

The existing dedicated RDS group was external to Terraform. This change imports
both it and its PostgreSQL rule. Verify the inventory from your Mac:

```bash
aws ec2 describe-security-group-rules \
  --region ap-southeast-7 \
  --filters Name=group-id,Values=sg-0117f4f2a6cad457c \
  --query 'SecurityGroupRules[].{Id:SecurityGroupRuleId,Egress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,SourceGroup:ReferencedGroupInfo.GroupId,CIDR:CidrIpv4}'
```

The import assumes TCP 5432 from the application SG `sg-0392fcf35269983b6`.
If that does not match, stop and adjust the import to the observed inventory.
Do not replace the DB SG or open PostgreSQL publicly to make the import pass.
Existing unrelated SG rules are not claimed as audited or removed by this PR.

The first HCP plan should show the state moves, two imports, and three new
foundation objects: the target parameter, its GitHub read policy and the uploads
restore SSM document. Existing deployment/rollback document contents also
change to wait for first-boot completion on a new host. There should be **no EC2,
RDS, subnet or VPC replacement or destruction**. Review any unexpected drift.

HCP's apply role needs the additional permissions described below before the
apply. After applying the reviewed adoption plan, set
`adopt_legacy_database_security_group=false`. A subsequent plan should not
attempt imports again. The managed SG stays in state and is now recreated with
the lab instead of relying on its old physical ID.

The PR also removes a tracked JSON state export from the new branch and ignores
`terraform-state-backups/`. Earlier commits/clones still contain the export;
removal in this PR is not a Git-history secret audit or a history purge.

## 2. Apply role permissions once

Keep the existing HCP plan/apply federation, account/region guards, read policies
and service-specific permissions. Do not add static AWS keys.

- `docs/hcp-apply-rebuild-policy.json` is an additive **permission draft** for
  the existing `tecerotech-hcp-property-apply` role. Create it as a separate
  customer-managed policy and attach it; do not replace existing permissions.
- `docs/hcp-plan-secret-policy.json` grants the plan role a narrowly scoped
  ephemeral read of `property-app/dev/config` when planning a fresh/restore DB.
  Existing mode does not perform that read. Apply needs the same scoped read.
- Read access to a runtime secret is a real privilege expansion. Use trusted
  code/branches for HCP runs and do not expose this credential to untrusted fork
  speculative runs. Masking a value in plan output is not an access boundary.

The draft lists regional EC2 lifecycle operations with `Resource="*"` because
the new VPC, subnets, routes and instance IDs do not exist yet. It is
**region-scoped, not a production least-privilege policy**. IAM writes are
restricted to the two existing deployment roles; `PassRole` is restricted to
`instanceRole` and EC2. RDS/SSM permissions are scoped to the lab names. Review
it against your account before attaching, and tighten resources/tags if this
account contains other workloads. AWS authorization has not been exercised
from this development environment. A specific AccessDenied must be resolved
against that action/resource, not by granting AdministratorAccess.

The KMS grant permissions cover the retained original snapshot key. A snapshot
encrypted under another customer key requires that key and its key policy to
permit restore. Existing HCP CloudWatch/SNS permissions still cover the alarms
and dashboard, which are removed/recreated with the lab.

## 3. Configure the GitHub target once

Merge the companion application PR into `aws-deployment` after the target
parameter and its read permission exist. In the application repository's
**Settings → Secrets and variables → Actions → Variables**, add:

```text
EC2_TARGET_PARAMETER=/property-app/dev/deployment/instance-id
```

Keep `AUTO_DEPLOY_ENABLED=true`. Keep the existing `AWS_ROLE_ARN`, deployment
document and rollback document variables. The old `EC2_INSTANCE_ID` may remain
as a fallback, but once the parameter is configured a lookup failure or `offline`
value never falls back to that old ID.

## 4. Test a parallel fresh rebuild first

Copy an exact successful ECR URI from a GitHub Actions run into HCP's Terraform
variable `initial_image_uri`. It must have the existing immutable
`sha-<40 hex>-run-<id>-<attempt>` format. Do not use `latest` or delete that image.

The retained application secret must contain one nonempty, single-line
`DATABASE_PASSWORD` entry and the JWT settings. For the password use an unquoted
value, a single-quoted value without embedded single quotes, or a JSON-compatible
double-quoted string. No inline comment is allowed on the password entry.
Dollar signs are literal. Terraform and the host parser use those same rules;
the installed Compose file uses `env_file` `format: raw`.

Set only:

```hcl
rehearsal_enabled              = true
rehearsal_snapshot_identifier  = ""
rehearsal_uploads_s3_prefix     = ""
```

Keep the primary lab in `existing` mode with `lab_enabled=true`. Queue a plan.
The additions should be under `module.rehearsal[0]`; no primary resource should
be replaced. The rehearsal creates its own VPC, routes, public EC2 and private
RDS, while reusing the retained registry, secret, IAM profile and log group.
It does not change the primary EIP, production DNS or deployment parameter.

Apply the reviewed plan. Temporary EC2, RDS, storage and public IPv4 resources
incur charges while they exist. Terraform creating the instance does not prove
cloud-init has finished. Read the `rehearsal` output and check that new instance
through SSM or SSH:

```bash
sudo cloud-init status --wait
sudo test -f /opt/property-app-rebuild/completed
curl -I http://127.0.0.1:5173/
curl -I http://127.0.0.1:8080/
sudo systemctl is-active docker caddy amazon-cloudwatch-agent
```

These commands are for the **rehearsal host**. Use SSM Run Command from your Mac
if you prefer not to open an SSH session. Do not print `.env` or secret values.
Bootstrap failures are reported in `/var/log/cloud-init-output.log`; a nonempty database missing the core application tables deliberately stops and
needs inspection. Replacing EC2 alone reuses an initialized database with
synchronization disabled; it does not reinitialize existing tables.

Caddy is tested on loopback HTTP 8080, without requesting a production
certificate. The image still has its production Vite HMR domain; full HMR and
all business features are outside this infrastructure test. The backup timer is
installed but disabled in the rehearsal. CWAgent metrics use the new InstanceId;
the primary dashboard/alarms remain attached to the original instance.

After recording successful evidence, set `rehearsal_enabled=false` and review
the deletion plan. Only `module.rehearsal[0]` should disappear. Its temporary DB
skips a final snapshot; the primary DB keeps its protection and snapshot policy.

## 5. Test database and upload recovery

Create a new manual snapshot of the original DB while it is available:

```bash
rebuild_snapshot="property-app-rebuild-$(date -u +%Y%m%d%H%M%S)"
aws rds create-db-snapshot --region ap-southeast-7 \
  --db-instance-identifier property-app-db \
  --db-snapshot-identifier "$rebuild_snapshot"
aws rds wait db-snapshot-available --region ap-southeast-7 \
  --db-snapshot-identifier "$rebuild_snapshot"
```

Run the existing uploads backup and record its exact recent S3 prefix. RDS and
upload backups are separate captures, not an atomic database/filesystem backup.
The bucket lifecycle expires old backup objects, so preserve the chosen archive
for the entire teardown/rebuild period. Keep the KMS key available.

Set `rehearsal_enabled=true`, `rehearsal_snapshot_identifier` to the available
snapshot name, and optionally `rehearsal_uploads_s3_prefix` to the backup prefix.
If a rehearsal already exists, this may replace its temporary DB/EC2; review the
plan and keep all replacements inside the rehearsal module.

The pinned AWS provider restores PostgreSQL first and uses a subsequent modify
operation for `password_wo`. The restored copy receives the retained application's
current password; the original DB and secret are not changed. Schema synchronization
is disabled. Compare representative `property`/`unit` counts on the restored
endpoint and verify the restored test document. `SELECT 1` alone does not prove
data completeness.

## 6. Deliberately turn off the primary lab

Do this only after the rehearsal, snapshots and uploads have been verified.
Keep HCP state/workspace, backups, the application secret, required KMS key and
the selected ECR image. Inventory any manually created test DBs/ENIs in the VPC;
unmanaged attachments can block VPC deletion and are not deleted automatically.

First choose a new unused `final_snapshot_identifier` and set
`database_deletion_protection=false` while `lab_enabled=true`. Review and apply
that change. **Do not combine this with disabling the module in one apply:**
AWS must first receive the protection change.

Then set `lab_enabled=false` and review the next plan. It should remove only
the primary disposable module plus its alarms/dashboard. The target parameter
becomes `offline`, so deployment fails clearly instead of targeting a retired
instance. It must retain the EIP allocation, ECR/images, S3 objects, application
secret, IAM/OIDC, SNS/log group and HCP state. A final RDS snapshot is requested.
Apply only the reviewed destruction plan.

The original resource-level Terraform destruction guards on RDS, its subnet
group and the EIP **association** are intentionally replaced by this controlled
module lifecycle and AWS RDS deletion protection. The EIP allocation, backup
bucket, secret and OIDC provider retain their existing guards. Do not run a
blanket root `terraform destroy`.

Retained EIP, snapshots, backup storage, logs and other retained services can
continue to incur charges; this is not a zero-bill or complete-account deletion.

## 7. Recreate through HCP, then deploy through GitHub

For a clean database, after the old module has been removed:

```hcl
lab_enabled                         = true
rebuild_mode                        = "fresh"
adopt_legacy_database_security_group = false
database_deletion_protection        = true
initial_image_uri                   = "COPY_THE_EXACT_RETAINED_IMAGE_URI"
database_snapshot_identifier        = ""
uploads_restore_s3_prefix           = ""
```

For old database data, use `rebuild_mode="restore"` and set the exact snapshot
identifier. Supply an uploads prefix to restore files during first boot, or
leave it empty and perform the separate operation below. Do not switch a live
primary directly from `existing` to `fresh` as a shortcut; that requests
replacement rather than the reviewed teardown sequence above.

Review and apply the HCP plan. It creates a new VPC, SGs, EC2 and RDS, attaches
the retained EIP, and updates the target parameter. EC2 loads the actual RDS
endpoint automatically, installs the host runtime and starts the pinned image.
The retained EIP keeps the Cloudflare DNS record usable; if you deliberately
change the EIP allocation, update Cloudflare separately. Caddy certificate
issuance still requires working DNS and inbound 80/443.

After bootstrap succeeds, run **Build, test and deploy property app** in GitHub
Actions on `aws-deployment`. With the target parameter configured, no EC2 ID or
Compose image edit is needed. Keep automatic deployment enabled. A new host
starts without previous-image rollback history; later successful deployments
establish that history.

Fresh databases have no application users or tenant data. Register the owner
through the lab's normal UI. No default administrator password is added.

## 8. Restore uploads separately from your Mac

After the new primary host reports bootstrap completion, use the dedicated SSM
document. The normal GitHub image-publisher role is deliberately not granted
permission to invoke this restore document. Use your operator AWS profile:

```bash
new_instance_id=$(aws ssm get-parameter --region ap-southeast-7 \
  --name /property-app/dev/deployment/instance-id \
  --query Parameter.Value --output text)

aws ssm send-command --region ap-southeast-7 \
  --instance-ids "$new_instance_id" \
  --document-name property-app-dev-restore-uploads \
  --document-version '$LATEST' \
  --parameters '{"BackupPrefix":["s3://tecerotech-property-147997138960-backups/uploads/REPLACE_WITH_BACKUP_ID/"]}'
```

Inspect the resulting command with `get-command-invocation` before declaring
success. Restore validates the checksum and archive paths, extracts into a new
volume, and changes the active release only after the app is healthy. The former
volume and `uploads-before-restore.env` are retained. The backup job reads the
active volume from `release.env`; it does not keep archiving the old volume.
This changes which uploads are active; it is not a merge of files uploaded since
the snapshot. Coordinate the database and file restore points before cutover.

## Scope and validation

This implements rebuild mechanics for the existing lab, not production app
hardening: the Vite runtime, master SQL user, known business issues and explicitly
open SSH rule remain. No ALB, HA, direct-S3 storage or scheduled HTTPS availability
monitor is added. Package and agent URLs resolve vendor releases; the application
image and checked-in runtime assets are pinned, but OS provisioning is not a
bit-for-bit AMI build.

Local Python tests cover runtime secrets/archive handling and the companion
workflow target resolver. Bash, YAML and compressed user-data syntax/size are
checked. Terraform tests use mocked providers without AWS writes. A local
provider-cache checksum failure prevented completing provider-backed validation
in the editing environment; CI and the HCP speculative plan must pass before
adoption. AWS provisioning/restore, IAM/KMS authorization and application
behavior still require the rehearsal above; none was executed from this editor.

References: [Terraform ephemeral values](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral),
[AWS provider ephemeral secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/ephemeral-resources/secretsmanager_secret_version),
[AWS provider DB instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance),
[EC2 user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html).
