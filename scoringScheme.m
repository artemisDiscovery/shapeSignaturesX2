//
//  scoringScheme.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 6/13/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "scoringScheme.h"


@implementation scoringScheme


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

- (scoreType) scoring 
	{
		return scoring ;
	}

- (BOOL) useLogistic 
	{
		return useLogistic ;
	}

- (double) switchThreshold 
	{
		return switchThreshold ;
	}

- (double) gamma 
	{
		return gamma ;
	}

- (void) setScoring:(scoreType)s 
	{
		scoring = s ;
		return ;
	}

- (void) setUseLogistic:(BOOL)u 
	{
		useLogistic = u ;
		return ;
	}

- (void) setSwitchThreshold:(double)t 
	{
		switchThreshold = t ;
		return ;
	}

- (void) setGamma:(double)g 
	{
		gamma = g ;
		return ;
	}


@end
