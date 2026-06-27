#!/usr/bin/env bash
if [ -z "${2:-}" ]; then
  echo "Usage: scripts/generate.sh input.smrt output.py"
  exit 1
fi
printf 'import smarthome::Generate;\nmain([\"%s\", \"%s\"]);\n' $1 $2 | java -jar ~/.vscode/extensions/usethesource.rascalmpl-0.13.5/assets/jars/rascal.jar