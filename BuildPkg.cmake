# ######################################################################### #
# Define User-Modifiable Global Variables                                   #
# ######################################################################### #
set(DOCS_DIR_NAME "docs" CACHE STRING "Directory for the documentation for Doxygen")
set(PUBLIC_DIR_NAME "include" CACHE STRING "Directory for the public (include) headers")
set(PRIVATE_DIR_NAME "src" CACHE STRING "Directory for the private source")
set(EXAMPLES_DIR_NAME "examples" CACHE STRING "Directory for the examples")
set(EXAMPLE_TARGET_NAME_FILE "TARGET_NAME" CACHE STRING "File in the example directory that contains the name of the example target name")
set(DOXYGEN_TARGET_SUFFIX "Doxygen" CACHE STRING "Suffix for the doxygen target")
set(CMAKE_BUILD_INFO_CONFIG "${CMAKE_CURRENT_LIST_DIR}/build_info.hpp.in" CACHE STRING "Global Build Information Header")
set(BUILD_PKG_API_HEADER_NAME "api.hpp" CACHE STRING "The file name to use for the shared library API header file")
set(CMAKE_BUILD_INFO_HEADER_NAME "build_info.hpp" CACHE STRING "The file name to use for the build info header file")

# TODO: RENAME CMAKE_BUILD* to BUILD_PKG*
# TODO: add BUILD_PKG prefix to other variables

include(ClangCheck)
include(ClangFormat)
include(ClangTidy)

set(BUILD_PKG_TOOLS_DIR ${CMAKE_CURRENT_LIST_DIR})

# ######################################################################### #
# Find Doxygen and Include Target                                           #
# ######################################################################### #
find_package(Doxygen)
if (DOXYGEN_FOUND AND NOT SKIP_GENERATE_DOXYGEN)
  add_custom_target(GenerateDoxygen FOLDER Utility)
endif()

