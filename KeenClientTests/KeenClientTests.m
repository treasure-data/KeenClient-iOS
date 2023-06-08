//
//  KeenClientTests.m
//  KeenClientTests
//
//  Created by Daniel Kador on 2/8/12.
//  Copyright (c) 2012 Keen Labs. All rights reserved.
//

#import "KeenClientTests.h"
#import "KeenClient.h"
#import <OCMock/OCMock.h>
#import "KeenConstants.h"
#import "KeenProperties.h"


@interface KeenClient (testability)

// The project ID for this particular client.
@property (nonatomic, strong) NSString *projectId;
@property (nonatomic, strong) NSString *writeKey;
@property (nonatomic, strong) NSString *readKey;

// If we're running tests.
@property (nonatomic) Boolean isRunningTests;

- (NSData *)sendEvents: (NSData *) data returningResponse: (NSURLResponse **) response error: (NSError **) error;
- (void)sendEvents:(NSData *)data database:(NSString *)database table:(NSString *)table completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (id)convertDate: (id) date;
- (id)handleInvalidJSONInObject:(id)value;
- (Boolean)migrateDBToSupportIngest;

@end

@interface KeenClientTests ()

- (NSString *)cacheDirectory;
- (NSString *)keenDirectory;
- (NSString *)eventDirectoryForCollection:(NSString *)collection;
- (NSArray *)contentsOfDirectoryForCollection:(NSString *)collection;
- (NSString *)pathForEventInCollection:(NSString *)collection WithTimestamp:(NSDate *)timestamp;
- (BOOL)writeNSData:(NSData *)data toFile:(NSString *)file;
@end

@implementation KeenClientTests

- (void)setUp {
    [super setUp];

    // Set-up code here.
    [[KeenClient sharedClient] setProjectId:nil];
    [[KeenClient sharedClient] setWriteKey:nil];
    [[KeenClient sharedClient] setReadKey:nil];
    [KeenClient enableLogging];
    [[KeenClient sharedClient] setGlobalPropertiesBlock:nil];
    [[KeenClient sharedClient] setGlobalPropertiesDictionary:nil];
}

- (void)tearDown {
    // Tear-down code here.
    NSLog(@"\n");
    [KeenClient clearAllEvents];

    [[KeenClient sharedClient] setGlobalPropertiesBlock:nil];
    [[KeenClient sharedClient] setGlobalPropertiesDictionary:nil];
    
    // delete all collections and their events.
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[self keenDirectory]]) {
        [fileManager removeItemAtPath:[self keenDirectory] error:&error];
        if (error) {
            XCTFail(@"No error should be thrown when cleaning up: %@", [error localizedDescription]);
        }
    }
    [super tearDown];
}

- (void)testInitWithProjectId{
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"something" andWriteKey:@"wk" andReadKey:@"rk"];
    XCTAssertEqualObjects(@"something", client.projectId, @"init with a valid project id should work");
    XCTAssertEqualObjects(@"wk", client.writeKey, @"init with a valid project id should work");
    XCTAssertEqualObjects(@"rk", client.readKey, @"init with a valid project id should work");
    
    KeenClient *client2 = [[KeenClient alloc] initWithProjectId:@"another" andWriteKey:@"wk2" andReadKey:@"rk2"];
    XCTAssertEqualObjects(@"another", client2.projectId, @"init with a valid project id should work");
    XCTAssertEqualObjects(@"wk2", client2.writeKey, @"init with a valid project id should work");
    XCTAssertEqualObjects(@"rk2", client2.readKey, @"init with a valid project id should work");
    XCTAssertTrue(client != client2, @"Another init should return a separate instance");
    
    client = [[KeenClient alloc] initWithProjectId:nil andWriteKey:@"wk" andReadKey:@"rk"];
    XCTAssertNil(client, @"init with a nil project ID should return nil");
}

- (void)testInstanceClient {
    KeenClient *client = [[KeenClient alloc] init];
    XCTAssertNil(client.projectId, @"a client's project id should be nil at first");
    XCTAssertNil(client.writeKey, @"a client's write key should be nil at first");
    XCTAssertNil(client.readKey, @"a client's read key should be nil at first");

    KeenClient *client2 = [[KeenClient alloc] init];
    XCTAssertTrue(client != client2, @"Another init should return a separate instance");
}

- (void)testSharedClientWithProjectId{
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    XCTAssertEqual(@"id", client.projectId, @"sharedClientWithProjectId with a non-nil project id should work.");
    XCTAssertEqualObjects(@"wk", client.writeKey, @"init with a valid project id should work");
    XCTAssertEqualObjects(@"rk", client.readKey, @"init with a valid project id should work");
    
    KeenClient *client2 = [KeenClient sharedClientWithProjectId:@"other" andWriteKey:@"wk2" andReadKey:@"rk2"];
    XCTAssertEqualObjects(client, client2, @"sharedClient should return the same instance");
    XCTAssertEqualObjects(@"wk2", client2.writeKey, @"sharedClient with a valid project id should work");
    XCTAssertEqualObjects(@"rk2", client2.readKey, @"sharedClient with a valid project id should work");
    
    client = [KeenClient sharedClientWithProjectId:nil andWriteKey:@"wk" andReadKey:@"rk"];
    XCTAssertNil(client, @"sharedClient with an invalid project id should return nil");
}

- (void)testSharedClient {
    KeenClient *client = [KeenClient sharedClient];
    XCTAssertNil(client.projectId, @"a client's project id should be nil at first");
    XCTAssertNil(client.writeKey, @"a client's write key should be nil at first");
    XCTAssertNil(client.readKey, @"a client's read key should be nil at first");
    
    KeenClient *client2 = [KeenClient sharedClient];
    XCTAssertEqualObjects(client, client2, @"sharedClient should return the same instance");
}

