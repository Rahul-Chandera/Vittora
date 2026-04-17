import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "VExpense" asset catalog color resource.
    static let vExpense = DeveloperToolsSupport.ColorResource(name: "VExpense", bundle: resourceBundle)

    /// The "VIncome" asset catalog color resource.
    static let vIncome = DeveloperToolsSupport.ColorResource(name: "VIncome", bundle: resourceBundle)

    /// The "VPrimary" asset catalog color resource.
    static let vPrimary = DeveloperToolsSupport.ColorResource(name: "VPrimary", bundle: resourceBundle)

    /// The "VPrimaryDark" asset catalog color resource.
    static let vPrimaryDark = DeveloperToolsSupport.ColorResource(name: "VPrimaryDark", bundle: resourceBundle)

    /// The "VPrimaryLight" asset catalog color resource.
    static let vPrimaryLight = DeveloperToolsSupport.ColorResource(name: "VPrimaryLight", bundle: resourceBundle)

    /// The "VSavings" asset catalog color resource.
    static let vSavings = DeveloperToolsSupport.ColorResource(name: "VSavings", bundle: resourceBundle)

    /// The "VTransfer" asset catalog color resource.
    static let vTransfer = DeveloperToolsSupport.ColorResource(name: "VTransfer", bundle: resourceBundle)

    /// The "VWarning" asset catalog color resource.
    static let vWarning = DeveloperToolsSupport.ColorResource(name: "VWarning", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "VExpense" asset catalog color.
    static var vExpense: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vExpense)
#else
        .init()
#endif
    }

    /// The "VIncome" asset catalog color.
    static var vIncome: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vIncome)
#else
        .init()
#endif
    }

    /// The "VPrimary" asset catalog color.
    static var vPrimary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vPrimary)
#else
        .init()
#endif
    }

    /// The "VPrimaryDark" asset catalog color.
    static var vPrimaryDark: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vPrimaryDark)
#else
        .init()
#endif
    }

    /// The "VPrimaryLight" asset catalog color.
    static var vPrimaryLight: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vPrimaryLight)
#else
        .init()
#endif
    }

    /// The "VSavings" asset catalog color.
    static var vSavings: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vSavings)
#else
        .init()
#endif
    }

    /// The "VTransfer" asset catalog color.
    static var vTransfer: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vTransfer)
#else
        .init()
#endif
    }

    /// The "VWarning" asset catalog color.
    static var vWarning: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vWarning)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "VExpense" asset catalog color.
    static var vExpense: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vExpense)
#else
        .init()
#endif
    }

    /// The "VIncome" asset catalog color.
    static var vIncome: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vIncome)
#else
        .init()
#endif
    }

    /// The "VPrimary" asset catalog color.
    static var vPrimary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vPrimary)
#else
        .init()
#endif
    }

    /// The "VPrimaryDark" asset catalog color.
    static var vPrimaryDark: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vPrimaryDark)
#else
        .init()
#endif
    }

    /// The "VPrimaryLight" asset catalog color.
    static var vPrimaryLight: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vPrimaryLight)
#else
        .init()
#endif
    }

    /// The "VSavings" asset catalog color.
    static var vSavings: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vSavings)
#else
        .init()
#endif
    }

    /// The "VTransfer" asset catalog color.
    static var vTransfer: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vTransfer)
#else
        .init()
#endif
    }

    /// The "VWarning" asset catalog color.
    static var vWarning: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .vWarning)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "VExpense" asset catalog color.
    static var vExpense: SwiftUI.Color { .init(.vExpense) }

    /// The "VIncome" asset catalog color.
    static var vIncome: SwiftUI.Color { .init(.vIncome) }

    /// The "VPrimary" asset catalog color.
    static var vPrimary: SwiftUI.Color { .init(.vPrimary) }

    /// The "VPrimaryDark" asset catalog color.
    static var vPrimaryDark: SwiftUI.Color { .init(.vPrimaryDark) }

    /// The "VPrimaryLight" asset catalog color.
    static var vPrimaryLight: SwiftUI.Color { .init(.vPrimaryLight) }

    /// The "VSavings" asset catalog color.
    static var vSavings: SwiftUI.Color { .init(.vSavings) }

    /// The "VTransfer" asset catalog color.
    static var vTransfer: SwiftUI.Color { .init(.vTransfer) }

    /// The "VWarning" asset catalog color.
    static var vWarning: SwiftUI.Color { .init(.vWarning) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "VExpense" asset catalog color.
    static var vExpense: SwiftUI.Color { .init(.vExpense) }

    /// The "VIncome" asset catalog color.
    static var vIncome: SwiftUI.Color { .init(.vIncome) }

    /// The "VPrimary" asset catalog color.
    static var vPrimary: SwiftUI.Color { .init(.vPrimary) }

    /// The "VPrimaryDark" asset catalog color.
    static var vPrimaryDark: SwiftUI.Color { .init(.vPrimaryDark) }

    /// The "VPrimaryLight" asset catalog color.
    static var vPrimaryLight: SwiftUI.Color { .init(.vPrimaryLight) }

    /// The "VSavings" asset catalog color.
    static var vSavings: SwiftUI.Color { .init(.vSavings) }

    /// The "VTransfer" asset catalog color.
    static var vTransfer: SwiftUI.Color { .init(.vTransfer) }

    /// The "VWarning" asset catalog color.
    static var vWarning: SwiftUI.Color { .init(.vWarning) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

