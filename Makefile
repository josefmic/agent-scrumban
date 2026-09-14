DERIVED := .build/release
APP := $(DERIVED)/Build/Products/Release/AgentScrumban.app
DIST := dist

.PHONY: generate test release clean

generate:
	xcodegen generate

test: generate
	cd Core && swift test
	xcodebuild test -project AgentScrumban.xcodeproj -scheme AgentScrumban -destination 'platform=macOS'

release: generate
	xcodebuild build -project AgentScrumban.xcodeproj -scheme AgentScrumban \
		-destination 'platform=macOS' -configuration Release -derivedDataPath $(DERIVED)
	mkdir -p $(DIST)
	rm -f $(DIST)/AgentScrumban.zip
	ditto -c -k --keepParent $(APP) $(DIST)/AgentScrumban.zip
	@echo "built $(DIST)/AgentScrumban.zip"

clean:
	rm -rf $(DERIVED) $(DIST)