- (void)testAddEvent {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    KeenClient *clientI = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    
    // nil dict should should do nothing
    NSError *error = nil;
    XCTAssertFalse([client addEvent:nil toEventCollection:@"foo" error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"nil dict should return NO");
    error = nil;

    XCTAssertFalse([clientI addEvent:nil toEventCollection:@"foo" error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"nil dict should return NO");
    error = nil;
    
    // nil collection should do nothing
    XCTAssertFalse([client addEvent:[NSDictionary dictionary] toEventCollection:nil error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"nil collection should return NO");
    error = nil;

    XCTAssertFalse([clientI addEvent:[NSDictionary dictionary] toEventCollection:nil error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"nil collection should return NO");
    error = nil;
    
    // basic dict should work
    NSArray *keys = [NSArray arrayWithObjects:@"a", @"b", @"c", nil];
    NSArray *values = [NSArray arrayWithObjects:@"apple", @"bapple", [NSNull null], nil];
    NSDictionary *event = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    XCTAssertTrue([client addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should succeed");
    XCTAssertNil(error, @"no error should be returned");
    XCTAssertTrue([clientI addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should succeed");
    XCTAssertNil(error, @"an okay event should return YES");
    error = nil;

    // dict with NSDate should work
    event = @{@"a": @"apple", @"b": @"bapple", @"a_date": [NSDate date]};
    XCTAssertTrue([client addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should succeed");
    XCTAssertNil(error, @"no error should be returned");
    XCTAssertTrue([clientI addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should succeed");
    XCTAssertNil(error, @"an event with a date should return YES");
    error = nil;

    // dict with non-serializable value should do nothing
    NSError *badValue = [[NSError alloc] init];
    event = @{@"a": @"apple", @"b": @"bapple", @"bad_key": badValue};
    XCTAssertFalse([client addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"an event that can't be serialized should return NO");
    XCTAssertNotNil([[error userInfo] objectForKey:NSUnderlyingErrorKey], @"and event that can't be serialized should return the underlaying error");
    error = nil;

    XCTAssertFalse([clientI addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"an event that can't be serialized should return NO");
    XCTAssertNotNil([[error userInfo] objectForKey:NSUnderlyingErrorKey], @"and event that can't be serialized should return the underlaying error");
    error = nil;
    
    // dict with root keen prop should do nothing
    badValue = [[NSError alloc] init];
    event = @{@"a": @"apple", @"keen": @"bapple"};
    XCTAssertFalse([client addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"");
    error = nil;

    XCTAssertFalse([clientI addEvent:event toEventCollection:@"foo" error:&error], @"addEvent should fail");
    XCTAssertNotNil(error, @"");
    error = nil;
    
    // dict with non-root keen prop should work
    error = nil;
    event = @{@"nested": @{@"keen": @"whatever"}};
    XCTAssertTrue([client addEvent:event toEventCollection:@"foo" error:nil], @"addEvent should succeed");
    XCTAssertNil(error, @"no error should be returned");
    XCTAssertTrue([clientI addEvent:event toEventCollection:@"foo" error:nil], @"addEvent should succeed");
    XCTAssertNil(error, @"an okay event should return YES");
}

- (void)testAddEventNoWriteKey {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:nil andReadKey:nil];
    KeenClient *clientI = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:nil andReadKey:nil];
    
    NSArray *keys = [NSArray arrayWithObjects:@"a", @"b", @"c", nil];
    NSArray *values = [NSArray arrayWithObjects:@"apple", @"bapple", [NSNull null], nil];
    NSDictionary *event = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    XCTAssertThrows([client addEvent:event toEventCollection:@"foo" error:nil], @"should throw an exception");
    XCTAssertThrows([clientI addEvent:event toEventCollection:@"foo" error:nil], @"should throw an exception");
}

- (void)testEventNoLongerAddTimestamp {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    KeenClient *clientI = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];

    NSDate *date = [NSDate date];
    KeenProperties *keenProperties = [[KeenProperties alloc] init];
    keenProperties.timestamp = date;
    [client addEvent:@{@"a": @"b"} withKeenProperties:keenProperties toEventCollection:@"foo" error:nil];
    [clientI addEvent:@{@"a": @"b"} withKeenProperties:keenProperties toEventCollection:@"foo" error:nil];

    NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:@"foo"];
    // Grab the first event we get back
    NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
    NSError *error = nil;
    NSDictionary *deserializedDict = [NSJSONSerialization JSONObjectWithData:eventData
                                                                options:0
                                                                  error:&error];

    NSString *deserializedDate = deserializedDict[@"keen"][@"timestamp"];
    XCTAssertEqualObjects(deserializedDate, nil, @"There should not be timestamp.");
}

- (void)testEventWithDictionary {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    KeenClient *clientI = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];

    NSString* json = @"{\"test_str_array\":[\"val1\",\"val2\",\"val3\"]}";
    NSDictionary* eventDictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    [client addEvent:eventDictionary toEventCollection:@"foo" error:nil];
    [clientI addEvent:eventDictionary toEventCollection:@"foo" error:nil];
    NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:@"foo"];
    // Grab the first event we get back
    NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
    NSError *error = nil;
    NSDictionary *deserializedDict = [NSJSONSerialization JSONObjectWithData:eventData
                                                                     options:0
                                                                       error:&error];

    XCTAssertEqualObjects(@"val1", deserializedDict[@"test_str_array"][0], @"array was incorrect");
    XCTAssertEqualObjects(@"val2", deserializedDict[@"test_str_array"][1], @"array was incorrect");
    XCTAssertEqualObjects(@"val3", deserializedDict[@"test_str_array"][2], @"array was incorrect");
}

- (void)testEventWithNonDictionaryKeen {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    KeenClient *clientI = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    
    NSDictionary *theEvent = @{@"keen": @"abc"};
    NSError *error = nil;
    [client addEvent:theEvent toEventCollection:@"foo" error:&error];
    [clientI addEvent:theEvent toEventCollection:@"foo" error:&error];
    XCTAssertNotNil(error, @"an event with a non-dict value for 'keen' should error");
}

- (void)testBasicAddon {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    KeenClient *clientI = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    
    NSDictionary *theEvent = @{
                               @"keen":@{
                                       @"addons" : @[
                                               @{
                                                   @"name" : @"addon:name",
                                                   @"input" : @{@"param_name" : @"property_that_contains_param"},
                                                   @"output" : @"property.to.store.output"
                                                   }
                                               ]
                                       },
                               @"a": @"b"
                               };
    
    // add the event
    NSError *error = nil;
    [client addEvent:theEvent toEventCollection:@"foo" error:&error];
    [clientI addEvent:theEvent toEventCollection:@"foo" error:&error];
    XCTAssertNil(error, @"event should add");
    
    // Grab the first event we get back
    NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:@"foo"];
    // Grab the first event we get back
    NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
    NSDictionary *deserializedDict = [NSJSONSerialization JSONObjectWithData:eventData
                                                                     options:0
                                                                       error:&error];
    
    NSDictionary *deserializedAddon = deserializedDict[@"keen"][@"addons"][0];
    XCTAssertEqualObjects(@"addon:name", deserializedAddon[@"name"], @"Addon name should be right");
}

- (NSDictionary *)buildResultWithSuccess:(Boolean)success 
                            andErrorCode:(NSString *)errorCode 
                          andDescription:(NSString *)description {
    NSDictionary *result = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:success]
                                                              forKey:@"success"];
    if (!success) {
        NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:errorCode, @"name",
                               description, @"description", nil];
        [result setValue:error forKey:@"error"];
    }
    return result;
}

- (NSDictionary *)buildResponseJsonWithSuccess:(Boolean)success 
                                 AndErrorCode:(NSString *)errorCode 
                               AndDescription:(NSString *)description {
    NSDictionary *result = [self buildResultWithSuccess:success 
                                           andErrorCode:errorCode 
                                         andDescription:description];
    NSArray *array = [NSArray arrayWithObject:result];
    return [NSDictionary dictionaryWithObject:array forKey:@"receipts"];
}

- (id)uploadTestHelperWithDataSequence:(NSArray *)dataSequence andStatusCodes:(NSArray *)codes {
    // set up the partial mock
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    id mock = [OCMockObject partialMockForObject:client];
    
    // setup data sequence
    NSMutableArray *serializedDataSequence = [NSMutableArray array];
    for (NSDictionary *d in dataSequence) {
        NSDictionary *data = d;
        if (!data) {
            data = [self buildResponseJsonWithSuccess:YES AndErrorCode:nil AndDescription:nil];
        }

        
        
        // serialize the faked out response data
        data = [client handleInvalidJSONInObject:data];
        NSData *serializedData = [NSJSONSerialization dataWithJSONObject:data
                                                                 options:0
                                                                   error:nil];
        [serializedDataSequence addObject:serializedData];
    }
    
    __block NSUInteger index = 0;
    [OCMStub([mock sendEvents:[OCMArg any] database:[OCMArg any] table:[OCMArg any] completionHandler:[OCMArg any]]) andDo:^(NSInvocation *invocation) {
        void (^handler)(NSData *data, NSURLResponse *response, NSError *error);
        [invocation getArgument:&handler atIndex:5];
        NSData *serializedData = serializedDataSequence[index];
        // set up the response we're faking out
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:[codes[index] integerValue] HTTPVersion:nil headerFields:nil];
        index += 1;
        handler(serializedData, response, nil);
    }];
    
    return mock;
}

- (id)uploadTestHelperWithData:(id)data andStatusCode:(NSInteger)code {
    if (!data) {
        data = [self buildResponseJsonWithSuccess:YES AndErrorCode:nil AndDescription:nil];
    }
    
    // set up the partial mock
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    id mock = [OCMockObject partialMockForObject:client];
    
    // set up the response we're faking out
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:code HTTPVersion:nil headerFields:nil];

    
    // serialize the faked out response data
    data = [client handleInvalidJSONInObject:data];
    NSData *serializedData = [NSJSONSerialization dataWithJSONObject:data
                                                             options:0
                                                               error:nil];
    // set up the response data we're faking out
//    [[[mock stub] andReturn:serializedData] sendEvents:[OCMArg any]
//                                     returningResponse:[OCMArg setTo:response]
//                                                 error:[OCMArg setTo:nil]];
    
    
    [OCMStub([mock sendEvents:[OCMArg any] database:[OCMArg any] table:[OCMArg any] completionHandler:[OCMArg any]]) andDo:^(NSInvocation *invocation) {
        void (^handler)(NSData *data, NSURLResponse *response, NSError *error);
        [invocation getArgument:&handler atIndex:5];
        handler(serializedData, response, nil);
    }];
    
    return mock;
}

- (id)uploadTestHelperWithDataInstanceClient:(id)data andStatusCode:(NSInteger)code {
    if (!data) {
        data = [self buildResponseJsonWithSuccess:YES AndErrorCode:nil AndDescription:nil];
    }
    
    // set up the partial mock
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    id mock = [OCMockObject partialMockForObject:client];
    
    // set up the response we're faking out
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:code HTTPVersion:nil headerFields:nil];

    // serialize the faked out response data
    data = [client handleInvalidJSONInObject:data];
    NSData *serializedData = [NSJSONSerialization dataWithJSONObject:data
                                                             options:0
                                                               error:nil];
    // set up the response data we're faking out
//    [[[mock stub] andReturn:serializedData] sendEvents:[OCMArg any]
//                                     returningResponse:[OCMArg setTo:response]
//                                                 error:[OCMArg setTo:nil]];
    
    [OCMStub([mock sendEvents:[OCMArg any] database:[OCMArg any] table:[OCMArg any] completionHandler:[OCMArg any]]) andDo:^(NSInvocation *invocation) {
        void (^handler)(NSData *data, NSURLResponse *response, NSError *error);
        [invocation getArgument:&handler atIndex:5];
        handler(serializedData, response, nil);
    }];
    
    return mock;
}

- (void)addSimpleEventAndUploadWithMock:(id)mock {
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    
    // and "upload" it
    [mock uploadWithFinishedBlock:nil];
}

- (void)addSimpleEventAndUploadWithMock:(id)mock andExpect:(void (^)(void))expect {
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:expect];
}

- (void)uploadWithMock:(id)mock andExpect:(void(^)(void))expect {
    XCTestExpectation *expectation = [XCTestExpectation new];
    
    [mock uploadWithFinishedBlock: ^{
        expect();
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:10];
}

- (void)testUploadSuccess {
    id mock = [self uploadTestHelperWithData:nil andStatusCode:200];

    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0, @"There should be no files after a successful upload.");
    }];
}

