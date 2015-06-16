//
//  NSString+serialized.h
//  AutoPkgr
//
//  Created by Eldon on 5/5/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (NSTaskData)

@property (copy, nonatomic, readonly) NSDictionary *taskData_serializedDictionary;

@property (copy, nonatomic, readonly) NSString *taskData_string;

@property (copy, nonatomic, readonly) NSArray *taskData_splitLines;

@property (assign, nonatomic, readonly) BOOL taskData_isInteractive;
-(BOOL)taskData_isInteractiveWithStrings:(NSArray *)interactiveStrings;

@property (copy, nonatomic, readonly) id taskData_serializePropertyList;
- (id)taskData_serializePropertyList:(NSPropertyListFormat *)format;

@end
