####
# AC_Utils.cmake:
#
# Defines needed utility functions that are (or should be) dependent on any autocoding calls to
# be made. Other utilites should go in *Utils.cmake*.
####

###
# Function `cheetah`:
#
# This function sets up the ability to call cheetah to compile chetah templates and prepare them for use
# within the auto-coder. Here we setup the "compilation" of Cheetah templates.
#
# TODO: when/if the autocoder stops depending on generated templates, this function may be removed. Otherwise,
# this must be updated to remove cheetah dependence for whatever new templating engine is used.
#
# - **CHEETAH_TEMPLATES:** list of cheetah templates
##
function(cheetah CHEETAH_TEMPLATES)
  # Derive output file names, which will be added as dependencies for the code generation step. This
  # forces cheetah templates to be compiled and up-to-date before running the auto-coder.
  string(REPLACE ".tmpl" ".py" PYTHON_TEMPLATES "${CHEETAH_TEMPLATES}")
  # Setup the cheetah-compile command that runs the physical compile of the above statement. This
  # controls the work to be done to create PYTHON_TEMPLATES from ${CHEETAH_TEMPLATES.
  find_program(CHEETAH_EXE NAMES "cheetah-compile" "cheetah-compile3")
  add_custom_command(
    OUTPUT ${PYTHON_TEMPLATES}
    COMMAND ${CHEETAH_EXE} ${CHEETAH_TEMPLATES}
    DEPENDS ${CHEETAH_TEMPLATES}
  )
  # Add the above PYTHON_TEMPLATES to the list of sources for the CODEGEN_TARGET target. Thus they will be
  # built as dependencies for the CODEGEN step.
  set_property(GLOBAL APPEND PROPERTY CODEGEN_OUTPUTS ${PYTHON_TEMPLATES})
endfunction(cheetah)

####
# Function `serialns`:
#
# Execute a command and set the serial namespace variable in "SERIAL_NS" parent. This allows us to
# predict the output files generated by the python dictionary generator.
#
# - **AI_XML:** path to AI XML used for serializable parsing
# - **Return: SERIAL_NS** (set in outer scope)
####
function(serialns AI_XML)
    # Executes while CMake is running
    execute_process(
        COMMAND ${FPRIME_FRAMEWORK_PATH}/cmake/support/parser/serializable_xml_ns.py "${AI_XML}"
        RESULT_VARIABLE ERR_RETURN
        OUTPUT_VARIABLE NS
    )
    if (${ERR_RETURN})
        message(FATAL_ERROR "${FPRIME_FRAMEWORK_PATH}/cmake/parser/serializable_xml_ns.py ${AI_XML} failed.")
    endif()
    set(SERIAL_NS "${NS}" PARENT_SCOPE)
endfunction(serialns)


####
# Function `acwrap`:
#
# This function wraps the actual call to the autocoder in order to ensure that the functions are
# performed correctly. This replaces a wrapper shell in order to step toward Windows support. This
# function registers the autocoding steps specific to `codegen.py`.
#
# Note: as the autocoder is rewritten, this will likely need to change.
#
# - **AC_TYPE:** serializable, port, component, or topology
# - **AC_FINAL_SOURCE:** final position of the CPP file
# - **AC_FINAL_HEADER:** final position of the HPP file
# - **AI_XML:** AI xml input to autocoder
# - **XML_FILE_DEPS:** xml file dependencies
# - **MOD_DEPS:** xml and hand specidied module dependencies
# - **Return: AC_OUTPUTS** (set in outer scope)
####
function(acwrap AC_TYPE AC_FINAL_SOURCE AC_FINAL_HEADER AI_XML XML_FILE_DEPS MOD_DEPS)
  # Setup the list such that new outputs can be appended to them
  set(OUTPUT_PRODUCTS "${AC_FINAL_SOURCE}" "${AC_FINAL_HEADER}")

  if(${AC_TYPE} STREQUAL "topologyapp")
    set(GEN_ARGS "--build_root" "--connect_only" "--xml_topology_dict")
  else()
    set(GEN_ARGS "--build_root")
  endif()
  # There are two places that files may appear. In-source and out-of-source. In-source generation must happen
  # due to limitations in the autocoder, and thus the files must be moved after generation in the secondary
  # variant of this command.
  get_filename_component(CPP_NAME ${AC_FINAL_SOURCE} NAME)
  get_filename_component(HPP_NAME ${AC_FINAL_HEADER} NAME)
  #Setup the output directory
  get_filename_component(TO_MK_DIR ${AC_FINAL_SOURCE} DIRECTORY)
  if (NOT "${TO_MK_DIR}" STREQUAL "${CMAKE_CURRENT_BINARY_DIR}")
      message(FATAL_ERROR "Output directory: ${TO_MK_DIR} differs from expected output directory ${CMAKE_CURRENT_BINARY_DIR}")
  endif()
  string(REPLACE ";" ":" FPRIME_BUILD_LOCATIONS_SEP "${FPRIME_BUILD_LOCATIONS}")
  add_custom_command(
      OUTPUT  ${OUTPUT_PRODUCTS}
      COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_CURRENT_SOURCE_DIR}
      ${CMAKE_COMMAND} -E env PYTHONPATH=${PYTHON_AUTOCODER_DIR}/src:${PYTHON_AUTOCODER_DIR}/utils BUILD_ROOT="${FPRIME_BUILD_LOCATIONS_SEP}"
      FPRIME_AC_CONSTANTS_FILE="${FPRIME_AC_CONSTANTS_FILE}"
      PYTHON_AUTOCODER_DIR=${PYTHON_AUTOCODER_DIR} DICTIONARY_DIR=${DICTIONARY_DIR}
      ${FPRIME_FRAMEWORK_PATH}/Autocoders/Python/bin/codegen.py ${GEN_ARGS} ${AI_XML}
      COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_COMMAND} -E copy ${CPP_NAME} ${HPP_NAME} ${CMAKE_CURRENT_BINARY_DIR}
      COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_COMMAND} -E remove ${CPP_NAME} ${HPP_NAME}
      DEPENDS ${AI_XML} ${XML_FILE_DEPS} ${FPRIME_AC_CONSTANTS_FILE} ${MOD_DEPS}
  )
  set(AC_OUTPUTS ${OUTPUT_PRODUCTS} PARENT_SCOPE)
endfunction(acwrap)
