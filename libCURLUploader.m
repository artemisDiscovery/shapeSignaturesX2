//
//  CFUploader.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 7/6/10.
//  Copyright 2010 Artemis Discovery, LLC. All rights reserved.
//

#import "libCURLUploader.h"
#include <stdio.h>
#include <string.h>

#include "/usr/include/curl/curl.h"
//#include <curl/types.h>
#include "/usr/include/curl/easy.h"


@implementation libCURLUploader

- (id) initWithURL:(NSString *)url data:(NSData *)d fileName:(NSString *)name
{
    self = [ super init ] ;
	
	targetURL = [ url retain ] ;
	
	uploadData = [ d retain ] ;
	
	uploadFileName = [ name retain ] ;
    
    return self ;
}

- (void) dealloc
{
	[ targetURL release ] ;
	[ uploadData release ] ;
	[ uploadFileName release ] ;
	
	[ super dealloc ] ;
	
	return ;
}
	

- (void) upload 
{
	char * dataPtr = (char *)[ uploadData bytes ] ;
	
	// Will send this as part of a form
	
	CURL *curl;
	CURLcode res;
	
	struct curl_httppost *formpost=NULL;
	struct curl_httppost *lastptr=NULL;
	struct curl_slist *headerlist=NULL;
	
	curl_global_init(CURL_GLOBAL_ALL);
	
	curl = curl_easy_init() ;
	
	curl_easy_setopt( curl, CURLOPT_URL, [ targetURL cString ] );
	
	headerlist = curl_slist_append( headerlist, "Content-Type: application/octet-stream");
	
	char buffer[1000] ;
	
	sprintf( buffer, "Content-Length: %d", [ uploadData length ] ) ;
	
	headerlist = curl_slist_append( headerlist, buffer ) ;
	
	curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, buffer ) ;
	
	curl_easy_setopt( curl, CURLOPT_POSTFIELDS, dataPtr) ;
	
	curl_easy_setopt( curl, CURLOPT_POSTFIELDSIZE, [ uploadData length ] ) ;
	
	curl_easy_setopt( curl, CURLOPT_HTTPHEADER, headerlist) ;
	
	CURLcode result = curl_easy_perform( curl ) ;
	
	curl_slist_free_all(headerlist); /* free the header list */
	
	curl_easy_cleanup( curl ) ;
	
	curl_global_cleanup() ;
}
	

@end
