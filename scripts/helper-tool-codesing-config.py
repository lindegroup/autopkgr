#!/usr/bin/python

""" Place this script at the root of the project directory
    and enter this for a Run Script during build phase
    
    Place this file in a folder named 'scripts' at
    the root of your project.
    
    Add this next line (including quotes) as a "Run Script"
    AFTER all copy file phases.
    
    "${PROJECT_DIR}/scripts/helper-tool-codesing-config.py"
    
    put the runscript right after Target Dependencies
"""

import os
import subprocess
import plistlib

""" If the helper tool's root folder is in a folder named something other than "helper"
    At the root of your project make the adjustments here. 
"""
helper_info = 'helper/helper-Info.plist'
helper_launchd = 'helper/helper-Launchd.plist'

"""
the name for the helper tool will be default to this format com.your.app.helper
which is the main apps bundleID with a .helper extension.
if the executable you're insatlling is something other than that specify it here
"""
helper_name_override = '';

tmp_filename = 'code_sign_tmp_file'

def getCodeSignIdent(build_dir):
    identity = os.getenv('CODE_SIGN_IDENTITY')
    checkVar(identity)
    
    file = os.path.join(build_dir,tmp_filename)
    
    open(file, 'w').close()
    result = subprocess.check_output(['codesign','--force','--sign',identity,file])
    result = subprocess.check_output(['codesign','-d','-r', '-',file])
    
    cid = result.split("=> ")[1]
    cid = cid.rstrip(os.linesep)
    
    os.remove(file)
    
    return cid


def editAppInfoPlist(cert_id,app_name):
    app_info_plist = os.getenv('PRODUCT_SETTINGS_PATH')
    
    checkVar(app_info_plist)
    try:
        p = plistlib.readPlist(app_info_plist)
        
        
        bundle_id = p['CFBundleIdentifier'].split("$")[0]
        
        if not helper_name_override:
            helper_id =  ''.join([bundle_id, app_name,'.helper'])
        else:
            helper_id = helper_name_override
        
        csstring = cert_id.replace(tmp_filename,helper_id)
        p['SMPrivilegedExecutables'] = {helper_id:csstring}
    except:
        print "There is No Info.plist for them main app, somethings really wrong"
        exit(1)
    
    plistlib.writePlist(p,app_info_plist)
    return bundle_id, helper_id


def editHelperInfoPlist(cert_id,project_path,bundle_id,app_name):
    helper_info_plist = os.path.join(project_path,helper_info)
    checkVar(helper_info_plist)
    
    app_id = ''.join([bundle_id,app_name])
    csstring = cert_id.replace(tmp_filename,app_id)
    
    try:
        p = plistlib.readPlist(helper_info_plist)
        p['SMAuthorizedClients'] = [csstring]
    except:
        print "There is No Info.plist for helper tool, somethings really wrong"
        exit(1)
    
    
    plistlib.writePlist(p,helper_info_plist)


def editHelperLaunchD(project_path,helper_id):
    helper_launchd_plist = os.path.join(project_path,helper_launchd)
    checkVar(helper_launchd_plist)
    try:
        p = plistlib.readPlist(helper_launchd_plist)
        p['Label'] = helper_id
        p['MachServices'] = {helper_id:True}
    except:
        p = {'Label':helper_id,
            'MachServices':{helper_id:True}}
    
    plistlib.writePlist(p,helper_launchd_plist)



def checkVar(var):
    if var == "" or var == None:
        exit(1)

def main():
    # Configure info from environment
    build_dir = os.getenv('BUILT_PRODUCTS_DIR')
    project_path = os.getenv('PROJECT_DIR')
    app_name = os.getenv('PRODUCT_NAME')
    
    # Get the existing cert values
    cs_ident = getCodeSignIdent(build_dir)
    
    # write out to the helper tool
    bundle_id,helper_id = editAppInfoPlist(cs_ident,app_name)
    editHelperInfoPlist(cs_ident,project_path,bundle_id,app_name)
    editHelperLaunchD(project_path,helper_id)

if __name__ == "__main__":
    main()