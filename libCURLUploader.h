//
//  CFUploader.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 7/6/10.
//  Copyright 2010 Artemis Discovery, LLC. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif


#ifdef OSX
#include <curl/curl.h>
#else
#include "/usr/include/curl/curl.h"
#endif


@interface libCURLUploader : NSObject 
{
	// This will use libCURL to implement shape signature upload
	// to a target URL, e.g. www.artemisdiscovery.com/uploadShapeSig.php 
	
	NSString *targetURL ;
	NSData *uploadData ;
	NSString *uploadFileName ;

}

- (id) initWithURL:(NSString *)url data:(NSData *)d fileName:(NSString *)name ;
- (void) upload ;


@end
