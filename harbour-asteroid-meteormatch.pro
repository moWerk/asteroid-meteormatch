# Pure QML, no binary: sailfish-qml (libsailfishapp-launcher) runs
# qml/harbour-asteroid-meteormatch.qml, so one noarch package serves every architecture.
TEMPLATE = aux
TARGET = harbour-asteroid-meteormatch

CONFIG += sailfishapp_i18n sailfishapp_i18n_idbased sailfishapp_i18n_unfinished

qml.files = qml
qml.path = /usr/share/$${TARGET}
desktop.files = $${TARGET}.desktop
desktop.path = /usr/share/applications
INSTALLS += qml desktop

for(size, $$list(86x86 108x108 128x128 172x172)) {
    icon$${size}.files = icons/$${size}/$${TARGET}.png
    icon$${size}.path = /usr/share/icons/hicolor/$${size}/apps
    INSTALLS += icon$${size}
}

DISTFILES += qml/$${TARGET}.qml \
    $$files(qml/game/*) \
    rpm/$${TARGET}.spec \
    $${TARGET}.desktop

# qsTrId() with //% engineering English: the id based build keeps the
# unfinished entries, so the default .qm carries that English.
TRANSLATIONS += translations/harbour-asteroid-meteormatch.ts
