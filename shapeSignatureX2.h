//
//  shapeSignatureX2.h
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface shapeSignatureX2 : NSObject 
{
	// This is the second incarnation of the new shape sig X object. 
	// I am starting from scratch as I will now reatain both inter- and intra-
	// fragment information. 
	
		NSString *identifier ;
	
		ctTree *sourceTree ;
		
		// Signature bundles are represented by a tag - for example
		// 1DHISTO, 2DMEPHISTO, 2DMEPREDUCEDHISTO, etc. 
		// A 1D class maps to histogram dictionary with key GLOBAL (all reflection segments),
		// intrafragment keys like "1", "2", etc, and interfragment (as found) with 
		// keys like "1_3", etc. 
		// A 2D class maps to histogram dictionary with key GLOBAL (all pairs of segments bordering
		// a single reflection) and also to all intrafragment and inter-fragment keys 
		// (with values like "1", "2", "1_3", "3_5_6", etc). 
		
		// This dictionary points at other dictionaries
		
		NSMutableDictionary *histogramBundleForTag ;
		
		// Important new feature is linear ordering of fragments. Arrange this way:
		//
		// Na(Ra1,Ra2,...)Nb(Rb1,Rb2,...)Nc
		//
		// Algorithm - Find first ring with one or zero non-ring neigbors. This 
		// becomes one terminus of the chain (Ra1). Find all rings that neighbor the
		// initial non-ring fragment ; only one of these (Ra') may connect through 

}

@end
