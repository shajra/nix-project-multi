- [About this project](#sec-1)
  - [Assumed toolchain](#sec-1-1)
  - [Problem solved](#sec-1-2)
- [Workflow](#sec-2)
- [Usage](#sec-3)
  - [Nix package manager setup](#sec-3-1)
  - [Cache setup](#sec-3-2)
  - [Manage projects with Niv](#sec-3-3)
  - [Configuration](#sec-3-4)
  - [Installing scripts](#sec-3-5)
  - [Detailed usage](#sec-3-6)
  - [GitHub rate limiting of Niv calls](#sec-3-7)
- [Release](#sec-4)
- [License](#sec-5)
- [Contribution](#sec-6)

[![img](https://github.com/shajra/nix-project-multi/workflows/CI/badge.svg)](https://github.com/shajra/nix-project-multi/actions)

# About this project<a id="sec-1"></a>

This project helps centralize dependency management for [Nix](https://nixos.org/nix)-based projects that use [Niv](https://github.com/nmattia/niv) for keeping dependencies updated.

## Assumed toolchain<a id="sec-1-1"></a>

There are many motivations to manage dependencies with Nix. It offers an exceptional precision, and Nix can manage dependencies for a variety of programming language ecosystems. See the [provided documentation on Nix](doc/nix.md) for more information.

All dependencies are assumed to be managed for Nix by [Niv](https://github.com/nmattia/niv). This means that all projects should have Niv's `sources.json` file. These are what are managed by this project.

## Problem solved<a id="sec-1-2"></a>

[Niv](https://github.com/nmattia/niv) can update all dependencies for a single project, or a single dependency at a time. But sometimes it's nice to pin all projects to the same version of a dependency. With just Niv, as you move from upgrading one project to another, you can easily pull in different versions at different times. Aligning versions of dependencies across projects isn't strictly necessary, but can make reasoning about different versions of the same dependency easier.

This project provides two scripts:

-   `dependencies-pull`, which collects all dependencies from specified projects' `sources.json` files into a central project's `sources.json` file.
-   `dependencies-push`, which overrides any dependencies listed in specified project's `source.json` files with dependencies from the central project's `sources.json` file.

This project also happens to be my personal centralized repository for all my projects, which is why its `sources.json` has many more dependencies than used within this project.

# Workflow<a id="sec-2"></a>

This is work in progress, and may refine as put into more practice. The idea is to update all project dependencies at once to pinned versions. And then go through each project, seeing that everything still works, and releasing the new version of them with updated dependencies.

1.  Call `dependencies-pull` to get all dependencies centralized.
2.  Call `dependencies-update` to update all dependencies to their latest versions.
3.  Call `dependencies-push` to push pinned versions out to all managed projects.
4.  Work on a project, call it `some-project`, and publish a new version.
5.  Call `dependencies-update some-project` in my central project, to pull in the new dependency without changing other pinned dependencies.
6.  Call `dependencies-push` to push it out to other projects that might depend on `some-project`.
7.  Repeat steps 4 through 6 as necessary until everything is up-to-date.
8.  On some later day, start all over again at step 1. The cycle of life continues.

# Usage<a id="sec-3"></a>

This project should work with either GNU/Linux or MacOS operating systems. Just follow the following steps.

## Nix package manager setup<a id="sec-3-1"></a>

> **<span class="underline">NOTE:</span>** You don't need this step if you're running NixOS, which comes with Nix baked in.

If you don't already have Nix, [the official installation script](https://nixos.org/learn.html) should work on a variety of UNIX-like operating systems:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

If you're on a recent release of MacOS, you will need an extra switch:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon \
    --darwin-use-unencrypted-nix-store-volume
```

After installation, you may have to exit your terminal session and log back in to have environment variables configured to put Nix executables on your `PATH`.

The `--daemon` switch installs Nix in the recommended multi-user mode. This requires the script to run commands with `sudo`. The script fairly verbosely reports everything it does and touches. If you later want to uninstall Nix, you can run the installation script again, and it will tell you what to do to get back to a clean state.

The Nix manual describes [other methods of installing Nix](https://nixos.org/nix/manual/#chap-installation) that may suit you more.

## Cache setup<a id="sec-3-2"></a>

It's recommended to configure Nix to use shajra.cachix.org as a Nix *substitutor*. This project pushes built Nix packages to [Cachix](https://cachix.org) as part of its continuous integration. Once configured, Nix will pull down these pre-built packages instead of building them locally (potentially saving a lot of time). This augments the default substitutor that pulls from cache.nixos.org.

You can configure shajra.cachix.org as a substitutor with the following command:

```sh
nix run \
    --file https://cachix.org/api/v1/install \
    cachix \
    --command cachix use shajra
```

Cachix is a service that anyone can use. You can call this command later to add substitutors for someone else using Cachix, replacing "shajra" with their cache's name.

If you've just run a multi-user Nix installation and are not yet a trusted user in `/etc/nix/nix.conf`, this command may not work. But it will report back some options to proceed.

One option sets you up as a trusted user, and installs Cachix configuration for Nix locally at `~/.config/nix/nix.conf`. This configuration will be available immediately, and any subsequent invocation of Nix commands will take advantage of the Cachix cache.

You can alternatively configure Cachix as a substitutor globally by running the above command as a root user (say with `sudo`), which sets up Cachix directly in `/etc/nix/nix.conf`. The invocation may give further instructions upon completion.

## Manage projects with Niv<a id="sec-3-3"></a>

Using [Niv](https://github.com/nmattia/niv) is not covered by this documentation. I use my own [Nix-project](https://github.com/shajra/nix-project) project, which delegates heavily to Niv. Each of these projects have instructions on how to manage dependencies for a Nix-based project, which should end up with a `sources.json` file listing out all dependencies.

One of the projects you create will be where dependencies are centralized, and need not have any code, just dependencies managed by Niv.

## Configuration<a id="sec-3-4"></a>

Create a YAML file at `~/.config/nix-project/multi.yaml`, which should have two top-level keys `packages` and `central`. Managed projects' `source.json` filepaths are set in an array in `packages`. The central project's `source.json` filepath is set in `central`. Here's an example:

```yaml
packages:
- /home/you/src/your-great-project/nix/sources.json
- /home/you/src/your-greater-project/nix/sources.json
central: /home/you/src/your-central-deps/nix/sources.json
```

## Installing scripts<a id="sec-3-5"></a>

Once configured, you can use `dependencies-pull` and `dependencies-push` directly from this repository.

Both of these scripts delegate to a single script `nix-project-multi`, which you can install with `nix-env` if you like. You can look at `dependencies-pull` and `dependencies-push` to see that all they do is call `nix-project-multi` with either a `pull` or `push` argument respectively.

Here's how to install `nix-project-multi`:

```sh
nix-env --install --file . --attr nix-project-multi 2>&1
```

    installing 'nix-project-multi'

If you have `~/.nix-profile/bin` on your `PATH`, you should be able to call `nix-project-multi`.

## Detailed usage<a id="sec-3-6"></a>

We can look at the script usage from the `--help` option for more details:

```sh
nix-project-multi --help
```

    USAGE: nix-project-multi MODE [OPTION]... [PROJECT_SOURCES_JSON]...
    
    DESCRIPTION:
    
        Manage dependencies for many projects from a centralized
        project.  The dependencies must be in the JSON format of
        the Niv tool.
    
    MODES
    
        pull   pull dependencies into centralized project
        push   push dependencies out to managed projects
    
    OPTIONS:
    
        --help             print this help message
        -C --config  PATH  path to configuration file to use
        -c --central PATH  centralized sources JSON
        -n --dry-run       print files affects, but don't run

## GitHub rate limiting of Niv calls<a id="sec-3-7"></a>

Many dependencies managed by Niv may come from GitHub. GitHub will rate limit anonymous API calls to 60/hour, which is not a lot. To increase this limit, you can make a [personal access token](https://github.com/settings/tokens) with GitHub. Then write the generated token value in the file `~/.config/nix-project/github.token`. Make sure to restrict the permissions of this file appropriately.

# Release<a id="sec-4"></a>

The "main" branch of the repository on GitHub has the latest released version of this code. There is currently no commitment to either forward or backward compatibility.

"user/shajra" branches are personal branches that may be force-pushed to. The "main" branch should not experience force-pushes and is recommended for general use.

# License<a id="sec-5"></a>

All files in this "nix-project" project are licensed under the terms of GPLv3 or (at your option) any later version.

Please see the [./COPYING.md](./COPYING.md) file for more details.

# Contribution<a id="sec-6"></a>

Feel free to file issues and submit pull requests with GitHub.

There is only one author to date, so the following copyright covers all files in this project:

Copyright © 2021 Sukant Hajra
