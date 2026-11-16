import QtQuick
import Noon.Utils.Latex

// Loaded dynamically by LatexService so the shell still starts when the
// optional Noon.Utils.Latex module is not built.
LatexRenderer {
    width: 0
    height: 0
    visible: false
}
