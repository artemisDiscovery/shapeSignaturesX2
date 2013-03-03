//
//  scoringScheme.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 6/13/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "scoringScheme.h"


@implementation scoringScheme

@synthesize scoring ;
@synthesize switchThreshold ;
@synthesize useLogistic ;
@synthesize gamma ;

- (id) init
{
	self = [ super init ] ;
	
	scoring = RAW ;
	switchThreshold = 0.1 ;
	gamma = 1.0 ;
	useLogistic = NO ;
	
	return self ;
}

- (void) dealloc
{
	[ super dealloc ] ;
	return ;
}

@end
