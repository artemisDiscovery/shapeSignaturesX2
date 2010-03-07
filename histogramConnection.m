//
//  histogramConnection.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "histogramConnection.h"


@implementation histogramConnection

- (id) initWithFirst:(histogram *)f second:(histogram *)s 
{
	self = [ super init ] ;
	
	active = NO ;
	
	first = f ;
	second = s ;
	
	[ f registerConnection:self ] ;
	[ s registerConnection:self ] ;
	
	return self ;
	
}


- (NSSet *) linkedHistograms 
{
	NSSet *returnSet = [ NSSet setWithObjects:first,second,nil ] ;
	
	return returnSet ;
}

- (BOOL) includes:(histogram *) h 
{
	if( first == h || second == h )
		{
			return YES ;
		}
		
	return NO ;
}

@end
