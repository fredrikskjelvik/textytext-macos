import Cocoa

extension NSColor {
    static let Monochrome = _NSMonochrome.self
    static let Primary = _NSPrimary.self
    static let Secondary = _NSSecondary.self
    static let Tertiary = _NSTertiary.self
    static let Alert = _NSAlert.self
   
    /// Initialize RGB with the familiar 0-255 scale (Probably won't use)
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat) {
        self.init(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: alpha)
    }
}

struct _NSGrayscale {
    static let Title = NSColor(named: "Grayscale.Title")!
    static let Body = NSColor(named: "Grayscale.Body")!
    static let Label = NSColor(named: "Grayscale.Label")!
    static let Placeholder = NSColor(named: "Grayscale.Placeholder")!
    static let Line = NSColor(named: "Grayscale.Line")!
    static let InputBackground = NSColor(named: "Grayscale.InputBackground")!
    static let Background = NSColor(named: "Grayscale.Background")!
    static let Offwhite = NSColor(named: "Grayscale.Offwhite")!
}


struct _NSMonochrome {
    static let RegularWhite = NSColor(named: "MonochromeRegularWhite")!
    static let RegularBlack = NSColor(named: "MonochromeRegularBlack")!
    static let LightGray = NSColor(named: "MonochromeLightGray")!
    static let HalfWhite = NSColor(named: "MonochromeHalfWhite")!
    static let Gray = NSColor(named: "MonochromeGray")!
    static let ExtraLightGray = NSColor(named: "MonochromeExtraLightGray")!
}

struct _NSPrimary {
    static let Regular = NSColor(named: "PrimaryGreenRegular")!
    static let Dark = NSColor(named: "PrimaryGreenDark")!
    static let Light = NSColor(named: "PrimaryGreenLight")!
}

struct _NSSecondary {
    static let Regular = NSColor(named: "SecondaryBlueRegular")!
    static let Dark = NSColor(named: "SecondaryBlueDark")!
    static let Light = NSColor(named: "SecondaryBlueLight")!
}

struct _NSTertiary {
    static let Regular = NSColor(named: "TertiarySandRegular")!
    static let Dark = NSColor(named: "TertiarySandDark")!
    static let Light = NSColor(named: "TertiarySandLight")!
}

struct _NSAlert {
    static let Regular = NSColor(named: "AlertRedRegular")!
    static let Dark = NSColor(named: "AlertRedDark")!
    static let Light = NSColor(named: "AlertRedLight")!
}
