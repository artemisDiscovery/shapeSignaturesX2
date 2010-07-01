//
//  URLUploader.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 6/29/10.
//  Copyright 2010 Artemis Discovery, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


// This is based on sample code from the CocoaDev website (http://www.cocoadev.com/index.pl?HTTPFileUploadSample)

@interface URLUploader : NSObject 
{
	NSURL *serverURL;
	NSString *X2SignatureData ;
	id delegate ;
	SEL doneSelector ;
	SEL errorSelector ;
	
	BOOL uploadDidSucceed ;
	
}

- (id)initWithURL: (NSURL *)serverURL
         X2Signature: (NSString *)X2SigString
         delegate: (id)delegate
     doneSelector: (SEL)doneSelector
    errorSelector: (SEL)errorSelector;

- (void)upload;

- (NSURLRequest *)postRequestWithURL: (NSURL *)url
                             boundry: (NSString *)boundry
                                data: (NSData *)data;

- (NSData *)compress: (NSData *)data;
- (void)uploadSucceeded: (BOOL)success;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@end
