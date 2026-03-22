add_library(asteroid-meteormatch main.cpp resources.qrc)
set_target_properties(asteroid-meteormatch PROPERTIES PREFIX "" SUFFIX "")

target_link_libraries(asteroid-meteormatch PUBLIC
    AsteroidApp)

install(TARGETS asteroid-meteormatch
    DESTINATION ${CMAKE_INSTALL_BINDIR})
