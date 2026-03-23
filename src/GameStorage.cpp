/*
 * Copyright (C) 2026 - Timo Könnecke <github.com/moWerk>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "GameStorage.h"
#include <QDir>
#include <QStandardPaths>

static GameStorage *s_instance = nullptr;

GameStorage::GameStorage(QObject *parent)
: QObject(parent)
// Explicit path — avoids HOME ambiguity in Lipstick session environment.
// QSettings creates the directory on first sync() if it doesn't exist.
, m_settings(
    QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
    + QStringLiteral("/.config/asteroid-meteormatch/game.ini"),
             QSettings::IniFormat)
{
    // Ensure config directory exists before any write
    QDir().mkpath(
        QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
        + QStringLiteral("/.config/asteroid-meteormatch"));
    s_instance = this;
}

GameStorage *GameStorage::instance()
{
    if (!s_instance)
        s_instance = new GameStorage();
    return s_instance;
}

QObject *GameStorage::qmlInstance(QQmlEngine *, QJSEngine *)
{
    return instance();
}

// ── Getters ──────────────────────────────────────────────────────────────────

int GameStorage::score() const
{
    return m_settings.value(QStringLiteral("score"), 0).toInt();
}

int GameStorage::highScore() const
{
    return m_settings.value(QStringLiteral("highScore"), 0).toInt();
}

QString GameStorage::board() const
{
    return m_settings.value(QStringLiteral("board"), QString()).toString();
}

bool GameStorage::dirty() const
{
    return m_settings.value(QStringLiteral("dirty"), false).toBool();
}

QString GameStorage::pendingTap() const
{
    return m_settings.value(QStringLiteral("pendingTap"), QString()).toString();
}

// ── Setters — QSettings::sync() called after every write ────────────────────
// sync() flushes to disk immediately, safe against power loss.

void GameStorage::setScore(int v)
{
    m_settings.setValue(QStringLiteral("score"), v);
    m_settings.sync();
    emit scoreChanged();
}

void GameStorage::setHighScore(int v)
{
    if (v <= highScore()) return;   // never lower the high score
    m_settings.setValue(QStringLiteral("highScore"), v);
    m_settings.sync();
    emit highScoreChanged();
}

void GameStorage::setBoard(const QString &v)
{
    m_settings.setValue(QStringLiteral("board"), v);
    m_settings.sync();
    emit boardChanged();
}

void GameStorage::setDirty(bool v)
{
    m_settings.setValue(QStringLiteral("dirty"), v);
    m_settings.sync();
    emit dirtyChanged();
}

void GameStorage::setPendingTap(const QString &v)
{
    m_settings.setValue(QStringLiteral("pendingTap"), v);
    m_settings.sync();
    emit pendingTapChanged();
}

QString GameStorage::fileName() const
{
    return m_settings.fileName();
}

void GameStorage::clear()
{
    m_settings.setValue(QStringLiteral("board"),      QString());
    m_settings.setValue(QStringLiteral("score"),      0);
    m_settings.setValue(QStringLiteral("pendingTap"), QString());
    m_settings.setValue(QStringLiteral("dirty"),      false);
    m_settings.sync();
    emit boardChanged();
    emit scoreChanged();
    emit pendingTapChanged();
    emit dirtyChanged();
}
