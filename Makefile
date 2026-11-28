.PHONY: check check-web fix clean

# What the pre-push hook runs: lint, format check, typecheck, tests and the build of the web app.
check: check-web

check-web:
	npm run check --prefix web

fix:
	npm run format --prefix web
	npm run lint --prefix web -- --fix

# What a check leaves behind. node_modules stays.
clean:
	rm -rf web/dist web/coverage web/node_modules/.vite