- (void)testUploadSuccessInstanceClient {
    id mock = [self uploadTestHelperWithDataInstanceClient:nil andStatusCode:200];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the event was deleted from the store
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0, @"There should be no files after a successful upload.");
    }];
}

- (void)testUploadFailedServerDown {
    id mock = [self uploadTestHelperWithData:nil andStatusCode:500];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file wasn't deleted from the store
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1, @"There should be one files after a successful upload.");
    }];
}

- (void)testUploadFailedServerDownInstanceClient {
    id mock = [self uploadTestHelperWithDataInstanceClient:nil andStatusCode:500];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file wasn't deleted from the store
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1, @"There should be one files after a successful upload.");
    }];
}

- (void)testUploadFailedServerDownNonJsonResponse {
    id mock = [self uploadTestHelperWithData:@{} andStatusCode:500];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file wasn't deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1, @"There should be one files after a successful upload.");
    }];
}

- (void)testUploadFailedServerDownNonJsonResponseInstanceClient {
    id mock = [self uploadTestHelperWithDataInstanceClient:@{} andStatusCode:500];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file wasn't deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1, @"There should be one files after a successful upload.");
    }];
}

- (void)testUploadFailedBadRequest {
    id mock = [self uploadTestHelperWithData:[self buildResponseJsonWithSuccess:NO
                                                                   AndErrorCode:@"InvalidCollectionNameError" 
                                                                 AndDescription:@"anything"] 
                               andStatusCode:200];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file was deleted locally
        // make sure the event was deleted from the store
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"An invalid event should be deleted after an upload attempt.");
    }];
}

