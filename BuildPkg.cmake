set(DOCS_DIR_NAME "docs" CACHE STRING "Directory for the documentation for Doxygen")
set(PUBLIC_DIR_NAME "include" CACHE STRING "Directory for the public (include) headers")
set(PRIVATE_DIR_NAME "src" CACHE STRING "Directory for the private source")
set(DOXYGEN_TARGET_SUFFIX "Doxygen" CACHE STRING "Suffix for the doxygen target")

include(ClangCheck)
include(ClangFormat)
include(ClangTidy)

find_package(Doxygen)

if (DOXYGEN_FOUND AND NOT SKIP_GENERATE_DOXYGEN)
  add_custom_target(GenerateDoxygen)
endif()

function(build_pkg)
  set(options "")
  set(oneValueArgs PKG_NAME PKG_TYPE NO_TEST_PKG NO_DOCS INCLUDE_PATH TEST_PREFIX IDE_FOLDER)
  set(multiValueArgs SOURCES TEST_SOURCES DOC_SOURCES PUBLIC_LINK_LIBRARIES PRIVATE_LINK_LIBRARIES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(PKG_NAME ${ARG_PKG_NAME})

  if(NOT ARG_IDE_FOLDER)
    set(ARG_IDE_FOLDER ${PKG_NAME})
  endif()

  if(ARG_INCLUDE_PATH)
    set(INCLUDE_PATH ${ARG_INCLUDE_PATH})
  else()
    set(INCLUDE_PATH ${PKG_NAME})
  endif()

  if (NOT ARG_SOURCES)
    file(GLOB_RECURSE ARG_SOURCES CONFIGURE_DEPENDS
      ${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/*.hpp
      ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/*.hpp
      ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/*.cpp
    )
  endif()

    # # Configure the passed string to allow replacing variables within the output path
    # # this is usually @PKG_NAME@
    # string(CONFIGURE ${CMAKE_BUILD_INFO_CONFIG_OUT} CMAKE_BUILD_INFO_CONFIG_OUT_PATH)

  # Include a global configuration header if it exists
  if(CMAKE_BUILD_INFO_CONFIG AND EXISTS "${CMAKE_SOURCE_DIR}/${CMAKE_BUILD_INFO_CONFIG}")
    # get the name of the file directly and drop the .in
    cmake_path(GET CMAKE_BUILD_INFO_CONFIG FILENAME CMAKE_BUILD_INFO_FILENAME)
    cmake_path(REMOVE_EXTENSION CMAKE_BUILD_INFO_FILENAME LAST_ONLY)

    configure_file(
      "${CMAKE_SOURCE_DIR}/${CMAKE_BUILD_INFO_CONFIG}"
      "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${ARG_INCLUDE_PATH}/${CMAKE_BUILD_INFO_FILENAME}"
    )

    list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${ARG_INCLUDE_PATH}/${CMAKE_BUILD_INFO_FILENAME}")
  else()
    message(STATUS "[${PKG_NAME}] Not including build info header.")
  endif()

  # Include a public configuration header if it exists
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/${PKG_NAME}.hpp.in")
    configure_file(
      "${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/${INCLUDE_PATH}.hpp.in"
      "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${INCLUDE_PATH}.hpp"
    )

    list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${INCLUDE_PATH}.hpp")
  endif()

  # Include a private configuration header if it exists
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp.in")
    configure_file(
      "${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp.in"
      "${CMAKE_CURRENT_BINARY_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp"
    )

    list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp")
  endif()

  if("${ARG_PKG_TYPE}" STREQUAL "EXE")
    add_executable(${PKG_NAME} ${ARG_SOURCES})
  else()
    add_library(${PKG_NAME} ${ARG_PKG_TYPE} ${ARG_SOURCES})
  endif()

  if(ARG_IDE_FOLDER)
    set_target_properties(${PKG_NAME} PROPERTIES FOLDER ${ARG_IDE_FOLDER})
  endif()

  target_include_directories(${PKG_NAME}
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}>
      $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}>
    PRIVATE
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}>
      $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${PRIVATE_DIR_NAME}>
  )

  target_compile_options(${PKG_NAME} PRIVATE
    $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:AppleClang>,$<CXX_COMPILER_ID:GNU>>:
      -Wall -Werror -pedantic-errors -Wextra -Wconversion -Wsign-conversion
    >
    $<$<CXX_COMPILER_ID:MSVC>:
      /W4 /WX
    >
  )

  target_link_libraries(${PKG_NAME}
    PUBLIC
      ${ARG_PUBLIC_LINK_LIBRARIES}

    PRIVATE
      ${ARG_PRIVATE_LINK_LIBRARIES}
  )

  # Create documentation if DOXYGEN is installed and we should be adding docs for this package
  if (DOXYGEN_FOUND AND (NOT SKIP_GENERATE_DOXYGEN) AND (NOT ARG_NO_DOCS))
    set(DOXYGEN_PROJECT_NAME "${PKG_NAME}")
    set(DOXYGEN_PROJECT_BRIEF "API Documentation for ${PROJECT_NAME}::${PKG_NAME} (${GIT_BRANCH}@${GIT_COMMIT_SHA})")
    set(DOXYGEN_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/doxygen/${PKG_NAME})

    set(DOXYGEN_SOURCES "${ARG_SOURCES}")

    if (NOT ARG_DOC_SOURCES)
      file(GLOB_RECURSE ARG_DOC_SOURCES CONFIGURE_DEPENDS
        # include README files within source and headers
        ${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/README.md
        ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/README.md

        # include markdown and text files within the docs folder
        ${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/*.md
        ${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/*.markdown
        ${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/*.txt
      )
    endif()
    list(APPEND DOXYGEN_SOURCES ${ARG_DOC_SOURCES})

    # if there is a README.md at the root of docs, use it as teh MAINPAGE
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/README.md")
      set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/README.md")
      message(STATUS "Using ${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/README.md for mainpage")
    endif()

    # If there is a top-level README file, include it as well.
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
      list(APPEND DOXYGEN_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/README.md")

      # if there isn't a mainpage yet, use the README
      if(NOT DOXYGEN_USE_MDFILE_AS_MAINPAGE)
        set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
      endif()
    endif()

    # if there is a stylesheet.css use it as the Doxygen header
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/stylesheet.css")
      set(DOXYGEN_HTML_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/stylesheet.css")
    endif()

    # if there is a header.html use it as the Doxygen header
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/header.html")
      set(DOXYGEN_HTML_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/header.html")
    endif()

    # if there is a footer.html use it as the Doxygen footer
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/footer.html")
      set(DOXYGEN_HTML_FOOTER "${CMAKE_CURRENT_SOURCE_DIR}/${DOCS_DIR_NAME}/footer.html")
    endif()

    # add the doxygen target and set its folder
    doxygen_add_docs("${PKG_NAME}${DOXYGEN_TARGET_SUFFIX}" ${DOXYGEN_SOURCES})
    set_target_properties("${PKG_NAME}${DOXYGEN_TARGET_SUFFIX}" PROPERTIES FOLDER ${ARG_IDE_FOLDER})

    # create the doxygen directory before building docs
    add_custom_command(
      TARGET ${PKG_NAME}${DOXYGEN_TARGET_SUFFIX} PRE_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DOXYGEN_OUTPUT_DIRECTORY}
      BYPRODUCTS ${DOXYGEN_OUTPUT_DIRECTORY}
    )

    add_dependencies(GenerateDoxygen "${PKG_NAME}${DOXYGEN_TARGET_SUFFIX}")
  endif()

  # Add the test package if it's not excluded from this package
  if (NOT ARG_NO_TEST_PKG AND (NOT "${ARG_PKG_TYPE}" STREQUAL "EXE"))
    # Add code coverage flags if building in test mode and not an executable
    if (${WITH_COVERAGE})
      target_compile_options(${PKG_NAME} PRIVATE -fprofile-instr-generate -fcoverage-mapping)
      target_link_libraries(${PKG_NAME} PRIVATE -fprofile-instr-generate -fcoverage-mapping)
    endif()

    if(NOT ARG_TEST_PREFIX AND NOT SKIP_DEFAULT_TEST_PREFIX)
      set(ARG_TEST_PREFIX "${PKG_NAME}/")
    endif()

    # Add the testing package target
    test_pkg(
      PKG_NAME ${PKG_NAME}
      TEST_PREFIX ${ARG_TEST_PREFIX}
      IDE_FOLDER ${ARG_IDE_FOLDER}
      SOURCES ${ARG_TEST_SOURCES}
    )
  endif()

  if(NOT SKIP_CLANG_FORMAT)
    clang_format(PKG_NAME ${PKG_NAME} SOURCES ${ARG_SOURCES} IDE_FOLDER ${ARG_IDE_FOLDER}/Clang)
  endif()

  if(NOT SKIP_CLANG_CHECK)
    clang_check(PKG_NAME ${PKG_NAME} SOURCES ${ARG_SOURCES} IDE_FOLDER ${ARG_IDE_FOLDER}/Clang)
  endif()

  if(NOT SKIP_CLANG_TIDY)
    clang_tidy(PKG_NAME ${PKG_NAME} SOURCES ${ARG_SOURCES} IDE_FOLDER ${ARG_IDE_FOLDER}/Clang)
  endif()
endfunction()
