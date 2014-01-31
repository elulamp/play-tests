import getopt
import sys
import os
import os.path
import shutil
import subprocess
from exceptions import ValueError

MODULE = "play-tests"

COMMANDS = ["tests", "clean-tests", "unit-tests", "itests", "ui-tests"]         # The new parallel tests

HELP = {
    "tests": "Compile and run all tests",
    "clean-tests": "Clean compiled tests and test results",
    "unit-tests": "Run plain unit-tests",
    "itests": "Run integration tests (unit-tests that required play start - they cannot be run with usual unit-tests)",
    "ui-tests": "Run UI tests (in parallel)"
}

def run_tests(app, args, gradle_opts, *tasks):
    module_dir = os.path.dirname(os.path.realpath(__file__))
    gradle_cmd = ["bash",
                  "%s/gradle" % module_dir,
                  "-b", "%s/build.gradle" % module_dir,
                  "-PPLAY_APP=%s" % app.path,
                  "-PPLAY_HOME=%s" % app.play_env["basedir"],
                  "-Dfile.encoding=UTF-8",
                  ] + list(tasks) + list(args) + gradle_opts

    print "~ %s" % ' '.join(gradle_cmd)
    return_code = subprocess.call(gradle_cmd, env=os.environ)
    if 0 != return_code:
        print "~ %ss FAILED" % list(tasks)
        sys.exit(return_code)

    print "~ Executed %s successfully" % list(tasks)


def execute(**kargs):
    command = kargs.get("command")
    app = kargs.get("app")
    args = kargs.get("args")

    uitest_class_pattern = 'ui/**'
    gradle_opts = []
    remote_debug = False
    daemon = False
    optlist, args = getopt.getopt(args, '', ['test=', 'uitest=', 'daemon=', 'remote_debug=', 'gradle_opts=', 'random='])
    for o, a in optlist:
        if o == '--uitest':
            uitest_class_pattern = a
            print "~ UI TEST: %s" % uitest_class_pattern
            print "~ "
        if o == '--gradle_opts':
            gradle_opts = a.split()
            print "~ GRADLE OPTS: %s" % gradle_opts
            print "~ "
        if o == '--remote_debug':
            remote_debug = a.lower() in ['true', '1', 't', 'y', 'yes']
            print "~ REMOTE DEBUG"
            print "~ "
        if o == '--daemon':
            daemon = a.lower() in ['true', '1', 't', 'y', 'yes']
            print "~ DAEMON"
            print "~ "

    if remote_debug:
        gradle_opts.append("-Duitest.debug=true")
    if daemon:
        gradle_opts.append('--daemon')

    if command == 'tests' or command == 'tests2':
        run_tests(app, args, gradle_opts, 'clean', 'test', 'itest', 'uitest', '-PUITEST_CLASS=%s' % uitest_class_pattern)
    elif command == 'clean-tests' or command == 'clean-tests2':
        run_tests(app, args, gradle_opts, 'cleanTest')
    elif command == 'unit-tests' or command == 'unit-tests2':
        run_tests(app, args, gradle_opts, 'test')
    elif command == 'ui-tests' or command == 'ui-tests2':
        run_tests(app, args, gradle_opts, 'uitest', '-PUITEST_CLASS=%s' % uitest_class_pattern)
    elif command == 'itests':
        run_tests(app, args, gradle_opts, 'itest')
    else:
        raise ValueError("Unknown command: %s" % command)
