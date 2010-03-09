//
//  fragmentConnection.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 3/8/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "fragmentConnection.h"


@implementation fragmentConnection

- (id) initWithFirst:(fragment *)f second:(fragment *)s 
	{
		self = [ super init ] ;
		
		active = NO ;
		
		first = f ;
		second = s ;
		
		firstIndex = f->index ;
		secondIndex = s->index ;
		
		[ f registerConnection:self ] ;
		[ s registerConnection:self ] ;
				
		return self ;
		
	}
	
- (void) dealloc
	{
		[ super dealloc ] ;
		
		return ;
	}


- (NSSet *) linkedFragments 
	{
		NSSet *returnSet = [ NSSet setWithObjects:first,second,nil ] ;
		
		return returnSet ;
	}

- (BOOL) includes:(fragment *) h 
	{
		if( first == h || second == h )
			{
				return YES ;
			}
			
		return NO ;
	}

- (BOOL) isEqualTo:(fragmentConnection * )c 
	{
		if( [ [ c linkedFragments ] member:first ] && [ [ c linkedFragments ] member:second ] )
			{
				return YES ;
			}
			
		return NO ;
	}
	
@end
