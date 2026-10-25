# Rebuild the property lab through HCP Terraform

**Updated:** 25 October 2026  
**Workspace:** `tecerotech/property-app-dev`  
**Region/account:** `ap-southeast-7` / `147997138960`

This is the current module-based operating guide. The one-time adoption is complete. Fresh provisioning, snapshot recovery, uploaded-file recovery, primary teardown and primary website recreation have been exercised. Keep `adopt_legacy_database_security_group=false`; do not repeat old-ID imports on a rebuilt environment.

| Completed exercise | Evidence |
|---|---|
| Fresh isolated EC2/RDS | Cloud-init done, Docker/Caddy/agent active, local HTTP 200, verified RDS TLS |
| Snapshot rehearsal | 1 property and 10 units on original/restored copies |
| Upload recovery | Synthetic file content `TeceroTech document recovery test` recovered; HTTP 200 afterward |
| Primary teardown | HCP Applied, encrypted final snapshot available, target parameter `offline` |
| Primary recreation, reported by 25 October 2026 | Website started after automated first-boot installation finished |

Snapshot `property-app-db-final-20261024100801` was verified available/encrypted during the earlier cycle. It is a dated checkpoint, not an automatically selected newest backup. Record each later final snapshot and uploads prefix.

An HCP apply creates resources; readiness is checked afterward. No dedicated one-click lifecycle workflow or guaranteed startup duration is claimed.

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

## 1. One-time adoption already completed

This section preserves the original migration and old physical IDs. Do not repeat it for fresh/restore operations. Keep `adopt_legacy_database_security_group=false` after adoption and retain moved blocks for older state versions.

The original adoption used these values in HCP workspace `tecerotech/property-app-dev`:

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

The migration removed a tracked JSON state export and added an ignore rule for
`terraform-state-backups/`. Earlier commits/clones still contain the export;
that removal was not a Git-history secret audit or a history purge.

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
  code/branches for HCP runs. HCP does not automatically run fork PR speculative
  plans; do not manually queue unreviewed configuration with secret access.
  Masking a value in plan output is not an access boundary.

The draft lists regional EC2 lifecycle operations with `Resource="*"` because
the new VPC, subnets, routes and instance IDs do not exist yet. It is
**region-scoped, not a production least-privilege policy**. IAM writes are
restricted to the two existing deployment roles; `PassRole` is restricted to
`instanceRole` and EC2. RDS/SSM permissions are scoped to the lab names. Review
it against your account before attaching, and tighten resources/tags if this
account contains other workloads. The roles were exercised in the reported HCP
fresh/restore runs; that does not establish least privilege for other workloads.
Resolve a specific AccessDenied against its action/resource.

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

Keep the primary lab's current mode and recovery inputs unchanged. The original
rehearsal used an adopted primary in `existing` mode; a restored primary stays in
`restore`. Queue a plan. Additions/replacements should be under
`module.rehearsal[0]`; no primary resource should be replaced. The rehearsal creates its own VPC, routes, public EC2 and private
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

Keep the HCP workspace/state, secret/value, selected ECR image, existing SSH key pair, snapshot KMS key, backup objects and EIP allocation. Inventory manual test DBs, custom SGs and ENIs; they can block VPC deletion.

### Back up current uploads

Before removing EC2, trigger `property-uploads-backup.service` through SSM on the current primary host. Confirm `Result=success` and `ExecMainStatus=0` and record the new S3 prefix from the job output. The job resolves the active uploads volume, including one selected by an earlier restore.

The RDS final snapshot covers database data; the uploads archive/checksum covers documents. They are separate captures at different times.

### Apply 1: save the next final-snapshot name and disable protection

Generate an unused name on the Mac:

```bash
final_snapshot_id="property-app-db-final-$(date -u +%Y%m%d%H%M%S)"
printf '%s\n' "$final_snapshot_id"
```

Generating the string does not change HCP. Copy the output into workspace **Terraform variable** `final_snapshot_identifier`, with **HCL unchecked**, save it and set:

| Variable | Preparation value | HCL |
|---|---|---|
| `lab_enabled` | `true` | Checked |
| `database_deletion_protection` | `false` | Checked |
| `final_snapshot_identifier` | The new unused name | Unchecked |
| `rehearsal_enabled` | `false` | Checked |

Keep the active `rebuild_mode` and source snapshot/image/uploads inputs unchanged. A restored primary stays in `restore`.

Queue a standard HCP plan/apply. Confirm the plan saves the new name and disables protection without replacing/destroying EC2 or RDS. Review unrelated changes before applying. Wait for **Applied**.

### Apply 2: disable the lab

Now set `lab_enabled=false` and keep `rehearsal_enabled=false`. Review/apply the next plan. It should remove the primary module, lab alarms/dashboard and EIP association. The EIP **allocation**, ECR/images, S3 backups, secret, IAM/OIDC, SNS/log group and HCP state remain.

The target becomes `offline`. Keep `AUTO_DEPLOY_ENABLED=true`; configured target lookup stops deployment/rollback without using an old ID.

