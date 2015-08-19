//
//  NSData+taskData.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/5/15.
//  Copyright 2015 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "NSData+taskData.h"
#import "NSString+cleaned.h"

@implementation NSData (NSTaskData)

- (id)taskData_serializePropertyList:(NSPropertyListFormat *)format
{
    id results = nil;
    if (self.length) {
        // Initialize our dict
        results = [NSPropertyListSerialization propertyListWithData:self
                                                            options:NSPropertyListImmutable
                                                             format:format
                                                              error:nil];
    }
    return results;
}

- (NSString *)taskData_string
{
    return [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
}

- (NSArray *)taskData_splitLines
{
    return [self.taskData_string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (id)taskData_serializePropertyList
{
    return [self taskData_serializePropertyList:nil];
}

- (NSDictionary *)taskData_serializedDictionary
{
    id results = self.taskData_serializePropertyList;
    if ([results isKindOfClass:[NSDictionary class]]) {
        return results;
    }
    return nil;
}

- (BOOL)taskData_isInteractive {
    NSArray *defaultMatches = @[@" [y/n]:",
                                @" [YES/NO]:",
                                @" Password:",
                                ];

    return [self taskData_isInteractiveWithStrings:defaultMatches];
}

- (BOOL)taskData_isInteractiveWithStrings:(NSArray *)interactiveStrings {
    NSString *message = [[[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray *predicates = [NSMutableArray arrayWithCapacity:interactiveStrings.count];
    for (NSString *string in interactiveStrings) {
        NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[CD] %@", string];
        [predicates addObject:p];
    }
    NSCompoundPredicate *evalPredicate = [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:predicates];
    if ([evalPredicate evaluateWithObject:message]) {
        return YES;
    }
    return NO;
}

@end