function(build_pkg)
  set(options "")
  set(oneValueArgs PKG_NAME PKG_TYPE NO_TEST_PKG NO_DOCS NO_EXAMPLES INCLUDE_PATH TEST_PREFIX IDE_FOLDER)
  set(multiValueArgs SOURCES TEST_SOURCES DOC_SOURCES PUBLIC_LINK_LIBRARIES PRIVATE_LINK_LIBRARIES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(PKG_NAME ${ARG_PKG_NAME})
  string(TOUPPER "${PKG_NAME}" UPPER_PKG_NAME)

  if(NOT ARG_IDE_FOLDER)
    # Set the default IDE_FOLDER to the local dir
    string(REPLACE "${CMAKE_SOURCE_DIR}/" "" ARG_IDE_FOLDER "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  if(ARG_INCLUDE_PATH)
    set(INCLUDE_PATH ${ARG_INCLUDE_PATH})
  else()
    set(INCLUDE_PATH ${PKG_NAME})
  endif()

  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY $<1:${CMAKE_CURRENT_BINARY_DIR}>)

  if (NOT ARG_SOURCES)
    file(GLOB_RECURSE PUBLIC_SOURCES CONFIGURE_DEPENDS
      ${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/*.h
      ${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/*.hpp    
    )

    file(GLOB_RECURSE PRIVATE_SOURCES CONFIGURE_DEPENDS
      ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/*.h
      ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/*.c

      ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/*.hpp
      ${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/*.cpp
    )

    list(APPEND ARG_SOURCES ${PUBLIC_SOURCES})
    list(APPEND ARG_SOURCES ${PRIVATE_SOURCES})
  endif()

    # # Configure the passed string to allow replacing variables within the output path
    # # this is usually @PKG_NAME@
    # string(CONFIGURE ${CMAKE_BUILD_INFO_CONFIG_OUT} CMAKE_BUILD_INFO_CONFIG_OUT_PATH)

  # ######################################################################### #
  # Include Global Configuration Header (if defined and exists)               #
  # ######################################################################### #
  if(CMAKE_BUILD_INFO_CONFIG)
    if(EXISTS "${CMAKE_BUILD_INFO_CONFIG}")
      set(PKG_BUILD_INFO_CONFIG_FILE "${CMAKE_BUILD_INFO_CONFIG}")
    elseif(EXISTS "${CMAKE_SOURCE_DIR}/${CMAKE_BUILD_INFO_CONFIG}")
      set(PKG_BUILD_INFO_CONFIG_FILE "${CMAKE_SOURCE_DIR}/${CMAKE_BUILD_INFO_CONFIG}")
    endif()

    if(PKG_BUILD_INFO_CONFIG_FILE)
      # get the name of the file directly and drop the .in
      # cmake_path(GET CMAKE_BUILD_INFO_CONFIG FILENAME CMAKE_BUILD_INFO_FILENAME)
      # cmake_path(REMOVE_EXTENSION CMAKE_BUILD_INFO_FILENAME LAST_ONLY)

      configure_file(
        "${PKG_BUILD_INFO_CONFIG_FILE}"
        "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${ARG_INCLUDE_PATH}/${CMAKE_BUILD_INFO_HEADER_NAME}"
      )

      list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${ARG_INCLUDE_PATH}/${CMAKE_BUILD_INFO_HEADER_NAME}")
    else()
      message(WARNING "[${PKG_NAME}] CMAKE_BUILD_INFO_CONFIG defined but no file found! (${CMAKE_BUILD_INFO_CONFIG})")
    endif()
  else()
    message(STATUS "[${PKG_NAME}] Not including build info header.")
  endif()

  # ######################################################################### #
  # Include Public Configuration Header (if exists)                           #
  # ######################################################################### #
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/${PKG_NAME}.hpp.in")
    configure_file(
      "${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/${INCLUDE_PATH}.hpp.in"
      "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${INCLUDE_PATH}.hpp"
    )

    list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${INCLUDE_PATH}.hpp")
  endif()

  # ######################################################################### #
  # Include Private Configuration Header (if exists)                          #
  # ######################################################################### #
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp.in")
    configure_file(
      "${CMAKE_CURRENT_SOURCE_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp.in"
      "${CMAKE_CURRENT_BINARY_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp"
    )

    list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PRIVATE_DIR_NAME}/${INCLUDE_PATH}.hpp")
  endif()

  # ######################################################################### #
  # Configure API Header File (for shared libraries)                          #
  # ######################################################################### #
  configure_file(${BUILD_PKG_TOOLS_DIR}/api.hpp.in ${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${BUILD_PKG_API_HEADER_NAME})
  list(APPEND ARG_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${PUBLIC_DIR_NAME}/${BUILD_PKG_API_HEADER_NAME}")

  # ######################################################################### #
  # Add Executable/Library Target                                             #
  # ######################################################################### #
  if("${ARG_PKG_TYPE}" STREQUAL "EXE")
    add_executable(${PKG_NAME} ${ARG_SOURCES})
  else()
    add_library(${PKG_NAME} ${ARG_PKG_TYPE} ${ARG_SOURCES})
  endif()

  # ######################################################################### #
  # Configure Shared Library Options                                          #
  # ######################################################################### #
  if("${ARG_PKG_TYPE}" STREQUAL "SHARED")
    set_target_properties(
      ${PKG_NAME} PROPERTIES
      VERSION ${PROJECT_VERSION}
      SOVERSION ${PROJECT_VERSION}
      PUBLIC_HEADER ${PUBLIC_SOURCES}
    )

    target_compile_definitions(${PKG_NAME} PRIVATE "${UPPER_PKG_NAME}_BUILD")
    target_include_directories(${PKG_NAME} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME})

    # install(TARGETS ${PKG_NAME}
    #   LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    #   PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    # )

    # if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/${PKG_NAME}.pc.in")
    #   set(PKG_PC_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${PUBLIC_DIR_NAME}/${PKG_NAME}.pc.in")
    # else()
    #   set(PKG_PC_FILE "${BUILD_PKG_TOOLS_DIR}/lib.pc.in")
    # endif()

    # configure_file(${PKG_PC_FILE} "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}.pc" @ONLY)
    # install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}.pc" DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/pkgconfig)
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

  # ######################################################################### #
  # Add Documentation (Doxygen)                                               #
  # ######################################################################### #
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

  # ######################################################################### #
  # Add Examples                                                              #
  # ######################################################################### #
  if (NOT ARG_NO_EXAMPLES AND EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${EXAMPLES_DIR_NAME}/)
    file(GLOB EXAMPLE_DIRS LIST_DIRECTORIES YES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${EXAMPLES_DIR_NAME}/*)
    foreach(EXAMPLE_DIR IN ITEMS ${EXAMPLE_DIRS})
      cmake_path(GET EXAMPLE_DIR STEM LAST_ONLY EXAMPLE_NAME)
      file(GLOB_RECURSE EXAMPLE_SOURCES CONFIGURE_DEPENDS
        ${EXAMPLE_DIR}/*.hpp
        ${EXAMPLE_DIR}/*.cpp
      )

      if(EXISTS ${EXAMPLE_DIR}/TARGET_NAME)
        file(READ ${EXAMPLE_DIR}/TARGET_NAME EXAMPLE_PKG_NAME)
        string(STRIP ${EXAMPLE_PKG_NAME} EXAMPLE_PKG_NAME)
      else()
        set(EXAMPLE_PKG_NAME ${EXAMPLE_NAME})
      endif()

      build_pkg(
        PKG_NAME ${EXAMPLE_PKG_NAME}
        PKG_TYPE EXE
        NO_TEST_PKG ON
        NO_DOCS ON
        NO_EXAMPLES ON
        IDE_FOLDER ${ARG_IDE_FOLDER}/Examples
        SOURCES ${EXAMPLE_SOURCES}
        PRIVATE_LINK_LIBRARIES ${PKG_NAME}
      )
    endforeach()
  endif()

  # ######################################################################### #
  # Add Test Package                                                          #
  # ######################################################################### #
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

  # ######################################################################### #
  # Add Clang Tools                                                           #
  # ######################################################################### #
  if(NOT SKIP_CLANG_FORMAT)
    clang_format(PKG_NAME ${PKG_NAME} SOURCES ${ARG_SOURCES} IDE_FOLDER ${ARG_IDE_FOLDER})
  endif()

  if(NOT SKIP_CLANG_CHECK)
    clang_check(PKG_NAME ${PKG_NAME} SOURCES ${ARG_SOURCES} IDE_FOLDER ${ARG_IDE_FOLDER})
  endif()

  if(NOT SKIP_CLANG_TIDY)
    clang_tidy(PKG_NAME ${PKG_NAME} SOURCES ${ARG_SOURCES} IDE_FOLDER ${ARG_IDE_FOLDER})
  endif()
endfunction()
