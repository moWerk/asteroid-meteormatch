cmake_minimum_required(VERSION 3.6.0)

project(asteroid-meteormatch
    VERSION 0.1
    DESCRIPTION "A block-matching puzzle game for AsteroidOS")

find_package(ECM REQUIRED NO_MODULE)
find_package(AsteroidApp REQUIRED)

set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${ASTEROID_MODULE_PATH})

include(FeatureSummary)
include(GNUInstallDirs)
include(ECMFindQmlModule)
include(AsteroidCMakeSettings)
include(AsteroidTranslations)

build_translations(i18n)

add_executable(asteroid-meteormatch
    src/main.cpp
    src/GameStorage.cpp
    src/resources.qrc)

target_link_libraries(asteroid-meteormatch PRIVATE AsteroidApp)

install(TARGETS asteroid-meteormatch DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES asteroid-meteormatch.desktop
        DESTINATION /usr/share/applications/)
