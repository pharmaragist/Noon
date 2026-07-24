import qs.common.widgets.shapes
import "shapes/material-shapes.js" as MaterialShapes

ShapeCanvas {
    id: root

    enum Shape {
        Circle,
        Square,
        Slanted,
        Arch,
        Fan,
        Arrow,
        SemiCircle,
        Oval,
        Pill,
        Triangle,
        Diamond,
        ClamShell,
        Pentagon,
        Gem,
        Sunny,
        VerySunny,
        Cookie4Sided,
        Cookie6Sided,
        Cookie7Sided,
        Cookie9Sided,
        Cookie12Sided,
        Ghostish,
        Clover4Leaf,
        Clover8Leaf,
        Burst,
        SoftBurst,
        Boom,
        SoftBoom,
        Flower,
        Puffy,
        PuffyDiamond,
        PixelCircle,
        PixelTriangle,
        Bun,
        Heart
    }
    property string _shape: "Clover4Leaf"
    property var shape: MaterialShape.Shape[_shape]
    property double implicitSize

    implicitHeight: implicitSize
    implicitWidth: implicitSize
    polygonIsNormalized: true
    roundedPolygon: {
        const dict = {
            [MaterialShape.Shape.Circle]: MaterialShapes.getCircle(),
            [MaterialShape.Shape.Square]: MaterialShapes.getSquare(),
            [MaterialShape.Shape.Slanted]: MaterialShapes.getSlanted(),
            [MaterialShape.Shape.Arch]: MaterialShapes.getArch(),
            [MaterialShape.Shape.Fan]: MaterialShapes.getFan(),
            [MaterialShape.Shape.Arrow]: MaterialShapes.getArrow(),
            [MaterialShape.Shape.SemiCircle]: MaterialShapes.getSemiCircle(),
            [MaterialShape.Shape.Oval]: MaterialShapes.getOval(),
            [MaterialShape.Shape.Pill]: MaterialShapes.getPill(),
            [MaterialShape.Shape.Triangle]: MaterialShapes.getTriangle(),
            [MaterialShape.Shape.Diamond]: MaterialShapes.getDiamond(),
            [MaterialShape.Shape.ClamShell]: MaterialShapes.getClamShell(),
            [MaterialShape.Shape.Pentagon]: MaterialShapes.getPentagon(),
            [MaterialShape.Shape.Gem]: MaterialShapes.getGem(),
            [MaterialShape.Shape.Sunny]: MaterialShapes.getSunny(),
            [MaterialShape.Shape.VerySunny]: MaterialShapes.getVerySunny(),
            [MaterialShape.Shape.Cookie4Sided]: MaterialShapes.getCookie4Sided(),
            [MaterialShape.Shape.Cookie6Sided]: MaterialShapes.getCookie6Sided(),
            [MaterialShape.Shape.Cookie7Sided]: MaterialShapes.getCookie7Sided(),
            [MaterialShape.Shape.Cookie9Sided]: MaterialShapes.getCookie9Sided(),
            [MaterialShape.Shape.Cookie12Sided]: MaterialShapes.getCookie12Sided(),
            [MaterialShape.Shape.Ghostish]: MaterialShapes.getGhostish(),
            [MaterialShape.Shape.Clover4Leaf]: MaterialShapes.getClover4Leaf(),
            [MaterialShape.Shape.Clover8Leaf]: MaterialShapes.getClover8Leaf(),
            [MaterialShape.Shape.Burst]: MaterialShapes.getBurst(),
            [MaterialShape.Shape.SoftBurst]: MaterialShapes.getSoftBurst(),
            [MaterialShape.Shape.Boom]: MaterialShapes.getBoom(),
            [MaterialShape.Shape.SoftBoom]: MaterialShapes.getSoftBoom(),
            [MaterialShape.Shape.Flower]: MaterialShapes.getFlower(),
            [MaterialShape.Shape.Puffy]: MaterialShapes.getPuffy(),
            [MaterialShape.Shape.PuffyDiamond]: MaterialShapes.getPuffyDiamond(),
            [MaterialShape.Shape.PixelCircle]: MaterialShapes.getPixelCircle(),
            [MaterialShape.Shape.PixelTriangle]: MaterialShapes.getPixelTriangle(),
            [MaterialShape.Shape.Bun]: MaterialShapes.getBun(),
            [MaterialShape.Shape.Heart]: MaterialShapes.getHeart()
        };
        return dict[root.shape] || MaterialShapes.getClover4Leaf();
    }
}
