# CMake Tools

This contains a few different tools that are useful. It can easily be added as a submodule to an
existing project and versioned along with the rest of a CMake project.

Most, if not all, of these tools are meant to be used within a monorepo CMake project.

## Installation

Add this function library to your project with:

```bash
git submodule add https://github.com/nikkomiu/cmake-tools.git
```

You can also add this to a specific subdirectory within your project instead of keeping it at the
top-level of your project with:

```bash
git submodule add https://github.com/nikkomiu/cmake-tools.git tools/cmake
```

Once you have this library added as a submodule to your project, you can update your
`CMakePresets.json` to set the variable (if you're using [cmake-presets](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html)).

Typically, I set this within a hidden base configuration and extend it for each of my specific
configurations. To do so, it'll probably look something like:

```json
{
    "configurePresets": [
        {
            "name": "base",
            "hidden": true,
            "cacheVariables": {
                "CMAKE_MODULE_PATH": "${sourceDir}/tools/cmake"
            }
        },
        {
            "name": "debug",
            "displayName": "Debug",
            "description": "Configuration for debug builds.",
            "inherits": "base",
            "cacheVariables": {
                "WITH_COVERAGE": "ON"
            }
        }
    ]
}
```

> **Note:** This can be a semicolon seperated list of values that contain multiple directories so
> you aren't limited to _just_ using this and not being able to include other CMake modules.

### Optional OS Dependencies

- `doxygen`: Used to generate documentation.
- `clang-format`: Used to run Clang Format on code.
- `clang-check`: Used to run Clang Check on code.
- `clang-tidy`: Used to run Clang Tidy on code.
- `llvm-profdata`: Used to build profiling data when testing with code coverage.
- `llvm-cov`: Used to generate HTML and LCOV reports when testing with code coverage.

### vcpkg

Commonly, I'll include `vcpkg` in my projects. However, I'm not a fan of including it at the system
level. I also don't care for the default functionality of needing to manually install packages with
the `vcpkg` tool. Their documentation doesn't give very clear guidance on setting up `vcpkg` as if
it was like a package manager in another language (think `npm` in JS, `go mod` in Go,
`requirements.txt` in Python, etc.).

> **Note:** All of these steps will need to be done with a **clean** project directory. Be sure to
> remove your CMake build directory before continuing. You can also do it at the very end to be sure.

First, we need to add the `vcpkg` repository as a submodule to our project. This will allow us to
version our dependencies along with our project (similar to how the `nix` package manager works for
Linux). I tend to keep mine in a `tools/` directory at the root of my project so here's the command
for that:

```bash
git submodule add https://github.com/microsoft/vcpkg.git tools/vcpkg
```

Once this is in place, we can add the toolchain file to the `CMakePresets.json` file.

> **Note:** If you're not using [cmake-presets](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html),
> you will need to either manually specify it on your build and/or set up your IDE to use it.

Typically I create a hidden base configuration preset that all other configurations inherit from. The
use of a toolchain is one such reason for this. Update your `CMakePresets.json` file to include the
`toolchainFile` on the base configuration preset:

```json
{
    "configurePresets": [
        {
            "name": "base",
            "displayName": "Base",
            "description": "Base configuration for project. All other configurations are based on this one.",
            "hidden": true,
            "binaryDir": "${sourceDir}/build",
            "toolchainFile": "${sourceDir}/tools/vcpkg/scripts/buildsystems/vcpkg.cmake"
        },
        {
            "name": "debug",
            "displayName": "Debug",
            "description": "Configuration for debug builds. (Includes coverage)",
            "inherits": "base"
        }
    ]
}
```

Now that we have `vcpkg` installed and CMake can use it, we can add our manifest file to tell `vcpkg`
which packages need to be installed for our project. This will make it so we don't need to explicitly
install dependencies in `vcpkg` before building our project.

To do this, add the `vcpkg.json` file at the root of your project:

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg.schema.json",
  "name": "my_project",
  "version-string": "0.1.0",
  "dependencies": [
    "gtest"
  ]
}
```

Let's go over what's in this file:

- `$schema`: This is an editor hint to the schema which says which options available to us for the configuration. I typically just set this to the `main` branch of the schema definition (even though my local version may not be targeting the current `main` code for `vcpkg`).
- `name`: Your top-level project name. Typically I just set this to the same value as what is in the `project()` in my top-level `CMakeLists.txt`.
- `version-string`: The version of your top-level project.
- `dependencies`: This is the important part. It defines which dependencies are to be built and available to us on the build. You can see a list of packages on [vcpkg.io](https://vcpkg.io/en/packages). The name of the package in the list is the value to put in the dependencies.

> **Note:** Doing this also means that we could end up with duplicate dependencies in multiple C/C++
> projects that are being worked on locally. However, I find the tradeoff in local duplicates worth
> the ease of use given by this setup.

At this point you should be able to build your project again with CMake and the `gtest` dependency
will be avaliable to include in your `CMakeLists.txt`. Check the configure output to see autogenerated
instructions of how to add the dependency to your project.

> **Note:** If you're using [BuildPkg](#buildpkg) you just need to specify the link libraries in
> either your `PUBLIC_LINK_LIBRARIES` or `PRIVATE_LINK_LIBRARIES` instead of their recommendation
> of what they say.
>
> Let's take `spdlog` as an example. The build output says to add this:
>
> ```cmake
> target_link_libraries(main PRIVATE spdlog::spdlog)
> ```
>
> but with [BuildPkg](#buildpkg), we just need to do the following on our `build_pkg()`:
>
> ```cmake
> build_pkg(PKG_NAME <name> PRIVATE_LINK_LIBRARIES spdlog::spdlog)
> ```

Specific to the `gtest` package you don't need to do anything since `gtest` is the testing package
that's used by [TestPkg](#testpkg) and it is automatically included in the build.

## Modules

This section outlines the use and properties of the modules that are available.

Each of the heading is the name of the module to include. So, to include Clang Check, you would add
the following to your `CMakeLists.txt`:

```cmake
include(PrintVariables)
```

Alternatively, if you didn't (or don't want to) set the `CMAKE_MODULE_PATH` variable to this
directory, you can always set the relative path to the module.

### PrintVariables

Once you include this module in your CMake project you can call `print_variables()` anywhere you want
to print out all of the current variables visible at that location. This is primarily used to check
variable outputs when building as a simple debugging tool or to see what's available based on other
side-effects of the CMake build process.

It may be useful to enable in CI environments where the build server isn't using reproducible
tooling and hosts (such as pre-built Docker containers or [nix](https://nix.dev)).

Example:

```cmake
print_variables()
```

This can also be disabled globally by setting the `NO_PRINT_VARIABLES` flag to `ON`. If you want to use
this as a CI variable only, you can set `NO_PRINT_VARIABLES` as a default of `ON` and override it for
CI builds only.

### Git

Git is a utility module that simply executes a handful of `git` commands within the project to set some
variables. This is primarily used when building a package to allow for setting some information about
the Git repository **within** the project (typically using a [`configure_file`](https://cmake.org/cmake/help/latest/command/configure_file.html)).

This process can be done nearly automatically using the [BuildPkg](#buildpkg) function. There is also
a basic `build_info.hpp.in` file within this directory that should serve as a starting point to a
"global" configuration file.

Once you've included this in your `CMakeLists.txt` file, you can expect to get the following variables:

- `GIT_BRANCH`: The branch (`abbrev-ref`) of the commit.
- `GIT_COMMIT_SHA`: The short (truncated) SHA of the commit ref.
- `GIT_COMMIT_SHA_FULL`: The full length SHA of the commit ref.
- `GIT_COMMIT_SUBJECT`: The subject (message) that was used for the commit.
- `GIT_COMMIT_AUTHOR_NAME`: The name that the Author used to submit the commit.
- `GIT_COMMIT_AUTHOR_EMAIL`: The email address that the Author used to submit the commit.
- `GIT_COMMIT_AUTHOR_DATE`: The date the Author submitted the commit.
- `GIT_TREE_DIRTY`: Checks if the tree is dirty when building. This should indicate if there are uncommited changes on the build.

These variables can be useful to get more complex diagnostics about a given build of the project at runtime.

### ClangCheck

> **TODO:** Document explicit use of `ClangCheck`.

This is used within the `BuildPkg` module during the build process to include `ClangCheck` on all projects.
If the `clang-check` binary is not installed on the system it will not be included in the build and the targets
will not be exposed.

You can manually install `clang-check` by downloading the [Latest LLVM Release](https://github.com/llvm/llvm-project/releases/latest). Currently, `clang-check` is a standalone executable that you can just add to your `PATH`.

### ClangFormat

> **TODO:** Document explicit use of `ClangFormat`.

This is used within the `BuildPkg` module during the build process to include `ClangFormat` on all projects.
If the `clang-format` binary is not installed on the system it will not be included in the build and the targets
will not be exposed.

You can manually install `clang-format` by downloading the [Latest LLVM Release](https://github.com/llvm/llvm-project/releases/latest). Currently, `clang-format` is a standalone executable that you can just add to your `PATH`.

### ClangTidy

> **TODO:** Document explicit use of `ClangTidy`.

This is used within the `BuildPkg` module during the build process to include `ClangTidy` on all projects.
If the `clang-tidy` binary is not installed on the system it will not be included in the build and the targets
will not be exposed.

You can manually install `clang-tidy` by downloading the [Latest LLVM Release](https://github.com/llvm/llvm-project/releases/latest). Currently, `clang-tidy` is a standalone executable that you can just add to your `PATH`.

### BuildPkg

The `BuildPkg` function is a complicated function built around creating consistent conventions for building and
testing code bases. This is designed to be convention first and the ability to override the configuration parameters
are either already present or will be updated at some point to be included.

This function makes some additional (and possibly unwanted) conventions. The primary convention that is likely to be
unwanted is how files are found. By default (when no `SOURCES` are provided) this will automatically find sources
using the `GLOB_RECURSE` and `CONFIGURE_DEPENDS` to find headers in `include/` and sources in `src/`. However, when
providing `SOURCES` this functionality isn't used at all.

> **Note:** [ClangCheck](#clangcheck), [ClangFormat](#clangformat), and [ClangTidy](#clangtidy) are all included
> by default when building with `BuildPkg`. The targets are added but not run by default so you don't currently
> need to include the Clang modules.

Instead of having many lines of configuration and system-specific compilation flags, this aims to simplify the user
experience of building libraries and executables by allowing just a single function call to build an entire package.

> **Note:** One of the biggest assumptions this (actually `TestPkg`) makes is that the testing will be done using
> [GTest](https://google.github.io/googletest/). These modules could be modified to allow for adding tests to CTest
> using a different testing framework. However, I almost always use GTest for testing since it includes some
> advanced testing features.

#### Configure Files

There are three different configure header files that can be added. There is a global one that can be set with `CMAKE_BUILD_INFO_CONFIG` (a path to a `.hpp.in` file relative to the SOURCE_DIR).
There are two additional ones that can be specified within each package:

- `include/${INCLUDE_PATH}.hpp.in`
- `src/${INCLUDE_PATH}.hpp.in`

#### Positional Parameters

- `<name>`: **(Required)** The name of the package to build. Usually passed in as `<name>` to either `add_library` or `add_executable`.

#### Single Value Parameters

These are the **single value** parameters that can be passed into the `BuildPkg` function:

- `PKG_TYPE`: The type of the package to be built. This is the same as `<type>` for `add_library` with the addition of the `EXE` type which will use `add_executable` instead. If not specified the default is `STATIC` or `SHARED` based on the value of the `BUILD_SHARED_LIBS` variable.
    - `STATIC`: An archive of object files for use when linking other targets.
    - `SHARED`: A dynamic library that may be linked by other targets and loaded at runtime.
    - `EXE`: An binary executable.
- `NO_TEST_PKG`: Should a testing target with the testing sources build be skipped? By default, this will build the test package for the package (value: `NO`).
- `NO_DOCS`: Should Doxygen documentation target be added for this package? By default, this will build the documentation for the package (value: `NO`).
- `TEST_PREFIX`: A prefix for the tests that are added to CTest. If no value is specified, this will use the value `${PKG_NAME}/`.
- `IDE_FOLDER`: If specified, the target will be put in an IDE folder. To use this you'll need to make sure you set folders to be used with: `set_property(GLOBAL PROPERTY USE_FOLDERS ON)`.
- `INCLUDE_PATH`: The name of the path to use for the include directory when using `configure_file`. (defaults to `PKG_NAME` when not specified)

#### Multi-Value Parameters

These are the **multi-value** parameters that can be passed into the `BuildPkg` function:

- `SOURCES`: A list of sources to use for the package build. If this is not specified, `GLOB_RECURSE` will be used along with `CONFIGURE_DEPENDS` to include header files in `include/` and source files in `src/`.
- `DOC_SOURCES`: A list of sources to include for documentation with Doxygen. If this is not specified, `GLOB_RECURSE` will be used along with `CONFIGURE_DEPENDS` to include `md` and `txt` files in `docs/` project subdirectory.
- `TEST_SOURCES`: A list of sources to include for the testing package. If this is not specified, `GLOB_RECURSE` will be used along with `CONFIGURE_DEPENDS` to include `hpp` and `cpp` files in the `tests/` project subdirectory.
- `PUBLIC_LINK_LIBRARIES`: A list of public libraries to link to the build.
- `PRIVATE_LINK_LIBRARIES`: A list of private libraries to link to the build.

#### Global Parameters

These parameters will globally enable, disable, or modify functionality for `BuildPkg`:

- `SKIP_GENERATE_DOXYGEN`: Allows for disabling the generation of documentation globally.
- `SKIP_CLANG_FORMAT`: Allows disabling the auto-included `clang_format` target.
- `SKIP_CLANG_CHECK`: Allows disabling the auto-included `clang_check` target.
- `SKIP_CLANG_TIDY`: Allows disabling the auto-included `clang_tidy` target.
- `SKIP_DEFAULT_TEST_PREFIX`: Allows disabling the **default** testing prefix of `${PKG_NAME}/`.
- `DOXYGEN_TARGET_SUFFIX`: Allow overriding the suffix for the Doxygen target (default suffix: `Doxygen`).

#### Examples

Minimal example:

```cmake
build_pkg(
    PKG_NAME MyLib
)
```

> This will create a `STATIC` or `SHARED` library (based on what you have set for `BUILD_SHARED_LIBS`) called
> `MyLib`. It will not contain any additional libraries (since none were specified). A documentation (Doxygen)
> target and tests (GTest) target will be included where the tests come from the `tests/` directory. It will also
> include `clang_format`, `clang_check`, and `clang_tidy` targets (both a version that will modify source and a
> "dry" version that will not).

Common example:

```cmake
build_pkg(
    PKG_NAME MyBin
    PKG_TYPE EXE
    PUBLIC_LINK_LIBRARIES
        spdlog::spdlog_header_only
    PRIVATE_LINK_LIBRARIES
        MyOtherPackage
)
```

> This will create an executable called `MyBin` with the `spdlog` library linked. This will **not** include a
> testing target but it **will** include documentation.

### TestPkg

> **TODO:** Document explicit use of `TestPkg`.

This is used within the `BuildPkg` module during the build process to include a testing package on all projects.
By default, `TestPkg` will look for test files in the `tests` subdirectory of the project. This can be overridden
globally by setting the `TEST_DIR_NAME` variable to the directory name where your tests are located.

#### Global Targets

These are global targets that are defined. They combine all of the project-specific targets (below) into a single target
that can be easily run for all targets:

- `TestAll`: Test all packages with this single target.
- `CoverAll`: Test all packages with coverage using this target.

#### Project Targets

These are the project specific targets that are defined:

- `<project_name>Test`: Run the tests for this project.
- `<project_name>Cover`: Run the tests with coverage for this project.

#### Customization

The following global variables exist to customize the functionality of the `TestPkg`

- `WITH_COVERAGE`: Defines if the coverage targets should be generated in the build. (default: `OFF`)
- `TEST_DIR_NAME`: Sets the project directory to search for tests in. (default: `tests`)
- `COVERAGE_DIR_NAME`: Sets the directory within the `CMAKE_BINARY_DIR` where coverage information is stored when running tests with coverage. (default: `coverage`)
- `TEST_TARGET_NAME`: Sets the global testing target name that runs all tests. (default: `TestAll`)
- `COVER_TARGET_NAME`: Sets the global coverage target name that runs all tests with coverage. (default `CoverAll`)
- `TEST_TARGET_SUFFIX`: Sets the suffix for testing targets for each package. (default: `Test`)
- `COVER_TARGET_SUFFIX`: Sets the suffix for testing targets with coverage for each package. (default: `Cover`)
- `WITH_LCOV_REPORT`: When enabled, this will generate an `lcov` report after running tests with coverage. This requires the `llvm-cov` binary within your `PATH` (on macOS it will use `xcrun`). (default: `OFF`)
- `WITH_HTML_REPORT`: When enabled, this will generate an `html` report after running tests with coverage. This requires the `llvm-cov` binary within your `PATH` (on macOS it will use `xcrun`). (default: `OFF`)
