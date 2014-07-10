//
//  SPBorderedView.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPBorderedView : NSView

- (CGRect) bounds;
- (CGRect) unionWithBounds:(CGRect)rect;
- (CGFloat) unionAreaWithBounds:(CGRect)rect;
- (BOOL) containsPoint:(CGPoint)point withInset:(CGFloat)inset;
- (CGFloat) areaWithPoint:(CGPoint)point;
- (CGFloat) area;
- (CGFloat) maxSideWithPoint:(CGPoint)point;
- (void) setBounds:(CGRect)_bounds;
- (void) mergeWithRegion:(SPBorderedView *)region;
- (void) reduceIfOverlaps:(SPBorderedView *)region;
- (void) expandBoundsBy:(CGFloat)pixels toMaxSize:(CGSize)size;

@end
