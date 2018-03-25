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
* Manages multiple independent environments (e.g. dev, staging, production), allowing them to be as similar or divergent as desired.
* Secure by default
* Common recipe patterns to simplify maximal use of higher level AWS components. 
* Free and open source core with a business friendly license (Apache)


## Installation

On Mac OS X:
```
brew install aws
brew install terraform
gem install atmos
```

## Usage

Usage is available via the command line: `atmos --help`
The [terraform docs](https://www.terraform.io/docs/index.html) are excellent.


## Quickstart

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
atmos generate aws/scaffold
```

Optionally bring up config/atmos.yml in your editor and make any other desired changes.

Bootstrap your cloud provider to work with atmos.  Answer `yes` when prompted to apply the changes.

```
AWS_PROFILE=<root_profile_name> atmos -e ops bootstrap
AWS_PROFILE=<root_profile_name> atmos -e ops apply
```

Setup a non-root user - using your email as the IAM username is convenient for email notifications in the future (e.g. per-user security validations like auto-expiry of access keys)

```
AWS_PROFILE=<root_profile_name> atmos user -l -k -g all-users -g ops-admin your@email.address
aws configure --profile <user_profile_name>
```

Now that a non-root user is created, you should be able to do everything as that user, so you can remove the root access keys if desired.  Keeping them around can be useful though, as there are some AWS operations one can only be done as the root user.  Leaving them in your shared credential store, but deactivating them in the AWS console till needed is a reasonable compromise.  

While you can do everything in a single account, i've found a better practice is to use a new account for each env (dev, staging, prod, etc), and leave the ops account providing authentication duties and acting as a jumping off point to the others.  This allows for better isolation between environments, thereby allow lots of safe iteration in dev environments without risking production.

Create a new `dev` account, and bootstrap it to work with atmos

```
AWS_PROFILE=<user_profile_name> atmos account create dev
AWS_PROFILE=<user_profile_name> atmos -e dev bootstrap
```

Note that you can `export AWS_PROFILE=<user_profile_name>` in your environment, or keep using it per operation as preferred.

Use the 'aws/service' template to setup an ECS Fargate based service, then apply it in the dev environment to make it active

```
atmos generate aws/service
atmos -e dev apply

```

Setup your application repo to work with ECS by generating a Dockerfile.  For example, [here is the example app](https://github.com/simplygenius/atmos-example-app) used in the demo

To deploy your app to ECS, first build an image using docker with a tag the same as your service name

```
# In your app repo directory
docker build -t <service_name> .
```

Then use atmos to push and deploy that image to the ECR repo:

```
atmos -e dev container deploy -c services <service_name>
```

The atmos aws scaffold also sets up a user named deployer, with restricted permissions sufficient to do the deploy.  Add the [key/secret](https://github.com/simplygenius/atmos-recipes/aws/scaffold/recipes/atmos-scaffold.tf#L348)) to the environment for your CI to get your CI to auto deploy on successful build.

```
AWS_ACCESS_KEY_ID=<deployer_key> AWS_SECRET_ACCESS_KEY=<deployer_secret> atmos -e <env_based on branch> container deploy -c services <service_name>
```

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
