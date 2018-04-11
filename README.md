[![Build Status](https://travis-ci.org/simplygenius/atmos.svg?branch=master)](https://travis-ci.org/simplygenius/atmos)
[![Coverage Status](https://coveralls.io/repos/github/simplygenius/atmos/badge.svg?branch=master)](https://coveralls.io/github/simplygenius/atmos?branch=master)

# Atmos

Atmos(phere) - Breathe easier with terraform

Atmos provides a layer of organization on top of terraform for creating cloud system architectures with Amazon Web Services.  It handles the plumbing so you can focus on your application.  The core atmos runtime is free and open-source, with a business friendly license (Apache).  It provides some basic recipes to help get you going with a service oriented architecture implemented with AWS Elastic Container Services.  For more in-depth recipes, please check out the Atmos Pro offering.

## Goals

* The whole is greater than the sum of its parts.  Assist in creating a cloud infrastructure _system_ rather than just discrete infrastructure components.  Learning aws and terraform is a lot to bite off when getting started.  It's much easier to start with a working system ,and learn incrementally as you go by making changes to it.

* The command line is king.  Using a CLI to iterate on and manage core infrastructure has always been more effective for me, so I aim to make things as convenient and usable as possible from there.

* No lock-in.  Since atmos just provides you convenience on top of using terraform, and the templates for defining your infrastructure are 99% in terraform, its possible to migrate away (albeit giving up all the convenience atmos provides) if your goals ever diverge from those of atmos.

* Your infrastructure is an important product.  It should have its own repo and be tracked under configuration management, not just clickety-click-clicked on in a UI and promptly forgotten what it is you actually did to get there.  The only guarantee you have, is that things are going to need to change, and you'll be much better off with a system that allows you to iterate easily.  Atmos gets you started with minimal up-front knowledge, but provides a path for your infrastructure to evolve.

## Features

* Manages AWS authentication, including MFA
* Integrated MFA token generation for convenience.  This is technically not as secure since a laptop compromise exposes the key (vs a separate device for MFA).  Plans to add yubikey support to get both convenience and security.
* Integrated secret management, with per-secret access permissions to minimize exposure footprint if something gets compromised
* Manages multiple independent environments (e.g. dev, staging, production), allowing them to be as similar or divergent as desired.
* Automates separation of environments across AWS accounts
* Secure by default
* Common recipe patterns to simplify maximal use of higher level AWS components. 
* Sets up dns for your domain along with a wildcard certificate for hassle free ssl on your services
* Free and open source core with a business friendly license (Apache)


## Installation

First install the dependencies:
 * [Install docker](https://www.docker.com/community-edition) for deploying containers
 * Install terraform (optional if running atmos as a docker image): e.g. `brew install terraform` on OS X 
 * Install the aws cli (optional, useful for managing aws credentials): e.g. `brew install aws` on OS X

Then install atmos:

To install as a gem:
 * gem install simplygenius-atmos
 * verify: `atmos --help`

To install/run as a docker image:
 * curl -sL https://raw.githubusercontent.com/simplygenius/atmos/master/exe/atmos-docker > /usr/local/bin/atmos
 * chmod +x /usr/local/bin/atmos
 * verify: `atmos --help`

Note that when running as a docker image, UI notifications get forced inline as text output as atmos no longer has access to your current OS.

## Usage

Usage is available via the command line: `atmos --help`
The [terraform docs](https://www.terraform.io/docs/index.html) are excellent.

## Quickstart

See the [screencast](https://simplygenius.wistia.com/projects/h595iz9tbq) for a detailed walkthrough (~1 hour) of the quickstart.

[Create an AWS account](https://portal.aws.amazon.com/billing/signup)
Setup root account access keys, make note of the numeric account id

It'll make your life easier dealing with multiple keys if you make use of the AWS shared credential store.  Save the access keys there with this command (picking your own name for the profile):

```
aws configure --profile <root_profile_name>
```

Create a new atmos project.  This should only contain files defining your infrastructure, and not your application:

```
mkdir my-ops-repo
cd my-ops-repo
atmos new
```

Initialize the atmos project for aws.  When prompted, input a short name for your organization and the AWS account id to use for the ops environment:

```
atmos generate --force aws/scaffold
```

The `--force` is optional and just prevents the prompt for every change the generator is making to files in your repo.

Optionally bring up config/atmos.yml in your editor and make any other desired changes.

Bootstrap your cloud provider to work with atmos.  Answer `yes` when prompted to apply the changes.

```
AWS_PROFILE=<root_profile_name> atmos -e ops bootstrap
AWS_PROFILE=<root_profile_name> atmos -e ops apply
```

Setup a non-root user - using your email as the IAM username is convenient for email notifications in the future (e.g. per-user security validations like auto-expiry of access keys)

```
AWS_PROFILE=<root_profile_name> atmos user create -l -k -g all-users -g ops-admin your@email.address
aws configure --profile <user_profile_name>
```

If you supply the "-m" flag, it will automatically create and activate a virtual MFA device with the user, and prompt you to save the secret to the atmos mfa keystore for integrated usage.  You can skip saving the secret and instead just copy/paste it into your MFA device of choice.  The "user create" command can also act in more of an upsert fashion, so to do something like reset a user's password and keys, you could do `atmos user create --force -l -m -k your@email.address`

Login to the aws console as that user, change your password and setup MFA there if you prefer doing it that way.  Make sure you log out and back in again with MFA before you try setting up the [role switcher](#per-user-role-switcher-in-console)

Now that a non-root user is created, you should be able to do everything as that user, so you can remove the root access keys if desired.  Keeping them around can be useful though, as there are some AWS operations that can only be done as the root user.  Leaving them in your shared credential store, but deactivating them in the AWS console till needed is a reasonable compromise.  

While you can do everything in a single account, i've found a better practice is to use a new account for each env (dev, staging, prod, etc), and leave the ops account providing authentication duties and acting as a jumping off point to the others.  This allows for easier role/permission management down the line as well as better isolation between environments, thereby enabling safe iteration in dev environments without risking production.

Create a new `dev` account, and bootstrap it to work with atmos

```
AWS_PROFILE=<user_profile_name> atmos account create dev
AWS_PROFILE=<user_profile_name> atmos -e ops apply
AWS_PROFILE=<user_profile_name> atmos -e dev bootstrap
```

Note that you can `export AWS_PROFILE=<user_profile_name>` in your environment, or keep using it per operation as preferred.

Use the 'aws/service' template to setup an ECS Fargate based service, then apply it in the dev environment to make it active.  This template will also pull in some dependent templates to setup a vpc, dns for the provided domain and a wildcard cert to enable ssl for your service

```
atmos generate --force aws/service
atmos -e dev apply

```

Setup your application repo to work with ECS by generating a Dockerfile.  For example, [here is the example app](https://github.com/simplygenius/atmos-example-app) used in the demo

To deploy your app to ECS, first use docker to build an image with a tag named the same as your service name

```
# In your app repo directory
docker build -t <service_name> .
```

Then use atmos to push and deploy that image to the ECR repo:

```
atmos -e dev container deploy -c services <service_name>
```

The atmos aws scaffold also sets up a user named deployer, with restricted permissions sufficient to do the deploy.  Add the [key/secret](https://github.com/simplygenius/atmos-recipes/blob/master/aws/scaffold/recipes/atmos-permissions.tf#L159)) to the environment for your CI to get your CI to auto deploy on successful build.

```
AWS_ACCESS_KEY_ID=<deployer_key> AWS_SECRET_ACCESS_KEY=<deployer_secret> atmos -e <env_based_on_branch> container deploy -c services <service_name>
```

To clean it all up:

```
# Applies flag to allow deleting empty buckets to existing resources
TF_VAR_force_destroy_buckets=true atmos -e dev apply

# Destroys all non-bootstrap resources create by atmos
atmos -e dev destroy

# Destroys the bootstrap resources (state, secret, lock storage and
# cross-account access role)
TF_VAR_force_destroy_buckets=true atmos -e dev apply --group bootstrap
atmos -e dev destroy --group bootstrap

# For normal usage you should rarely need to cleanup the ops account, but
# included here in case you want to completely purge the atmos resources after
# trying things out.

# Cleanup non-bootstrap ops
AWS_PROFILE=<root_profile_name> TF_VAR_force_destroy_buckets=true atmos -e ops apply
AWS_PROFILE=<root_profile_name> atmos -e ops destroy

# Cleanup ops bootstrap
AWS_PROFILE=<root_profile_name> TF_VAR_force_destroy_buckets=true atmos -e ops apply --group bootstrap
AWS_PROFILE=<root_profile_name> atmos -e ops destroy --group bootstrap

```

These are separate commands so that day-day usage where you want to tear down everything (e.g. CI spinning up then destroying while testing) doesn't compromise your ability to use atmos/terraform.  You can avoid the extra steps of applying with `TF_VAR_force_destroy_buckets=true` if you set `force_destroy_buckets: true` in atmos.yml

## Per-User Role switcher in Console

If you are following the account-per-environment pattern, you will need to setup a role switcher for each account in the AWS console for your user.  The AWS console seems to store these in cookies, so if you make a mistake its easy to fix by clearing them.  First, login to the AWS console with your personal aws user that was created in the ops account.  Select the dropdown with your email at top right of the page, Switch Role.  Fill the details for the environment you want to be able to access from the console:

* Account number for the environment (See environments->`<env>`-> account_id in `config/atmos.yml` 
* Role `<env>-admin` - this is the role you assume in the destination account.
* Pick a name (e.g. DevAdmin)
* Pick a color that you like (e.g. Red=production, Yellow=staging, Green=dev)

## Managing secrets

Secrets are stored in a s3 bucket unique to each environment, and automatically passed into terraform when it is executed by atmos.  The secret key should be the same as a terraform variable name defined in your terraform recipes, and if the secret exists, it will override whatever default value you have setup for the terraform variable.

To set a secret:

`atmos secret -e <env> set key value`

For other secret usage:
 
`atmos secret --help`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/simplygenius/atmos.


## License

The gem is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/apache-2.0).

# About Us

Simply Genius LLC is an independently run organization in Boston, MA USA.  Its Chief Everything is Matt Conway, a software engineer and executive with more than 20 years of experience in the Boston Tech Startup scene.  Atmos is his attempt at providing the world with the same tools, techniques, mindset and philosophy that he strives for when building a system architecture for a new startup.