Do not combine these applies. The final-snapshot name is a Terraform deletion setting, not an AWS property that can be read back. Once the module is removed from configuration, changing that root variable may leave deletion using the resource's prior saved value.

### Verify recovery and offline status

After HCP Applied, run in the same Mac terminal:

```bash
aws rds describe-db-snapshots \
  --region ap-southeast-7 \
  --db-snapshot-identifier "$final_snapshot_id" \
  --query 'DBSnapshots[0].{Snapshot:DBSnapshotIdentifier,Status:Status,Encrypted:Encrypted}' \
  --output table

aws ssm get-parameter \
  --region ap-southeast-7 \
  --name /property-app/dev/deployment/instance-id \
  --query 'Parameter.Value' \
  --output text
```

Expected: snapshot `available` and encrypted; target `offline`. In a new terminal, set `final_snapshot_id` to the actual recorded name first.

The disposable RDS/subnet group/EIP-association destruction guards were replaced by this lifecycle and AWS deletion protection; retained foundation guards remain. Use the controlled workflow rather than blanket root `terraform destroy`.

Retained public IPv4, snapshots, secrets, registry/storage and telemetry can still cost money. Current uploads objects expire after 30 days; preserve an independent archive/checksum for a longer shutdown.

### Duplicate final snapshot name

`DBSnapshotAlreadyExists` means deletion attempted to create a name already in use. Preserve the earlier backup.

| Variable | Purpose |
|---|---|
| `database_snapshot_identifier` | Existing available source used for restoration |
| `final_snapshot_identifier` | Different unused name for the next deletion |

If teardown is partially applied, re-enabling the module can recreate removed resources. A one-time operator recovery can finish only the remaining RDS deletion:

1. Wait until the failed HCP run finishes; keep `lab_enabled=false`.
2. Confirm the intended `property-app-db` still exists and deletion protection is off.
3. Generate a new name and request deletion with a final snapshot.
4. Wait until that snapshot is available/encrypted and RDS reports `DBInstanceNotFound` for the DB.
5. Queue a fresh HCP plan/apply with the lab disabled. Provider refresh recognizes the absent DB and remaining Terraform cleanup can finish.

Mac commands for step 3:

```bash
cleanup_final_snapshot="property-app-db-final-$(date -u +%Y%m%d%H%M%S)"
printf '%s\n' "$cleanup_final_snapshot"

aws rds delete-db-instance \
  --region ap-southeast-7 \
  --db-instance-identifier property-app-db \
  --no-skip-final-snapshot \
  --final-db-snapshot-identifier "$cleanup_final_snapshot" \
  --query 'DBInstance.{Database:DBInstanceIdentifier,Status:DBInstanceStatus}' \
  --output table
```

This is failed-teardown recovery, not the normal lifecycle. It preserves existing manual snapshots and requests a new final snapshot. Do not skip the snapshot, delete the old restore point or edit/remove state as the first workaround.

## 7. Recreate through HCP, then deploy through GitHub

Finish the previous teardown first. Keep the same workspace, remote state, trusted VCS connection and AWS dynamic-credential environment variables.

### Verify the selected recovery inputs

From the Mac, confirm the chosen snapshot is `available`, the exact ECR image exists, `uploads.tgz` and `uploads.tgz.sha256` exist at the chosen prefix, the secret has an `AWSCURRENT` version and is not pending deletion, and the snapshot key, EIP and SSH key pair remain.

Choose the recovery point you want. The configuration does not automatically select the newest snapshot, uploads archive or application image.

### Set workspace variables

Use **Terraform variable**, not Environment variable. Check **HCL** for booleans. For strings leave HCL unchecked and enter text without surrounding quotes.

| Variable | Saved-data rebuild | HCL |
|---|---|---|
| `lab_enabled` | `true` | Checked |
| `rebuild_mode` | `restore` | Unchecked |
| `adopt_legacy_database_security_group` | `false` | Checked |
| `rehearsal_enabled` | `false` | Checked |
| `database_deletion_protection` | `true` | Checked |
| `database_snapshot_identifier` | Exact available source snapshot | Unchecked |
| `initial_image_uri` | Exact retained immutable ECR URI | Unchecked |
| `uploads_restore_s3_prefix` | Available archive prefix, or blank for a later separate restore | Unchecked |
| `final_snapshot_identifier` | Different unused name for the next teardown | Unchecked |

For an empty database, choose `rebuild_mode=fresh`, an empty snapshot input and empty uploads prefix. It creates `propertyapp` and initializes only a completely empty schema, then disables synchronization. There are no restored users/tenant data and no added default admin password.

Keep existing role/profile, account/region, key-pair and required network inputs. These are retained prerequisites; the procedure does not reconstruct an empty AWS account.

### Apply and verify readiness

Queue a standard plan/apply. Expect new `module.lab[0]` resources, EIP association, lab alarms/dashboard and deployment-target/policy updates, with the foundation retained. Review before **Confirm & Apply**.

EC2 uses the new RDS endpoint, installs the runtime and starts `initial_image_uri`. An uploads prefix restores that archive during first boot. The retained EIP preserves the Cloudflare A record; Caddy still needs correct DNS and ingress 80/443.

