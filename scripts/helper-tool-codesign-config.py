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

'''If the helper tool's root folder is in a folder named something other 
than helper At the root of your project make the adjustments here'''
HELPER_INFO = 'helper/helper-Info.plist'

HELPER_LAUNCHD = 'helper/helper-Launchd.plist'

'''the name for the helper tool will be default to this format com.your.app.helper
which is the main apps bundleID with a .helper extension. if the executable you're
insatlling is something other than that specify it here'''
HELPER_NAME_OVERRIDE = ''

TMP_FILENAME = 'code_sign_tmp_file'

def get_code_sign_ident(build_dir):
    '''Get code signing identity'''
    identity = os.getenv('CODE_SIGN_IDENTITY')
    check_var(identity)

    _file = os.path.join(build_dir, TMP_FILENAME)

    open(_file, 'w').close()
    result = subprocess.check_output(['codesign', '--force', '--sign', identity, _file])
    result = subprocess.check_output(['codesign', '-d', '-r', '-', _file])

    cid = result.split("=> ")[1]
    cid = cid.rstrip(os.linesep)

    os.remove(_file)

    return cid


def edit_app_info_plist(cert_id, app_name):
    '''Edit app info.plist with correct cert identity'''
    app_info_plist = os.getenv('PRODUCT_SETTINGS_PATH')

    check_var(app_info_plist)
    try:
        plist = plistlib.readPlist(app_info_plist)


        bundle_id = plist['CFBundleIdentifier'].split("$")[0]

        if not HELPER_NAME_OVERRIDE:
            helper_id = ''.join([bundle_id, app_name, '.helper'])
        else:
            helper_id = HELPER_NAME_OVERRIDE

        csstring = cert_id.replace(TMP_FILENAME, helper_id)
        plist['SMPrivilegedExecutables'] = {helper_id:csstring}
    except Exception:
        print "There is no Info.plist for them main app. Something's really wrong."
        exit(1)

    plistlib.writePlist(plist, app_info_plist)
    return bundle_id, helper_id


def edit_helper_info_plist(cert_id, project_path, bundle_id, app_name):
    '''Edit the helper.plist file to match the cert identity'''
    helper_info_plist = os.path.join(project_path, HELPER_INFO)
    check_var(helper_info_plist)

    app_id = ''.join([bundle_id, app_name])
    csstring = cert_id.replace(TMP_FILENAME, app_id)

    try:
        plist = plistlib.readPlist(helper_info_plist)
        plist['SMAuthorizedClients'] = [csstring]
    except Exception:
        print "There is no Info.plist for them main app. Something's really wrong."
        exit(1)


    plistlib.writePlist(plist, helper_info_plist)


def edit_helper_launchd(project_path, helper_id):
    '''Edit helper launchd'''
    helper_launchd_plist = os.path.join(project_path, HELPER_LAUNCHD)
    check_var(helper_launchd_plist)
    try:
        plist = plistlib.readPlist(helper_launchd_plist)
        plist['Label'] = helper_id
        plist['MachServices'] = {helper_id:True}
    except Exception:
        plist = {'Label':helper_id, 'MachServices':{helper_id:True}}

    plistlib.writePlist(plist, helper_launchd_plist)



def check_var(var):
    '''Check for empty string or None'''
    if var == "" or var == None:
        exit(1)

def main():
    '''main'''
    # Configure info from environment
    build_dir = os.getenv('BUILT_PRODUCTS_DIR')
    project_path = os.getenv('PROJECT_DIR')
    app_name = os.getenv('PRODUCT_NAME')

    # Get the existing cert values
    cs_ident = get_code_sign_ident(build_dir)

    # write out to the helper tool
    bundle_id, helper_id = edit_app_info_plist(cs_ident, app_name)
    edit_helper_info_plist(cs_ident, project_path, bundle_id, app_name)
    edit_helper_launchd(project_path, helper_id)

if __name__ == "__main__":
    main()
