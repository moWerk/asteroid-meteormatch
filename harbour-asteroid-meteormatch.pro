TARGET = harbour-asteroid-meteormatch

CONFIG += sailfishapp sailfishapp_i18n sailfishapp_i18n_idbased sailfishapp_i18n_unfinished

SOURCES += src/main.cpp \
    src/GameStorage.cpp

HEADERS += src/GameStorage.h

DISTFILES += qml/harbour-asteroid-meteormatch.qml \
    qml/game/*.qml \
    qml/game/qmldir \
    rpm/harbour-asteroid-meteormatch.spec \
    harbour-asteroid-meteormatch.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# The texts use qsTrId() with //% engineering English. The id based
# build turns that into harbour-asteroid-meteormatch.qm, which
# libsailfishapp loads as the default translation.
TRANSLATIONS += translations/harbour-asteroid-meteormatch.ts
