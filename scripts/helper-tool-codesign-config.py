#!/usr/bin/python

'''Place this file in a folder named 'scripts' at
the root of your project.

Add this next line (including quotes) as a "Run Script"
right after Target Dependencies

"${PROJECT_DIR}/scripts/helper-tool-codesign-config.py"
'''

import os
import subprocess
import plistlib

HELPER_LAUNCHD = 'Privileged Helper/helper-Launchd.plist'

'''If the helper tool's root folder is in a folder named something other 
than helper At the root of your project make the adjustments here '''
HELPER_INFO = 'Privileged Helper/helper-Info.plist'

'''the name for the helper tool will be default to this format com.your.app.helper
which is the main apps bundleID with a .helper extension. if the executable you're
insatlling is something other than that specify it here'''
HELPER_NAME_OVERRIDE = ''

TMP_FILENAME = 'SUB_SIGNING_IDENTITY'

# Since it's hard to see exactly what's happening on runscripts
# set this to True to turn on debug logging.
DEBUG = True

def log(message, new=False):
    '''Log a message to file for inspection'''
    if DEBUG:
        mode = 'w' if new else 'a'
        logfile = '/tmp/_helper_codesign.log'
        with open(logfile, mode) as log_file:
            log_file.write('%s\n' % message)

class HelperSignError(Exception):
    '''Exception when an error is encounter updating the helper signing info'''
    pass

def get_code_sign_certificate_string():
    '''Get code signing identity
    Returns a string representing the code signing identity
    '''
    # Get the signing identity the current build is using.

    build_dir = os.getenv('BUILT_PRODUCTS_DIR')
    identity = os.getenv('CODE_SIGN_IDENTITY')

    if not identity:
        raise HelperSignError('Could not get the current build identity')

    tmp_file = os.path.join(build_dir, TMP_FILENAME)

    # Write and empty file to the tmp path
    open(tmp_file, 'w').close()

    # Code sign the file with the certificate XCode is using to sign ...
    subprocess.check_call(['codesign', '--force', '--sign', identity, tmp_file])

    # Now get the output of the codesign check.
    result = subprocess.check_output(['codesign', '-d', '-r', '-', tmp_file])

    signing_certificate_string = result.split("=> ")[1]
    signing_certificate_string = signing_certificate_string.rstrip(os.linesep)

    os.remove(tmp_file)
    return signing_certificate_string.encode('utf-8')

def update_app_info_plist(cert_id, bundle_id):
    '''Edit app info.plist with correct cert identity'''
    app_info_plist = os.getenv('PRODUCT_SETTINGS_PATH')
    app_name = os.getenv('PRODUCT_NAME')

    if not os.path.isfile(app_info_plist):
        raise HelperSignError('''There is no Info.plist for the main app.
                              Something's really wrong.''')
    try:
        plist = plistlib.readPlist(app_info_plist)     
    except Exception as error:
        raise HelperSignError('''There was a problem reading the
                              Info.plist at %s: [Error %s ]''' % (app_info_plist, error))

    if not bundle_id:
        bundle_id = '.'.join([plist['CFBundleIdentifier'].split("$")[0].rstrip('.'), app_name])

    helper_id = HELPER_NAME_OVERRIDE if HELPER_NAME_OVERRIDE else \
                    '.'.join([bundle_id, 'helper'])
    
    try:
        corrected_certificate_string = cert_id.replace(TMP_FILENAME, helper_id)
        plist['SMPrivilegedExecutables'] = {helper_id: corrected_certificate_string}
        plistlib.writePlist(plist, app_info_plist)
    except Exception as error:
        raise HelperSignError('''There was a problem writing the
                              Info.plist at %s: [Error %s ]''' % (app_info_plist, error))

    except Exception:
        raise HelperSignError('''There was a problem parsing the
                              Info.plist at %s''' % app_info_plist)
  
    return helper_id, bundle_id


def update_helper_info_plist(cert_id, project_path, app_id):
    '''Edit the helper.plist file to match the cert identity'''
    helper_info_plist = os.path.join(project_path, HELPER_INFO)
    if not os.path.isfile(helper_info_plist):
        raise HelperSignError('''There is no Info.plist for the helper app.
                              Something's really wrong.''')


    corrected_certificate_string = cert_id.replace(TMP_FILENAME, app_id)
    plist = plistlib.readPlist(helper_info_plist)

    # In the helper tool info.plist SMAuthorizedClienst is an Array.
    plist['SMAuthorizedClients'] = [corrected_certificate_string]
    
    plistlib.writePlist(plist, helper_info_plist)

def update_helper_launchd(project_path, helper_id):
    '''Edit helper launchd'''
    helper_launchd_plist = os.path.join(project_path, HELPER_LAUNCHD)

    if not os.path.isfile(helper_launchd_plist):
        plist = {'Label': helper_id, 'MachServices': {helper_id: True}}
    else:
        plist = plistlib.readPlist(helper_launchd_plist)
        plist['Label'] = helper_id
        plist['MachServices'] = {helper_id: True}

    log(plist)
    log(helper_launchd_plist)

    plistlib.writePlist(plist, helper_launchd_plist)
        
def main():
    '''main'''

    # Get the existing cert values
    codesign_identity_string = get_code_sign_certificate_string()

    # Update the main app's info.plist
    bundle_id = os.getenv('PRODUCT_BUNDLE_IDENTIFIER')
    helper_id, bundle_id = update_app_info_plist(codesign_identity_string, bundle_id)
    
    # Update the helper tool's info.plist and mach service launchd
    project_path = os.getenv('PROJECT_DIR')
    update_helper_info_plist(codesign_identity_string, project_path, bundle_id)
    update_helper_launchd(project_path, helper_id)

if __name__ == "__main__":
    main()
