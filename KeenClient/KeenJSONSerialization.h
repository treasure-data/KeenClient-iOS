//
//  KeenJSONSerialization.h
//  KeenClient
//
//  Created by Daniel Kador on 8/21/12.
//  Copyright (c) 2012 Keen Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeenJSONSerialization : NSObject

+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error;

@end