- (void)testUploadFailedBadRequestInstanceClient {
    id mock = [self uploadTestHelperWithDataInstanceClient:[self buildResponseJsonWithSuccess:NO
                                                                   AndErrorCode:@"InvalidCollectionNameError"
                                                                 AndDescription:@"anything"]
                               andStatusCode:200];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file was deleted locally
        // make sure the event was deleted from the store
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"An invalid event should be deleted after an upload attempt.");
    }];
}

- (void)testUploadFailedBadRequestUnknownError {
    id mock = [self uploadTestHelperWithData:@{} andStatusCode:400];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file wasn't deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1, @"An upload that results in an unexpected error should not delete the event.");
    }];
}

- (void)testUploadFailedBadRequestUnknownErrorInstanceClient {
    id mock = [self uploadTestHelperWithDataInstanceClient:@{} andStatusCode:400];
    
    [self addSimpleEventAndUploadWithMock:mock andExpect:^{
        // make sure the file wasn't deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1, @"An upload that results in an unexpected error should not delete the event.");
    }];
}

- (void)testUploadMultipleEventsSameCollectionSuccess {
    NSDictionary *result1 = [self buildResultWithSuccess:YES 
                                            andErrorCode:nil 
                                          andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil 
                                          andDescription:nil];
    NSDictionary *result = [NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:result1, result2, nil]
                                                       forKey:@"receipts"];
    id mock = [self uploadTestHelperWithData:result andStatusCode:200];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple2" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the events were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no files after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsSameCollectionSuccessInstanceClient {
    NSDictionary *result1 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil
                                          andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil
                                          andDescription:nil];
    NSDictionary *result = [NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:result1, result2, nil]
                                                       forKey:@"receipts"];
    id mock = [self uploadTestHelperWithDataInstanceClient:result andStatusCode:200];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple2" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the events were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no files after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsDifferentCollectionSuccess {
    NSDictionary *result1 = [self buildResultWithSuccess:YES 
                                            andErrorCode:nil 
                                          andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil 
                                          andDescription:nil];
    NSDictionary *response1 = @{@"receipts": @[result1]};
    NSDictionary *response2 = @{@"receipts": @[result2]};
    id mock = [self uploadTestHelperWithDataSequence:@[response1, response2] andStatusCodes:@[@200, @200]];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the files were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no events after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsDifferentCollectionSuccessInstanceClient {
    NSDictionary *result1 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil
                                          andDescription:nil];
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObjects:result1, nil], @"receipts", nil];
    id mock = [self uploadTestHelperWithDataInstanceClient:result andStatusCode:200];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo1.bar1" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the files were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no events after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsSameCollectionOneFails {
    NSDictionary *result1 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil
                                          andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:NO
                                            andErrorCode:@"InvalidCollectionNameError"
                                          andDescription:@"something"];
    NSDictionary *result = [NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:result1, result2, nil]
                                                       forKey:@"receipts"];
    id mock = [self uploadTestHelperWithData:result andStatusCode:200];

    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple2" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];

    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the file were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no events after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsSameCollectionOneFailsInstanceClient {
    NSDictionary *result1 = [self buildResultWithSuccess:YES
                                            andErrorCode:nil
                                          andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:NO
                                            andErrorCode:@"InvalidCollectionNameError"
                                          andDescription:@"something"];
    NSDictionary *result = [NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:result1, result2, nil]
                                                       forKey:@"receipts"];
    id mock = [self uploadTestHelperWithDataInstanceClient:result andStatusCode:200];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple2" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the file were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no events after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsDifferentCollectionsAndFails {
    NSDictionary *result1 = [self buildResultWithSuccess:NO
                                            andErrorCode:@"InvalidCollectionNameError"
                                          andDescription:@"something"];
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObject:result1], @"receipts", nil];
    id mock = [self uploadTestHelperWithData:result andStatusCode:200];

    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo1.bar1" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];

    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the files were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no events after a successful upload.");
    }];
}

- (void)testUploadMultipleEventsDifferentCollectionsAndFailsForServerReason {
    NSDictionary *result1 = [self buildResultWithSuccess:NO
                                            andErrorCode:@"barf"
                                          andDescription:@"something"];
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObjects:result1, nil], @"receipts", nil];
    id mock = [self uploadTestHelperWithData:result andStatusCode:200];

    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo1.bar1" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];

    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the files were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 2,  @"There should be 1 events after a partial upload.");
    }];
}

- (void)testMaxUploadEventsAtOnceSuccess {
    NSDictionary *result1 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result3 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result4 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result5 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *response1 = @{@"receipts": @[result1, result2]};
    NSDictionary *response2 = @{@"receipts": @[result3, result4]};
    NSDictionary *response3 = @{@"receipts": @[result5]};
    id mock = [self uploadTestHelperWithDataSequence:@[response1, response2, response3] andStatusCodes:@[@200, @200, @200]];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"orange" forKey:@"a"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"borange" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"corange" forKey:@"c"] toEventCollection:@"foo2.bar2" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        // make sure the files were deleted locally
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 0,  @"There should be no events after a successful upload.");
    }];
}

- (void)testMaxUploadEventsAtOnceFailure {
//    NSDictionary *result1 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
//    NSDictionary *result2 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result3 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result4 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result5 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *response1 = @{};
    NSDictionary *response2 = @{@"receipts": @[result3, result4]};
    NSDictionary *response3 = @{@"receipts": @[result5]};
    id mock = [self uploadTestHelperWithDataSequence:@[response1, response2, response3] andStatusCodes:@[@500, @200, @200]];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"orange" forKey:@"a"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"borange" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"corange" forKey:@"c"] toEventCollection:@"foo2.bar2" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        NSLog(@"getTotalEventCount %lu", [[KeenClient getEventStore] getTotalEventCount]);
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 2,  @"There should be 2 events after request #1 fails upload.");
    }];
}

