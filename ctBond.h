//
//  ctBond.h
//  fftool
//
//  Created by Randy Zauhar on 5/11/09.
//  Copyright 2009 ArtemisDiscovery LLC. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "FFToolTypeDefs.h"


@class ctNode ;

@interface ctBond : NSObject 
{
		@public
		
		// This represents a physical bond in our tree structure - the image of stBond
		
		ctNode *node1, *node2 ;
		
		bondType type ;
		
		int closureIndex ;

}

- (id) initWithNode1:(ctNode *)n1 andNode2:(ctNode *)n2 andType:(bondType)t ;

- (ctNode *) startNode ;
- (ctNode *) endNode ;

- (char) returnBondSymbol ;

- (NSSet *) neighborNodes ;
- (NSSet *) neighborNodesWithBondType:(bondType)t ;

- (NSDictionary *) propertyListDict ;

- (id) initWithPropertyListDict:(NSDictionary *) pListDict andNodeTranslator:(NSDictionary *)nodeTran ;

@end
