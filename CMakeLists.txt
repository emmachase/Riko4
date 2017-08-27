cmake_minimum_required(VERSION 3.2)
project(riko4)

if(APPLE)
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-pagezero_size 10000 -image_base 100000000")
endif()

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

file(GLOB_RECURSE SOURCE_FILES src/*.cpp src/*.c)
add_executable(riko4 ${SOURCE_FILES}) 

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(SDL2 REQUIRED)

if(SDL2_FOUND)
    include_directories(${SDL2_INCLUDE_DIR})
    target_link_libraries(riko4 ${SDL2_LIBRARY})
endif()

find_package(LuaJIT REQUIRED)

if(LUAJIT_FOUND)
    include_directories(${LUAJIT_INCLUDE_DIR})
    target_link_libraries(riko4 ${LUAJIT_LIBRARIES})
endif()

include_directories(${CMAKE_SOURCE_DIR}/libs/include)