**HCP Applied can precede website readiness.** Discover the current host on the Mac:

```bash
new_instance_id=$(aws ssm get-parameter \
  --region ap-southeast-7 \
  --name /property-app/dev/deployment/instance-id \
  --query 'Parameter.Value' \
  --output text)
printf '%s\n' "$new_instance_id"

aws ssm describe-instance-information \
  --region ap-southeast-7 \
  --filters "Key=InstanceIds,Values=$new_instance_id" \
  --query 'InstanceInformationList[].{Instance:InstanceId,Status:PingStatus}' \
  --output table
```

Wait for an `i-...` target and SSM **Online**. Then:

```bash
bootstrap_check_id=$(aws ssm send-command \
  --region ap-southeast-7 \
  --instance-ids "$new_instance_id" \
  --document-name AWS-RunShellScript \
  --parameters '{
    "commands": [
      "set -eu",
      "cloud-init status --wait --long",
      "test -f /opt/property-app-rebuild/completed",
      "echo BOOTSTRAP_COMPLETE",
      "systemctl is-active docker caddy amazon-cloudwatch-agent",
      "docker exec -i code-web-1 node --input-type=module < /opt/property-app-deploy/check-db.mjs",
      "curl -fsSI --max-time 10 http://127.0.0.1:5173/"
    ],
    "executionTimeout": ["1800"]
  }' \
  --query 'Command.CommandId' \
  --output text)

aws ssm get-command-invocation \
  --region ap-southeast-7 \
  --command-id "$bootstrap_check_id" \
  --instance-id "$new_instance_id" \
  --query '{Status:Status,Details:StatusDetails,Output:StandardOutputContent,Error:StandardErrorContent}' \
  --output json
```

Poll the same command while Pending/InProgress; immediate invocation-not-found responses can be temporary. Success requires cloud-init done, BOOTSTRAP_COMPLETE, active services, verified RDS TLS and local HTTP 200. Optional first-boot uploads restore also creates `/opt/property-app-rebuild/uploads-restored`. Verify representative DB records and an expected uploaded file, not only the login page.

Check public HTTPS from the Mac and sign in with a restored account:

```bash
curl -fsSI --max-time 30 https://property.tecerotech.com/
```

For failures, inspect cloud-init status/output, local port 5173, Caddy's journal and EIP association. Keep secrets out of shared output. An initially unavailable site during first boot alone does not justify another rebuild.

### Later application releases

Bootstrap already starts the selected image; a new GitHub build is not required to bring that saved version online. Publish newer code with **Build, test and deploy property app** on `aws-deployment` after readiness succeeds. Keep `AUTO_DEPLOY_ENABLED=true` and `EC2_TARGET_PARAMETER=/property-app/dev/deployment/instance-id`.

The SSM documents wait when a bootstrap-start marker exists; operators still verify completion before a workflow. No instance-ID or Compose-image edit is required. A fresh host has no previous-image rollback history until later successful releases establish it.

Keep `rebuild_mode=restore` on a restored lab. Do not reset it to `existing` or casually change live snapshot/image/uploads bootstrap inputs; these can request replacement. After the next completed teardown, choose the newly recorded snapshot/uploads prefix when those are the desired recovery points.

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

Infrastructure CI [passed on the merged rebuild configuration](https://github.com/SilvaRohit/myProperty-infra/actions/runs/40070890881). It runs Terraform formatting/validation, Python bootstrap tests, Bash syntax checks and plan-only lifecycle tests.

The lifecycle tests use real provider configuration with dummy credentials, credential/metadata validation disabled and the AMI read overridden. They are plan-only, do not create AWS resources and do not read the runtime secret. They do not use a mock provider for ephemeral resources. Runtime parser/archive tests and the application's target-resolver tests cover separate behavior.

Actual provisioning/recovery was exercised separately through HCP and operator checks: fresh rehearsal, snapshot restore, verified RDS TLS, representative counts (1 property, 10 units), synthetic file recovery, primary teardown with an encrypted available final snapshot, offline targeting and primary website recreation. The website was reported working by 25 October 2026 after first-boot setup. This supersedes the earlier editing-environment/provider-cache validation limitation.

An earlier rehearsal replacement hit an AWS provider 6.69.1 inconsistent-final-plan error involving `root_block_device.volume_id`. A fresh HCP plan/apply with unchanged intended inputs completed. This is an observed recovery, not a claim that the provider bug was fixed. Inspect partial state/results and a fresh plan before retrying; do not start with manual state edits.

This remains a portfolio lab: Vite development runtime, master SQL login, known business issues and intentionally open SSH remain. There is no ALB/HA conversion, production migration system, direct-S3 primary uploads or scheduled HTTPS monitor. OS packages/agents resolve vendor releases, so the selected app image and reviewed assets do not make the OS build bit-for-bit reproducible.

Readiness, representative data and one recovered file do not establish complete integrity, zero downtime, atomic DB/filesystem consistency or a measured recovery-time objective.

References: [Terraform ephemeral values](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral),
[AWS provider ephemeral secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/ephemeral-resources/secretsmanager_secret_version),
[AWS provider DB instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance),
[EC2 user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html).
