//
//  URLUploader.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 6/29/10.
//  Copyright 2010 Artemis Discovery, LLC. All rights reserved.
//

#import "URLUploader.h"
//#import "zlib.h"

static NSString * const BOUNDRY = @"0xKhTmLbOuNdArY";
static NSString * const FORM_FLE_INPUT = @"uploaded";

#define ASSERT(x) NSAssert(x, @"")






@implementation URLUploader

- (id)initWithURL: (NSURL *)aServerURL   // IN
         X2Signature: (NSString *)X2SigString // IN
         delegate: (id)aDelegate         // IN
     doneSelector: (SEL)aDoneSelector    // IN
    errorSelector: (SEL)anErrorSelector  // IN
{
	if ((self = [super init])) {
		ASSERT(aServerURL);
		ASSERT(X2SigString);
		ASSERT(aDelegate);
		ASSERT(aDoneSelector);
		ASSERT(anErrorSelector);
		
		serverURL = [aServerURL retain];
		X2SignatureData = [X2SigString retain];
		delegate = [aDelegate retain];
		doneSelector = aDoneSelector;
		errorSelector = anErrorSelector;
		
		[self upload];
	}
	return self;
}

- (void)dealloc
{
	[serverURL release];
	serverURL = nil;
	[X2SignatureData release];
	X2SignatureData = nil;
	[delegate release];
	delegate = nil;
	doneSelector = NULL;
	errorSelector = NULL;
	
	[super dealloc];
}

- (void)upload
{
	NSData *data = [ X2SignatureData dataWithEncoding:NSASCIIStringEncoding ] ;
	
	ASSERT(data);
	if (!data) {
		[self uploadSucceeded:NO];
		return;
	}
	if ([data length] == 0) {
		// There's no data, treat this the same as no file.
		[self uploadSucceeded:YES];
		return;
	}
	
	//NSData *compressedData = [self compress:data];
	//ASSERT(compressedData && [compressedData length] != 0);
	//if (!compressedData || [compressedData length] == 0) {
	//	[self uploadSucceeded:NO];
	//	return;
	//}
	
	NSURLRequest *urlRequest = [self postRequestWithURL:serverURL
												boundry:BOUNDRY
												   data:data];
	if (!urlRequest) {
		[self uploadSucceeded:NO];
		return;
	}
	
	NSURLConnection * connection =
	[[NSURLConnection alloc] initWithRequest:urlRequest delegate:self ];
	if (!connection) {
		[self uploadSucceeded:NO];
	}
	
	// Now wait for the URL connection to call us back.
}

- (NSURLRequest *)postRequestWithURL: (NSURL *)url        // IN
                             boundry: (NSString *)boundry // IN
                                data: (NSData *)data      // IN
{
	// from http://www.cocoadev.com/index.pl?HTTPFileUpload
	NSMutableURLRequest *urlRequest =
	[NSMutableURLRequest requestWithURL:url];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest setValue:
	 [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundry]
      forHTTPHeaderField:@"Content-Type"];
	
	NSMutableData *postData =
	[NSMutableData dataWithCapacity:[data length] + 512];
	[postData appendData:
	 [[NSString stringWithFormat:@"--%@\r\n", boundry] dataUsingEncoding:NSUTF8StringEncoding]];
	[postData appendData:
	 [[NSString stringWithFormat:
	   @"Content-Disposition: form-data; name=\"%@\"; filename=\"test.bin\"\r\n\r\n", FORM_FLE_INPUT]
	  dataUsingEncoding:NSUTF8StringEncoding]];
	[postData appendData:data];
	[postData appendData:
	 [[NSString stringWithFormat:@"\r\n--%@--\r\n", boundry] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[urlRequest setHTTPBody:postData];
	return urlRequest;
}

/*
- (NSData *)compress: (NSData *)data // IN
{
	if (!data || [data length] == 0)
		return nil;
	
	// zlib compress doc says destSize must be 1% + 12 bytes greater than source.
	uLong destSize = [data length] * 1.001 + 12;
	NSMutableData *destData = [NSMutableData dataWithLength:destSize];
	
	int error = compress([destData mutableBytes],
						 &destSize,
						 [data bytes],
						 [data length]);
	if (error != Z_OK) {
		printf( "zlib error on compress - Failed!\n" ) ;
		return nil;
	}
	
	[destData setLength:destSize];
	return destData;
}
*/

- (void)uploadSucceeded: (BOOL)success // IN
{
	[delegate performSelector:success ? doneSelector : errorSelector
				   withObject:self];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection // IN
{
	[connection release];
	[self uploadSucceeded:uploadDidSucceed];
}

- (void)connection:(NSURLConnection *)connection // IN
  didFailWithError:(NSError *)error              // IN
{
	printf( "CONNECTION FAILED WITH ERROR: %s\n", 
		[ [ error description ] cString ] ) ;
	
	[connection release];
	[self uploadSucceeded:NO];
}


-(void)       connection:(NSURLConnection *)connection // IN
      didReceiveResponse:(NSURLResponse *)response     // IN
{
	printf( "CONNECTION SUCCEEDED, CALLER: %s\n", __func__ ) ;
}

- (void)connection:(NSURLConnection *)connection // IN
    didReceiveData:(NSData *)data                // IN
{
	
	NSString *reply = [[[NSString alloc] initWithData:data
											 encoding:NSUTF8StringEncoding]
					   autorelease];
	
	if ([reply hasPrefix:@"YES"]) {
		uploadDidSucceed = YES;
	}
}


@end
