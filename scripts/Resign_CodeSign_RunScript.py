#!/usr/bin/python

'''
    Make sure nested Frameworks get properly signed,
    (in the Version/A folder).

    Place this file in a folder named 'scripts' at
    the root of your project.

    Add this next line (including quotes) as a "Run Script"
    AFTER all copy file phases.

    "${PROJECT_DIR}/scripts/Resign_CodeSign_RunScript.py"

    Note: If you have `--deep` set on any of your codesign
    flags remove it!

'''

import os
import subprocess


# Since it's hard to see exactly what's happening on runscripts
# set this to True to turn on debug logging.
debug = False


def log(message, new=False):
    global debug

    if debug:
        mode = 'w' if new else 'a'
        logfile = '/tmp/_xcode_build.log'
        with open(logfile, mode) as f:
            f.write('%s\n' % message)


def checkVar(var, description):
    log('Checking %s:%s\n' % (description, var))
    if not var:
        print('The variable %s is blank.' % description)
        return False
    else:
        return True


def deepSign(path, identity):
    if os.path.exists(path):
        log('Signing %s\n' % (path))
        sign_cmd = [
            'codesign',
            '--verbose',
            '--force',
            '--sign',
            '%s' % identity, path
        ]
        log('%s\n' % ' '.join(sign_cmd))

        p1 = subprocess.Popen(
            sign_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        output, err = p1.communicate()

        if output:
            log('%s\n' % output)
        if err:
            log('ERROR: %s\n' % err)

        if not p1.returncode == 0:
            log('ERROR: Problem signing item at %s [rc: %d]\n' % (path))


def checkSigning(path):
    sign_cmd = ['codesign', '-vvvv', path]
    log('%s\n' % ' '.join(sign_cmd))

    p1 = subprocess.Popen(
        sign_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    output, err = p1.communicate()

    if output:
        log('%s\n' % output)
    if err:
        log('ERROR: %s\n' % err)


def main():
    # Configure info from environment
    log('### Starting Run Script ####\n\n', new=True)

    identity = os.getenv('CODE_SIGN_IDENTITY')
    log('Signing with identity %s\n' % identity)

    build_dir = os.getenv('BUILT_PRODUCTS_DIR')
    checkVar(build_dir, 'BUILT_PRODUCTS_DIR')

    app_path = os.getenv('CODESIGNING_FOLDER_PATH')
    checkVar(app_path, 'PRODUCT_NAME')

    # Sign all of the frameworks in our build directory
    frameworks_folder_path = os.getenv('FRAMEWORKS_FOLDER_PATH')
    frameworks_path = os.path.join(build_dir, frameworks_folder_path)
    frameworks = os.listdir(frameworks_path)

    for i in frameworks:
        path = os.path.join(
            frameworks_path,
            i,
            'Versions',
            'A'
        )
        deepSign(path, identity)

    # Sign any of our helper tools
    launch_service_path = os.path.join(
        app_path,
        'Contents',
        'Library',
        'LaunchServices'
    )
    if os.path.exists(launch_service_path):
        helpers = os.listdir(launch_service_path)
        log(helpers)
        log(launch_service_path)
        for i in helpers:
            path = os.path.join(launch_service_path, i)
            deepSign(path, identity)

    # Verify that everything is signed correctly
    checkSigning(app_path)

    log('### Done with RunScript####\n\n')


if __name__ == '__main__':
    main()
