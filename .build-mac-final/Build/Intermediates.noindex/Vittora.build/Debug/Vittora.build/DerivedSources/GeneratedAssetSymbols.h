#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.enerjiktech.vittora";

/// The "VExpense" asset catalog color resource.
static NSString * const ACColorNameVExpense AC_SWIFT_PRIVATE = @"VExpense";

/// The "VIncome" asset catalog color resource.
static NSString * const ACColorNameVIncome AC_SWIFT_PRIVATE = @"VIncome";

/// The "VPrimary" asset catalog color resource.
static NSString * const ACColorNameVPrimary AC_SWIFT_PRIVATE = @"VPrimary";

/// The "VPrimaryDark" asset catalog color resource.
static NSString * const ACColorNameVPrimaryDark AC_SWIFT_PRIVATE = @"VPrimaryDark";

/// The "VPrimaryLight" asset catalog color resource.
static NSString * const ACColorNameVPrimaryLight AC_SWIFT_PRIVATE = @"VPrimaryLight";

/// The "VSavings" asset catalog color resource.
static NSString * const ACColorNameVSavings AC_SWIFT_PRIVATE = @"VSavings";

/// The "VTransfer" asset catalog color resource.
static NSString * const ACColorNameVTransfer AC_SWIFT_PRIVATE = @"VTransfer";

/// The "VWarning" asset catalog color resource.
static NSString * const ACColorNameVWarning AC_SWIFT_PRIVATE = @"VWarning";

#undef AC_SWIFT_PRIVATE
