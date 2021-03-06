#!/bin/bash
# Functions for compiling and running of tests in your app

PLAY=`which play`
PLAY=`readlink -f $PLAY`
PLAY_HOME=`dirname $PLAY`

function modify_test_env() {
  # this can be overridden
  echo
}

function resolve_module() {
  NAME=$1
  MODULE=`ls -d modules/*$NAME*`
  if [ -f $MODULE ]; then
    MODULE=`cat $MODULE`
  fi
  echo $MODULE
}

function prepare_test_env() {
  TEST_CLASSPATH="lib/*:"
  TEST_CLASSES=`find app -name '*.java'`
  for m in `ls modules`; do
    module=`resolve_module $m`
    TEST_CLASSPATH=$TEST_CLASSPATH:$module/lib/*
    TEST_CLASSES="$TEST_CLASSES `find $module/app -name '*.java' 2>/dev/null`"
    case "$m" in
      guice*|cms*)
        #echo "Ignore tests: $m"
        ;;
      *)
        TEST_CLASSES="$TEST_CLASSES `find $module/test -name '*.java' 2>/dev/null`"
        ;;
    esac
  done
  TEST_CLASSES="$TEST_CLASSES `find test -name '*.java'`"

  export TEST_CLASSPATH=$TEST_CLASSPATH:test:"$PLAY_HOME/framework/*:$PLAY_HOME/framework/lib/*"
  export TEST_CLASSES=$TEST_CLASSES

  mkdir -p test-result
  modify_test_env
}

function compile_tests() {
  echo "Compiling tests..."
  prepare_test_env

  rm -fr test-classes && mkdir test-classes
  # javac -g -source 1.7 -target 1.7 -nowarn -cp $TEST_CLASSPATH $TEST_CLASSES -d test-classes || exit 1
  java -cp $TEST_CLASSPATH play.test.Compiler || exit 1
}

function run_unit_tests() {
  echo "Running unit tests... "
  prepare_test_env

  set -o pipefail

  java $TEST_JAVA_OPTS -XX:-UseSplitVerifier -cp test-classes:$TEST_CLASSPATH \
    play.test.JUnitRunnerWithXMLOutput UNIT 2>&1 | tee test-result/unit-tests.log || exit 2

  echo ""
  egrep test-result/unit-tests.log -e "TEST.*FAILED"

  if [ "$?" == "0" ] ; then
    echo "Unit tests failed"
    exit 1
  fi

  echo "Finished unit tests."
}

function run_ui_tests() {
  check_and_install_chromedriver
  TESTS_FILE=$1

  echo "Running UI tests... "
  prepare_test_env

  set -o pipefail

  java $TEST_JAVA_OPTS -XX:-UseSplitVerifier -Dprecompiled=true -Dbrowser=chrome -Dselenide.reports=test-result \
    -cp test-classes:$TEST_CLASSPATH \
    play.test.JUnitRunnerWithXMLOutput UI $TESTS_FILE 2>&1 | tee test-result/ui-tests.log || exit 3

  echo ""
  egrep test-result/ui-tests.log -e "TEST.*FAILED"

  if [ "$?" == "0" ] ; then
    echo "UI tests failed"
    exit 1
  fi

  echo "Finished UI tests."
}

function install_chromedriver() {
  echo "Downloading chromedriver binary into ~/bin"
  mkdir -p ~/bin
  FILE=`wget http://chromedriver.storage.googleapis.com/ -O - | sed 's@.*\([0-9]\+\.[0-9]\+/chromedriver_linux64.zip\).*@\1@'`
  wget http://chromedriver.storage.googleapis.com/$FILE -O ~/bin/chromedriver.zip &&
  cd ~/bin && unzip chromedriver.zip && rm chromedriver.zip && cd -
}

function check_and_install_chromedriver() {
  which chromedriver >/dev/null
  if [ $? != 0 ]; then
    install_chromedriver
    which chromedriver
    if [ $? != 0 ]; then
      echo "Cannot start downloaded chromedriver, probably you need to restart your terminal"
      exit 1
    fi
  fi
}
