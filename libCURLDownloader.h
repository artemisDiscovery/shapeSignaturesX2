//
//  libCURLDownloader.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 7/18/10.
//  Copyright 2010 Artemis Discovery, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "platform.h"

#ifdef OSX
#include <curl/curl.h>
#define TAR_EXE @"/usr/bin/tar"
#define GUNZIP_EXE @"/usr/bin/gunzip"
#else
#include "/usr/include/curl/curl.h"
#define TAR_EXE @"/bin/tar"
#define GUNZIP_EXE @"/usr/bin/gunzip"
#endif


@interface libCURLDownloader : NSObject 
{
@public
	NSString *URL ;
	NSString *outputDirectory ;
}

- (id) initWithURL:(NSString *)arch ;
- (void) download ;

@end