- (void)testMaxUploadEventsAtOncePartialFailureInCollection {
    NSDictionary *result1 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
//    NSDictionary *result3 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
//    NSDictionary *result4 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result5 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *response1 = @{@"receipts": @[result1, result2]};
    NSDictionary *response2 = @{};
    NSDictionary *response3 = @{@"receipts": @[result5]};
    id mock = [self uploadTestHelperWithDataSequence:@[response1, response2, response3] andStatusCodes:@[@200, @500, @200]];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"orange" forKey:@"a"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"borange" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"corange" forKey:@"c"] toEventCollection:@"foo2.bar2" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        NSLog(@"getTotalEventCount %lu", [[KeenClient getEventStore] getTotalEventCount]);
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 2,  @"There should be 2 events after request #2 fails upload.");
    }];
}

- (void)testMaxUploadEventsAtOncePartialFailureInRequest {
    NSDictionary *result1 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result2 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result3 = [self buildResultWithSuccess:NO andErrorCode:nil andDescription:nil];
    NSDictionary *result4 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *result5 = [self buildResultWithSuccess:YES andErrorCode:nil andDescription:nil];
    NSDictionary *response1 = @{@"receipts": @[result1, result2]};
    NSDictionary *response2 = @{@"receipts": @[result3, result4]};
    NSDictionary *response3 = @{@"receipts": @[result5]};
    id mock = [self uploadTestHelperWithDataSequence:@[response1, response2, response3] andStatusCodes:@[@200, @200, @200]];
    
    // add an event
    [mock addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"bapple" forKey:@"b"] toEventCollection:@"foo.bar" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"orange" forKey:@"a"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"borange" forKey:@"b"] toEventCollection:@"foo2.bar2" error:nil];
    [mock addEvent:[NSDictionary dictionaryWithObject:@"corange" forKey:@"c"] toEventCollection:@"foo2.bar2" error:nil];
    
    // and "upload" it
    [self uploadWithMock:mock andExpect:^{
        NSLog(@"getTotalEventCount %lu", [[KeenClient getEventStore] getTotalEventCount]);
        XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 1,  @"There should be 1 events after request #2 fails upload.");
    }];
}

- (void)testTooManyEventsCached {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"foo", nil];
    // create 5 events
    for (int i=0; i<5; i++) {
        [client addEvent:event toEventCollection:@"something" error:nil];
    }
    XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 5,  @"There should be exactly five events.");
    // now do one more, should age out 1 old ones
    [client addEvent:event toEventCollection:@"something" error:nil];
    // so now there should be 4 left (5 - 2 + 1)
    XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 4, @"There should be exactly five events.");
}

- (void)testTooManyEventsCachedInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"foo", nil];
    // create 5 events
    for (int i=0; i<5; i++) {
        [client addEvent:event toEventCollection:@"something" error:nil];
    }
    XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 5,  @"There should be exactly five events.");
    // now do one more, should age out 1 old ones
    [client addEvent:event toEventCollection:@"something" error:nil];
    // so now there should be 4 left (5 - 2 + 1)
    XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 4, @"There should be exactly five events.");
}

- (void)testGlobalPropertiesDictionary {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary * (^RunTest)(NSDictionary*, NSUInteger) = ^(NSDictionary *globalProperties,
                                                             NSUInteger expectedNumProperties) {
        NSString *eventCollectionName = [NSString stringWithFormat:@"foo%f", [[NSDate date] timeIntervalSince1970]];
        client.globalPropertiesDictionary = globalProperties;
        NSDictionary *event = @{@"foo": @"bar"};
        [client addEvent:event toEventCollection:eventCollectionName error:nil];
        NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:eventCollectionName];
        // Grab the first event we get back
        NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
        NSError *error = nil;
        NSDictionary *storedEvent = [NSJSONSerialization JSONObjectWithData:eventData
                                                                  options:0
                                                                    error:&error];

        XCTAssertEqualObjects(event[@"foo"], storedEvent[@"foo"], @"");
        XCTAssertTrue([storedEvent count] == expectedNumProperties + 1, @"");
        return storedEvent;
    };
    
    // a nil dictionary should be okay
    RunTest(nil, 0);
    
    // an empty dictionary should be okay
    RunTest(@{}, 0);
    
    // a dictionary that returns some non-conflicting property names should be okay
    NSDictionary *storedEvent = RunTest(@{@"default_name": @"default_value"}, 1);
    XCTAssertEqualObjects(@"default_value", storedEvent[@"default_name"], @"");
    
    // a dictionary that returns a conflicting property name should not overwrite the property on
    // the event
    RunTest(@{@"foo": @"some_new_value"}, 0);
    
    // a dictionary that contains an addon should be okay
    NSDictionary *theEvent = @{
                               @"keen":@{
                                       @"addons" : @[
                                               @{
                                                   @"name" : @"addon:name",
                                                   @"input" : @{@"param_name" : @"property_that_contains_param"},
                                                   @"output" : @"property.to.store.output"
                                                   }
                                               ]
                                       },
                               @"a": @"b"
                               };
    storedEvent = RunTest(theEvent, 2);
    NSDictionary *deserializedAddon = storedEvent[@"keen"][@"addons"][0];
    XCTAssertEqualObjects(@"addon:name", deserializedAddon[@"name"], @"Addon name should be right");
}

- (void)testGlobalPropertiesDictionaryInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary * (^RunTest)(NSDictionary*, NSUInteger) = ^(NSDictionary *globalProperties,
                                                             NSUInteger expectedNumProperties) {
        NSString *eventCollectionName = [NSString stringWithFormat:@"foo%f", [[NSDate date] timeIntervalSince1970]];
        client.globalPropertiesDictionary = globalProperties;
        NSDictionary *event = @{@"foo": @"bar"};
        [client addEvent:event toEventCollection:eventCollectionName error:nil];
        NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:eventCollectionName];
        // Grab the first event we get back
        NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
        NSError *error = nil;
        NSDictionary *storedEvent = [NSJSONSerialization JSONObjectWithData:eventData
                                                                    options:0
                                                                      error:&error];
        
        XCTAssertEqualObjects(event[@"foo"], storedEvent[@"foo"], @"");
        XCTAssertTrue([storedEvent count] == expectedNumProperties + 1, @"");
        return storedEvent;
    };
    
    // a nil dictionary should be okay
    RunTest(nil, 0);
    
    // an empty dictionary should be okay
    RunTest(@{}, 0);
    
    // a dictionary that returns some non-conflicting property names should be okay
    NSDictionary *storedEvent = RunTest(@{@"default_name": @"default_value"}, 1);
    XCTAssertEqualObjects(@"default_value", storedEvent[@"default_name"], @"");
    
    // a dictionary that returns a conflicting property name should not overwrite the property on
    // the event
    RunTest(@{@"foo": @"some_new_value"}, 0);
    
    // a dictionary that contains an addon should be okay
    NSDictionary *theEvent = @{
                               @"keen":@{
                                       @"addons" : @[
                                               @{
                                                   @"name" : @"addon:name",
                                                   @"input" : @{@"param_name" : @"property_that_contains_param"},
                                                   @"output" : @"property.to.store.output"
                                                   }
                                               ]
                                       },
                               @"a": @"b"
                               };
    storedEvent = RunTest(theEvent, 2);
    NSDictionary *deserializedAddon = storedEvent[@"keen"][@"addons"][0];
    XCTAssertEqualObjects(@"addon:name", deserializedAddon[@"name"], @"Addon name should be right");
}

