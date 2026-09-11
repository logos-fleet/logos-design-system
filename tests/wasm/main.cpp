// Loads a QML document that imports Logos.Theme and Logos.Controls. In wasm the
// scene needs a canvas, so this is not run here — what the build proves is that
// the document COMPILES against the design system's type set and that the image
// links with the static QML plugins in it (nix/wasm-smoke.nix reads the
// registration symbols back off the wasm).
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    qInfo("logos-ds-wasm-smoke: starting");

    QQmlApplicationEngine engine;
    engine.loadFromModule("LogosDesignSystemWasmSmoke", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
