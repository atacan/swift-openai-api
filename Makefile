# merge the current branch to main and push
merge_main:
	# get the name of the current branch
	$(eval BRANCH := $(shell git branch --show-current))
	# merge the current branch to main
	git checkout main
	git merge $(BRANCH)
	git push

check_uncommitted:
	@if git diff-index --quiet HEAD --; then \
		echo '\033[32mNo uncommitted changes found.\033[0m'; \
	else \
		echo '\033[31mUncommitted changes detected. Aborting.\033[0m'; \
		exit 1; \
	fi

# Run the formatters manually
format: check_uncommitted
	# run the formatters
	# nicklockwood/SwiftFormat
	swiftformat --config .swiftformat --swiftversion 5.7 .
	# apple/swift-format
	swift-format . -i -p --ignore-unparsable-files -r --configuration .swift-format
	# commit
	git add .
	git commit -m "Format code"

# spm clean cache
clean_spm_cache:
	swift package purge-cache

download-openapi:
	swift scripts/openaiYamlDownload.swift

generate-openapi:
	# automatically provide the "yes" response
	echo "yes" | swift package generate-code-from-openapi