//
//  ctNode.h
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

#import "ctBond.h"
#import "FFToolTypeDefs.h"
#include <string.h>


// This is a mirror of the stNode class. An instance represents a physical atom. 

@class stNode ;
@class ctTree ;

@interface ctNode : NSObject 
{
@public 
		
		int atomicNumber ;
		double atomicWeight ;
		char *element ;
		
		int index ;
		
		double coord[3] ;
		
		NSMutableDictionary *properties ;
		
		int currentAtomTypeIndex ;
		
		geometryType hybridization ;
		
		int valence ;
		
		double charge ;			// Should be integer?
		
		int nBonds, nBondAlloc ;
		
		ctBond **bonds ;
		
		BOOL *atBondStart ;
		
		stNode *matchNode ;
		
		int pathIndex ;
		
		int fragmentIndex ;
		ctTree *fragmentTree ;
		
		
		
		id displayAtom ;
		

}

- (id) initWithElement:(char *)e andIndex:(int)idx ;

- (void) addBond:(ctBond *)b ;

- (void) setCharge:(double)q ;

- (void) addPropertyValue:(char *)v forKey:(char *)k ;

- (char *) elementName ;

- (NSArray *) neighbors ;
- (NSArray *) neighborsExcludeBond:(ctBond *)excl  ;

- (NSArray *) neighborsWithPathIndexOtherThan:(int)excludePath ;

- (NSArray *) neighborsWithDifferentFragmentIndex ;

- (NSArray *) neighborsWithPathIndex:(int)includePath ;

- (ctBond *) returnBondWithNode:(ctNode *)n ;

- (void) setX:(double)x Y:(double)y Z:(double)z ;

- (void) assignToFragmentIndex:(int)f withFragmentType:(const char *)t ;

- (void) adjustFragmentIndex:(int)idx ;

- (NSString *) returnPropertyForKey:(NSString *)k ;

- (NSDictionary *) properties ;

- (BOOL) isRingNode ;

- (NSDictionary *) propertyListDict ;

- (id) initWithPropertyListDict:(NSDictionary *)pListDict ;

//- (void) printNode ;

@end
