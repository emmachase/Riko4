cmake_minimum_required(VERSION 3.2)
project(riko4)

set($SDL2_gpu_PATH "${SDL2_gpu_PATH}" CACHE INTERNAL "SDL2_gpu" FORCE)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

file(GLOB_RECURSE SOURCE_FILES src/*.cpp src/*.c src/*.h)
add_executable(riko4 ${SOURCE_FILES})

set_target_properties(riko4 PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON)

find_package(SDL2 REQUIRED)

if (SDL2_FOUND)
    include_directories(${SDL2_INCLUDE_DIR})
    target_link_libraries(riko4 ${SDL2_LIBRARY})
endif ()

find_package(LuaJIT REQUIRED)

if (LUAJIT_FOUND)
    include_directories(${LUAJIT_INCLUDE_DIR})
    target_link_libraries(riko4 ${LUAJIT_LIBRARIES})
endif ()

find_package(SDL2_gpu REQUIRED)

if (SDL2_GPU_FOUND)
    include_directories(${SDL2_gpu_INCLUDE_DIR})
    target_link_libraries(riko4 ${SDL2_gpu_LIBRARY})
endif ()

find_package(CURL REQUIRED)

if (CURL_FOUND)
    include_directories(${CURL_INCLUDE_DIR})
    target_link_libraries(riko4 ${CURL_LIBRARY})
endif ()

find_package(CURLpp REQUIRED)

if (CURLPP_FOUND)
    include_directories(${CURLPP_INCLUDE_DIR})
    target_link_libraries(riko4 ${CURLPP_LIBRARY})
endif ()

include_directories(${CMAKE_SOURCE_DIR}/libs/include)
include_directories(${CMAKE_SOURCE_DIR}/src)

if (WIN32)
    target_link_libraries(riko4 ${CMAKE_SOURCE_DIR}/src/resources/icon.res)
endif ()

if (APPLE)
    set(myApp_ICON ${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.icns)
    set_source_files_properties(${myApp_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")

    set_target_properties(riko4 PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_ICON_FILE icon.icns
        MACOSX_BUNDLE_BUNDLE_NAME "Riko4"
    )

    target_sources(riko4 PRIVATE ${myApp_ICON})

    set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "Riko4")
endif ()

if (APPLE)
    install(TARGETS riko4 RUNTIME DESTINATION bin BUNDLE DESTINATION .)
else()
    install(TARGETS riko4 RUNTIME DESTINATION bin)
endif()
