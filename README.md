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

### ClangFormat

### ClangTidy

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
- `DOC_SOURCES`: A list of sources to include for documentation with Doxygen. If this is not specified, `GLOB_RECURSE` will be used along with `CONFIGURE_DEPENDS` to include header files in `docs/`.
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
