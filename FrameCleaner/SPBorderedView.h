//
//  SPBorderedView.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPBorderedView : NSView

@property (nonatomic, assign) NSInteger numberOfPoints;
@property (strong) NSMutableArray *data;

- (CGRect) cgrect;
- (BOOL) containsPoint:(CGPoint)point withInset:(CGFloat)inset;
- (CGFloat) areaWithPoint:(CGPoint)point;
- (CGFloat) area;
- (CGFloat) maxSideWithPoint:(CGPoint)point;
- (void) addPoint:(CGPoint)point;
- (CGRect) unionWithFrame:(CGRect)rect;
- (CGFloat) unionAreaWithFrame:(CGRect)rect;
- (void) mergeWithRegion:(SPBorderedView *)region;
- (void) reduceIfOverlaps:(SPBorderedView *)region;
- (NSInteger) overlapCount:(SPBorderedView *)region;
- (BOOL) overlaps:(SPBorderedView *)region;
- (NSRect) splitByRemovingRect:(NSRect)remove;

@end
