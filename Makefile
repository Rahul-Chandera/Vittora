.PHONY: help build-ios build-macos test test-unit test-ios-ui test-ios-ui-onboarding test-tax test-sync test-data test-recurring ci-clean

SCHEME := Vittora
CONFIG := Debug
TEST_DERIVED := .build-ci

# Override in CI after Scripts/ci/resolve-ios-simulator-destination.sh
IOS_SIM_DEST ?= platform=iOS Simulator,name=iPhone 16

# Ad-hoc signing for Simulator installs (no Apple ID secret on CI). The Simulator has
# no device Secure Enclave; real SE encryption paths remain manual/device-gated (L5).
IOS_TEST_SIGN_FLAGS := CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-

# Serial testing on CI avoids parallel simulator clone instability.
ifeq ($(GITHUB_ACTIONS),true)
IOS_CI_SERIAL_FLAGS := -parallel-testing-enabled NO -maximum-parallel-testing-workers 1
# Onboarding UI test is flaky on CI simulators; logic covered by OnboardingViewModelTests.
IOS_UI_SKIP_FLAGS := -skip-testing:VittoraUITests/OnboardingFlowUITests
else
IOS_CI_SERIAL_FLAGS :=
IOS_UI_SKIP_FLAGS :=
endif

help:
	@echo "Vittora developer commands"
	@echo ""
	@echo "  make build-ios        Compile iOS target (no signing)"
	@echo "  make build-macos      Compile macOS target (no signing)"
	@echo "  make test             Run unit + UI tests on iOS Simulator (CI default)"
	@echo "  make test-unit        Run VittoraTests on iOS Simulator"
	@echo "  make test-ios-ui      Run VittoraUITests on iOS Simulator (CI skips onboarding flow)"
	@echo "  make test-ios-ui-onboarding  Run quarantined OnboardingFlowUITests only"
	@echo "  make test-tax         Run US tax calculator tests (macOS host; needs macOS 26+)"
	@echo "  make test-sync        Run sync conflict tests (macOS host; needs macOS 26+)"
	@echo "  make test-data        Run data/document repository tests (macOS host; needs macOS 26+)"
	@echo "  make test-recurring   Run recurring use case tests (macOS host; needs macOS 26+)"
	@echo "  make ci-clean         Remove CI test result bundles"
	@echo ""
	@echo "Note: make test runs on the iOS Simulator so GitHub macos-15 runners can execute"
	@echo "      against iOS 26.x. macOS-host-specific tests (#if os(macOS)) need a self-hosted"
	@echo "      macOS 26 runner or Xcode Cloud for full macOS coverage."

build-ios:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath .build-ios \
		build CODE_SIGNING_ALLOWED=NO

build-macos:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build-macos \
		build CODE_SIGNING_ALLOWED=NO

ci-clean:
	rm -rf $(TEST_DERIVED)

test: ci-clean test-unit test-ios-ui

test-unit:
	@mkdir -p $(TEST_DERIVED)
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(IOS_SIM_DEST)' \
		-derivedDataPath $(TEST_DERIVED)/DerivedData-unit \
		-resultBundlePath '$(TEST_DERIVED)/Test-Unit.xcresult' \
		-only-testing:VittoraTests \
		-skip-testing:VittoraTests/ModelContainerOnDiskTests \
		$(IOS_TEST_SIGN_FLAGS) \
		$(IOS_CI_SERIAL_FLAGS) \
		test

test-ios-ui:
	@mkdir -p $(TEST_DERIVED)
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(IOS_SIM_DEST)' \
		-derivedDataPath $(TEST_DERIVED)/DerivedData-ios-ui \
		-resultBundlePath '$(TEST_DERIVED)/Test-iOS-UI.xcresult' \
		-only-testing:VittoraUITests \
		$(IOS_UI_SKIP_FLAGS) \
		$(IOS_TEST_SIGN_FLAGS) \
		$(IOS_CI_SERIAL_FLAGS) \
		test

test-ios-ui-onboarding:
	@mkdir -p $(TEST_DERIVED)
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(IOS_SIM_DEST)' \
		-derivedDataPath $(TEST_DERIVED)/DerivedData-ios-ui-onboarding \
		-resultBundlePath '$(TEST_DERIVED)/Test-iOS-UI-Onboarding.xcresult' \
		-only-testing:VittoraUITests/OnboardingFlowUITests \
		$(IOS_TEST_SIGN_FLAGS) \
		$(IOS_CI_SERIAL_FLAGS) \
		test

test-tax:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/USTaxCalculatorTests \
		-only-testing:VittoraTests/TaxCalculatorRegressionTests \
		-only-testing:VittoraTests/IndiaSectionDeductionEngineTests \
		test

test-sync:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/SyncConflictHandlerTests \
		-only-testing:VittoraTests/ReconcileAccountBalanceUseCaseTests \
		-only-testing:VittoraTests/SyncIntegrityValidatorTests \
		test

test-data:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/DataManagementServiceTests \
		-only-testing:VittoraTests/ModelContainerConfigTests \
		-only-testing:VittoraTests/ModelContainerOnDiskTests \
		-only-testing:VittoraTests/SwiftDataDocumentRepositoryTests \
		test

test-recurring:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/RecurringUseCaseTests \
		test
