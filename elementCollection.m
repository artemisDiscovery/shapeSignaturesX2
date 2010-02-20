//
//  elementCollection.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "elementCollection.h"


@implementation elementCollection

- (id) init
	{
		self = [ super init ] ;
		
		nAlloc = 10 ;
		
		nEle = 0 ;
		
		indices = (int *) malloc( nAlloc * sizeof( int ) ) ;
		
		return self ;
	}
	
- (void) dealloc
	{
		free( indices ) ;
		
		[ super dealloc ] ;
		
		return ;
	}
		
		

- (void) addIndex:(int) i
	{
		if( nEle == nAlloc )
			{
				nAlloc += 10 ;
				
				indices = (int *) realloc( indices, nAlloc * sizeof( int ) ) ;
			}
			
		indices[nEle] = i ;
		
		++nEle ;
		
		return ;
	}

- (int) count 
	{
		return nEle ;
	}

- (int *) indices 
	{
		return indices ;
	}

@end
