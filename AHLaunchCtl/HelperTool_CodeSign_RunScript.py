#!/usr/bin/python

''' Place this script at the root of the project directory
    and enter this for a Run Script during build phase of the helper app
    
    ${PROJECT_DIR}"/HelperTool_CodeSign_RunScript.py
    
    put the run script right after Target Dependencies

    What this script does is write the SMPrivilegedExecutables dictionary
    into the Main app's Info.plist and the SMAuthorizedClients array into 
    the Helper Tool's Info.plist.  

    You still need to add this 
    
    -sectcreate __TEXT __info_plist helper/helper-Info.plist 
    -sectcreate __TEXT __launchd_plist helper/helper-Launchd.plist
    
    to the Other Linker Flags Settings for your helper tool.
    and the helper tool must be signed by the same identity as the main app_name
'''

import os
import subprocess
import plistlib

'''
the name for the helper tool will be default to this format

com.your.app.helper

which is the main apps bundleID with a .helper extension.
if the helper tool is named something other than this, specify it here
'''
helper_name_override = '';

'''Set these to the appropriate path (relative to you project root)'''
helper_info = 'helper/helper-Info.plist'
helper_launchd = 'helper/helper-Launchd.plist'


tmp_filename = 'code_sign_tmp_file'

def getCodeSignIdent(build_dir):
    identity = os.getenv('CODE_SIGN_IDENTITY')
    checkVar(identity,'identity')
    
    file = os.path.join(build_dir,tmp_filename)
    
    open(file, 'w').close()
    result = subprocess.check_output(['codesign','--force','--sign',identity,file])
    result = subprocess.check_output(['codesign','-d','-r', '-',file])
    
    code_sign_identity = result.split("=> ")[1]
    code_sign_identity = code_sign_identity.rstrip(os.linesep)
    
    os.remove(file)
    
    return code_sign_identity


def editAppInfoPlist(cert_id,app_name):
    app_info_plist = os.getenv('PRODUCT_SETTINGS_PATH')
    
    checkVar(app_info_plist,'App Info.plist')
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
        print "There is No Info.plist for them main app, somethings very wrong"
        exit(1)
    
    plistlib.writePlist(p,app_info_plist)
    return bundle_id, helper_id


def editHelperInfoPlist(cert_id,project_path,bundle_id,app_name):
    helper_info_plist = os.path.join(project_path,helper_info)
    checkVar(helper_info_plist,'Helper info.plist')
    
    app_id = ''.join([bundle_id,app_name])
    csstring = cert_id.replace(tmp_filename,app_id)
    
    try:
        p = plistlib.readPlist(helper_info_plist)
        p['SMAuthorizedClients'] = [csstring]
    except:
        p = {
            'CFBundleIdentifier':helper_id,
            'CFBundleName':helper_id,
            'CFBundleVersion':'0.1.0',
            'CFBundleInfoDictionaryVersion':'6.0',
            'SMAuthorizedClients':[cstring],
        }
    
    
    plistlib.writePlist(p,helper_info_plist)


def editHelperLaunchD(project_path,helper_id):
    helper_launchd_plist = os.path.join(project_path,helper_launchd)
    checkVar(helper_launchd_plist,'Helper launchd.plist')
    try:
        p = plistlib.readPlist(helper_launchd_plist)
        p['Label'] = helper_id
        p['MachServices'] = {helper_id:True}
    except:
        p = {'Label':helper_id,
            'MachServices':{helper_id:True}}
    
    plistlib.writePlist(p,helper_launchd_plist)



def checkVar(var,description):
    if var == "" or var == None:
        print ("the variable %s is blank" % description)
        exit(1)

def main():
    # Configure info from environment
    build_dir    = os.getenv('BUILT_PRODUCTS_DIR')
    checkVar(build_dir,'BUILT_PRODUCTS_DIR')

    project_path = os.getenv('PROJECT_DIR')
    checkVar(project_path,"PROJECT_DIR")

    app_name     = os.getenv('PRODUCT_NAME')
    checkVar(app_name,"PRODUCT_NAME(App Name)")
    # Get the existing cert values
    code_sign_identity = getCodeSignIdent(build_dir)
    
    # write out to the helper tool
    bundle_id,helper_id = editAppInfoPlist(code_sign_identity,app_name)
    editHelperInfoPlist(code_sign_identity,project_path,bundle_id,app_name)
    editHelperLaunchD(project_path,helper_id)

if __name__ == "__main__":
    main()
