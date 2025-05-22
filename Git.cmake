# Current branch for the commit
execute_process(
    COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Commit SHA (truncated) for the commit
execute_process(
    COMMAND git log -1 --format=%h
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_SHA
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Full Commit SHA value for the commit
execute_process(
    COMMAND git log -1 --format=%H
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_SHA_FULL
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Name of the Author for the commit
execute_process(
    COMMAND git log -1 --format=%an
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_AUTHOR_NAME
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Email of the Author for the commit
execute_process(
    COMMAND git log -1 --format=%ae
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_AUTHOR_EMAIL
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Date (and time) the Author submitted the commit
execute_process(
    COMMAND git log -1 --format=%ad
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_AUTHOR_DATE
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Commit subject (message)
execute_process(
    COMMAND git log -1 --format=%s
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_SUBJECT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Checks if the tree is dirty when building
execute_process(
    COMMAND git diff-index --quiet HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    RESULT_VARIABLE GIT_TREE_DIRTY
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
