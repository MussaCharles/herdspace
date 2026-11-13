#!/usr/bin/env bash
# demo-projects.sh creates made-up projects and a project list, for tests and
# for screenshots. It uses no real project names.
set -e
cd "$HOME"
for p in website api mobile-app docs; do
  mkdir -p "projects/${p}/src"
  cd "projects/${p}"
  git init -q -b main
  git config user.name demo
  git config user.email demo@example.com
  printf '# %s\n\nA demo project.\n' "$p" >README.md
  # shellcheck disable=SC2016 # The text is JavaScript.
  printf 'export function greet(name) {\n  return `Hello, ${name}`;\n}\n' >src/index.js
  printf '{ "name": "%s", "version": "1.0.0" }\n' "$p" >package.json
  git add .
  git commit -q -m 'First version'
  cd "$HOME"
done
cd "$HOME/projects/website"
# shellcheck disable=SC2016
printf 'export function greet(name) {\n  const text = `Hello, ${name}!`;\n  return text;\n}\n\nexport const version = "1.1.0";\n' >src/index.js
printf 'body { margin: 0; }\n' >src/site.css
cat >"$HOME/my-projects.code-workspace" <<'JSON'
{ "folders": [
  { "name": "website", "path": "./projects/website" },
  { "name": "api", "path": "./projects/api" },
  { "name": "mobile-app", "path": "./projects/mobile-app" },
  { "name": "docs", "path": "./projects/docs" }
] }
JSON
