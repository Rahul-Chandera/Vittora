.PHONY: help build-ios build-macos test test-tax test-sync test-data test-recurring

SCHEME := Vittora
CONFIG := Debug

help:
	@echo "Vittora developer commands"
	@echo ""
	@echo "  make build-ios        Compile iOS target (no signing)"
	@echo "  make build-macos      Compile macOS target (no signing)"
	@echo "  make test             Run full test suite"
	@echo "  make test-tax         Run US tax calculator tests"
	@echo "  make test-sync        Run sync conflict tests"
	@echo "  make test-data        Run data/document repository tests"
	@echo "  make test-recurring   Run recurring use case tests"

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

test:
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath .build \
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
