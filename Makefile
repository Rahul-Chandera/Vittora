.PHONY: help build-ios build-macos test test-macos test-ios-ui test-tax test-sync test-data test-recurring ci-clean

SCHEME := Vittora
CONFIG := Debug
TEST_DERIVED := .build-ci

# Override in CI after Scripts/ci/resolve-ios-simulator-destination.sh
IOS_SIM_DEST ?= platform=iOS Simulator,name=iPhone 16

# Ad-hoc signing on the runner exercises real Keychain/Secure Enclave paths for the app
# under test while remaining CI-friendly (no Apple ID secret required for Simulator).
IOS_TEST_SIGN_FLAGS := CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-

help:
	@echo "Vittora developer commands"
	@echo ""
	@echo "  make build-ios        Compile iOS target (no signing)"
	@echo "  make build-macos      Compile macOS target (no signing)"
	@echo "  make test             Run macOS unit tests + iOS Simulator UI tests"
	@echo "  make test-macos       Run VittoraTests on macOS only"
	@echo "  make test-ios-ui      Run VittoraUITests on iOS Simulator"
	@echo "  make test-tax         Run US tax calculator tests"
	@echo "  make test-sync        Run sync conflict tests"
	@echo "  make test-data        Run data/document repository tests"
	@echo "  make test-recurring   Run recurring use case tests"
	@echo "  make ci-clean         Remove CI test result bundles"

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

test: test-macos test-ios-ui

test-macos:
	@mkdir -p $(TEST_DERIVED)
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath $(TEST_DERIVED)/DerivedData-macos \
		-resultBundlePath '$(TEST_DERIVED)/Test-macOS.xcresult' \
		-skip-testing:VittoraUITests \
		test

test-ios-ui:
	@mkdir -p $(TEST_DERIVED)
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(IOS_SIM_DEST)' \
		-derivedDataPath $(TEST_DERIVED)/DerivedData-ios \
		-resultBundlePath '$(TEST_DERIVED)/Test-iOS-UI.xcresult' \
		-only-testing:VittoraUITests \
		$(IOS_TEST_SIGN_FLAGS) \
		test

test-tax:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/USTaxCalculatorTests \
		-only-testing:VittoraTests/TaxCalculatorRegressionTests \
		test

test-sync:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/SyncConflictHandlerTests \
		-only-testing:VittoraTests/ReconcileAccountBalanceUseCaseTests \
		test

test-data:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath .build \
		-only-testing:VittoraTests/DataManagementServiceTests \
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
