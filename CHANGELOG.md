0.11.9 (02/13/2020)
-------------------

* Automatically run init when needed for current environment [f902232](https://github.com/simplygenius/atmos/commit/f902232)


0.11.8 (02/04/2020)
-------------------

* newer terraform in docker image [771ab07](https://github.com/simplygenius/atmos/commit/771ab07)
* fix plan summary to handle newer terraform [f0a5b95](https://github.com/simplygenius/atmos/commit/f0a5b95)

0.11.7 (01/30/2020)
-------------------

* add ability to wait for a service to deploy [9448bd1](https://github.com/simplygenius/atmos/commit/9448bd1)
* force a shorter session duration when bootstrapping since the role to extend session has not been setup yet [c1b5394](https://github.com/simplygenius/atmos/commit/c1b5394)

0.11.6 (01/03/2020)
-------------------

* fix passing of complex types from atmos to terraform for 0.12 and up [1df9b3d](https://github.com/simplygenius/atmos/commit/1df9b3d)

0.11.5 (12/12/2019)
-------------------

* fix usage to include exe name and add -v for checking version [64a6183](https://github.com/simplygenius/atmos/commit/64a6183)
* allow setting atmos root/config_file from env, and pass it down to subprocesses so that tfutil can act the same from the terraform working dir [c417d4c](https://github.com/simplygenius/atmos/commit/c417d4c)
* add tfutil.jsonify to make it easier to call out from terraform data.external [c9bfdf5](https://github.com/simplygenius/atmos/commit/c9bfdf5)
* add ability to dump config as json [9e6176f](https://github.com/simplygenius/atmos/commit/9e6176f)
* allow customization of what gets linked into terraform working dir [115e460](https://github.com/simplygenius/atmos/commit/115e460)


0.11.4 (11/27/2019)
-------------------

* add the ability to spawn a console for any service container [0d1764e](https://github.com/simplygenius/atmos/commit/0d1764e)
* allow escaping atmos interpolations [3d8b59e](https://github.com/simplygenius/atmos/commit/3d8b59e)


0.11.3 (11/12/2019)
-------------------

* add a compat mode for running with terraform 0.11 [30052a1](https://github.com/simplygenius/atmos/commit/30052a1)
* handle deleting a secret that doesn't exist [224c926](https://github.com/simplygenius/atmos/commit/224c926)
* update rubyzip to avoid vulnerability [d46d817](https://github.com/simplygenius/atmos/commit/d46d817)


0.11.2 (10/18/2019)
-------------------

* paginate across all secrets when listing [7f43461](https://github.com/simplygenius/atmos/commit/7f43461)

0.11.1 (10/16/2019)
-------------------

* stop pinning aws sdk versions as they change too frequently [61cfebf](https://github.com/simplygenius/atmos/commit/61cfebf)

0.11.0 (09/25/2019)
-------------------

#### Notes on major changes

 * Upgraded to support using terraform 0.12 .  This should continue to work with terraform 0.11, but revving the minor version in case it introduces a breaking change.  Most of the breaking changes were in the atmos-recipes repo, but you can pin to an older version of that to avoid getting the 0.12 recipes.

#### Full changelog

* fix 2.3 test failure [c20f957](https://github.com/simplygenius/atmos/commit/c20f957)
* terraform 0.12 conversion - fix passing of atmos variables to terraform process [cad8c8f](https://github.com/simplygenius/atmos/commit/cad8c8f)
* add_config comment detection needs single quote empty strings [2ef430b](https://github.com/simplygenius/atmos/commit/2ef430b)
* fix summary for terraform 0.12 [bccb915](https://github.com/simplygenius/atmos/commit/bccb915)
* use empty string instead of null as terraform 0.12 now treats null differently [8dd3853](https://github.com/simplygenius/atmos/commit/8dd3853)

0.10.1 (09/20/2019)
-------------------

* add a quiet output option to make it easier to use secret values in external scripts [da7770a](https://github.com/simplygenius/atmos/commit/da7770a)
* latest 0.11 terraform [0959ba6](https://github.com/simplygenius/atmos/commit/0959ba6)
* add aws cli to image as it comes in handy for oddball deploy scenarios [392bb9b](https://github.com/simplygenius/atmos/commit/392bb9b)

0.10.0 (09/13/2019)
-------------------

#### Notes on breaking changes

* Made AWS SSM Parameter Store the default secrets store for atmos.  The s3 secrets will still work unless you overwrite your provider/aws.yml with the changes
* Interpolations in the yml config now look up from the top level only if missing in the current level (hashes of hashes).  Previously it looked up values from the top level before the current level, which was causing a number of issues.  One can force a lookup from the top level by prefixing the key in the interpolations with `_root_`, e.g. The [config/provider/aws.yml](https://github.com/simplygenius/atmos-recipes/blob/master/aws/scaffold/config/atmos/providers/aws.yml#L20) in the atmos aws scaffold.  You will know you forgot to do this when you get s circular reference error when running atmos.
* Atmos pro has been merged into core Atmos, so you should stop using of the atmos-pro-recipes repository as well as the atmos-pro-plugins gem as they will go away soon.

#### Full changelog
* add ability to push or activate instead of always doing both as deploy does [dfac7ad](https://github.com/simplygenius/atmos/commit/dfac7ad)
* add ruby 2.6 [a3b8aff](https://github.com/simplygenius/atmos/commit/a3b8aff)
* add ruby 2.6 [db3469f](https://github.com/simplygenius/atmos/commit/db3469f)
* running deploy as deployer user needs the deployer specific role to be specified [06a34b0](https://github.com/simplygenius/atmos/commit/06a34b0)
* move client out of ctor to fix tests [b9d8c02](https://github.com/simplygenius/atmos/commit/b9d8c02)
* make s3 consistent with ssm for trying to set an existing secret add force option when setting secret to cause ssm (and s3) to overwrite existing secret [b05f189](https://github.com/simplygenius/atmos/commit/b05f189)
* add aws ssm for secret management, update aws gem version dependencies [8cb4350](https://github.com/simplygenius/atmos/commit/8cb4350)
* Merge pull request #3 from nirvdrum/readme-improvements [d82710b](https://github.com/simplygenius/atmos/commit/d82710b)
* interpolations in config should only lookup values from root only if they don't exit in current level of hash.  One can force a root lookup with the _root_ prefix.  This is a breaking change [cc925d3](https://github.com/simplygenius/atmos/commit/cc925d3)
* Minor README clean-ups. [16778b1](https://github.com/simplygenius/atmos/commit/16778b1)
* Homebrew is now available on Linux, so no need to limit the docs to just macOS. [6885a35](https://github.com/simplygenius/atmos/commit/6885a35)
* Update the package names to be installed via Homebrew. [68f3cde](https://github.com/simplygenius/atmos/commit/68f3cde)
* friendlier output for cycles in interpolation, better exception handling [dea7766](https://github.com/simplygenius/atmos/commit/dea7766)
* fix whitespace [870f4c2](https://github.com/simplygenius/atmos/commit/870f4c2)
* allow running multiple organizations from a single ops account [baef6c3](https://github.com/simplygenius/atmos/commit/baef6c3)
* Fix config interpolation to allow one path to refer to another that also needs interpolation [202fd85](https://github.com/simplygenius/atmos/commit/202fd85)
* Inline all the atmos pro functionality/recipes to make atmos fully open source [b906d7e](https://github.com/simplygenius/atmos/commit/b906d7e)
* mention setting of secret for example app [382db44](https://github.com/simplygenius/atmos/commit/382db44)
* upgrade bundler [667c7a6](https://github.com/simplygenius/atmos/commit/667c7a6)

0.9.4 (03/20/2019)
------------------

* allow deploying the same image to multiple services and make task vs service auto detected [9f841d7](https://github.com/simplygenius/atmos/commit/9f841d7)
* fix link [deba98f](https://github.com/simplygenius/atmos/commit/deba98f)

0.9.3 (02/12/2019)
------------------

* add the ability to use a prefix for scoping secrets [470556a](https://github.com/simplygenius/atmos/commit/470556a)
* add comment [b0592d5](https://github.com/simplygenius/atmos/commit/b0592d5)
* fix pro recipe source url [9ddb8a8](https://github.com/simplygenius/atmos/commit/9ddb8a8)
* handle flushing of data in plugin output handlers when streaming completes [e1e4707](https://github.com/simplygenius/atmos/commit/e1e4707)
* refactor secrets config into a more general user config file in users home directory [06875b7](https://github.com/simplygenius/atmos/commit/06875b7)
* expand warnings for missing aws auth [3ad6ec0](https://github.com/simplygenius/atmos/commit/3ad6ec0)

0.9.2 (12/01/2018)
------------------

* add more useful display of type mismatches during config merges [b751a82](https://github.com/simplygenius/atmos/commit/b751a82)
* ensure all config files are hash like [5ad14fb](https://github.com/simplygenius/atmos/commit/5ad14fb)

0.9.1 (11/30/2018)
------------------

* fix some json weirdness with ruby v2.3 vs 2.5 and active support [82c02d1](https://github.com/simplygenius/atmos/commit/82c02d1)
* docker tweaks [f44c9b1](https://github.com/simplygenius/atmos/commit/f44c9b1)
* warn instead of trace for empty recipe config [7c83238](https://github.com/simplygenius/atmos/commit/7c83238)
* fix docker based runtime, pass through more mounts and skip aws cli based auth lookup as it slowed things down too much [f9844e9](https://github.com/simplygenius/atmos/commit/f9844e9)

0.9.0 (10/18/2018)
------------------

* change terraform plugin sharing to do so by copying the plugins to the home directory location that is searched by terraform . [9779685](https://github.com/simplygenius/atmos/commit/9779685)
* fix comment [58e51a1](https://github.com/simplygenius/atmos/commit/58e51a1)
* handle empty config files [8f48c98](https://github.com/simplygenius/atmos/commit/8f48c98)
* push working group up to main cli and add to atmos config so that we can reference it in backend state key [ca87c24](https://github.com/simplygenius/atmos/commit/ca87c24)
* move all but config location to atmos runtime config [3f86a3e](https://github.com/simplygenius/atmos/commit/3f86a3e)
* fix dev tools [1edf4e2](https://github.com/simplygenius/atmos/commit/1edf4e2)
* version constrain all the dependencies [cdce71f](https://github.com/simplygenius/atmos/commit/cdce71f)
* make explicit the use of working_group for state key by passing in atmos_working_group as a terraform variable [83a581f](https://github.com/simplygenius/atmos/commit/83a581f)
* move atmos vars in yml into their own namespace [705beda](https://github.com/simplygenius/atmos/commit/705beda)
* force hashie version [e52cd93](https://github.com/simplygenius/atmos/commit/e52cd93)
* fix to work with ruby 2.3 [b2612ec](https://github.com/simplygenius/atmos/commit/b2612ec)
* log load path [3b4945d](https://github.com/simplygenius/atmos/commit/3b4945d)
* add ability to add to ruby load path from cli/config [e13935b](https://github.com/simplygenius/atmos/commit/e13935b)
* allow templates to directly reference scoped context with method_missing (lets skip assigning a var when asking questions) [8cf203e](https://github.com/simplygenius/atmos/commit/8cf203e)
* fix doc strinng [7257229](https://github.com/simplygenius/atmos/commit/7257229)
* add choose to ui in templates [efb7047](https://github.com/simplygenius/atmos/commit/efb7047)
* add update to generator to allow applying all previously installed templates [2faa6e9](https://github.com/simplygenius/atmos/commit/2faa6e9)
* make state file be plain yaml (no atmos class refs) [625d508](https://github.com/simplygenius/atmos/commit/625d508)
* allow disabling built in sourcepaths from cli [64a2c18](https://github.com/simplygenius/atmos/commit/64a2c18)
* refactor loading of env/providers so they can be in a dedicated file [fedf915](https://github.com/simplygenius/atmos/commit/fedf915)
* extract recipes to own yml [518e1b7](https://github.com/simplygenius/atmos/commit/518e1b7)
* plugin config tweaks [3cbc19e](https://github.com/simplygenius/atmos/commit/3cbc19e)
* allow custom config sources [9d82d09](https://github.com/simplygenius/atmos/commit/9d82d09)
* refactor template/context/hash mess into template class, fix a number of issues with context, disallow duplicate template names for now, add initial state tracking [e00a4dc](https://github.com/simplygenius/atmos/commit/e00a4dc)
* add context, allow UI to get answers from context, fix dependency traversal to handle context [43584d3](https://github.com/simplygenius/atmos/commit/43584d3)
* cleanup plugins, allow per-plugin config [89c9f96](https://github.com/simplygenius/atmos/commit/89c9f96)
* handle inline as an option to notify [de7afff](https://github.com/simplygenius/atmos/commit/de7afff)
* remove debug [463ad0d](https://github.com/simplygenius/atmos/commit/463ad0d)
* fix sourcepath directory expansion [e41304c](https://github.com/simplygenius/atmos/commit/e41304c)
* rework generators to allow disambiguation template name duplication across sources, and to prepare for saving a list of all installed templates and fully qualifying templates names by source [b06fa68](https://github.com/simplygenius/atmos/commit/b06fa68)
* separate plugin loading from initialization [e0801d0](https://github.com/simplygenius/atmos/commit/e0801d0)
* add in simplygenius to namespace, refactor to handle namespacing better (Module.nesting) across code/tests [168af71](https://github.com/simplygenius/atmos/commit/168af71)
* update pro release sources [454b054](https://github.com/simplygenius/atmos/commit/454b054)
* helper for local plugin dev [1479604](https://github.com/simplygenius/atmos/commit/1479604)
* add basic plugin mechanism and refactor terraform output filtering as a plugin [29e32a3](https://github.com/simplygenius/atmos/commit/29e32a3)
* add passthrough to highline choose for menus [d9cda18](https://github.com/simplygenius/atmos/commit/d9cda18)
* write auth cache when auto renewing session [bc2f8f9](https://github.com/simplygenius/atmos/commit/bc2f8f9)
* handle interrupts [f8db090](https://github.com/simplygenius/atmos/commit/f8db090)
* try to fix travis error [cceaf43](https://github.com/simplygenius/atmos/commit/cceaf43)
* newer bundler [eaffeba](https://github.com/simplygenius/atmos/commit/eaffeba)
* fix test [030d8c4](https://github.com/simplygenius/atmos/commit/030d8c4)
* version update [0257e0c](https://github.com/simplygenius/atmos/commit/0257e0c)
* use eq [8e7eccc](https://github.com/simplygenius/atmos/commit/8e7eccc)
* show exe output on fail [e2fecf4](https://github.com/simplygenius/atmos/commit/e2fecf4)
* fix/add tests for username in assume role session [5ff99ff](https://github.com/simplygenius/atmos/commit/5ff99ff)
* add username to assume role session name for easier tracking, e.g. in cloudtrail [585a974](https://github.com/simplygenius/atmos/commit/585a974)
* added custom merge logic that works better and removes hacks [d668dd9](https://github.com/simplygenius/atmos/commit/d668dd9)
* fix homogenize of atmos_config, and don't homogenize yaml that gets directly added so that yml can be used to set values for maps/list for declared vars [7e1c221](https://github.com/simplygenius/atmos/commit/7e1c221)
* do an additive merge of lists in config as its more useable in the average case of adding to a default [d9d654d](https://github.com/simplygenius/atmos/commit/d9d654d)
* test more ruby versions [8733d46](https://github.com/simplygenius/atmos/commit/8733d46)
* fix permalink to atmos-pro [c0e6a57](https://github.com/simplygenius/atmos/commit/c0e6a57)
* readme tweaks [16db27a](https://github.com/simplygenius/atmos/commit/16db27a)
* helper for tagging recipe repos when releasing [9632bee](https://github.com/simplygenius/atmos/commit/9632bee)

0.7.1 (05/03/2018)
------------------

* version lock recipe sources by default [e88d027](https://github.com/simplygenius/atmos/commit/e88d027)
* test zip archive over http [e7c51db](https://github.com/simplygenius/atmos/commit/e7c51db)
* add an architecture picture to readme [83377da](https://github.com/simplygenius/atmos/commit/83377da)
* add condensed screencast [a58633e](https://github.com/simplygenius/atmos/commit/a58633e)
* lookup and pass aws keys to docker [b5d0240](https://github.com/simplygenius/atmos/commit/b5d0240)
* allow rubygems push [2dd2c9b](https://github.com/simplygenius/atmos/commit/2dd2c9b)

0.7.0 (04/11/2018)
------------------

* First public release
