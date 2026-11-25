.PHONY: check analyze test coverage smoke fix format clean

check:
	dart format --set-exit-if-changed .
	flutter analyze
	flutter test

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
