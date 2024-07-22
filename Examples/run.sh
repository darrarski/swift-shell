#!/usr/bin/env bash

CURRENT_SCRIPT_PATH="$(readlink -f $0)"
CURRENT_SCRIPT_NAME="$(basename "${CURRENT_SCRIPT_PATH}")"
EXAMPLES_DIR="$(echo "${CURRENT_SCRIPT_PATH}" | xargs dirname)/"

function help {
  echo "OVERVIEW: Build and run example."
  echo ""
  echo "USAGE: ${CURRENT_SCRIPT_NAME} [options] -- [name]"
  echo ""
  echo "Parameters:"
  echo "  name                  Name of the example to run."
  echo ""
  echo "OPTIONS:"
  echo "  -h, --help            Show help information."
}

while (($#)); do
  case "$1" in
    -h|--help)
      help
      exit 0;;
    --)
      shift
      EXAMPLE_NAME="$1"
      shift
      EXAMPLE_ARGUMENTS="$@"
      break;;
    *)
      echo "Unknown argument: $1"
      echo ""
      help
      exit 1;;
  esac
  shift
done

if [[ -z $EXAMPLE_NAME ]]; then
  echo "Missing example name."
  echo ""
  help
  exit 1
fi

echo "==> Building examples..."
echo ""
cd "${EXAMPLES_DIR}"
swift build --configuration release
echo ""

echo "==> Runnning example..."
echo ""
EXAMPLE_BIN_PATH="${EXAMPLES_DIR}/.build/release/${EXAMPLE_NAME}"
if [[ ! -f $EXAMPLE_BIN_PATH ]]; then
  echo "Example ${EXAMPLE_NAME} not found!"
  exit 1
fi
env NSUnbufferedIO=YES "$EXAMPLE_BIN_PATH" $EXAMPLE_ARGUMENTS
