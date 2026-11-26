.PHONY: check check-web analyze test coverage smoke fix format clean

check: check-web
	dart format --set-exit-if-changed .
	flutter analyze
	flutter test

check-web:
	npm run check --prefix web

analyze:
	flutter analyze

test:
	flutter test

coverage:
	flutter test --coverage
	@echo "Coverage report: coverage/lcov.info"

smoke:
	SMOKE=1 flutter test test/smoke/

format:
	dart format .

fix:
	dart fix --apply
	dart format .

clean:
	flutter clean
	flutter pub get
