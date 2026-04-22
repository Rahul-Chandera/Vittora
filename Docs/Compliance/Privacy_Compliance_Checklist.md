# Vittora Privacy Compliance Checklist

## Current Baseline

- Privacy manifest file is present at `Vittora/PrivacyInfo.xcprivacy`.
- Tracking is explicitly disabled.
- No data collection categories are currently declared.
- No tracking domains are currently declared.
- Accessed API declarations are intentionally empty pending final release verification.

## Pre-Release Verification Steps

- Run Xcode archive and App Store privacy report checks.
- Confirm all required-reason API categories and reason codes are declared.
- Confirm no third-party SDKs add additional privacy manifest requirements.
- Re-verify `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSContactsUsageDescription`, and `NSFaceIDUsageDescription` copy.
- Confirm legal/privacy policy text in-app matches final App Store privacy declarations.

## Owner Workflow

- Engineering updates `PrivacyInfo.xcprivacy` for any new platform API usage.
- Product/legal review each privacy declaration before TestFlight/App Store submission.
- Release checklist sign-off requires this file and the manifest to be up to date.
