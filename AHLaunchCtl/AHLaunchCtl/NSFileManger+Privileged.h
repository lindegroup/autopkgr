//
//  NSFileManager+authorized.h
//  AHLaunchCtl
//
//  Created by Eldon on 2/19/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AHLaunchCtl.h"

/**
 *  An Catagory for NSFileManger that extends it to perform privileged
 * operations using AHLaunchCtl library and
 */
@interface NSFileManager (Privileged)
/**
 *  Move a file to an protected path
 *
 *  @param path      source file
 *  @param location  destination folder
 *  @param overwrite YES to overwrite, NO to ignore
 *  @param error     populate should error occur
 *
 *  @return YES on success NO on failure
 */
- (BOOL)moveItemAtPath:(NSString*)path
    toPrivilegedLocation:(NSString*)location
               overwrite:(BOOL)overwrite
                   error:(NSError**)error;

/**
 *  Move a file to an protected path
 *
 *  @param path      source file
 *  @param location  destination folder
 *  @param overwrite YES to overwrite, NO to ignore
 *  @param error     populate should error occur
 *
 *  @return YES on success NO on failure
 */
- (BOOL)copyItemAtPath:(NSString*)path
    toPrivilegedLocation:(NSString*)location
               overwrite:(BOOL)overwrite
                   error:(NSError**)error;

/**
 *  Move a file to an protected path
 *
 *  @param path      source file
 *  @param error     populate should error occur
 *
 *  @return YES on success NO on failure
 */
- (BOOL)deleteItemAtPrivilegedPath:(NSString*)path error:(NSError**)error;

/**
 *  Set permissions on a protected file
 *
 *  @param attributes Dictionary of attributes. Conform to NSFileManger set
 *attribute keys
 *  @param path       file path
 *  @param error     populate should error occur
 *
 *  @return YES on success NO on failure
 */
- (BOOL)setAttributes:(NSDictionary*)attributes
    ofItemAtPrivilegedPath:(NSString*)path
                     error:(NSError**)error;
@end
