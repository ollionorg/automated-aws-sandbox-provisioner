
# AWS NUKE

Clean up AWS DevOps Sandbox environment periodically

<img src="README.png" alt="AWS Nuke" style="width: 40%;"/>

## Caution!

Be aware that *aws-nuke* is a very destructive tool, hence you have to be very
careful while using it. Otherwise you might delete production data.

**It is strongly advised to not run this application on any AWS account, where
you cannot afford to lose all resources.**

To reduce the blast radius of accidents, there are some safety precautions:

1. By default *aws-nuke* only lists all nukeable resources. You need to add
   `--no-dry-run` to actually delete resources.
2. *aws-nuke* asks you twice to confirm the deletion by entering the account
   alias. The first time is directly after the start and the second time after
   listing all nukeable resources.
3. To avoid just displaying a account ID, which might gladly be ignored by
   humans, it is required to actually set an [Account
   Alias](https://docs.aws.amazon.com/IAM/latest/UserGuide/console_account-alias.html)
   for your account. Otherwise *aws-nuke* will abort.
4. The Account Alias must not contain the string `prod`. This string is
   hardcoded and it is recommended to add it to every actual production account
   (eg `mycompany-production-ecr`).
5. The config file contains a blocklist field. If the Account ID of the account
   you want to nuke is part of this blocklist, *aws-nuke* will abort. It is
   recommended, that you add every production account to this blocklist.
6. To ensure you don't just ignore the blocklisting feature, the blocklist must
   contain at least one Account ID.
7. The config file contains account specific settings (eg. filters). The
   account you want to nuke must be explicitly listed there.
8. To ensure to not accidentally delete a random account, it is required to
   specify a config file. It is recommended to have only a single config file
   and add it to a central repository. This way the account blocklist is way
   easier to manage and keep up to date.

# AWS Nuke Exclude Resources

##
#### Filtering Resources for AWS DevOps Sandbox Account
The config file is available at https://github.com/cldcvr/cldcvr-xa-admin/tree/main/admin-aws-nuke-cc-accounts/nuke-config

##

It is possible to filter resources, this is important for not deleting the
current user for example or for resources like S3 Buckets which
have a globally shared namespace and might be hard to recreate.
Currently the filtering is based on the resource identifier. The identifier will be printed as the first step of aws-nuke (eg `i-01b489457a60298dd` for an EC2 instance).

```diff
 Note: Even with filters you should not run aws-nuke on any 
 AWS account, where you cannot afford to lose all resources. 
 It is easy to make mistakes in the filter configuration. Also, 
 since aws-nuke is in continous development, there is always a 
 possibility to introduce new bugs, no matter how careful we 
 review new code.
```
The filters are part of the account-specific configuration and are grouped by resource types.

##
Any resource whose resource identifier exactly matches any of the filters in the list will be skipped. These will be marked as "filtered by config" on the aws-nuke run.

#### Filter Properties
Some resources support filtering via properties. When a resource support these properties, they will be listed in the output like in this example:

```
global - IAMUserPolicyAttachment - 'admin -> AdministratorAccess' - [RoleName: "admin", PolicyArn: "arn:aws:iam::aws:policy/AdministratorAccess", PolicyName: "AdministratorAccess"] - would remove
```
To use properties, it is required to specify a object with properties and value instead of the plain string.

These types can be used to simplify the configuration. For example, it is possible to protect all access keys of a single user:

```
IAMUserAccessKey:
- property: UserName
  value: "admin"
```
#### Filter Types

There are also additional comparision types than an exact match:

* `exact` – The identifier must exactly match the given string. This is the default.
* `contains` – The identifier must contain the given string.
* `glob` – The identifier must match against the given [glob
  pattern](https://en.wikipedia.org/wiki/Glob_(programming)). This means the
  string might contains wildcards like `*` and `?`. Note that globbing is
  designed for file paths, so the wildcards do not match the directory
  separator (`/`). Details about the glob pattern can be found in the [library
  documentation](https://godoc.org/github.com/mb0/glob).
* `regex` – The identifier must match against the given regular expression.
  Details about the syntax can be found in the [library
  documentation](https://golang.org/pkg/regexp/syntax/).
* `dateOlderThan` - The identifier is parsed as a timestamp. After the offset is added to it (specified in the `value` field), the resulting timestamp must be AFTER the current
  time. Details on offset syntax can be found in
  the [library documentation](https://golang.org/pkg/time/#ParseDuration). Supported
  date formats are epoch time, `2006-01-02`, `2006/01/02`, `2006-01-02T15:04:05Z`,
  `2006-01-02T15:04:05.999999999Z07:00`, and `2006-01-02T15:04:05Z07:00`.

To use a non-default comparision type, it is required to specify an object with
`type` and `value` instead of the plain string.

These types can be used to simplify the configuration. For example, it is
possible to protect all access keys of a single user by using `glob`:

```yaml
IAMUserAccessKey:
- type: glob
  value: "admin -> *"
```


#### Using Them Together

It is also possible to use Filter Properties and Filter Types together. For
example to protect all Hosted Zone of a specific TLD:

```yaml
Route53HostedZone:
- property: Name
  type: glob
  value: "*.rebuy.cloud."
```

####  Inverting Filter Results

Any filter result can be inverted by using `invert: true`, for example:
```yaml
CloudFormationStack:
- property: Name
  value: "foo"
  invert: true
```

In this case *any* CloudFormationStack ***but*** the ones called "foo" will be
filtered. Be aware that *aws-nuke* internally takes every resource and applies
every filter on it. If a filter matches, it marks the node as filtered.


#### Filter Presets

It might be the case that some filters are the same across multiple accounts.
This especially could happen, if provisioning tools like Terraform are used or
if IAM resources follow the same pattern.

For this case *aws-nuke* supports presets of filters, that can applied on
multiple accounts. A configuration could look like this:

```yaml
---
regions:
- "global"
- "eu-west-1"

account-blocklist:
- 1234567890

accounts:
  555421337:
    presets:
    - "common"
  555133742:
    presets:
    - "common"
    - "terraform"
  555134237:
    presets:
    - "common"
    - "terraform"
    filters:
      EC2KeyPair:
      - "notebook"

presets:
  terraform:
    filters:
      S3Bucket:
      - type: glob
        value: "my-statebucket-*"
      DynamoDBTable:
      - "terraform-lock"
  common:
    filters:
      IAMRole:
      - "OrganizationAccountAccessRole"
```
