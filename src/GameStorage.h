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

#ifndef GAMESTORAGE_H
#define GAMESTORAGE_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QQmlEngine>

class GameStorage : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int    score     READ score     WRITE setScore     NOTIFY scoreChanged)
    Q_PROPERTY(int    highScore READ highScore WRITE setHighScore NOTIFY highScoreChanged)
    Q_PROPERTY(QString board    READ board     WRITE setBoard     NOTIFY boardChanged)
    Q_PROPERTY(bool   dirty     READ dirty     WRITE setDirty     NOTIFY dirtyChanged)
    Q_PROPERTY(QString pendingTap READ pendingTap WRITE setPendingTap NOTIFY pendingTapChanged)

public:
    explicit GameStorage(QObject *parent = nullptr);
    static GameStorage *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    int     score()      const;
    int     highScore()  const;
    QString board()      const;
    bool    dirty()      const;
    QString pendingTap() const;

    void setScore(int v);
    void setHighScore(int v);
    void setBoard(const QString &v);
    void setDirty(bool v);
    void setPendingTap(const QString &v);

    Q_INVOKABLE void clear();
    Q_INVOKABLE QString fileName() const;

signals:
    void scoreChanged();
    void highScoreChanged();
    void boardChanged();
    void dirtyChanged();
    void pendingTapChanged();

private:
    QSettings m_settings;
};

#endif // GAMESTORAGE_H
