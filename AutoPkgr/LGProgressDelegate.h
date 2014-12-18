//
//  LGProgressDelegate.h
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//
//  Copyright 2014 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

@protocol LGProgressDelegate <NSObject>
@optional
- (void)startProgressWithMessage:(NSString *)message;
- (void)stopProgress:(NSError *)error;
- (void)updateProgress:(NSString *)message progress:(double)progress;

@end
