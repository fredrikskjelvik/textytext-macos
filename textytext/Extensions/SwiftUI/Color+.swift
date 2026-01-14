import SwiftUI

extension Color {
    static let Monochrome = _Monochrome.self
	static let Primary = _Primary.self
    static let Secondary = _Secondary.self
    static let Tertiary = _Tertiary.self
    static let Alert = _Alert.self
}


struct _Monochrome {
	static let RegularWhite = Color("MonochromeRegularWhite")
	static let RegularBlack = Color("MonochromeRegularBlack")
    static let LightGray = Color("MonochromeLightGray")
    static let HalfWhite = Color("MonochromeHalfWhite")
    static let Gray = Color("MonochromeGray")
    static let ExtraLightGray = Color("MonochromeExtraLightGray")
}

struct _Primary {
	static let Regular = Color("PrimaryGreenRegular")
    static let Dark = Color("PrimaryGreenDark")
    static let Light = Color("PrimaryGreenLight")
}

struct _Secondary {
    static let Regular = Color("SecondaryBlueRegular")
    static let Dark = Color("SecondaryBlueDark")
    static let Light = Color("SecondaryBlueLight")
}

struct _Tertiary {
    static let Regular = Color("TertiarySandRegular")
    static let Dark = Color("TertiarySandDark")
    static let Light = Color("TertiarySandLight")
}

struct _Alert {
    static let Regular = Color("AlertRedRegular")
    static let Dark = Color("AlertRedDark")
    static let Light = Color("AlertRedLight")
}
