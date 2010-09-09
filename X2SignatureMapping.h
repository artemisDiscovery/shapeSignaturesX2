//
//  XSignatureMapping.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 10/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "shapeSignatureX2.h"
#import "histogramGroupBundle.h"

// This object defines a mapping between histogram group bundles, based on two X2Signatures

// In the case of global comparison, there is only one histogram comparison (the appopriate global histos)
// while in the case of a fragment-based histogram there will be an array of matches


@interface X2SignatureMapping : NSObject 
{
@public

	// A mapping is for a particular tag
	
	histogramGroupBundle *query, *target ;
	
	
	NSMutableArray *histoGroupPairs ;
	NSMutableSet *unpairedQueryHistoGroups, *unpairedTargetHistoGroups ;
	
	BOOL isMaximal ;

}

- (id) initWithMapping:(X2SignatureMapping *)map ;

- (id) initWithQuery:(histogramGroupBundle *)q andTarget:(histogramGroupBundle *)t  ;

- (BOOL) addMatchBetweenQueryHistoGroup:(histogramGroup *)q andTargetHistoGroup:(histogramGroup *)t ;

+ (NSMutableArray *) expandMappings:(NSMutableArray *)mappings ;

- (BOOL) isEqualToMapping:(X2SignatureMapping *)targetMap ;



@end