- (void)testGlobalPropertiesBlock {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary * (^RunTest)(KeenGlobalPropertiesBlock, NSUInteger) = ^(KeenGlobalPropertiesBlock block,
                                                                         NSUInteger expectedNumProperties) {
        NSString *eventCollectionName = [NSString stringWithFormat:@"foo%f", [[NSDate date] timeIntervalSince1970]];
        client.globalPropertiesBlock = block;
        NSDictionary *event = @{@"foo": @"bar"};
        [client addEvent:event toEventCollection:eventCollectionName error:nil];

        NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:eventCollectionName];
        // Grab the first event we get back
        NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
        NSError *error = nil;
        NSDictionary *storedEvent = [NSJSONSerialization JSONObjectWithData:eventData
                                                                    options:0
                                                                      error:&error];

        XCTAssertEqualObjects(event[@"foo"], storedEvent[@"foo"], @"");
        XCTAssertTrue([storedEvent count] == expectedNumProperties + 1, @"");
        return storedEvent;
    };
    
    // a block that returns nil should be okay
    RunTest(nil, 0);
    
    // a block that returns an empty dictionary should be okay
    RunTest(^NSDictionary *(NSString *eventCollection) {
        return [NSDictionary dictionary];
    }, 0);
    
    // a block that returns some non-conflicting property names should be okay
    NSDictionary *storedEvent = RunTest(^NSDictionary *(NSString *eventCollection) {
        return @{@"default_name": @"default_value"};
    }, 1);
    XCTAssertEqualObjects(@"default_value", storedEvent[@"default_name"], @"");
    
    // a block that returns a conflicting property name should not overwrite the property on the event
    RunTest(^NSDictionary *(NSString *eventCollection) {
        return @{@"foo": @"some new value"};
    }, 0);
    
    // a dictionary that contains an addon should be okay
    NSDictionary *theEvent = @{
                               @"keen":@{
                                       @"addons" : @[
                                               @{
                                                   @"name" : @"addon:name",
                                                   @"input" : @{@"param_name" : @"property_that_contains_param"},
                                                   @"output" : @"property.to.store.output"
                                                   }
                                               ]
                                       },
                               @"a": @"b"
                               };
    storedEvent = RunTest(^NSDictionary *(NSString *eventCollection) {
        return theEvent;
    }, 2);
    NSDictionary *deserializedAddon = storedEvent[@"keen"][@"addons"][0];
    XCTAssertEqualObjects(@"addon:name", deserializedAddon[@"name"], @"Addon name should be right");
}

- (void)testGlobalPropertiesBlockInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary * (^RunTest)(KeenGlobalPropertiesBlock, NSUInteger) = ^(KeenGlobalPropertiesBlock block,
                                                                         NSUInteger expectedNumProperties) {
        NSString *eventCollectionName = [NSString stringWithFormat:@"foo%f", [[NSDate date] timeIntervalSince1970]];
        client.globalPropertiesBlock = block;
        NSDictionary *event = @{@"foo": @"bar"};
        [client addEvent:event toEventCollection:eventCollectionName error:nil];
        
        NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:eventCollectionName];
        // Grab the first event we get back
        NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
        NSError *error = nil;
        NSDictionary *storedEvent = [NSJSONSerialization JSONObjectWithData:eventData
                                                                    options:0
                                                                      error:&error];
        
        XCTAssertEqualObjects(event[@"foo"], storedEvent[@"foo"], @"");
        XCTAssertTrue([storedEvent count] == expectedNumProperties + 1, @"");
        return storedEvent;
    };
    
    // a block that returns nil should be okay
    RunTest(nil, 0);
    
    // a block that returns an empty dictionary should be okay
    RunTest(^NSDictionary *(NSString *eventCollection) {
        return [NSDictionary dictionary];
    }, 0);
    
    // a block that returns some non-conflicting property names should be okay
    NSDictionary *storedEvent = RunTest(^NSDictionary *(NSString *eventCollection) {
        return @{@"default_name": @"default_value"};
    }, 1);
    XCTAssertEqualObjects(@"default_value", storedEvent[@"default_name"], @"");
    
    // a block that returns a conflicting property name should not overwrite the property on the event
    RunTest(^NSDictionary *(NSString *eventCollection) {
        return @{@"foo": @"some new value"};
    }, 0);
    
    // a dictionary that contains an addon should be okay
    NSDictionary *theEvent = @{
                               @"keen":@{
                                       @"addons" : @[
                                               @{
                                                   @"name" : @"addon:name",
                                                   @"input" : @{@"param_name" : @"property_that_contains_param"},
                                                   @"output" : @"property.to.store.output"
                                                   }
                                               ]
                                       },
                               @"a": @"b"
                               };
    storedEvent = RunTest(^NSDictionary *(NSString *eventCollection) {
        return theEvent;
    }, 2);
    NSDictionary *deserializedAddon = storedEvent[@"keen"][@"addons"][0];
    XCTAssertEqualObjects(@"addon:name", deserializedAddon[@"name"], @"Addon name should be right");
}

- (void)testGlobalPropertiesTogether {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    // properties from the block should take precedence over properties from the dictionary
    // but properties from the event itself should take precedence over all
    client.globalPropertiesDictionary = @{@"default_property": @5, @"foo": @"some_new_value"};
    client.globalPropertiesBlock = ^NSDictionary *(NSString *eventCollection) {
        return @{ @"default_property": @6, @"foo": @"some_other_value"};
    };
    [client addEvent:@{@"foo": @"bar"} toEventCollection:@"apples" error:nil];

    NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:@"apples"];
    // Grab the first event we get back
    NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
    NSError *error = nil;
    NSDictionary *storedEvent = [NSJSONSerialization JSONObjectWithData:eventData
                                                                options:0
                                                                  error:&error];

    XCTAssertEqualObjects(@"bar", storedEvent[@"foo"], @"");
    XCTAssertEqualObjects(@6, storedEvent[@"default_property"], @"");
    XCTAssertTrue([storedEvent count] == 2, @"");
}

- (void)testGlobalPropertiesTogetherInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    // properties from the block should take precedence over properties from the dictionary
    // but properties from the event itself should take precedence over all
    client.globalPropertiesDictionary = @{@"default_property": @5, @"foo": @"some_new_value"};
    client.globalPropertiesBlock = ^NSDictionary *(NSString *eventCollection) {
        return @{ @"default_property": @6, @"foo": @"some_other_value"};
    };
    [client addEvent:@{@"foo": @"bar"} toEventCollection:@"apples" error:nil];
    
    NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:@"apples"];
    // Grab the first event we get back
    NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:0]];
    NSError *error = nil;
    NSDictionary *storedEvent = [NSJSONSerialization JSONObjectWithData:eventData
                                                                options:0
                                                                  error:&error];
    
    XCTAssertEqualObjects(@"bar", storedEvent[@"foo"], @"");
    XCTAssertEqualObjects(@6, storedEvent[@"default_property"], @"");
    XCTAssertTrue([storedEvent count] == 2, @"");
}

- (void)testInvalidEventCollection {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary *event = @{@"a": @"b"};
    // collection can't start with $
    NSError *error = nil;
    [client addEvent:event toEventCollection:@"$asd" error:&error];
    XCTAssertNotNil(error, @"collection can't start with $");
    error = nil;
    
    // collection can't be over 256 chars
    NSMutableString *longString = [NSMutableString stringWithCapacity:257];
    for (int i=0; i<257; i++) {
        [longString appendString:@"a"];
    }
    [client addEvent:event toEventCollection:@"$asd" error:&error];
    XCTAssertNotNil(error, @"collection can't be longer than 256 chars");
}

- (void)testInvalidEventCollectionInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary *event = @{@"a": @"b"};
    // collection can't start with $
    NSError *error = nil;
    [client addEvent:event toEventCollection:@"$asd" error:&error];
    XCTAssertNotNil(error, @"collection can't start with $");
    error = nil;
    
    // collection can't be over 256 chars
    NSMutableString *longString = [NSMutableString stringWithCapacity:257];
    for (int i=0; i<257; i++) {
        [longString appendString:@"a"];
    }
    [client addEvent:event toEventCollection:@"$asd" error:&error];
    XCTAssertNotNil(error, @"collection can't be longer than 256 chars");
}

- (void)testUploadMultipleTimes {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    [client uploadWithFinishedBlock:nil];
    [client uploadWithFinishedBlock:nil];
    [client uploadWithFinishedBlock:nil];
}

- (void)testUploadMultipleTimesInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    [client uploadWithFinishedBlock:nil];
    [client uploadWithFinishedBlock:nil];
    [client uploadWithFinishedBlock:nil];
}

- (void)testMigrateFSEvents {

    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;

    // make sure the directory we want to write the file to exists
    NSString *dirPath = [self eventDirectoryForCollection:@"foo"];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    [manager createDirectoryAtPath:dirPath withIntermediateDirectories:true attributes:nil error:&error];
    XCTAssertNil(error, @"created directory for events");

    // Write out a couple of events that we can import later!
    NSDictionary *event1 = [NSDictionary dictionaryWithObject:@"apple" forKey:@"a"];
    NSDictionary *event2 = [NSDictionary dictionaryWithObject:@"orange" forKey:@"b"];

    NSData *json1 = [NSJSONSerialization dataWithJSONObject:event1 options:0 error:&error];
    NSData *json2 =[NSJSONSerialization dataWithJSONObject:event2 options:0 error:&error];

    NSString *fileName1 = [self pathForEventInCollection:@"foo" WithTimestamp:[NSDate date]];
    NSString *fileName2 = [self pathForEventInCollection:@"foo" WithTimestamp:[NSDate date]];

    [self writeNSData:json1 toFile:fileName1];
    [self writeNSData:json2 toFile:fileName2];

    [client importFileData];
    // Now we're gonna add an event and verify the events we just wrote to the fs
    // are added to the database and the files are cleaned up.
    error = nil;
    NSDictionary *event3 = @{@"nested": @{@"keen": @"whatever"}};
    [client addEvent:event3 toEventCollection:@"foo" error:nil];

    XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 3,  @"There should be 3 events after an import.");
    XCTAssertFalse([manager fileExistsAtPath:[self keenDirectory] isDirectory:true], @"The Keen directory should be gone.");
}

- (NSDictionary *)getEventOfCollection:(NSString *)collectionName atIndex:(NSInteger)index {
    NSDictionary *eventsForCollection = [[[KeenClient getEventStore] getEvents] objectForKey:collectionName];
    NSData *eventData = [eventsForCollection objectForKey:[[eventsForCollection allKeys] objectAtIndex:index]];
    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:eventData options:0 error:&error];
    return event;
}

- (void)testMigrateDBToSupportIngest {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary *event10 = @{@"key": @"value"};
    NSDictionary *event11 = @{@"key": @"value", @"keen": @{@"time": @12324567890}, @"#SSUT": @"test-ssut"};
    NSDictionary *event20 = @{@"nested": @{@"keen": @"whatever"}, @"keen": @{@"time": @22324567890}, @"#UUID": @"test-uuid", @"#SSUT": @"test-ssut2"};
    NSDictionary *event21 = @{@"nested": @{@"keen": @"whatever"}, @"#UUID": @"test-uuid"};
    NSDictionary *event30 = @{@"key": @"value", @"key2": @"value2", @"keen": @{@"time": @22324567890}, @"#UUID": @"test-uuid", @"#SSUT": @"test-ssut3"};
    
    [client addEvent:event11 toEventCollection:@"foo1.bar1" error:nil];
    [client addEvent:event10 toEventCollection:@"foo1.bar1" error:nil];
    [client addEvent:event21 toEventCollection:@"foo2.bar2" error:nil];
    [client addEvent:event20 toEventCollection:@"foo2.bar2" error:nil];
    [client addEvent:event30 toEventCollection:@"foo3.bar3" error:nil];
    Boolean success = [client migrateDBToSupportIngest];
    
    XCTAssertTrue(success, @"migrateToVersion1 should returns true");
    XCTAssertEqual([[KeenClient getEventStore] getTotalEventCount], 5);

    NSDictionary *expect1 = @{@"key": @"value"};
    XCTAssertEqualObjects([self getEventOfCollection:@"foo1.bar1" atIndex:0], expect1);
    XCTAssertEqualObjects([self getEventOfCollection:@"foo1.bar1" atIndex:1], expect1);
    NSDictionary *expect2 = @{@"nested": @{@"keen": @"whatever"}, @"uuid": @"test-uuid"};
    XCTAssertEqualObjects([self getEventOfCollection:@"foo2.bar2" atIndex:0], expect2);
    XCTAssertEqualObjects([self getEventOfCollection:@"foo2.bar2" atIndex:1], expect2);
    NSDictionary *expect3 = @{@"key": @"value", @"key2": @"value2", @"uuid": @"test-uuid"};
    XCTAssertEqualObjects([self getEventOfCollection:@"foo3.bar3" atIndex:0], expect3);
}

