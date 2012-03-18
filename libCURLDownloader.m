//
//  libCURLDownloader.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 7/18/10.
//  Copyright 2010 Artemis Discovery, LLC. All rights reserved.
//

#import "libCURLDownloader.h"

struct MemoryStruct 
{
	char *memory;
	size_t size;
};

static void *myrealloc(void *ptr, size_t size);

static void *myrealloc(void *ptr, size_t size)
{
	/* There might be a realloc() out there that doesn't like reallocing
     NULL pointers, so we take care of it here */ 
	if(ptr)
		return realloc(ptr, size);
	else
		return malloc(size);
}

static size_t WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data)
{
	size_t realsize = size * nmemb;
	struct MemoryStruct *mem = (struct MemoryStruct *)data;
	
	mem->memory = myrealloc(mem->memory, mem->size + realsize + 1);
	if (mem->memory) {
		memcpy(&(mem->memory[mem->size]), ptr, realsize);
		mem->size += realsize;
		mem->memory[mem->size] = 0;
	}
	return realsize;
}


@implementation libCURLDownloader

- (id) initWithURL:(NSString *)arch 
{
	self = [ super init ] ;
	
	URL = [ arch retain ] ;
	outputDirectory = nil ;
	
	return self ;
	
}

- (void) dealloc 
{
	[ URL release ] ;
	
	[ super dealloc ] ;
}

- (void) download 
{
	
	// Check for existence of directory to be created
	
	// First, extract archive name from URL
	
	NSArray *urlComponents = [ URL componentsSeparatedByString:@"/" ] ;
	
	NSString *tarFileName = [ urlComponents lastObject ] ;
	
	BOOL decompress = NO ;
	NSString *tarName, *directoryName ;
	
	if( [ tarFileName hasSuffix:@".Z" ] == YES || [ tarFileName hasSuffix:@".gz" ] == YES )
		{
			decompress = YES ;
		
			tarName = [ tarFileName stringByDeletingPathExtension ] ;
		}
	else
		{
			tarName = tarFileName ;
		}
		
	if( [ tarName hasSuffix:@".tar" ] == NO )
		{
			printf( "ERROR - DOWNLOAD FILE %s DOES NOT APPEAR TO BE TAR ARCHIVE - Exit!\n",
					[ tarFileName cString ] ) ;
			exit(1) ;
		}
	
	directoryName = [ tarName stringByDeletingPathExtension ] ;
	
	NSFileManager *fileManager = [ NSFileManager defaultManager ] ;
	
	if( [ fileManager fileExistsAtPath:directoryName ] == YES )
		{
			printf( "ERROR - TARGET DIRECTORY %s ALREADY EXISTS - Exit!\n", [ directoryName cString ] ) ;
			exit(1) ;
		}
	
	
		
	
	CURL *curl_handle;
	
	struct MemoryStruct chunk;
	
	chunk.memory=NULL; /* we expect realloc(NULL, size) to work */ 
	chunk.size = 0;    /* no data at this point */ 
	
	curl_global_init(CURL_GLOBAL_ALL);
	
	/* init the curl session */ 
	curl_handle = curl_easy_init();
	
	/* specify URL to get */ 
	curl_easy_setopt(curl_handle, CURLOPT_URL, [ URL cString ] );
	
	/* Verbose for testing */
	curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 1);
	
	/* send all data to this function  */ 
	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
	
	/* we pass our 'chunk' struct to the callback function */ 
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *)&chunk);
	
	curl_easy_setopt(curl_handle, CURLOPT_INFILESIZE_LARGE, (curl_off_t)-1);  
	
	/* some servers don't like requests that are made without a user-agent
     field, so we provide one */ 
	//curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "libcurl-agent/1.0");
	
	/* get it! */ 
	curl_easy_perform(curl_handle);
	
	/* cleanup curl stuff */ 
	curl_easy_cleanup(curl_handle);
	
	/*
	 * Now, our chunk.memory points to a memory block that is chunk.size
	 * bytes big and contains the remote file.
	 *
	 * Do something nice with it!
	 *
	 * You should be aware of the fact that at this point we might have an
	 * allocated data block, and nothing has yet deallocated that data. So when
	 * you're done with it, you should free() it as a nice application.
	 */ 
	
	// Save to the download file name
	
	// Assume we are working in present working directory
	
	if( chunk.memory )
		{
			FILE *fp = fopen( [ tarFileName cString ], "w" ) ;
		
			int nWritten = fwrite( chunk.memory, sizeof( char ), chunk.size, fp ) ;
		
			fclose( fp ) ;
		
			if( nWritten != chunk.size )
				{
					printf( "ERROR WRITING TAR ARCHIVE %s TO LOCAL DIRECTORY - Exit!\n", [ tarFileName cString ] ) ;
					exit(1) ;
				}
		
			if( decompress == YES )
				{
					NSTask *decompressTask = [ NSTask launchedTaskWithLaunchPath:GUNZIP_EXE
																	   arguments:[ NSArray arrayWithObject:tarFileName ] ] ;
					
					[ decompressTask waitUntilExit ] ;
					
					if( [ decompressTask terminationStatus ] != 0 )
						{
							printf( "ERROR - DECOMPRESSION OF %s FAILED - Exit!\n", [ tarFileName cString ] ) ;
							exit(1) ;
						}
				}
		
			// Untar
		
			NSTask *untarTask = [ NSTask launchedTaskWithLaunchPath:TAR_EXE 
										arguments:[ NSArray arrayWithObjects:@"xf",tarName,nil ] ] ;
		
			[ untarTask waitUntilExit ] ;
			
			if( [ untarTask terminationStatus ] != 0 )
				{
					printf( "ERROR - TAR EXTRACTION OF %s FAILED - Exit!\n", [ tarName cString ] ) ;
					exit(1) ;
				}
		
			// Assume all is OK - set name of output directory, including path
		
			NSString *path = [ fileManager currentDirectoryPath ] ;
			outputDirectory = [ path stringByAppendingFormat:@"/%s/", 
							   [ directoryName cString ] ] ;
		
			free( chunk.memory ) ;
				
		}
	else
		{
			printf( "ERROR IN DOWNLOADING TAR ARCHIVE - Exit!\n" ) ;
			exit(1) ;
		}
	
	
	
	
	
	/* we're done with libcurl, so clean it up */ 
	curl_global_cleanup();
	
	return ;	
}

@end
