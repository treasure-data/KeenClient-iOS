//
//  KeenJSONSerialization.m
//  KeenClient
//
//  Created by Daniel Kador on 8/21/12.
//  Copyright (c) 2012 Keen Labs. All rights reserved.
//

#import "KeenJSONSerialization.h"
#import "ISO8601DateFormatter.h"

static ISO8601DateFormatter *dateFormatter;

@interface KeenJSONSerialization ()

+ (id)convertNSDatesInJSONObject:(id)obj;
+ (id)convertDate: (id) date;

@end

@implementation KeenJSONSerialization

+ (void)initialize {
    [super initialize];
    
    if (!dateFormatter) {
        dateFormatter = [[ISO8601DateFormatter alloc] init];
        [dateFormatter setIncludeTime:YES];
        NSTimeZone *timeZone = [NSTimeZone localTimeZone];
        [dateFormatter setDefaultTimeZone:timeZone];
    }
}

+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error {
    // this is sort of the worst, but we want to support serializing NSDates and I can't think of
    // a good way to inject ourselves into the serialization code such that we handle NSDates but
    // the library handles all the other Foundation objects that NSJSSONSerialization supports.
    id toSerialize = [self convertNSDatesInJSONObject:obj];
    id val = [NSJSONSerialization dataWithJSONObject:toSerialize options:opt error:error];
    return val;
}

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    return [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
}

+ (id)convertNSDatesInJSONObject:(id)obj {
    id returnMe;
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:obj];
        for (NSString *key in [copy allKeys]) {
            id val = [obj objectForKey:key];
            id newVal = [self convertNSDatesInJSONObject:val];
            [copy setValue:newVal forKey:key];
        }
        returnMe = copy;
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *copy = [NSMutableArray arrayWithArray:obj];
        for (int i=0; i<[copy count]; i++) {
            id arrayObj = [copy objectAtIndex:i];
            [copy replaceObjectAtIndex:i withObject:[self convertNSDatesInJSONObject:arrayObj]];
        }
        returnMe = copy;
    } else if ([obj isKindOfClass:[NSDate class]]) {
        returnMe = [self convertDate:obj];
    } else {
        returnMe = obj;
    }
    return returnMe;
}

+ (id)convertDate: (id) date {
    return [dateFormatter stringFromDate:date];
}

@end