- (void)testMigrateDBToSupportIngestWithEmptyEvents {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    NSDictionary *event00 = @{}; // Empty event will be removed
    NSDictionary *event01 = @{@"keen": @{@"time": @12324567890}, @"#UUID": @"test-uuid", @"#SSUT": @"test-ssut"}; // Empty event will be removed
    NSDictionary *event02 = @{@"key": @"value"}; // Only this event will be migrated
    
    [client addEvent:event00 toEventCollection:@"foo0.bar0" error:nil];
    [client addEvent:event01 toEventCollection:@"foo0.bar0" error:nil];
    [client addEvent:event02 toEventCollection:@"foo0.bar0" error:nil];
    Boolean success = [client migrateDBToSupportIngest];

    XCTAssertTrue(success, @"migrateToVersion1 should returns true");
    XCTAssertEqual([[KeenClient getEventStore] getTotalEventCount], 1);
}

- (void)testMigrateFSEventsInstanceClient {
    
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    // make sure the directory we want to write the file to exists
    NSString *dirPath = [self eventDirectoryForCollection:@"foo"];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    [manager createDirectoryAtPath:dirPath withIntermediateDirectories:true attributes:nil error:&error];
    XCTAssertNil(error, @"created directory for events");
    
    // Write out a couple of events that we can import later!
    NSDictionary *event1 = [NSDictionary dictionaryWithObject:@"apple" forKey:@"a"];
    NSDictionary *event2 = [NSDictionary dictionaryWithObject:@"orange" forKey:@"b"];
    
    NSData *json1 = [NSJSONSerialization dataWithJSONObject:event1 options:0 error:&error];
    NSData *json2 =[NSJSONSerialization dataWithJSONObject:event2 options:0 error:&error];
    
    NSString *fileName1 = [self pathForEventInCollection:@"foo" WithTimestamp:[NSDate date]];
    NSString *fileName2 = [self pathForEventInCollection:@"foo" WithTimestamp:[NSDate date]];
    
    [self writeNSData:json1 toFile:fileName1];
    [self writeNSData:json2 toFile:fileName2];
    
    [client importFileData];
    // Now we're gonna add an event and verify the events we just wrote to the fs
    // are added to the database and the files are cleaned up.
    error = nil;
    NSDictionary *event3 = @{@"nested": @{@"keen": @"whatever"}};
    [client addEvent:event3 toEventCollection:@"foo" error:nil];
    
    XCTAssertTrue([[KeenClient getEventStore] getTotalEventCount] == 3,  @"There should be 3 events after an import.");
    XCTAssertFalse([manager fileExistsAtPath:[self keenDirectory] isDirectory:true], @"The Keen directory should be gone.");
}

- (void)testSDKVersion {
    KeenClient *client = [KeenClient sharedClientWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    // result from class method should equal the SDK Version constant
    XCTAssertTrue([KeenClient sdkVersion] == kKeenSdkVersion,  @"SDK Version from class method equals the SDK Version constant.");
    XCTAssertFalse([KeenClient sdkVersion] != kKeenSdkVersion, @"SDK Version from class method doesn't equal the SDK Version constant.");
}

- (void)testSDKVersionInstanceClient {
    KeenClient *client = [[KeenClient alloc] initWithProjectId:@"id" andWriteKey:@"wk" andReadKey:@"rk"];
    client.isRunningTests = YES;
    
    // result from class method should equal the SDK Version constant
    XCTAssertTrue([KeenClient sdkVersion] == kKeenSdkVersion,  @"SDK Version from class method equals the SDK Version constant.");
    XCTAssertFalse([KeenClient sdkVersion] != kKeenSdkVersion, @"SDK Version from class method doesn't equal the SDK Version constant.");
}

# pragma mark - test filesystem utility methods

- (NSString *)cacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

- (NSString *)keenDirectory {
    return [[[self cacheDirectory] stringByAppendingPathComponent:@"keen"] stringByAppendingPathComponent:@"id"];
}

- (NSString *)eventDirectoryForCollection:(NSString *)collection {
    return [[self keenDirectory] stringByAppendingPathComponent:collection];
}

- (NSArray *)contentsOfDirectoryForCollection:(NSString *)collection {
    NSString *path = [self eventDirectoryForCollection:collection];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [manager contentsOfDirectoryAtPath:path error:&error];
    if (error) {
        XCTFail(@"Error when listing contents of directory for collection %@: %@",
               collection, [error localizedDescription]);
    }
    return contents;
}

- (NSString *)pathForEventInCollection:(NSString *)collection WithTimestamp:(NSDate *)timestamp {
    // get a file manager.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // determine the root of the filename.
    NSString *name = [NSString stringWithFormat:@"%f", [timestamp timeIntervalSince1970]];
    // get the path to the directory where the file will be written
    NSString *directory = [self eventDirectoryForCollection:collection];
    // start a counter that we'll use to make sure that even if multiple events are written with the same timestamp,
    // we'll be able to handle it.
    uint count = 0;

    // declare a tiny helper block to get the next path based on the counter.
    NSString * (^getNextPath)(uint count) = ^(uint count) {
        return [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%i", name, count]];
    };

    // starting with our root filename.0, see if a file exists.  if it doesn't, great.  but if it does, then go
    // on to filename.1, filename.2, etc.
    NSString *path = getNextPath(count);
    while ([fileManager fileExistsAtPath:path]) {
        count++;
        path = getNextPath(count);
    }

    return path;
}

- (BOOL)writeNSData:(NSData *)data toFile:(NSString *)file {
    // write file atomically so we don't ever have a partial event to worry about.
    Boolean success = [data writeToFile:file atomically:YES];
    if (!success) {
        KCLog(@"Error when writing event to file: %@", file);
        return NO;
    } else {
        KCLog(@"Successfully wrote event to file: %@", file);
    }
    return YES;
}

@end
